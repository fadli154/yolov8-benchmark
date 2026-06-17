import 'dart:math';
import '../models/benchmark.dart';

/// Pure-static service for statistical computations.
/// No state, no dependencies — safe to call from anywhere.
class StatisticsService {
  StatisticsService._();

  // ── Basic statistics ──────────────────────────────────────────────────────

  static double mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double stdDev(List<double> values) {
    if (values.length < 2) return 0.0;
    final m = mean(values);
    final variance =
        values.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) /
            values.length;
    return sqrt(variance);
  }

  static double cv(List<double> values) {
    final m = mean(values);
    if (m == 0) return 0.0;
    return (stdDev(values) / m) * 100.0;
  }

  static double minimum(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce(min);
  }

  static double maximum(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce(max);
  }

  // ── Grouping ──────────────────────────────────────────────────────────────

  /// Group benchmark runs by their model+backend key.
  static Map<String, List<BenchmarkRun>> groupRunsByKey(
      List<BenchmarkRun> runs) {
    final map = <String, List<BenchmarkRun>>{};
    for (final run in runs) {
      map.putIfAbsent(run.groupKey, () => []).add(run);
    }
    return map;
  }

  // ── Aggregation ───────────────────────────────────────────────────────────

  /// Compute one BenchmarkAggregated per model+backend group.
  static Map<String, BenchmarkAggregated> aggregateAll(
      List<BenchmarkRun> runs) {
    final groups = groupRunsByKey(runs);
    return groups.map(
      (key, groupRuns) => MapEntry(key, BenchmarkAggregated.fromRuns(groupRuns)),
    );
  }

  /// Get aggregated results only for a specific model.
  static List<BenchmarkAggregated> forModel(
      Map<String, BenchmarkAggregated> aggregated, String modelName) {
    return aggregated.values
        .where((a) => a.modelName.toLowerCase().contains(modelName.toLowerCase()))
        .toList();
  }

  /// Get aggregated results only for a specific backend.
  static List<BenchmarkAggregated> forBackend(
      Map<String, BenchmarkAggregated> aggregated, String backendType) {
    return aggregated.values
        .where((a) => a.backendType.toUpperCase() == backendType.toUpperCase())
        .toList();
  }

  // ── Conclusion helpers ────────────────────────────────────────────────────

  /// Returns the aggregated result with the highest mean FPS.
  static BenchmarkAggregated? fastestCombo(
      Map<String, BenchmarkAggregated> aggregated) {
    if (aggregated.isEmpty) return null;
    return aggregated.values
        .reduce((a, b) => a.meanFps > b.meanFps ? a : b);
  }

  /// Returns the aggregated result with the lowest mean latency.
  static BenchmarkAggregated? lowestLatencyCombo(
      Map<String, BenchmarkAggregated> aggregated) {
    if (aggregated.isEmpty) return null;
    return aggregated.values
        .reduce((a, b) => a.meanLatency < b.meanLatency ? a : b);
  }

  /// Returns the aggregated result with the lowest mean RAM.
  static BenchmarkAggregated? lowestRamCombo(
      Map<String, BenchmarkAggregated> aggregated) {
    if (aggregated.isEmpty) return null;
    return aggregated.values
        .reduce((a, b) => a.meanRam < b.meanRam ? a : b);
  }

  /// Returns the aggregated result with the best FPS stability.
  static BenchmarkAggregated? mostStableCombo(
      Map<String, BenchmarkAggregated> aggregated) {
    if (aggregated.isEmpty) return null;
    return aggregated.values
        .reduce((a, b) => a.meanFpsStability > b.meanFpsStability ? a : b);
  }

  /// Returns the aggregated result with the highest detection success rate.
  static BenchmarkAggregated? bestSuccessRateCombo(
      Map<String, BenchmarkAggregated> aggregated) {
    if (aggregated.isEmpty) return null;
    return aggregated.values
        .reduce((a, b) => a.meanSuccessRate > b.meanSuccessRate ? a : b);
  }

  // ── Formatting helpers ────────────────────────────────────────────────────

  static String formatMeanStd(double m, double s, {int decimals = 1}) {
    return '${m.toStringAsFixed(decimals)} ± ${s.toStringAsFixed(decimals)}';
  }

  static String formatPercent(double value, {int decimals = 1}) {
    return '${(value * 100).toStringAsFixed(decimals)}%';
  }
}
