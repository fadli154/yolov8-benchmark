import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/detection_controller.dart';
import '../widgets/bounding_boxes.dart';
import '../widgets/control_panel.dart';
import '../widgets/top_hud.dart';

/// Slim DetectionPage — just composes widgets.
/// All logic lives in DetectionController.
///
/// Lifecycle:
///   initState  → Get.put(DetectionController)  → onInit → services init
///   dispose    → Get.delete(DetectionController) → onClose → single cleanup
///   PopScope   → safeClose() ensures stream stops BEFORE navigation
class DetectionPage extends StatefulWidget {
  final String modelType;

  const DetectionPage({super.key, required this.modelType});

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  late final DetectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      DetectionController(initialModelType: widget.modelType),
    );
  }

  @override
  void dispose() {
    // Triggers DetectionController.onClose() → single cleanup path
    Get.delete<DetectionController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Safe close: stops stream, saves benchmark, disposes all services
        await _controller.safeClose();
        if (context.mounted) Get.back();
      },
      child: const Scaffold(
        backgroundColor: Colors.black,
        body: _DetectionBody(),
      ),
    );
  }
}

/// Stateless body — all state via Obx bindings to DetectionController.
class _DetectionBody extends StatelessWidget {
  const _DetectionBody();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<DetectionController>();

    return Obx(() {
      // ── Loading state ─────────────────────────────────────────────
      if (!c.isLoaded.value) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                  color: Color(0xFF10B981), strokeWidth: 2.5),
              SizedBox(height: 16),
              Text(
                'Initializing camera & model…',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        );
      }

      final camera = c.cameraController;
      final switching = c.isSwitchingModel.value;
      final closed = c.isPageClosed.value;

      return Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview or switching overlay ─────────────────
          if (closed || switching || camera == null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                      color: Color(0xFF10B981), strokeWidth: 2.5),
                  if (switching) ...[
                    const SizedBox(height: 14),
                    Obx(() => Text(
                          'Memuat ${c.modelDisplayName}…',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        )),
                  ],
                ],
              ),
            )
          else
            CameraPreview(camera),

          // ── Bounding boxes (only when actively scanning) ─────────
          if (!closed && !switching)
            const BoundingBoxesWidget(),

          // ── Top HUD ───────────────────────────────────────────────
          const TopHudWidget(),

          // ── Control panel ─────────────────────────────────────────
          const ControlPanelWidget(),
        ],
      );
    });
  }
}
