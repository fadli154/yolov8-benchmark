import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Manages CameraController lifecycle.
///
/// Key guarantees:
///   • Single cleanup path prevents double-dispose freeze.
///   • stopImageStream is always awaited before dispose.
///   • ResolutionPreset.medium balances quality and CPU cost.
class DetectionCameraService {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isDisposing = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Initialize the back camera at medium resolution (best FPS/quality balance).
  Future<void> initialize() async {
    if (_isInitialized && _controller != null) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras found on this device.');

    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      backCamera,
      // medium = ~640×480 on most Android SoCs
      // ↑ better FPS vs 'high', still enough resolution for YOLO at 640px input
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // native format — zero conversion cost
    );

    await _controller!.initialize();

    // Disable auto-focus chasing that causes periodic frame-rate drops
    try {
      await _controller!.setFocusMode(FocusMode.auto);
    } catch (_) {}

    // Disable flash
    try {
      await _controller!.setFlashMode(FlashMode.off);
    } catch (_) {}

    _isInitialized = true;
    debugPrint('[CameraService] Initialized @ medium resolution.');
  }

  /// Start image stream. [onFrame] called for every incoming camera frame.
  Future<void> startImageStream(Function(CameraImage) onFrame) async {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isStreamingImages) return;

    await _controller!.startImageStream(onFrame);
    debugPrint('[CameraService] Image stream started.');
  }

  /// Stop image stream. Safe to call even if not streaming.
  Future<void> stopImageStream() async {
    if (_controller == null) return;
    if (!_controller!.value.isStreamingImages) return;
    try {
      await _controller!.stopImageStream();
      debugPrint('[CameraService] Image stream stopped.');
    } catch (e) {
      debugPrint('[CameraService] stopImageStream error: $e');
    }
  }

  /// Full disposal. Stops stream, then disposes controller.
  Future<void> dispose() async {
    if (_isDisposing) return;
    _isDisposing = true;
    _isInitialized = false;

    final ctrl = _controller;
    _controller = null;

    if (ctrl != null) {
      await _stopStreamSafe(ctrl);
      try {
        await ctrl.dispose();
        debugPrint('[CameraService] Controller disposed.');
      } catch (e) {
        debugPrint('[CameraService] dispose error: $e');
      }
    }
    _isDisposing = false;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _stopStreamSafe(CameraController ctrl) async {
    try {
      if (ctrl.value.isStreamingImages) {
        await ctrl.stopImageStream();
      }
    } catch (e) {
      debugPrint('[CameraService] stopStream in dispose error: $e');
    }
  }
}
