import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/detection/services/benchmark_service.dart';
import '../features/detection/widgets/benchmark_chart.dart';
import '../models/benchmark.dart';
import '../widgets/metric_card.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DetectionBenchmarkService _svc;

  ModelBenchmarkData? _nanoData;
  ModelBenchmarkData? _smallData;

  bool _exportingPdf = false;
  bool _exportingCsv = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _svc = Get.find<DetectionBenchmarkService>();
    _nanoData = _svc.nanoData;
    _smallData = _svc.smallData;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Reset Benchmarks?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Semua data benchmark session saat ini akan dihapus.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal',
                  style: TextStyle(color: Colors.white60))),
          TextButton(
              onPressed: () {
                _svc.reset();
                setState(() {
                  _nanoData = null;
                  _smallData = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Reset',
                  style: TextStyle(color: Color(0xFF10B981)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _nanoData != null || _smallData != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text('Benchmark Comparison',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFF10B981),
          tabs: const [
            Tab(icon: Icon(Icons.table_chart_rounded), text: 'Tabel'),
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Charts'),
            Tab(icon: Icon(Icons.download_rounded), text: 'Export'),
          ],
        ),
        actions: [
          if (hasData)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _reset,
              tooltip: 'Reset benchmark data',
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Stats Table ──────────────────────────────────
          _StatsTab(nanoData: _nanoData, smallData: _smallData),
          // ── Tab 2: Charts ───────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              BenchmarkChartWidget(
                  nanoData: _nanoData, smallData: _smallData),
              const SizedBox(height: 24),
              _ConclusionBox(nanoData: _nanoData, smallData: _smallData),
            ]),
          ),
          // ── Tab 3: Export ───────────────────────────────────────
          _ExportTab(
            hasData: hasData,
            exportingPdf: _exportingPdf,
            exportingCsv: _exportingCsv,
            onExportPdf: _handlePdfExport,
            onExportCsv: _handleCsvExport,
          ),
        ],
      ),
    );
  }

  Future<void> _handlePdfExport() async {
    setState(() => _exportingPdf = true);
    await _svc.exportPdf();
    if (mounted) setState(() => _exportingPdf = false);
  }

  Future<void> _handleCsvExport() async {
    setState(() => _exportingCsv = true);
    await _svc.exportCsv();
    if (mounted) setState(() => _exportingCsv = false);
  }
}

