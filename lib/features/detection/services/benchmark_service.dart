import 'dart:async';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/benchmark.dart';
import '../../../services/statistics_service.dart';

/// Manages all benchmark data: legacy passive recording AND deliberate timed runs.
///
/// Two modes:
///   1. **Legacy passive mode** — used by DetectionController (startSession / recordFrame / saveSession).
///      Records every frame during detection. Saves to `history` list.
///   2. **Deliberate benchmark mode** — used by BenchmarkPage (startBenchmarkSession / recordBenchmarkFrame / finalizeBenchmarkRun).
///      Has warm-up phase + configurable duration timer. Saves to `runs` list.
class DetectionBenchmarkService {
  static const String _storageKey = 'benchmark_data';
  static const String _runsKey = 'benchmark_runs_v2';

  final GetStorage _storage = GetStorage();
  static const _platform = MethodChannel('com.example.waste_detection/memory');

  // ── Legacy passive mode accumulators ─────────────────────────────────────

  final List<double> _fpsRecords = [];
  final List<double> _latencyRecords = [];
  final List<double> _ramRecords = [];
  final List<int> _objectsRecords = [];
  int _totalInferences = 0;
  DateTime? _sessionStart;

  // ── Legacy saved results ──────────────────────────────────────────────────

  ModelBenchmarkData? nanoData;
  ModelBenchmarkData? smallData;
  final List<ModelBenchmarkData> history = [];

  // ── Deliberate benchmark run state ────────────────────────────────────────

  final List<BenchmarkRun> runs = [];

  // Active benchmark session state
  String _benchModelName = '';
  String _benchBackendType = '';
  String _benchBackendStatus = '';
  int _benchDurationMinutes = 1;
  int _benchWarmupTarget = 30;
  int _benchWarmupCount = 0;
  bool _benchIsWarmingUp = true;
  bool _benchSessionActive = false;
  DateTime? _benchSessionStart;
  int _benchRunIndex = 0;

  final List<double> _benchFpsRecords = [];
  final List<double> _benchLatencyRecords = [];
  final List<double> _benchRamRecords = [];
  final List<int> _benchObjectsRecords = [];
  int _benchTotalInferences = 0;

  Timer? _benchmarkTimer;
  VoidCallback? _onBenchmarkComplete;

  // Reactive state exposed to UI
  int get warmupFramesRemaining =>
      (_benchWarmupTarget - _benchWarmupCount).clamp(0, _benchWarmupTarget);
  bool get isWarmingUp => _benchIsWarmingUp;
  bool get isBenchmarkSessionActive => _benchSessionActive;
  int get currentRunIndex => _benchRunIndex;

  // ── Legacy passive session API ────────────────────────────────────────────

  void startSession() {
    _fpsRecords.clear();
    _latencyRecords.clear();
    _ramRecords.clear();
    _objectsRecords.clear();
    _totalInferences = 0;
    _sessionStart ??= DateTime.now();
  }

  void resetSessionTimer() {
    _sessionStart = DateTime.now();
  }

  void recordFrame({
    required double fps,
    required double latencyMs,
    required double ramMb,
    required int objectCount,
  }) {
    if (fps > 0) _fpsRecords.add(fps);
    _latencyRecords.add(latencyMs);
    _ramRecords.add(ramMb);
    _objectsRecords.add(objectCount);
    _totalInferences++;
  }

  bool get hasSessionData => _latencyRecords.isNotEmpty;

