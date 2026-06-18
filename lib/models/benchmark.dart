import 'dart:math';

// ═══════════════════════════════════════════════════════════════════════════════
// ModelBenchmarkData — Legacy single-session model (kept for compatibility)
// ═══════════════════════════════════════════════════════════════════════════════

/// Full benchmark data for a single model session (legacy format).
/// Still used by DetectionController for passive recording during detection.
class ModelBenchmarkData {
  final String modelName;
  final String backendType;
  final String backendStatus;
  final String deviceInfo;
  final String androidVersion;
  final DateTime benchmarkTimestamp;
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
    required this.backendType,
    required this.backendStatus,
    required this.deviceInfo,
    required this.androidVersion,
    required this.benchmarkTimestamp,
    required this.fpsRecords,
    required this.latencyRecords,
    required this.ramRecords,
    required this.objectsRecords,
    required this.modelSizeMb,
    required this.sessionStart,
    required this.sessionEnd,
    required this.totalInferenceCount,
  });

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

  double get averageRam {
    if (ramRecords.isEmpty) return 0.0;
    return ramRecords.reduce((a, b) => a + b) / ramRecords.length;
  }

  double get peakRam {
    if (ramRecords.isEmpty) return 0.0;
    return ramRecords.reduce(max);
  }

  double get averageObjects {
    if (objectsRecords.isEmpty) return 0.0;
    return objectsRecords.reduce((a, b) => a + b) / objectsRecords.length;
  }

  double get detectionSuccessRate {
    if (objectsRecords.isEmpty) return 0.0;
    final detected = objectsRecords.where((o) => o > 0).length;
    return detected / objectsRecords.length;
  }

  int get maxObjects {
    if (objectsRecords.isEmpty) return 0;
    return objectsRecords.reduce(max);
  }

  int get minObjects {
    if (objectsRecords.isEmpty) return 0;
    return objectsRecords.reduce(min);
  }

  int get sessionDurationSeconds =>
      sessionEnd.difference(sessionStart).inSeconds;

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

  List<double> get fpsTimeline {
    if (fpsRecords.isEmpty) return [];
    if (fpsRecords.length <= 60) return List.from(fpsRecords);
    final step = fpsRecords.length / 60;
    return List.generate(60, (i) => fpsRecords[(i * step).floor()]);
  }

  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'backendType': backendType,
        'backendStatus': backendStatus,
        'deviceInfo': deviceInfo,
        'androidVersion': androidVersion,
        'benchmarkTimestamp': benchmarkTimestamp.toIso8601String(),
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
      backendType: json['backendType'] as String? ?? 'CPU',
      backendStatus:
          json['backendStatus'] as String? ?? 'Unknown (legacy benchmark)',
      deviceInfo: json['deviceInfo'] as String? ?? 'Unknown',
      androidVersion: json['androidVersion'] as String? ?? 'Unknown',
      benchmarkTimestamp: json['benchmarkTimestamp'] != null
          ? DateTime.parse(json['benchmarkTimestamp'] as String)
          : (json['sessionStart'] != null
              ? DateTime.parse(json['sessionStart'] as String)
              : DateTime.now()),
      fpsRecords: (json['fpsRecords'] as List).cast<double>(),
      latencyRecords: (json['latencyRecords'] as List).cast<double>(),
      ramRecords: (json['ramRecords'] as List).cast<double>(),
      objectsRecords: (json['objectsRecords'] as List).cast<int>(),
      modelSizeMb: (json['modelSizeMb'] as num).toDouble(),
      sessionStart: json['sessionStart'] != null
          ? DateTime.parse(json['sessionStart'] as String)
          : DateTime.now(),
      sessionEnd: json['sessionEnd'] != null
          ? DateTime.parse(json['sessionEnd'] as String)
          : DateTime.now(),
      totalInferenceCount: json['totalInferenceCount'] as int? ?? 0,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BenchmarkRun — One timed, deliberate benchmark run
// ═══════════════════════════════════════════════════════════════════════════════

/// Represents a single deliberate benchmark run with configurable duration.
/// Warm-up frames are tracked but excluded from the recorded metrics.
class BenchmarkRun {
  final int runIndex;
  final String modelName;
  final String backendType;
  final String backendStatus;
  final String deviceInfo;
  final String androidVersion;
  final int durationMinutes;
  final int warmupFrames;
  final List<double> fpsRecords;
  final List<double> latencyRecords;
  final List<double> ramRecords;
  final List<int> objectsRecords;
  final double modelSizeMb;
  final DateTime runTimestamp;
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final int totalInferenceCount;

