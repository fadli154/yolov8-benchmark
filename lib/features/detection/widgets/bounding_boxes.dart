import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/detection_controller.dart';

class BoundingBoxesWidget extends StatelessWidget {
  const BoundingBoxesWidget({super.key});

  static const Map<String, Color> _classColors = {
    'kaca': Color(0xFF06B6D4),
    'kertas': Color(0xFF3B82F6),
    'logam': Color(0xFFEF4444),
    'plastik': Color(0xFFF59E0B),
  };

  @override
  Widget build(BuildContext context) {
    final c = Get.find<DetectionController>();

    return Obx(() {
      if (c.yoloResults.isEmpty ||
          c.cameraController == null ||
          !c.cameraController!.value.isInitialized) {
        return const SizedBox.shrink();
      }

      final controller = c.cameraController!;
      final previewSize = controller.value.previewSize;
      if (previewSize == null) return const SizedBox.shrink();

      final screenSize = MediaQuery.sizeOf(context);

      // Camera preview is landscape; the stream shown in portrait needs this swap.
      final previewWidth = previewSize.height.toDouble();
      final previewHeight = previewSize.width.toDouble();

      // Keep the same geometry as the preview display.
      final scaleX = screenSize.width / previewWidth;
      final scaleY = screenSize.height / previewHeight;

      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: c.yoloResults.map((result) {
            final rawBox = result['box'] as List<dynamic>;
            final tag = (result['tag'] ?? '').toString().toLowerCase().trim();

            if (rawBox.length < 4) {
              return const SizedBox.shrink();
            }

            // LOG KAMU MENUNJUKKAN FORMAT INI:
            // [x1, y1, x2, y2, conf]
            final x1 = (rawBox[0] as num).toDouble();
            final y1 = (rawBox[1] as num).toDouble();
            final x2 = (rawBox[2] as num).toDouble();
            final y2 = (rawBox[3] as num).toDouble();

            final confidence = rawBox.length > 4
                ? (rawBox[4] as num).toDouble()
                : 0.0;

            // Convert XYXY -> XYWH
            final boxWidth = (x2 - x1).abs();
            final boxHeight = (y2 - y1).abs();

            // Scale from model/image coordinate space to screen space
            final left = x1 * scaleX;
            final top = y1 * scaleY;
            final width = boxWidth * scaleX;
            final height = boxHeight * scaleY;

            final color = _classColors[tag] ?? Colors.greenAccent;

            return Positioned(
              left: left.clamp(0.0, screenSize.width - 2),
              top: top.clamp(0.0, screenSize.height - 2),
              width: width.clamp(10.0, screenSize.width),
              height: height.clamp(10.0, screenSize.height),
              child: _BoundingBox(
                label: result['tag'].toString(),
                confidence: confidence,
                color: color,
              ),
            );
          }).toList(),
        ),
      );
    });
  }
}

class _BoundingBox extends StatelessWidget {
  final String label;
  final double confidence;
  final Color color;

  const _BoundingBox({
    required this.label,
    required this.confidence,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final confText = confidence > 0
        ? '${(confidence * 100).toStringAsFixed(0)}%'
        : '';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2.5),
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.08),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(8),
              topLeft: Radius.circular(6),
            ),
          ),
          child: Text(
            confText.isEmpty ? label : '$label $confText',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              shadows: [Shadow(blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }
}