// ── Stats Table Tab ───────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final ModelBenchmarkData? nanoData;
  final ModelBenchmarkData? smallData;

  const _StatsTab({required this.nanoData, required this.smallData});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Performance Metrics'),
        const SizedBox(height: 12),
        _buildTable(),
        const SizedBox(height: 24),
        _sectionTitle('Session Highlights'),
        const SizedBox(height: 12),
        if (nanoData != null) ...[
          MetricCard(
            title: 'YOLOv8n — Avg FPS',
            value: '${nanoData!.averageFps.toStringAsFixed(1)} fps',
            subtitle: 'Min: ${nanoData!.minFps.toStringAsFixed(1)}  Max: ${nanoData!.maxFps.toStringAsFixed(1)}',
            icon: Icons.speed_rounded,
          ),
          const SizedBox(height: 10),
          MetricCard(
            title: 'YOLOv8n — Avg Latency',
            value: '${nanoData!.averageLatency.toStringAsFixed(0)} ms',
            subtitle: 'Min: ${nanoData!.minLatency.toStringAsFixed(0)} ms  Max: ${nanoData!.maxLatency.toStringAsFixed(0)} ms',
            icon: Icons.timer_rounded,
            color: Colors.amber,
          ),
          const SizedBox(height: 10),
          MetricCard(
            title: 'YOLOv8n — Peak RAM',
            value: '${nanoData!.peakRam.toStringAsFixed(0)} MB',
            subtitle: 'Avg: ${nanoData!.averageRam.toStringAsFixed(0)} MB · Size: ${nanoData!.modelSizeMb.toStringAsFixed(1)} MB',
            icon: Icons.memory_rounded,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 18),
        ],
        if (smallData != null) ...[
          MetricCard(
            title: 'YOLOv8s — Avg FPS',
            value: '${smallData!.averageFps.toStringAsFixed(1)} fps',
            subtitle: 'Min: ${smallData!.minFps.toStringAsFixed(1)}  Max: ${smallData!.maxFps.toStringAsFixed(1)}',
            icon: Icons.speed_rounded,
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(height: 10),
          MetricCard(
            title: 'YOLOv8s — Avg Latency',
            value: '${smallData!.averageLatency.toStringAsFixed(0)} ms',
            subtitle: 'Min: ${smallData!.minLatency.toStringAsFixed(0)} ms  Max: ${smallData!.maxLatency.toStringAsFixed(0)} ms',
            icon: Icons.timer_rounded,
            color: Colors.deepOrange,
          ),
          const SizedBox(height: 10),
          MetricCard(
            title: 'YOLOv8s — Peak RAM',
            value: '${smallData!.peakRam.toStringAsFixed(0)} MB',
            subtitle: 'Avg: ${smallData!.averageRam.toStringAsFixed(0)} MB · Size: ${smallData!.modelSizeMb.toStringAsFixed(1)} MB',
            icon: Icons.memory_rounded,
            color: Colors.purpleAccent,
          ),
        ],
        if (nanoData == null && smallData == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(children: [
                const Icon(Icons.hourglass_empty_rounded,
                    color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Belum ada data.\nKembali ke Home dan jalankan deteksi.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: Colors.white38, fontSize: 14, height: 1.6),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _buildTable() {
    final rows = [
      _TableRow('Average FPS', nanoData?.averageFps, smallData?.averageFps, higherBetter: true),
      _TableRow('Min FPS', nanoData?.minFps, smallData?.minFps, higherBetter: true),
      _TableRow('Max FPS', nanoData?.maxFps, smallData?.maxFps, higherBetter: true),
      _TableRow('Avg Latency (ms)', nanoData?.averageLatency, smallData?.averageLatency, higherBetter: false),
      _TableRow('Min Latency (ms)', nanoData?.minLatency, smallData?.minLatency, higherBetter: false),
      _TableRow('Max Latency (ms)', nanoData?.maxLatency, smallData?.maxLatency, higherBetter: false),
      _TableRow('Avg RAM (MB)', nanoData?.averageRam, smallData?.averageRam, higherBetter: false),
      _TableRow('Peak RAM (MB)', nanoData?.peakRam, smallData?.peakRam, higherBetter: false),
      _TableRow('Model Size (MB)', nanoData?.modelSizeMb, smallData?.modelSizeMb, higherBetter: false),
      _TableRow('Avg Objects', nanoData?.averageObjects, smallData?.averageObjects, higherBetter: true),
      _TableRow('Success Rate (%)',
          nanoData != null ? nanoData!.detectionSuccessRate * 100 : null,
          smallData != null ? smallData!.detectionSuccessRate * 100 : null,
          higherBetter: true),
      _TableRow('FPS Stability (%)',
          nanoData != null ? nanoData!.fpsStability * 100 : null,
          smallData != null ? smallData!.fpsStability * 100 : null,
          higherBetter: true),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.6),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
        },
        border: TableBorder.symmetric(
          inside: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        children: [
          // Header
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF0F172A)),
            children: ['Metric', 'YOLOv8n', 'YOLOv8s']
                .map((h) => _cell(h, header: true))
                .toList(),
          ),
          ...rows.map((r) => TableRow(children: [
                _cell(r.label, metricName: true),
                _cell(_fmt(r.nanoVal, r.label), winner: r.nanoWins),
                _cell(_fmt(r.smallVal, r.label), winner: r.smallWins),
              ])),
        ],
      ),
    );
  }

  String _fmt(double? v, String label) {
    if (v == null) return 'N/A';
    if (label.contains('%')) return '${v.toStringAsFixed(1)}%';
    if (label.contains('ms') || label.contains('MB')) {
      return v.toStringAsFixed(label.contains('MB') ? 1 : 0);
    }
    return v.toStringAsFixed(1);
  }

  Widget _cell(String text,
      {bool header = false, bool metricName = false, bool winner = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: metricName ? TextAlign.left : TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight:
              header || winner ? FontWeight.bold : FontWeight.normal,
          color: header
              ? Colors.white
              : winner
                  ? const Color(0xFF10B981)
                  : metricName
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.outfit(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
}

class _TableRow {
  final String label;
  final double? nanoVal;
  final double? smallVal;
  final bool higherBetter;

  _TableRow(this.label, this.nanoVal, this.smallVal,
      {required this.higherBetter});

  bool get nanoWins {
    if (nanoVal == null || smallVal == null) return false;
    return higherBetter ? nanoVal! > smallVal! : nanoVal! < smallVal!;
  }

  bool get smallWins {
    if (nanoVal == null || smallVal == null) return false;
    return higherBetter ? smallVal! > nanoVal! : smallVal! < nanoVal!;
  }
}

// ── Conclusion Box ────────────────────────────────────────────────────────────

class _ConclusionBox extends StatelessWidget {
  final ModelBenchmarkData? nanoData;
  final ModelBenchmarkData? smallData;

  const _ConclusionBox({required this.nanoData, required this.smallData});

  String _conclusion() {
    if (nanoData == null && smallData == null) {
      return 'Belum ada data benchmark. Jalankan deteksi dengan kedua model untuk mendapatkan perbandingan.';
    }
    if (nanoData == null) return 'Hanya data YOLOv8s tersedia. Jalankan YOLOv8n untuk perbandingan.';
    if (smallData == null) return 'Hanya data YOLOv8n tersedia. Jalankan YOLOv8s untuk perbandingan.';

    final faster = nanoData!.averageFps > smallData!.averageFps ? 'YOLOv8n' : 'YOLOv8s';
    final moreAccurate = nanoData!.detectionSuccessRate > smallData!.detectionSuccessRate
        ? 'YOLOv8n'
        : 'YOLOv8s';

    return '📊 $faster memiliki FPS lebih tinggi '
        '(${nanoData!.averageFps.toStringAsFixed(1)} vs ${smallData!.averageFps.toStringAsFixed(1)} fps).\n\n'
        '⚡ Latency — YOLOv8n: ${nanoData!.averageLatency.toStringAsFixed(0)} ms  |  '
        'YOLOv8s: ${smallData!.averageLatency.toStringAsFixed(0)} ms.\n\n'
        '💾 RAM — YOLOv8n: ${nanoData!.averageRam.toStringAsFixed(0)} MB  |  '
        'YOLOv8s: ${smallData!.averageRam.toStringAsFixed(0)} MB.\n\n'
        '🎯 $moreAccurate memiliki detection success rate lebih tinggi '
        '(${(nanoData!.detectionSuccessRate * 100).toStringAsFixed(1)}% vs '
        '${(smallData!.detectionSuccessRate * 100).toStringAsFixed(1)}%).\n\n'
        '✅ Rekomendasi: YOLOv8n untuk perangkat mid-range (stabilitas & kecepatan). '
        'YOLOv8s untuk flagship yang mengutamakan akurasi.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.2), width: 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lightbulb_outline_rounded,
            color: Color(0xFF10B981), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _conclusion(),
            style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 13,
                height: 1.6),
          ),
        ),
      ]),
    );
  }
}

