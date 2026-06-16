import 'dart:ui';

class Detection {
  final Rect boundingBox; // Normalized [0.0, 1.0] relative to portrait screen orientation
  final String className;
  final double confidence;

  Detection({
    required this.boundingBox,
    required this.className,
    required this.confidence,
  });
}