  Future<void> saveSession({
    required String modelName,
    required double modelSizeMb,
    required String backendType,
    required String backendStatus,
  }) async {
    if (!hasSessionData) return;

    String devInfo = 'Unknown Device';
    String osVer = 'Unknown Android';
    try {
      if (Platform.isAndroid) {
        final Map<dynamic, dynamic>? meta =
            await _platform.invokeMethod('getDeviceMetadata');
        if (meta != null) {
          final device = meta['device']?.toString() ?? 'Unknown Device';
          final release = meta['androidVersion']?.toString() ?? 'Unknown';
          final sdk = meta['sdkInt']?.toString() ?? 'Unknown';
          devInfo = device;
          osVer = 'Android $release (API $sdk)';
        }
      }
    } catch (e) {
      debugPrint('[BenchmarkService] getDeviceMetadata error: $e');
    }

    final data = ModelBenchmarkData(
      modelName: modelName,
      backendType: backendType,
      backendStatus: backendStatus,
      deviceInfo: devInfo,
      androidVersion: osVer,
      benchmarkTimestamp: DateTime.now(),
      fpsRecords: List<double>.from(_fpsRecords),
      latencyRecords: List<double>.from(_latencyRecords),
      ramRecords: List<double>.from(_ramRecords),
      objectsRecords: List<int>.from(_objectsRecords),
      modelSizeMb: modelSizeMb,
      sessionStart: _sessionStart ?? DateTime.now(),
      sessionEnd: DateTime.now(),
      totalInferenceCount: _totalInferences,
    );

    if (modelName.toLowerCase().contains('8n')) {
      nanoData = data;
    } else {
      smallData = data;
    }

    history.add(data);
    await _persistToStorage();
    _clearAccumulators();
  }

  void _clearAccumulators() {
    _fpsRecords.clear();
    _latencyRecords.clear();
    _ramRecords.clear();
    _objectsRecords.clear();
    _totalInferences = 0;
    _sessionStart = null;
  }

  // ── Deliberate benchmark run API ──────────────────────────────────────────

  /// Start a deliberate timed benchmark session.
  /// The first [warmupFrames] frames are excluded from statistics.
  /// After [durationMinutes] minutes, [onComplete] is called.
  void startBenchmarkSession({
    required String modelName,
    required String backendType,
    required String backendStatus,
    required int durationMinutes,
    required VoidCallback onComplete,
    int warmupFrames = 30,
  }) {
    // Cancel any existing session
    _benchmarkTimer?.cancel();

    _benchModelName = modelName;
    _benchBackendType = backendType;
    _benchBackendStatus = backendStatus;
    _benchDurationMinutes = durationMinutes;
    _benchWarmupTarget = warmupFrames;
    _benchWarmupCount = 0;
    _benchIsWarmingUp = true;
    _benchSessionActive = true;
    _benchSessionStart = DateTime.now();
    _onBenchmarkComplete = onComplete;

    _benchFpsRecords.clear();
    _benchLatencyRecords.clear();
    _benchRamRecords.clear();
    _benchObjectsRecords.clear();
    _benchTotalInferences = 0;

    // Start countdown timer
    _benchmarkTimer = Timer(Duration(minutes: durationMinutes), () {
      if (_benchSessionActive) {
        _benchSessionActive = false;
        _onBenchmarkComplete?.call();
      }
    });

    debugPrint('[BenchmarkService] Benchmark session started: $modelName + $backendType, ${durationMinutes}min, $warmupFrames warmup frames');
  }

  /// Record a frame during a deliberate benchmark session.
  void recordBenchmarkFrame({
    required double fps,
    required double latencyMs,
    required double ramMb,
    required int objectCount,
  }) {
    if (!_benchSessionActive) return;

    // Warm-up phase
    if (_benchIsWarmingUp) {
      _benchWarmupCount++;
      if (_benchWarmupCount >= _benchWarmupTarget) {
        _benchIsWarmingUp = false;
        debugPrint('[BenchmarkService] Warm-up complete. Recording started.');
      }
      return;
    }

    // Measurement phase
    if (fps > 0) _benchFpsRecords.add(fps);
    _benchLatencyRecords.add(latencyMs);
    _benchRamRecords.add(ramMb);
    _benchObjectsRecords.add(objectCount);
    _benchTotalInferences++;
  }

  /// Cancel the active benchmark session without saving.
  void cancelBenchmarkSession() {
    _benchmarkTimer?.cancel();
    _benchSessionActive = false;
    _benchIsWarmingUp = false;
    _benchFpsRecords.clear();
    _benchLatencyRecords.clear();
    _benchRamRecords.clear();
    _benchObjectsRecords.clear();
    _benchTotalInferences = 0;
    debugPrint('[BenchmarkService] Benchmark session cancelled.');
  }