  const BenchmarkRun({
    required this.runIndex,
    required this.modelName,
    required this.backendType,
    required this.backendStatus,
    required this.deviceInfo,
    required this.androidVersion,
    required this.durationMinutes,
    required this.warmupFrames,
    required this.fpsRecords,
    required this.latencyRecords,
    required this.ramRecords,
    required this.objectsRecords,
    required this.modelSizeMb,
    required this.runTimestamp,
    required this.sessionStart,
    required this.sessionEnd,
    required this.totalInferenceCount,
  });

  // ── Key for grouping (model+backend) ──────────────────────────────────────

  String get groupKey => '$modelName|$backendType';

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

  double get detectionSuccessRate {
    if (objectsRecords.isEmpty) return 0.0;
    final detected = objectsRecords.where((o) => o > 0).length;
    return detected / objectsRecords.length;
  }

  int get maxObjects {
    if (objectsRecords.isEmpty) return 0;
    return objectsRecords.reduce(max);
  }

  int get minObjects {
    if (objectsRecords.isEmpty) return 0;
    return objectsRecords.reduce(min);
  }

  // ── Session ───────────────────────────────────────────────────────────────

  int get sessionDurationSeconds =>
      sessionEnd.difference(sessionStart).inSeconds;

  // ── FPS Stability ─────────────────────────────────────────────────────────

