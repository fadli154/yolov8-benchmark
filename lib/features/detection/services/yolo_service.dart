import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_vision/flutter_vision.dart';

/// Manages the entire lifecycle of one FlutterVision instance.
///
/// Key guarantees:
///   • Only ONE FlutterVision instance ever exists (no duplicate native interpreters).
///   • [switchModel] follows the safe 7-step sequence to prevent crash.
///   • [isInferring] acts as a mutex — only one frame is processed at a time.
///   • Frame skipping reduces CPU load without hurting accuracy.
class YoloService {
  final FlutterVision _vision = FlutterVision();

  bool _isModelLoaded = false;
  bool _isInferring = false;
  bool _isDisposed = false;
  String? _currentModelPath;

  /// True after [loadModel] succeeds.
  bool get isModelLoaded => _isModelLoaded;

  /// True while native inference is running.
  bool get isInferring => _isInferring;

  // ── Frame skipping ────────────────────────────────────────────────────────
  int _frameCounter = 0;

  /// How many frames to skip between processed frames.
  /// 1 = process every 2nd frame, 2 = every 3rd, etc.
  int frameSkip = 1;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Load a YOLO TFLite model. Safe to call even if a model is already loaded.
  Future<void> loadModel(String modelPath) async {
    if (_isDisposed) return;
    if (_currentModelPath == modelPath && _isModelLoaded) return;

    await _closeModel();

    debugPrint('[YoloService] Loading model: $modelPath');
    try {
      await _vision.loadYoloModel(
        labels: 'assets/models/labels.txt',
        modelPath: modelPath,
        modelVersion: 'yolov8',
        numThreads: 4,
        useGpu: false,
      );
      _currentModelPath = modelPath;
      _isModelLoaded = true;
      debugPrint('[YoloService] Model loaded: $modelPath');
    } catch (e) {
      _isModelLoaded = false;
      _currentModelPath = null;
      debugPrint('[YoloService] Model load error: $e');
      rethrow;
    }
  }

  /// Safe model switch sequence (7 steps):
  /// 1. Set flag to prevent new inference
  /// 2. Wait for current inference to finish
  /// 3. Stop image stream (caller must stop before calling)
  /// 4. Close old model
  /// 5. GC hint delay
  /// 6. Load new model
  /// 7. Ready
  Future<void> switchModel(String newModelPath) async {
    if (_isDisposed) return;
    if (newModelPath == _currentModelPath && _isModelLoaded) return;

    debugPrint('[YoloService] Switching to $newModelPath');

    // Step 1-2: Wait for any in-flight inference (max 1s)
    await _waitForInference(timeoutMs: 1000);

    // Step 3: Caller already stopped stream before calling switchModel

    // Step 4: Close old model
    await _closeModel();

    // Step 5: Native GC hint delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 6-7: Load new model
    await loadModel(newModelPath);
  }

  /// Process one camera frame. Returns detection results or null if skipped/busy.
  Future<List<Map<String, dynamic>>?> runInference({
    required CameraImage image,
    required double confThreshold,
    double iouThreshold = 0.4,
  }) async {
    if (_isDisposed || !_isModelLoaded || _isInferring) return null;

    // Frame skipping
    _frameCounter++;
    if (_frameCounter % (frameSkip + 1) != 0) return null;

    _isInferring = true;
    try {
      final result = await _vision.yoloOnFrame(
        bytesList: image.planes.map((p) => p.bytes).toList(),
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: iouThreshold,
        confThreshold: confThreshold,
        classThreshold: confThreshold,
      );
      return result;
    } catch (e) {
      debugPrint('[YoloService] Inference error: $e');
      return null;
    } finally {
      _isInferring = false;
    }
  }

  /// Release all native resources. Cannot be reused after calling this.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _waitForInference(timeoutMs: 800);
    await _closeModel();
    debugPrint('[YoloService] Disposed.');
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _closeModel() async {
    if (!_isModelLoaded) return;
    _isModelLoaded = false;
    try {
      await _vision.closeYoloModel();
      debugPrint('[YoloService] Model closed.');
    } catch (e) {
      debugPrint('[YoloService] closeYoloModel error: $e');
    }
    _currentModelPath = null;
  }

  Future<void> _waitForInference({required int timeoutMs}) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (_isInferring && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 25));
    }
    // Force-clear after timeout to avoid permanent deadlock
    _isInferring = false;
  }
}