  /// Finalize and save the completed benchmark run.
  Future<BenchmarkRun?> finalizeBenchmarkRun({
    required double modelSizeMb,
  }) async {
    if (_benchLatencyRecords.isEmpty) return null;

    _benchmarkTimer?.cancel();

    String devInfo = 'Unknown Device';
    String osVer = 'Unknown Android';
    try {
      if (Platform.isAndroid) {
        final Map<dynamic, dynamic>? meta =
            await _platform.invokeMethod('getDeviceMetadata');
        if (meta != null) {
          devInfo = meta['device']?.toString() ?? 'Unknown Device';
          final release = meta['androidVersion']?.toString() ?? 'Unknown';
          final sdk = meta['sdkInt']?.toString() ?? 'Unknown';
          osVer = 'Android $release (API $sdk)';
        }
      }
    } catch (e) {
      debugPrint('[BenchmarkService] getDeviceMetadata error: $e');
    }

    // Find the next run index for this model+backend combo
    _benchRunIndex = _nextRunIndex(_benchModelName, _benchBackendType);

    final run = BenchmarkRun(
      runIndex: _benchRunIndex,
      modelName: _benchModelName,
      backendType: _benchBackendType,
      backendStatus: _benchBackendStatus,
      deviceInfo: devInfo,
      androidVersion: osVer,
      durationMinutes: _benchDurationMinutes,
      warmupFrames: _benchWarmupTarget,
      fpsRecords: List<double>.from(_benchFpsRecords),
      latencyRecords: List<double>.from(_benchLatencyRecords),
      ramRecords: List<double>.from(_benchRamRecords),
      objectsRecords: List<int>.from(_benchObjectsRecords),
      modelSizeMb: modelSizeMb,
      runTimestamp: DateTime.now(),
      sessionStart: _benchSessionStart ?? DateTime.now(),
      sessionEnd: DateTime.now(),
      totalInferenceCount: _benchTotalInferences,
    );

    runs.add(run);
    _benchSessionActive = false;

    // Also add to legacy history for backward compatibility
    final legacyData = ModelBenchmarkData(
      modelName: run.modelName,
      backendType: run.backendType,
      backendStatus: run.backendStatus,
      deviceInfo: run.deviceInfo,
      androidVersion: run.androidVersion,
      benchmarkTimestamp: run.runTimestamp,
      fpsRecords: run.fpsRecords,
      latencyRecords: run.latencyRecords,
      ramRecords: run.ramRecords,
      objectsRecords: run.objectsRecords,
      modelSizeMb: run.modelSizeMb,
      sessionStart: run.sessionStart,
      sessionEnd: run.sessionEnd,
      totalInferenceCount: run.totalInferenceCount,
    );
    history.add(legacyData);

    await _persistAll();
    debugPrint('[BenchmarkService] Run #$_benchRunIndex finalized: ${run.modelName} + ${run.backendType}');
    return run;
  }

  int _nextRunIndex(String modelName, String backendType) {
    final existing = runs.where(
      (r) => r.modelName == modelName && r.backendType == backendType,
    );
    return existing.isEmpty ? 1 : (existing.map((r) => r.runIndex).reduce((a, b) => a > b ? a : b) + 1);
  }

  // ── Aggregated statistics ─────────────────────────────────────────────────

  /// Compute aggregated statistics for all model+backend combinations.
  Map<String, BenchmarkAggregated> get aggregatedResults {
    if (runs.isEmpty) return {};
    return StatisticsService.aggregateAll(runs);
  }

  // ── System metrics ────────────────────────────────────────────────────────

  Future<double> getMemoryUsageMb() async {
    try {
      if (Platform.isAndroid) {
        final int ramMb = await _platform.invokeMethod('getMemoryUsage');
        return ramMb.toDouble();
      }
    } catch (e) {
      debugPrint('[BenchmarkService] getMemoryUsage error: $e');
    }
    return 150.0;
  }

