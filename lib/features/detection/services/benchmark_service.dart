import 'dart:io';
import 'dart:math';
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

/// Manages benchmark data collection, persistence, and export.
///
/// Uses GetStorage to persist data across sessions.
/// Provides PDF and CSV export for research/journal use.
class DetectionBenchmarkService {
  static const String _storageKey = 'benchmark_data';

  final GetStorage _storage = GetStorage();
  static const _platform = MethodChannel('com.example.waste_detection/memory');

  // ── Session accumulators ──────────────────────────────────────────────────

  final List<double> _fpsRecords = [];
  final List<double> _latencyRecords = [];
  final List<double> _ramRecords = [];
  final List<int> _objectsRecords = [];
  int _totalInferences = 0;
  DateTime? _sessionStart;

  // ── Saved results ─────────────────────────────────────────────────────────

  ModelBenchmarkData? nanoData;
  ModelBenchmarkData? smallData;

  // ── Session API ───────────────────────────────────────────────────────────

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

  /// Save the current session for [modelName] and persist to storage.
  Future<void> saveSession({
    required String modelName,
    required double modelSizeMb,
  }) async {
    if (!hasSessionData) return;

    final data = ModelBenchmarkData(
      modelName: modelName,
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

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _persistToStorage() async {
    final map = <String, dynamic>{};
    if (nanoData != null) map['nano'] = nanoData!.toJson();
    if (smallData != null) map['small'] = smallData!.toJson();
    await _storage.write(_storageKey, map);
  }

  void loadFromStorage() {
    try {
      final raw = _storage.read<Map<String, dynamic>>(_storageKey);
      if (raw == null) return;
      if (raw.containsKey('nano')) {
        nanoData = ModelBenchmarkData.fromJson(
            Map<String, dynamic>.from(raw['nano'] as Map));
      }
      if (raw.containsKey('small')) {
        smallData = ModelBenchmarkData.fromJson(
            Map<String, dynamic>.from(raw['small'] as Map));
      }
    } catch (e) {
      debugPrint('[BenchmarkService] loadFromStorage error: $e');
    }
  }

  void reset() {
    nanoData = null;
    smallData = null;
    _storage.remove(_storageKey);
    _clearAccumulators();
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
    return 150.0; // Reasonable fallback
  }

  Future<double> getModelSizeMb(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      return byteData.lengthInBytes / (1024.0 * 1024.0);
    } catch (e) {
      return assetPath.contains('8s') ? 21.4 : 5.9;
    }
  }

  // ── CSV Export ────────────────────────────────────────────────────────────

  Future<void> exportCsv() async {
    final rows = <List<dynamic>>[];
    rows.add([
      'Model',
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
      'Detection Success Rate (%)',
      'Total Inferences',
      'Session Duration (s)',
    ]);

    for (final data in [nanoData, smallData]) {
      if (data == null) continue;
      rows.add([
        data.modelName,
        data.averageFps.toStringAsFixed(2),
        data.minFps.toStringAsFixed(2),
        data.maxFps.toStringAsFixed(2),
        data.averageLatency.toStringAsFixed(2),
        data.minLatency.toStringAsFixed(2),
        data.maxLatency.toStringAsFixed(2),
        data.averageRam.toStringAsFixed(2),
        data.peakRam.toStringAsFixed(2),
        data.modelSizeMb.toStringAsFixed(2),
        data.averageObjects.toStringAsFixed(2),
        (data.detectionSuccessRate * 100).toStringAsFixed(1),
        data.totalInferenceCount.toString(),
        data.sessionDurationSeconds.toString(),
      ]);
    }

    // Append raw FPS timeline
    rows.add([]);
    rows.add(['--- RAW FPS TIMELINE ---']);
    rows.add(['Frame Index', 'YOLOv8n FPS', 'YOLOv8s FPS']);
    final nTimeline = nanoData?.fpsTimeline ?? [];
    final sTimeline = smallData?.fpsTimeline ?? [];
    final maxLen = max(nTimeline.length, sTimeline.length);
    for (int i = 0; i < maxLen; i++) {
      rows.add([
        i.toString(),
        i < nTimeline.length ? nTimeline[i].toStringAsFixed(1) : '',
        i < sTimeline.length ? sTimeline[i].toStringAsFixed(1) : '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    await _shareText(csv, 'benchmark_results.csv', 'text/csv');
  }

  // ── PDF Export ────────────────────────────────────────────────────────────

  Future<void> exportPdf() async {
    final pdf = pw.Document();
    final dateStr = DateTime.now().toString().substring(0, 19);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _pdfHeader(dateStr),
          pw.SizedBox(height: 16),
          _pdfStatsTable(),
          pw.SizedBox(height: 16),
          _pdfBarChart(),
          pw.SizedBox(height: 16),
          _pdfConclusion(),
          pw.SizedBox(height: 16),
          _pdfRawDataSection(),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'waste_detector_benchmark.pdf');
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
            'Generated: $dateStr\nModels: YOLOv8n (Nano) vs YOLOv8s (Small)',
            style: pw.TextStyle(color: PdfColors.grey400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfStatsTable() {
    final headers = [
      'Metric',
      'YOLOv8n',
      'YOLOv8s',
    ];

    final rows = [
      ['Average FPS', _fmt(nanoData?.averageFps), _fmt(smallData?.averageFps)],
      ['Min FPS', _fmt(nanoData?.minFps), _fmt(smallData?.minFps)],
      ['Max FPS', _fmt(nanoData?.maxFps), _fmt(smallData?.maxFps)],
      ['Avg Latency (ms)', _fmt(nanoData?.averageLatency), _fmt(smallData?.averageLatency)],
      ['Min Latency (ms)', _fmt(nanoData?.minLatency), _fmt(smallData?.minLatency)],
      ['Max Latency (ms)', _fmt(nanoData?.maxLatency), _fmt(smallData?.maxLatency)],
      ['Avg RAM (MB)', _fmt(nanoData?.averageRam), _fmt(smallData?.averageRam)],
      ['Peak RAM (MB)', _fmt(nanoData?.peakRam), _fmt(smallData?.peakRam)],
      ['Model Size (MB)', _fmtFixed(nanoData?.modelSizeMb), _fmtFixed(smallData?.modelSizeMb)],
      ['Avg Objects/Frame', _fmt(nanoData?.averageObjects), _fmt(smallData?.averageObjects)],
      ['Detection Success (%)', _fmtPct(nanoData?.detectionSuccessRate), _fmtPct(smallData?.detectionSuccessRate)],
      ['FPS Stability', _fmtStability(nanoData?.fpsStability), _fmtStability(smallData?.fpsStability)],
      ['Total Inferences', '${nanoData?.totalInferenceCount ?? "N/A"}', '${smallData?.totalInferenceCount ?? "N/A"}'],
      ['Session Duration (s)', '${nanoData?.sessionDurationSeconds ?? "N/A"}', '${smallData?.sessionDurationSeconds ?? "N/A"}'],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Performance Statistics',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.teal100),
              children: headers
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(h,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ))
                  .toList(),
            ),
            ...rows.map((row) => pw.TableRow(
                  children: row
                      .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 11)),
                          ))
                      .toList(),
                )),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfBarChart() {
    // Simple ASCII-style bar chart using PDF rectangles
    final metrics = [
      ('Avg FPS', nanoData?.averageFps ?? 0, smallData?.averageFps ?? 0, 60.0),
      ('Avg Latency', nanoData?.averageLatency ?? 0, smallData?.averageLatency ?? 0, 300.0),
      ('Avg RAM (MB)', nanoData?.averageRam ?? 0, smallData?.averageRam ?? 0, 512.0),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Comparative Bar Chart',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        ...metrics.map((m) {
          final label = m.$1;
          final nVal = m.$2;
          final sVal = m.$3;
          final maxVal = m.$4;
          final nW = (nVal / maxVal * 200).clamp(2.0, 200.0);
          final sW = (sVal / maxVal * 200).clamp(2.0, 200.0);
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
              pw.Row(children: [
                pw.Container(width: 60, child: pw.Text('YOLOv8n', style: const pw.TextStyle(fontSize: 9))),
                pw.Container(width: nW, height: 14, color: PdfColors.teal600),
                pw.SizedBox(width: 4),
                pw.Text(nVal.toStringAsFixed(1), style: const pw.TextStyle(fontSize: 9)),
              ]),
              pw.SizedBox(height: 2),
              pw.Row(children: [
                pw.Container(width: 60, child: pw.Text('YOLOv8s', style: const pw.TextStyle(fontSize: 9))),
                pw.Container(width: sW, height: 14, color: PdfColors.indigo600),
                pw.SizedBox(width: 4),
                pw.Text(sVal.toStringAsFixed(1), style: const pw.TextStyle(fontSize: 9)),
              ]),
              pw.SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _pdfConclusion() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.teal200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Automated Conclusion',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(_buildConclusion(), style: const pw.TextStyle(fontSize: 11, lineSpacing: 4)),
        ],
      ),
    );
  }

  pw.Widget _pdfRawDataSection() {
    if (nanoData == null && smallData == null) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('FPS Timeline (sampled)',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(
          'YOLOv8n: ${nanoData?.fpsTimeline.map((v) => v.toStringAsFixed(1)).take(20).join(", ") ?? "N/A"}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'YOLOv8s: ${smallData?.fpsTimeline.map((v) => v.toStringAsFixed(1)).take(20).join(", ") ?? "N/A"}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  String _buildConclusion() {
    if (nanoData == null && smallData == null) {
      return 'No benchmark data available. Run detection sessions with both models to generate a comparison.';
    }
    if (nanoData == null) return 'Only YOLOv8s data available. Run YOLOv8n to compare.';
    if (smallData == null) return 'Only YOLOv8n data available. Run YOLOv8s to compare.';

    final nFps = nanoData!.averageFps;
    final sFps = smallData!.averageFps;
    final nLat = nanoData!.averageLatency;
    final sLat = smallData!.averageLatency;
    final nRam = nanoData!.averageRam;
    final sRam = smallData!.averageRam;
    final faster = nFps > sFps ? 'YOLOv8n' : 'YOLOv8s';
    final moreAccurate = nanoData!.detectionSuccessRate > smallData!.detectionSuccessRate
        ? 'YOLOv8n'
        : 'YOLOv8s';

    return '$faster memiliki FPS lebih tinggi (${nFps.toStringAsFixed(1)} vs ${sFps.toStringAsFixed(1)} FPS).\n'
        'YOLOv8n latency: ${nLat.toStringAsFixed(0)} ms vs YOLOv8s: ${sLat.toStringAsFixed(0)} ms.\n'
        'RAM usage — YOLOv8n: ${nRam.toStringAsFixed(0)} MB, YOLOv8s: ${sRam.toStringAsFixed(0)} MB.\n'
        '$moreAccurate memiliki detection success rate lebih tinggi.\n'
        'Rekomendasi: YOLOv8n untuk perangkat mid-range (stabilitas & kecepatan), '
        'YOLOv8s untuk perangkat flagship yang mengutamakan akurasi.';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(double? v) => v != null ? v.toStringAsFixed(1) : 'N/A';
  String _fmtFixed(double? v) => v != null ? v.toStringAsFixed(2) : 'N/A';
  String _fmtPct(double? v) => v != null ? '${(v * 100).toStringAsFixed(1)}%' : 'N/A';
  String _fmtStability(double? v) => v != null ? '${(v * 100).toStringAsFixed(0)}%' : 'N/A';

  Future<void> _shareText(String content, String filename, String mimeType) async {
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
