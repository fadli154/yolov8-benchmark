import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/yolo_service.dart';
import '../services/camera_service.dart';
import '../services/tts_service.dart';
import '../services/benchmark_service.dart';

/// GetxController that orchestrates all detection services.
///
/// Design guarantees:
///   • All reactive state via Rx — zero setState() calls anywhere.
///   • Single cleanup path via [safeClose] + [onClose].
///   • Model switching follows safe 7-step sequence.
///   • Card expand/collapse uses RxBool — only that widget rebuilds.
///   • Uses globally registered DetectionBenchmarkService (Get.find).
class DetectionController extends GetxController {
  final String initialModelType;

  DetectionController({required this.initialModelType});

  // ── Services ──────────────────────────────────────────────────────────────
  final _yolo = YoloService();
  final _camera = DetectionCameraService();
  final _tts = DetectionTtsService();
  // Uses globally registered service (registered in main.dart)
  late final DetectionBenchmarkService _benchmark;

  // ── Reactive state ────────────────────────────────────────────────────────
  final isLoaded = false.obs;
  final isRealtime = false.obs;
  final isSwitchingModel = false.obs;
  final isPageClosed = false.obs;

  final currentModelType = ''.obs;
  final yoloResults = <Map<String, dynamic>>[].obs;

  final currentFps = 0.0.obs;
  final currentLatency = 0.0.obs;
  final currentRam = 0.0.obs;

  final selectedBackend = 'CPU'.obs;
  final activeBackendType = 'CPU'.obs;
  final activeBackendStatus = 'CPU active'.obs;

  // Card expand/collapse — targeted Obx avoids full-tree rebuilds
  final topCardExpanded = true.obs;
  final controlCardExpanded = true.obs;

  // Controls
  final voiceEnabled = true.obs;
  final confThreshold = 0.5.obs;
  final speechRate = 0.4.obs;
  final speakCooldown = 3000.obs; // ms

  // ── Computed getters ──────────────────────────────────────────────────────
  CameraController? get cameraController => _camera.controller;

  String get modelPath => currentModelType.value == 'nano'
      ? 'assets/models/best_yolov8n.tflite'
      : 'assets/models/best_yolov8s.tflite';

  String get modelDisplayName => currentModelType.value == 'nano'
      ? 'YOLOv8n (Nano)'
      : 'YOLOv8s (Small)';

  // ── Private counters ──────────────────────────────────────────────────────
  int _inferenceCount = 0;
  DateTime? _fpsWindowStart;
  Timer? _ramTimer;
  bool _cleanupDone = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    // Use globally registered benchmark service
    _benchmark = Get.find<DetectionBenchmarkService>();

    currentModelType.value = initialModelType;
    _yolo.frameSkip = initialModelType == 'nano' ? 1 : 2;