  Future<double> getModelSizeMb(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      return byteData.lengthInBytes / (1024.0 * 1024.0);
    } catch (e) {
      return assetPath.contains('8s') ? 21.4 : 5.9;
    }
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _persistToStorage() async {
    final map = <String, dynamic>{};
    map['history'] = history.map((e) => e.toJson()).toList();
    if (nanoData != null) map['nano'] = nanoData!.toJson();
    if (smallData != null) map['small'] = smallData!.toJson();
    await _storage.write(_storageKey, map);
  }

  Future<void> _persistAll() async {
    await _persistToStorage();
    await _storage.write(_runsKey, runs.map((r) => r.toJson()).toList());
  }

  void loadFromStorage() {
    // Load legacy history
    try {
      final raw = _storage.read<Map<String, dynamic>>(_storageKey);
      if (raw != null) {
        history.clear();
        if (raw.containsKey('history')) {
          final list = raw['history'] as List;
          for (final item in list) {
            history.add(ModelBenchmarkData.fromJson(
                Map<String, dynamic>.from(item as Map)));
          }
        }
        if (raw.containsKey('nano')) {
          final legacyNano = ModelBenchmarkData.fromJson(
              Map<String, dynamic>.from(raw['nano'] as Map));
          nanoData = legacyNano;
          if (!history.any((h) => h.sessionStart == legacyNano.sessionStart)) {
            history.add(legacyNano);
          }
        }
        if (raw.containsKey('small')) {
          final legacySmall = ModelBenchmarkData.fromJson(
              Map<String, dynamic>.from(raw['small'] as Map));
          smallData = legacySmall;
          if (!history.any((h) => h.sessionStart == legacySmall.sessionStart)) {
            history.add(legacySmall);
          }
        }
      }
    } catch (e) {
      debugPrint('[BenchmarkService] loadFromStorage (legacy) error: $e');
    }

    // Load deliberate benchmark runs
    try {
      final rawRuns = _storage.read<List>(_runsKey);
      if (rawRuns != null) {
        runs.clear();
        for (final item in rawRuns) {
          runs.add(BenchmarkRun.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        debugPrint('[BenchmarkService] Loaded ${runs.length} benchmark runs from storage.');
      }
    } catch (e) {
      debugPrint('[BenchmarkService] loadFromStorage (runs) error: $e');
    }
  }

  void reset() {
    nanoData = null;
    smallData = null;
    history.clear();
    runs.clear();
    _benchmarkTimer?.cancel();
    _benchSessionActive = false;
    _storage.remove(_storageKey);
    _storage.remove(_runsKey);
    _clearAccumulators();
    debugPrint('[BenchmarkService] All data reset.');
  }

  // ── CSV Export ────────────────────────────────────────────────────────────

  Future<void> exportCsv() async {
    final rows = <List<dynamic>>[];

    // ── Section 1: Per-run raw data ──────────────────────────────────────
    rows.add(['=== BENCHMARK RUNS (Raw Data) ===']);
    rows.add([
      'Run Index',
      'Model',
      'Backend',
      'Backend Status',
      'Duration (min)',
      'Warmup Frames',
      'Avg FPS',
      'Min FPS',
      'Max FPS',
      'Avg Latency (ms)',
      'Min Latency (ms)',
      'Max Latency (ms)',
      'Avg RAM (MB)',
      'Peak RAM (MB)',
      'Model Size (MB)',
      'Avg Objects',
      'Success Rate (%)',
      'FPS Stability',
      'Inference Count',
      'Duration (s)',
      'Device',
      'Android Version',
      'Timestamp',
    ]);

    for (final r in runs) {
      rows.add([
        r.runIndex,
        r.modelName,
        r.backendType,
        r.backendStatus,
        r.durationMinutes,
        r.warmupFrames,
        r.averageFps.toStringAsFixed(2),
        r.minFps.toStringAsFixed(2),
        r.maxFps.toStringAsFixed(2),
        r.averageLatency.toStringAsFixed(2),
        r.minLatency.toStringAsFixed(2),
        r.maxLatency.toStringAsFixed(2),
        r.averageRam.toStringAsFixed(2),
        r.peakRam.toStringAsFixed(2),
        r.modelSizeMb.toStringAsFixed(2),
        r.averageObjects.toStringAsFixed(2),
        (r.detectionSuccessRate * 100).toStringAsFixed(1),
        r.fpsStability.toStringAsFixed(3),
        r.totalInferenceCount,
        r.sessionDurationSeconds,
        r.deviceInfo,
        r.androidVersion,
        r.runTimestamp.toIso8601String(),
      ]);
    }

    // ── Section 2: Statistical summary ───────────────────────────────────
    final aggregated = aggregatedResults;
    if (aggregated.isNotEmpty) {
      rows.add([]);
      rows.add(['=== STATISTICAL SUMMARY (Mean ± Std per Model+Backend) ===']);
      rows.add([
        'Model',
        'Backend',
        'Run Count',
        'Mean FPS',
        'Std FPS',
        'CV FPS (%)',
        'Min FPS',
        'Max FPS',
        'Mean Latency (ms)',
        'Std Latency',
        'Min Latency',
        'Max Latency',
        'Mean RAM (MB)',
        'Std RAM',
        'Peak RAM (MB)',
        'Mean Success Rate (%)',
        'Mean FPS Stability',
        'Model Size (MB)',
        'Best Run Index',
        'Worst Run Index',
      ]);

      for (final agg in aggregated.values) {
        rows.add([
          agg.modelName,
          agg.backendType,
          agg.runCount,
          agg.meanFps.toStringAsFixed(2),
          agg.stdFps.toStringAsFixed(2),
          agg.cvFps.toStringAsFixed(1),
          agg.minFps.toStringAsFixed(2),
          agg.maxFps.toStringAsFixed(2),
          agg.meanLatency.toStringAsFixed(2),
          agg.stdLatency.toStringAsFixed(2),
          agg.minLatency.toStringAsFixed(2),
          agg.maxLatency.toStringAsFixed(2),
          agg.meanRam.toStringAsFixed(2),
          agg.stdRam.toStringAsFixed(2),
          agg.peakRam.toStringAsFixed(2),
          (agg.meanSuccessRate * 100).toStringAsFixed(1),
          agg.meanFpsStability.toStringAsFixed(3),
          agg.modelSizeMb.toStringAsFixed(2),
          agg.bestRunIndex,
          agg.worstRunIndex,
        ]);
      }
    }

    // ── Section 3: Legacy history ─────────────────────────────────────────
    if (history.isNotEmpty) {
      rows.add([]);
      rows.add(['=== LEGACY PASSIVE DETECTION HISTORY ===']);
      rows.add([
        'Model', 'Backend', 'Status', 'Avg FPS', 'Avg Latency', 'Avg RAM',
        'Peak RAM', 'Success Rate', 'Inferences', 'Duration (s)', 'Timestamp'
      ]);
      for (final data in history) {
        rows.add([
          data.modelName,
          data.backendType,
          data.backendStatus,
          data.averageFps.toStringAsFixed(2),
          data.averageLatency.toStringAsFixed(2),
          data.averageRam.toStringAsFixed(2),
          data.peakRam.toStringAsFixed(2),
          (data.detectionSuccessRate * 100).toStringAsFixed(1),
          data.totalInferenceCount,
          data.sessionDurationSeconds,
          data.benchmarkTimestamp.toIso8601String(),
        ]);
      }
    }

    final csv = const ListToCsvConverter().convert(rows);
    await _shareText(csv, 'waste_detector_benchmark.csv', 'text/csv');
  }

  // ── PDF Export ────────────────────────────────────────────────────────────

  Future<void> exportPdf() async {
    final pdf = pw.Document();
    final dateStr = DateTime.now().toString().substring(0, 19);
    final aggregated = aggregatedResults;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _pdfHeader(dateStr),
          pw.SizedBox(height: 16),
          if (aggregated.isNotEmpty) ...[
            _pdfStatisticsTable(aggregated),
            pw.SizedBox(height: 16),
          ],
          _pdfStatsTable(),
          pw.SizedBox(height: 16),
          _pdfBarChart(),
          pw.SizedBox(height: 16),
          _pdfConclusion(aggregated),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
        bytes: bytes, filename: 'waste_detector_benchmark.pdf');
  }

  pw.Widget _pdfHeader(String dateStr) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal800,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Smart Waste Detector — Benchmark Report',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated: $dateStr\nAndroid-based Mobile Benchmarking: YOLOv8n vs YOLOv8s with CPU / GPU / NNAPI Delegates',
            style: pw.TextStyle(color: PdfColors.grey400, fontSize: 11),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfStatisticsTable(Map<String, BenchmarkAggregated> aggregated) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Statistical Summary (Mean ± Std)',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(0.8),
            2: const pw.FlexColumnWidth(0.5),
            3: const pw.FlexColumnWidth(1.4),
            4: const pw.FlexColumnWidth(1.4),
            5: const pw.FlexColumnWidth(1.4),
            6: const pw.FlexColumnWidth(0.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.teal100),
              children: ['Model', 'Backend', 'Runs', 'FPS (mean±std)', 'Latency (mean±std)', 'RAM (mean±std)', 'CV%']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      ))
                  .toList(),
            ),
            ...aggregated.values.map((agg) => pw.TableRow(
                  children: [
                    agg.modelName,
                    agg.backendType,
                    '${agg.runCount}',
                    agg.fpsLabel(),
                    agg.latencyLabel(),
                    agg.ramLabel(),
                    '${agg.cvFps.toStringAsFixed(1)}%',
                  ]
                      .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(cell,
                                style: const pw.TextStyle(fontSize: 7.5)),
                          ))
                      .toList(),
                )),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfStatsTable() {
    final headers = ['Model', 'Backend', 'Status', 'FPS', 'Latency', 'RAM', 'Date'];
    final rows = history.map((data) => [
          data.modelName,
          data.backendType,
          data.backendStatus,
          data.averageFps.toStringAsFixed(1),
          '${data.averageLatency.toStringAsFixed(0)} ms',
          '${data.averageRam.toStringAsFixed(0)} MB',
          data.benchmarkTimestamp.toString().substring(0, 16),
        ]).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Session History',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(0.8),
            2: const pw.FlexColumnWidth(1.8),
            3: const pw.FlexColumnWidth(0.7),
            4: const pw.FlexColumnWidth(0.8),
            5: const pw.FlexColumnWidth(0.8),
            6: const pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.teal50),
              children: headers
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      ))
                  .toList(),
            ),
            ...rows.map((row) => pw.TableRow(
                  children: row
                      .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(cell,
                                style: const pw.TextStyle(fontSize: 7.5)),
                          ))
                      .toList(),
                )),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfBarChart() {
    final source = runs.isNotEmpty ? null : history;
    if (source == null && runs.isEmpty) return pw.SizedBox();
    if (source != null && source.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Average FPS Comparison',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (runs.isNotEmpty)
          ...runs.map((r) {
            final label = '${r.modelName} (${r.backendType}) #${r.runIndex}';
            final fps = r.averageFps;
            final w = (fps / 60.0 * 200).clamp(2.0, 200.0);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(children: [
                pw.Container(
                    width: 140,
                    child: pw.Text(label,
                        style: const pw.TextStyle(fontSize: 8))),
                pw.Container(
                    width: w,
                    height: 10,
                    color: r.modelName.toLowerCase().contains('8n')
                        ? PdfColors.teal600
                        : PdfColors.indigo600),
                pw.SizedBox(width: 5),
                pw.Text('${fps.toStringAsFixed(1)} FPS',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ]),
            );
          })
        else
          ...history.map((data) {
            final label = '${data.modelName} (${data.backendType})';
            final fps = data.averageFps;
            final w = (fps / 60.0 * 200).clamp(2.0, 200.0);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(children: [
                pw.Container(
                    width: 140,
                    child: pw.Text(label,
                        style: const pw.TextStyle(fontSize: 8))),
                pw.Container(
                    width: w,
                    height: 10,
                    color: data.modelName.toLowerCase().contains('8n')
                        ? PdfColors.teal600
                        : PdfColors.indigo600),
                pw.SizedBox(width: 5),
                pw.Text('${fps.toStringAsFixed(1)} FPS',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ]),
            );
          }),
      ],
    );
  }

  pw.Widget _pdfConclusion(Map<String, BenchmarkAggregated> aggregated) {
    final text = _buildPdfConclusionText(aggregated);
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.teal200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Automated Research Conclusion',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(text,
              style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 4)),
        ],
      ),
    );
  }

  String _buildPdfConclusionText(Map<String, BenchmarkAggregated> aggregated) {
    final buffer = StringBuffer();
    buffer.writeln(
        'Smart Waste Detector — Android Mobile Benchmark Conclusion');
    buffer.writeln(
        'Framework: YOLOv8n vs YOLOv8s | Backends: CPU / GPU Delegate / NNAPI Delegate');
    buffer.writeln('');

    if (aggregated.isNotEmpty) {
      final fastest = StatisticsService.fastestCombo(aggregated);
      final lowLat = StatisticsService.lowestLatencyCombo(aggregated);
      final lowRam = StatisticsService.lowestRamCombo(aggregated);
      final stable = StatisticsService.mostStableCombo(aggregated);

      if (fastest != null) {
        buffer.writeln(
            '⚡ Fastest: ${fastest.modelName} + ${fastest.backendType} '
            '(${fastest.meanFps.toStringAsFixed(1)} ± ${fastest.stdFps.toStringAsFixed(1)} FPS)');
      }
      if (lowLat != null) {
        buffer.writeln(
            '⏱  Lowest Latency: ${lowLat.modelName} + ${lowLat.backendType} '
            '(${lowLat.meanLatency.toStringAsFixed(1)} ± ${lowLat.stdLatency.toStringAsFixed(1)} ms)');
      }
      if (lowRam != null) {
        buffer.writeln(
            '🧠 Lowest RAM: ${lowRam.modelName} + ${lowRam.backendType} '
            '(${lowRam.meanRam.toStringAsFixed(1)} MB avg)');
      }
      if (stable != null) {
        buffer.writeln(
            '📊 Most Stable: ${stable.modelName} + ${stable.backendType} '
            '(stability: ${(stable.meanFpsStability * 100).toStringAsFixed(1)}%)');
      }
    } else {
      buffer.writeln('Run at least 1 benchmark session to generate conclusions.');
    }

    final gpuRuns = runs.where((r) =>
        r.backendType == 'GPU' &&
        r.backendStatus.toLowerCase().contains('active'));
    final nnapiRuns = runs.where((r) =>
        r.backendType == 'NNAPI' &&
        r.backendStatus.toLowerCase().contains('active'));
    final cpuRuns = runs.where((r) => r.backendType == 'CPU');

    buffer.writeln('');
    buffer.writeln('Delegate Notes:');
    if (gpuRuns.isNotEmpty) {
      buffer.writeln(
          '• GPU delegate: active. Provides hardware-accelerated inference, best for high FPS targets.');
    }
    if (nnapiRuns.isNotEmpty) {
      buffer.writeln(
          '• NNAPI delegate: active. Leverages on-device NPU/DSP when available.');
    }
    if (cpuRuns.isNotEmpty) {
      buffer.writeln(
          '• CPU backend: used as baseline. Most compatible across all Android devices.');
    }
    return buffer.toString();
  }

  Future<void> _shareText(
      String content, String filename, String mimeType) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(content);
      await Share.shareXFiles([XFile(file.path, mimeType: mimeType)]);
    } catch (e) {
      debugPrint('[BenchmarkService] share error: $e');
    }
  }
}
