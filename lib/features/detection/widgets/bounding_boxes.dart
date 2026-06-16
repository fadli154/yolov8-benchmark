import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/detection_controller.dart';

/// Renders YOLO detection bounding boxes over the camera preview.
/// Uses Obx — only rebuilds when yoloResults changes.
class BoundingBoxesWidget extends StatelessWidget {
  const BoundingBoxesWidget({super.key});

  static const Map<String, Color> _classColors = {
    'kaca': Color(0xFF06B6D4),     // Cyan
    'kertas': Color(0xFF3B82F6),   // Blue
    'logam': Color(0xFFEF4444),    // Red
    'plastik': Color(0xFFF59E0B),  // Amber
  };

  @override
  Widget build(BuildContext context) {
    final c = Get.find<DetectionController>();

    return Obx(() {
      if (c.yoloResults.isEmpty || c.cameraController == null) {
        return const SizedBox.shrink();
      }

      final screen = MediaQuery.sizeOf(context);
      final previewSize = c.cameraController!.value.previewSize;
      if (previewSize == null) return const SizedBox.shrink();

      // Camera stream is landscape on Android; preview is rotated to portrait.
      // previewSize.height = camera width → maps to screen width
      // previewSize.width  = camera height → maps to screen height
      final scaleX = screen.width / previewSize.height;
      final scaleY = screen.height / previewSize.width;

      return Stack(
        children: c.yoloResults.map((r) {
          final box = r['box'] as List<dynamic>;
          final tag = (r['tag'] as String).toLowerCase().trim();
          final conf = box.length > 4 ? (box[4] as num).toDouble() : 0.0;

          final double x = (box[0] as num).toDouble() * scaleX;
          final double y = (box[1] as num).toDouble() * scaleY;
          final double w = (box[2] as num).toDouble() * scaleX;
          final double h = (box[3] as num).toDouble() * scaleY;

          final color = _classColors[tag] ?? const Color(0xFF10B981);

          return Positioned(
            left: x.clamp(0.0, screen.width - 2),
            top: y.clamp(0.0, screen.height - 2),
            width: w.clamp(10.0, screen.width),
            height: h.clamp(10.0, screen.height),
            child: _BoundingBox(
              label: r['tag'] as String,
              confidence: conf,
              color: color,
            ),
          );
        }).toList(),
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