    _benchmark.loadFromStorage();
    _initAll();
  }

  @override
  void onClose() {
    _internalCleanup();
    super.onClose();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _initAll() async {
    try {
      await _tts.initialize(speechRate: speechRate.value);
      await _camera.initialize();
      await _yolo.loadModel(modelPath, backend: selectedBackend.value);
      activeBackendType.value = _yolo.activeBackendType;
      activeBackendStatus.value = _yolo.activeBackendStatus;
      _benchmark.startSession();
      _startRamPolling();
      isLoaded.value = true;
      await startRealtime();
    } catch (e) {
      debugPrint('[DetectionController] Init error: $e');
    }
  }

  // ── Realtime detection ────────────────────────────────────────────────────

  Future<void> startRealtime() async {
    if (isRealtime.value || _cleanupDone) return;
    isRealtime.value = true;
    _fpsWindowStart = null;
    _inferenceCount = 0;
    await _camera.startImageStream(_onCameraFrame);
  }

  Future<void> stopRealtime() async {
    if (!isRealtime.value) return;
    isRealtime.value = false;
    await _camera.stopImageStream();
    yoloResults.value = [];
  }

  void _onCameraFrame(CameraImage image) async {
    if (_cleanupDone || !isRealtime.value) return;

    final sw = Stopwatch()..start();
    final result = await _yolo.runInference(
      image: image,
      confThreshold: confThreshold.value,
    );
    sw.stop();

    if (result == null || _cleanupDone) return;

    // ── FPS calculation (1-second sliding window) ─────────────────────────
    final latency = sw.elapsedMilliseconds.toDouble();
    currentLatency.value = latency;

    _inferenceCount++;
    final now = DateTime.now();
    _fpsWindowStart ??= now;
    final elapsedMs = now.difference(_fpsWindowStart!).inMilliseconds;
    if (elapsedMs >= 1000) {
      currentFps.value = _inferenceCount * 1000.0 / elapsedMs;
      _inferenceCount = 0;
      _fpsWindowStart = now;
    }

    // ── Benchmark recording ───────────────────────────────────────────────
    _benchmark.recordFrame(
      fps: currentFps.value,
      latencyMs: latency,
      ramMb: currentRam.value,
      objectCount: result.length,
    );

    // ── Update detections (targeted Obx rebuild) ──────────────────────────
    yoloResults.value = result;

    // ── TTS ───────────────────────────────────────────────────────────────
    if (result.isNotEmpty && voiceEnabled.value) {
      final tag = result.first['tag'] as String;
      await _tts.speak(tag, cooldownMs: speakCooldown.value);
    }
  }

  // ── Model switching ───────────────────────────────────────────────────────

  Future<void> switchModel() async {
    if (isSwitchingModel.value || _cleanupDone) return;

    final newType = currentModelType.value == 'nano' ? 'small' : 'nano';
    final newPath = newType == 'nano'
        ? 'assets/models/best_yolov8n.tflite'
        : 'assets/models/best_yolov8s.tflite';

    isSwitchingModel.value = true;

    // 1. Save current session before switch
    await _saveSession();

    // 2. Stop stream
    isRealtime.value = false;
    await _camera.stopImageStream();

    // 3. Reset display state
    yoloResults.value = [];
    currentFps.value = 0.0;
    currentLatency.value = 0.0;
    _inferenceCount = 0;
    _fpsWindowStart = null;

    try {
      // 4. Safe 7-step model switch (YoloService handles steps 4-7)
      await _yolo.switchModel(newPath, backend: selectedBackend.value);
      currentModelType.value = newType;
      _yolo.frameSkip = newType == 'nano' ? 1 : 2;
      activeBackendType.value = _yolo.activeBackendType;
      activeBackendStatus.value = _yolo.activeBackendStatus;

      // 5. Start new benchmark session
      _benchmark.startSession();
      _benchmark.resetSessionTimer();
    } catch (e) {
      debugPrint('[DetectionController] switchModel error: $e');
    }

    isSwitchingModel.value = false;

    if (!_cleanupDone) {
      await startRealtime();
    }
  }

  Future<void> changeBackend(String backend) async {
    if (isSwitchingModel.value || _cleanupDone) return;
    if (selectedBackend.value == backend) return;

    selectedBackend.value = backend;
    isSwitchingModel.value = true;

    // 1. Save current session before switch
    await _saveSession();

    // 2. Stop stream
    isRealtime.value = false;
    await _camera.stopImageStream();

    // 3. Reset display state
    yoloResults.value = [];
    currentFps.value = 0.0;
    currentLatency.value = 0.0;
    _inferenceCount = 0;
    _fpsWindowStart = null;

    try {
      // Rebuild interpreter with same model but different backend
      await _yolo.loadModel(modelPath, backend: backend);
      activeBackendType.value = _yolo.activeBackendType;
      activeBackendStatus.value = _yolo.activeBackendStatus;

      // 5. Start new benchmark session
      _benchmark.startSession();
      _benchmark.resetSessionTimer();
    } catch (e) {
      debugPrint('[DetectionController] changeBackend error: $e');
    }

    isSwitchingModel.value = false;

    if (!_cleanupDone) {
      await startRealtime();
    }
  }

  // ── RAM polling ───────────────────────────────────────────────────────────

  void _startRamPolling() {
    _ramTimer?.cancel();
    _ramTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_cleanupDone) return;
      final ram = await _benchmark.getMemoryUsageMb();
      if (!_cleanupDone) currentRam.value = ram;
    });
  }

  // ── Benchmark ─────────────────────────────────────────────────────────────

  Future<void> _saveSession() async {
    if (!_benchmark.hasSessionData) return;
    final sizeMb = await _benchmark.getModelSizeMb(modelPath);
    await _benchmark.saveSession(
      modelName: modelDisplayName,
      modelSizeMb: sizeMb,
      backendType: activeBackendType.value,
      backendStatus: activeBackendStatus.value,
    );
  }

  // ── TTS control ───────────────────────────────────────────────────────────

  Future<void> updateSpeechRate(double rate) async {
    speechRate.value = rate;
    await _tts.setSpeechRate(rate);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Called by PopScope before Get.back(). Guard ensures single call.
  Future<void> safeClose() async => _internalCleanup();

  Future<void> _internalCleanup() async {
    if (_cleanupDone) return;
    _cleanupDone = true;

    _ramTimer?.cancel();
    isPageClosed.value = true;
    isRealtime.value = false;

    // Save benchmark before closing
    await _saveSession();

    // Ordered teardown — stream before model before camera
    await _camera.stopImageStream();
    await _yolo.dispose();     // waits for inference + closes model
    await _camera.dispose();   // disposes CameraController
    await _tts.dispose();      // stops TTS

    debugPrint('[DetectionController] Cleanup complete.');
  }

  // ── Benchmark accessor (for external use) ─────────────────────────────────
  DetectionBenchmarkService get benchmarkService => _benchmark;
}
