import 'dart:math';

/// Full benchmark data for a single model session.
/// Contains all raw records plus computed statistics for journal analysis.
class ModelBenchmarkData {
  final String modelName;
  final List<double> fpsRecords;
  final List<double> latencyRecords;
  final List<double> ramRecords;
  final List<int> objectsRecords;
  final double modelSizeMb;
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final int totalInferenceCount;

  const ModelBenchmarkData({
    required this.modelName,
    required this.fpsRecords,
    required this.latencyRecords,
    required this.ramRecords,
    required this.objectsRecords,
    required this.modelSizeMb,
    required this.sessionStart,
    required this.sessionEnd,
    required this.totalInferenceCount,
  });

  // ── FPS ───────────────────────────────────────────────────────────────────

  double get averageFps {
    if (fpsRecords.isEmpty) return 0.0;
    return fpsRecords.reduce((a, b) => a + b) / fpsRecords.length;
  }

  double get minFps {
    if (fpsRecords.isEmpty) return 0.0;
    return fpsRecords.reduce(min);
  }

  double get maxFps {
    if (fpsRecords.isEmpty) return 0.0;
    return fpsRecords.reduce(max);
  }

  // ── Latency ───────────────────────────────────────────────────────────────

  double get averageLatency {
    if (latencyRecords.isEmpty) return 0.0;
    return latencyRecords.reduce((a, b) => a + b) / latencyRecords.length;
  }

  double get minLatency {
    if (latencyRecords.isEmpty) return 0.0;
    return latencyRecords.reduce(min);
  }

  double get maxLatency {
    if (latencyRecords.isEmpty) return 0.0;
    return latencyRecords.reduce(max);
  }

  // ── RAM ───────────────────────────────────────────────────────────────────

  double get averageRam {
    if (ramRecords.isEmpty) return 0.0;
    return ramRecords.reduce((a, b) => a + b) / ramRecords.length;
  }

  double get peakRam {
    if (ramRecords.isEmpty) return 0.0;
    return ramRecords.reduce(max);
  }

  // ── Objects ───────────────────────────────────────────────────────────────

  double get averageObjects {
    if (objectsRecords.isEmpty) return 0.0;
    return objectsRecords.reduce((a, b) => a + b) / objectsRecords.length;
  }

  /// Percentage of frames where at least 1 object was detected.
  double get detectionSuccessRate {
    if (objectsRecords.isEmpty) return 0.0;
    final detected = objectsRecords.where((o) => o > 0).length;
    return detected / objectsRecords.length;
  }

  // ── Session ───────────────────────────────────────────────────────────────

  int get sessionDurationSeconds =>
      sessionEnd.difference(sessionStart).inSeconds;

  // ── FPS stability (1 - coefficient of variation) ─────────────────────────

  /// 1.0 = perfectly stable FPS, 0.0 = very unstable.
  double get fpsStability {
    if (fpsRecords.length < 2) return 1.0;
    final mean = averageFps;
    if (mean == 0) return 0.0;
    final variance = fpsRecords
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        fpsRecords.length;
    final cv = sqrt(variance) / mean;
    return (1.0 - cv.clamp(0.0, 1.0));
  }

  // ── FPS timeline (sampled for chart — max 60 points) ─────────────────────

  List<double> get fpsTimeline {
    if (fpsRecords.isEmpty) return [];
    if (fpsRecords.length <= 60) return List.from(fpsRecords);
    final step = fpsRecords.length / 60;
    return List.generate(
      60,
      (i) => fpsRecords[(i * step).floor()],
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'fpsRecords': fpsRecords,
        'latencyRecords': latencyRecords,
        'ramRecords': ramRecords,
        'objectsRecords': objectsRecords,
        'modelSizeMb': modelSizeMb,
        'sessionStart': sessionStart.toIso8601String(),
        'sessionEnd': sessionEnd.toIso8601String(),
        'totalInferenceCount': totalInferenceCount,
      };

  factory ModelBenchmarkData.fromJson(Map<String, dynamic> json) {
    return ModelBenchmarkData(
      modelName: json['modelName'] as String,
      fpsRecords: (json['fpsRecords'] as List).cast<double>(),
      latencyRecords: (json['latencyRecords'] as List).cast<double>(),
      ramRecords: (json['ramRecords'] as List).cast<double>(),
      objectsRecords: (json['objectsRecords'] as List).cast<int>(),
      modelSizeMb: (json['modelSizeMb'] as num).toDouble(),
      sessionStart: DateTime.parse(json['sessionStart'] as String),
      sessionEnd: DateTime.parse(json['sessionEnd'] as String),
      totalInferenceCount: json['totalInferenceCount'] as int,
    );
  }
}