// ── Export Tab ────────────────────────────────────────────────────────────────

class _ExportTab extends StatelessWidget {
  final bool hasData;
  final bool exportingPdf;
  final bool exportingCsv;
  final VoidCallback onExportPdf;
  final VoidCallback onExportCsv;

  const _ExportTab({
    required this.hasData,
    required this.exportingPdf,
    required this.exportingCsv,
    required this.onExportPdf,
    required this.onExportCsv,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Export Hasil Benchmark',
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Ekspor data untuk kebutuhan jurnal dan penelitian.',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 28),

        // PDF Export
        _ExportCard(
          icon: Icons.picture_as_pdf_rounded,
          color: const Color(0xFFEF4444),
          title: 'Export PDF Report',
          description:
              'Laporan lengkap dengan semua statistik, bar chart perbandingan, dan kesimpulan otomatis. Siap untuk jurnal.',
          buttonLabel: 'Export PDF',
          loading: exportingPdf,
          enabled: hasData,
          onTap: onExportPdf,
        ),
        const SizedBox(height: 16),

        // CSV Export
        _ExportCard(
          icon: Icons.table_view_rounded,
          color: const Color(0xFF10B981),
          title: 'Export CSV Data',
          description:
              'Raw data semua metrik + FPS timeline untuk analisis lebih lanjut di Excel/Python/MATLAB.',
          buttonLabel: 'Export CSV',
          loading: exportingCsv,
          enabled: hasData,
          onTap: onExportCsv,
        ),
        const SizedBox(height: 28),

        // Metrics included
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Metrik yang Disertakan',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 10),
              ...[
                'Average / Min / Max FPS',
                'Average / Min / Max Latency (ms)',
                'Average / Peak RAM Usage (MB)',
                'Model Size (MB)',
                'Average Objects per Frame',
                'Detection Success Rate (%)',
                'FPS Stability Score',
                'Total Inference Count',
                'Session Duration (s)',
                'FPS Timeline (sampled)',
              ].map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF10B981), size: 15),
                      const SizedBox(width: 8),
                      Text(m,
                          style: GoogleFonts.inter(
                              color: Colors.white70, fontSize: 12)),
                    ]),
                  )),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String buttonLabel;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  const _ExportCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(description,
            style: GoogleFonts.inter(
                color: Colors.white60, fontSize: 12, height: 1.5)),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: enabled ? color : Colors.white12,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: enabled && !loading ? onTap : null,
            child: loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    enabled ? buttonLabel : 'Jalankan deteksi terlebih dahulu',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
          ),
        ),
      ]),
    );
  }
}