  double get fpsStability {
    if (fpsRecords.length < 2) return 1.0;
    final m = averageFps;
    if (m == 0) return 0.0;
    final variance =
        fpsRecords.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) /
            fpsRecords.length;
    final cv = sqrt(variance) / m;
    return (1.0 - cv.clamp(0.0, 1.0));
  }

  // ── FPS Timeline (sampled) ────────────────────────────────────────────────

  List<double> get fpsTimeline {
    if (fpsRecords.isEmpty) return [];
    if (fpsRecords.length <= 60) return List.from(fpsRecords);
    final step = fpsRecords.length / 60;
    return List.generate(60, (i) => fpsRecords[(i * step).floor()]);
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'runIndex': runIndex,
        'modelName': modelName,
        'backendType': backendType,
        'backendStatus': backendStatus,
        'deviceInfo': deviceInfo,
        'androidVersion': androidVersion,
        'durationMinutes': durationMinutes,
        'warmupFrames': warmupFrames,
        'fpsRecords': fpsRecords,
        'latencyRecords': latencyRecords,
        'ramRecords': ramRecords,
        'objectsRecords': objectsRecords,
        'modelSizeMb': modelSizeMb,
        'runTimestamp': runTimestamp.toIso8601String(),
        'sessionStart': sessionStart.toIso8601String(),
        'sessionEnd': sessionEnd.toIso8601String(),
        'totalInferenceCount': totalInferenceCount,
      };

  factory BenchmarkRun.fromJson(Map<String, dynamic> json) {
    List<double> doubleList(dynamic raw) {
      if (raw == null) return [];
      return (raw as List).map((e) => (e as num).toDouble()).toList();
    }

    List<int> intList(dynamic raw) {
      if (raw == null) return [];
      return (raw as List).map((e) => (e as num).toInt()).toList();
    }

    return BenchmarkRun(
      runIndex: json['runIndex'] as int? ?? 0,
      modelName: json['modelName'] as String? ?? 'Unknown',
      backendType: json['backendType'] as String? ?? 'CPU',
      backendStatus: json['backendStatus'] as String? ?? 'CPU active',
      deviceInfo: json['deviceInfo'] as String? ?? 'Unknown',
      androidVersion: json['androidVersion'] as String? ?? 'Unknown',
      durationMinutes: json['durationMinutes'] as int? ?? 1,
      warmupFrames: json['warmupFrames'] as int? ?? 0,
      fpsRecords: doubleList(json['fpsRecords']),
      latencyRecords: doubleList(json['latencyRecords']),
      ramRecords: doubleList(json['ramRecords']),
      objectsRecords: intList(json['objectsRecords']),
      modelSizeMb: (json['modelSizeMb'] as num?)?.toDouble() ?? 0.0,
      runTimestamp: json['runTimestamp'] != null
          ? DateTime.parse(json['runTimestamp'] as String)
          : DateTime.now(),
      sessionStart: json['sessionStart'] != null
          ? DateTime.parse(json['sessionStart'] as String)
          : DateTime.now(),
      sessionEnd: json['sessionEnd'] != null
          ? DateTime.parse(json['sessionEnd'] as String)
          : DateTime.now(),
      totalInferenceCount: json['totalInferenceCount'] as int? ?? 0,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BenchmarkAggregated — Statistical summary across multiple BenchmarkRuns
// ═══════════════════════════════════════════════════════════════════════════════

/// Aggregated statistical metrics for a specific model+backend combination,
/// computed from a list of BenchmarkRun records.
class BenchmarkAggregated {
  final String modelName;
  final String backendType;
  final int runCount;

  // FPS statistics
  final double meanFps;
  final double stdFps;
  final double minFps;
  final double maxFps;
  final double cvFps; // coefficient of variation

  // Latency statistics
  final double meanLatency;
  final double stdLatency;
  final double minLatency;
  final double maxLatency;

  // RAM statistics
  final double meanRam;
  final double stdRam;
  final double peakRam;

  // Other
  final double meanSuccessRate;
  final double meanFpsStability;
  final double meanObjects;
  final double modelSizeMb;

  // Best / worst runs (by FPS)
  final int bestRunIndex;
  final int worstRunIndex;

  const BenchmarkAggregated({
    required this.modelName,
    required this.backendType,
    required this.runCount,
    required this.meanFps,
    required this.stdFps,
    required this.minFps,
    required this.maxFps,
    required this.cvFps,
    required this.meanLatency,
    required this.stdLatency,
    required this.minLatency,
    required this.maxLatency,
    required this.meanRam,
    required this.stdRam,
    required this.peakRam,
    required this.meanSuccessRate,
    required this.meanFpsStability,
    required this.meanObjects,
    required this.modelSizeMb,
    required this.bestRunIndex,
    required this.worstRunIndex,
  });

  String get groupKey => '$modelName|$backendType';

  /// Format mean ± std for display
  String fpsLabel() =>
      '${meanFps.toStringAsFixed(1)} ± ${stdFps.toStringAsFixed(1)}';
  String latencyLabel() =>
      '${meanLatency.toStringAsFixed(1)} ± ${stdLatency.toStringAsFixed(1)}';
  String ramLabel() =>
      '${meanRam.toStringAsFixed(1)} ± ${stdRam.toStringAsFixed(1)}';

  /// Factory: compute aggregated statistics from a list of BenchmarkRun records.
  factory BenchmarkAggregated.fromRuns(List<BenchmarkRun> runs) {
    assert(runs.isNotEmpty);
    final modelName = runs.first.modelName;
    final backendType = runs.first.backendType;

    final fpsList = runs.map((r) => r.averageFps).toList();
    final latList = runs.map((r) => r.averageLatency).toList();
    final ramList = runs.map((r) => r.averageRam).toList();
    final successList = runs.map((r) => r.detectionSuccessRate).toList();
    final stabilityList = runs.map((r) => r.fpsStability).toList();
    final objectsList = runs.map((r) => r.averageObjects).toList();

    final meanFps = _mean(fpsList);
    final stdFps = _std(fpsList);
    final cvFps = meanFps > 0 ? (stdFps / meanFps) * 100.0 : 0.0;

    final allPeakRams = runs.map((r) => r.peakRam).toList();

    // Best/worst by FPS
    int bestIdx = 0;
    int worstIdx = 0;
    for (int i = 1; i < runs.length; i++) {
      if (runs[i].averageFps > runs[bestIdx].averageFps) bestIdx = i;
      if (runs[i].averageFps < runs[worstIdx].averageFps) worstIdx = i;
    }

    return BenchmarkAggregated(
      modelName: modelName,
      backendType: backendType,
      runCount: runs.length,
      meanFps: meanFps,
      stdFps: stdFps,
      minFps: fpsList.reduce(min),
      maxFps: fpsList.reduce(max),
      cvFps: cvFps,
      meanLatency: _mean(latList),
      stdLatency: _std(latList),
      minLatency: latList.reduce(min),
      maxLatency: latList.reduce(max),
      meanRam: _mean(ramList),
      stdRam: _std(ramList),
      peakRam: allPeakRams.reduce(max),
      meanSuccessRate: _mean(successList),
      meanFpsStability: _mean(stabilityList),
      meanObjects: _mean(objectsList),
      modelSizeMb: runs.first.modelSizeMb,
      bestRunIndex: runs[bestIdx].runIndex,
      worstRunIndex: runs[worstIdx].runIndex,
    );
  }

  static double _mean(List<double> list) {
    if (list.isEmpty) return 0.0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  static double _std(List<double> list) {
    if (list.length < 2) return 0.0;
    final m = _mean(list);
    final variance =
        list.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) /
            list.length;
    return sqrt(variance);
  }
}
