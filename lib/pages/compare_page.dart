import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/detection/services/benchmark_service.dart';
import '../features/detection/widgets/benchmark_chart.dart';
import '../models/benchmark.dart';
import '../services/statistics_service.dart';
import '../widgets/aggregated_summary_card.dart';
import '../widgets/conclusion_card.dart';
import '../widgets/metric_stat_card.dart';
import '../widgets/run_history_card.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ComparePage — 5-Tab Benchmark Comparison Dashboard
// ═══════════════════════════════════════════════════════════════════════════════

class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DetectionBenchmarkService _svc;

  List<ModelBenchmarkData> _history = [];
  List<BenchmarkRun> _runs = [];
  Map<String, BenchmarkAggregated> _aggregated = {};

  bool _exportingPdf = false;
  bool _exportingCsv = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _svc = Get.find<DetectionBenchmarkService>();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _history = List.from(_svc.history);
      _runs = List.from(_svc.runs);
      _aggregated = _svc.aggregatedResults;
    });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset All Data?',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'All benchmark runs, sessions, and aggregated statistics will be permanently deleted.',
          style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              _svc.reset();
              Navigator.pop(context);
              _refresh();
            },
            child: const Text('Reset',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  bool get _hasAnyData => _runs.isNotEmpty || _history.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text('Benchmark Results',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          if (_hasAnyData)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _refresh,
              tooltip: 'Refresh',
            ),
          if (_hasAnyData)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: _reset,
              tooltip: 'Reset all data',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF10B981),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle:
              const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Summary'),
            Tab(icon: Icon(Icons.analytics_rounded, size: 18), text: 'Stats'),
            Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'History'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Charts'),
            Tab(icon: Icon(Icons.download_rounded, size: 18), text: 'Export'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1 — Summary
          _SummaryTab(
              aggregated: _aggregated,
              runs: _runs,
              history: _history),
          // Tab 2 — Statistics table
          _StatisticsTab(aggregated: _aggregated, runs: _runs),
          // Tab 3 — Run History
          _HistoryTab(runs: _runs, history: _history),
          // Tab 4 — Charts
          _ChartsTab(history: _history),
          // Tab 5 — Export
          _ExportTab(
            hasData: _hasAnyData,
            exportingPdf: _exportingPdf,
            exportingCsv: _exportingCsv,
            onExportPdf: () async {
              setState(() => _exportingPdf = true);
              await _svc.exportPdf();
              if (mounted) setState(() => _exportingPdf = false);
            },
            onExportCsv: () async {
              setState(() => _exportingCsv = true);
              await _svc.exportCsv();
              if (mounted) setState(() => _exportingCsv = false);
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 1 — Summary
// ═══════════════════════════════════════════════════════════════════════════════

class _SummaryTab extends StatelessWidget {
  final Map<String, BenchmarkAggregated> aggregated;
  final List<BenchmarkRun> runs;
  final List<ModelBenchmarkData> history;

  const _SummaryTab({
    required this.aggregated,
    required this.runs,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    if (aggregated.isEmpty && history.isEmpty) {
      return _EmptyState(
        icon: Icons.dashboard_rounded,
        title: 'No benchmark data yet',
        subtitle:
            'Tap "Run Benchmark" on the home screen to start a timed session.',
      );
    }

    final fastest = StatisticsService.fastestCombo(aggregated);
    final lowLat = StatisticsService.lowestLatencyCombo(aggregated);
    final lowRam = StatisticsService.lowestRamCombo(aggregated);

    // Group aggregated by model
    final nanoEntries = aggregated.values
        .where((a) => a.modelName.toLowerCase().contains('8n'))
        .toList()
      ..sort((a, b) => a.backendType.compareTo(b.backendType));
    final smallEntries = aggregated.values
        .where((a) => !a.modelName.toLowerCase().contains('8n'))
        .toList()
      ..sort((a, b) => a.backendType.compareTo(b.backendType));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick stats row
          if (runs.isNotEmpty) ...[
            _QuickStatsRow(runs: runs, aggregated: aggregated),
            const SizedBox(height: 20),
          ],

          // YOLOv8n section
          if (nanoEntries.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.bolt_rounded,
              color: const Color(0xFF10B981),
              title: 'YOLOv8n (Nano)',
              subtitle: '${nanoEntries.fold(0, (s, a) => s + a.runCount)} total runs',
            ),
            const SizedBox(height: 10),
            ...nanoEntries.map((agg) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AggregatedSummaryCard(
                    agg: agg,
                    isFastest: fastest?.groupKey == agg.groupKey,
                    isLowestLatency: lowLat?.groupKey == agg.groupKey,
                    isLowestRam: lowRam?.groupKey == agg.groupKey,
                  ),
                )),
            const SizedBox(height: 12),
          ],

          // YOLOv8s section
          if (smallEntries.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.auto_awesome_rounded,
              color: const Color(0xFF6366F1),
              title: 'YOLOv8s (Small)',
              subtitle: '${smallEntries.fold(0, (s, a) => s + a.runCount)} total runs',
            ),
            const SizedBox(height: 10),
            ...smallEntries.map((agg) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AggregatedSummaryCard(
                    agg: agg,
                    isFastest: fastest?.groupKey == agg.groupKey,
                    isLowestLatency: lowLat?.groupKey == agg.groupKey,
                    isLowestRam: lowRam?.groupKey == agg.groupKey,
                  ),
                )),
            const SizedBox(height: 12),
          ],

          // Legacy passive sessions (if no runs yet)
          if (runs.isEmpty && history.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.history_rounded,
              color: Colors.white38,
              title: 'Detection Sessions',
              subtitle: '${history.length} session(s)',
            ),
            const SizedBox(height: 10),
            ...history.map((data) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LegacySessionCard(data: data),
                )),
            const SizedBox(height: 12),
          ],

          // Conclusion card
          ConclusionCard(aggregated: aggregated),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final List<BenchmarkRun> runs;
  final Map<String, BenchmarkAggregated> aggregated;

  const _QuickStatsRow({required this.runs, required this.aggregated});

  @override
  Widget build(BuildContext context) {
    final combos = aggregated.length;
    final totalRuns = runs.length;
    final bestFps = aggregated.isEmpty
        ? 0.0
        : aggregated.values.map((a) => a.meanFps).reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        Expanded(
            child: _QuickStat('Combos Tested', '$combos',
                const Color(0xFF10B981), Icons.compare_arrows_rounded)),
        const SizedBox(width: 8),
        Expanded(
            child: _QuickStat('Total Runs', '$totalRuns',
                const Color(0xFF3B82F6), Icons.repeat_rounded)),
        const SizedBox(width: 8),
        Expanded(
            child: _QuickStat('Best FPS',
                bestFps > 0 ? bestFps.toStringAsFixed(1) : '--',
                const Color(0xFFF59E0B), Icons.speed_rounded)),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _QuickStat(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.outfit(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegacySessionCard extends StatelessWidget {
  final ModelBenchmarkData data;

  const _LegacySessionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isNano = data.modelName.toLowerCase().contains('8n');
    final color =
        isNano ? const Color(0xFF10B981) : const Color(0xFF6366F1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isNano ? Icons.bolt_rounded : Icons.auto_awesome_rounded,
                  color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${data.modelName} (${data.backendType})',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                data.benchmarkTimestamp.toString().substring(5, 16),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniStat('FPS', data.averageFps.toStringAsFixed(1), color),
              _MiniStat('Latency',
                  '${data.averageLatency.toStringAsFixed(0)} ms', Colors.white70),
              _MiniStat('Peak RAM',
                  '${data.peakRam.toStringAsFixed(0)} MB', Colors.white70),
              _MiniStat('Success',
                  '${(data.detectionSuccessRate * 100).toStringAsFixed(0)}%',
                  Colors.white70),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.backendStatus,
            style: TextStyle(
              color: data.backendStatus.toLowerCase().contains('active')
                  ? const Color(0xFF10B981)
                  : Colors.amber,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 9)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 2 — Statistics
// ═══════════════════════════════════════════════════════════════════════════════

class _StatisticsTab extends StatelessWidget {
  final Map<String, BenchmarkAggregated> aggregated;
  final List<BenchmarkRun> runs;

  const _StatisticsTab({required this.aggregated, required this.runs});

  @override
  Widget build(BuildContext context) {
    if (aggregated.isEmpty) {
      return _EmptyState(
        icon: Icons.analytics_rounded,
        title: 'No statistics available',
        subtitle: 'Complete at least 1 benchmark run to see statistics.',
      );
    }

    final fastest = StatisticsService.fastestCombo(aggregated);
    final lowLat = StatisticsService.lowestLatencyCombo(aggregated);
    final lowRam = StatisticsService.lowestRamCombo(aggregated);
    final stable = StatisticsService.mostStableCombo(aggregated);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FPS stats grid
          _StatsSection(
            title: 'FPS Statistics',
            icon: Icons.speed_rounded,
            color: const Color(0xFF10B981),
            children: aggregated.values.map((agg) {
              return MetricStatCard(
                label: '${agg.modelName}\n${agg.backendType}',
                meanStdValue: agg.fpsLabel(),
                unit: 'fps  •  ${agg.runCount} run(s)',
                minValue: agg.minFps.toStringAsFixed(1),
                maxValue: agg.maxFps.toStringAsFixed(1),
                accentColor: const Color(0xFF10B981),
                icon: Icons.speed_rounded,
                isBest: fastest?.groupKey == agg.groupKey,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Latency stats grid
          _StatsSection(
            title: 'Latency Statistics',
            icon: Icons.timer_rounded,
            color: const Color(0xFF3B82F6),
            children: aggregated.values.map((agg) {
              return MetricStatCard(
                label: '${agg.modelName}\n${agg.backendType}',
                meanStdValue: agg.latencyLabel(),
                unit: 'ms',
                minValue: '${agg.minLatency.toStringAsFixed(1)} ms',
                maxValue: '${agg.maxLatency.toStringAsFixed(1)} ms',
                accentColor: const Color(0xFF3B82F6),
                icon: Icons.timer_rounded,
                isBest: lowLat?.groupKey == agg.groupKey,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // RAM stats grid
          _StatsSection(
            title: 'RAM Usage Statistics',
            icon: Icons.memory_rounded,
            color: const Color(0xFFF59E0B),
            children: aggregated.values.map((agg) {
              return MetricStatCard(
                label: '${agg.modelName}\n${agg.backendType}',
                meanStdValue: agg.ramLabel(),
                unit: 'MB  •  Peak: ${agg.peakRam.toStringAsFixed(0)} MB',
                accentColor: const Color(0xFFF59E0B),
                icon: Icons.memory_rounded,
                isBest: lowRam?.groupKey == agg.groupKey,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Stability stats grid
          _StatsSection(
            title: 'FPS Stability',
            icon: Icons.show_chart_rounded,
            color: const Color(0xFF8B5CF6),
            children: aggregated.values.map((agg) {
              return MetricStatCard(
                label: '${agg.modelName}\n${agg.backendType}',
                meanStdValue:
                    '${(agg.meanFpsStability * 100).toStringAsFixed(1)}%',
                unit: 'CV: ${agg.cvFps.toStringAsFixed(1)}%  •  ${agg.runCount} run(s)',
                accentColor: const Color(0xFF8B5CF6),
                icon: Icons.show_chart_rounded,
                isBest: stable?.groupKey == agg.groupKey,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Full comparison table (scrollable)
          _FullStatsTable(aggregated: aggregated),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _StatsSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(title,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.5,
          children: children,
        ),
      ],
    );
  }
}

class _FullStatsTable extends StatelessWidget {
  final Map<String, BenchmarkAggregated> aggregated;

  const _FullStatsTable({required this.aggregated});

  @override
  Widget build(BuildContext context) {
    final entries = aggregated.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Full Comparison Table',
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Mean ± Std (per model × backend combination)',
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF0F172A)),
              dataRowColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? const Color(0xFF10B981).withValues(alpha: 0.08)
                      : null),
              columnSpacing: 20,
              horizontalMargin: 14,
              headingTextStyle: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
              dataTextStyle: GoogleFonts.inter(
                  color: Colors.white70, fontSize: 10),
              columns: const [
                DataColumn(label: Text('Model')),
                DataColumn(label: Text('Backend')),
                DataColumn(label: Text('Runs'), numeric: true),
                DataColumn(label: Text('FPS (μ±σ)')),
                DataColumn(label: Text('CV%'), numeric: true),
                DataColumn(label: Text('Latency (μ±σ)')),
                DataColumn(label: Text('RAM (μ±σ)')),
                DataColumn(label: Text('Stability'), numeric: true),
                DataColumn(label: Text('Success'), numeric: true),
              ],
              rows: entries.map((agg) {
                return DataRow(cells: [
                  DataCell(Text(
                    agg.modelName.replaceAll('YOLOv8', 'v8'),
                    overflow: TextOverflow.ellipsis,
                  )),
                  DataCell(_BackendChip(agg.backendType)),
                  DataCell(Text('${agg.runCount}')),
                  DataCell(Text(
                      '${agg.meanFps.toStringAsFixed(1)}±${agg.stdFps.toStringAsFixed(1)}')),
                  DataCell(Text('${agg.cvFps.toStringAsFixed(1)}%')),
                  DataCell(Text(
                      '${agg.meanLatency.toStringAsFixed(1)}±${agg.stdLatency.toStringAsFixed(1)}')),
                  DataCell(Text(
                      '${agg.meanRam.toStringAsFixed(0)}±${agg.stdRam.toStringAsFixed(0)}')),
                  DataCell(Text(
                      '${(agg.meanFpsStability * 100).toStringAsFixed(0)}%')),
                  DataCell(Text(
                      '${(agg.meanSuccessRate * 100).toStringAsFixed(0)}%')),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackendChip extends StatelessWidget {
  final String backend;
  const _BackendChip(this.backend);

  Color get _color {
    switch (backend.toUpperCase()) {
      case 'GPU':
        return const Color(0xFFF59E0B);
      case 'NNAPI':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(backend,
          style: TextStyle(
              color: _color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 3 — Run History
// ═══════════════════════════════════════════════════════════════════════════════

class _HistoryTab extends StatelessWidget {
  final List<BenchmarkRun> runs;
  final List<ModelBenchmarkData> history;

  const _HistoryTab({required this.runs, required this.history});

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty && history.isEmpty) {
      return _EmptyState(
        icon: Icons.history_rounded,
        title: 'No run history',
        subtitle: 'Use "Run Benchmark" to start timed benchmark sessions.',
      );
    }

    // Group runs by model+backend
    final groups = StatisticsService.groupRunsByKey(runs);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (runs.isNotEmpty) ...[
            Text(
              '${runs.length} Benchmark Run(s)',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Grouped by model + backend combination',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 14),
            ...groups.entries.map((entry) {
              final groupRuns = entry.value
                ..sort((a, b) => b.runIndex.compareTo(a.runIndex));
              final first = groupRuns.first;
              final isNano =
                  first.modelName.toLowerCase().contains('8n');
              final color = isNano
                  ? const Color(0xFF10B981)
                  : const Color(0xFF6366F1);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group header
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            isNano
                                ? Icons.bolt_rounded
                                : Icons.auto_awesome_rounded,
                            color: color,
                            size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${first.modelName} × ${first.backendType}',
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${groupRuns.length} run(s)',
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  ...groupRuns.map((run) => RunHistoryCard(
                        run: run,
                        accentColor: color,
                      )),
                  const SizedBox(height: 8),
                ],
              );
            }),
          ],

          // Legacy history section
          if (history.isNotEmpty) ...[
            if (runs.isNotEmpty) ...[
              const Divider(color: Colors.white12, height: 32),
              Text(
                'Detection Sessions (Passive)',
                style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Recorded during live detection (not timed runs)',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
              const SizedBox(height: 10),
            ],
            ...history.reversed.map((data) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LegacySessionCard(data: data),
                )),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 4 — Charts
// ═══════════════════════════════════════════════════════════════════════════════

class _ChartsTab extends StatelessWidget {
  final List<ModelBenchmarkData> history;

  const _ChartsTab({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return _EmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'No chart data',
        subtitle: 'Complete benchmark sessions to visualize performance.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          BenchmarkChartWidget(history: history),
          const SizedBox(height: 24),
          ConclusionCard(aggregated: {}),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 5 — Export
// ═══════════════════════════════════════════════════════════════════════════════

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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export Benchmark Data',
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Export results for academic documentation and journal submission.',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 24),

          _ExportCard(
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFFEF4444),
            title: 'Export PDF Report',
            description:
                'Full research report: statistical summary (mean ± std), FPS bar charts, backend comparison, automated conclusions. Ready for journal submission.',
            buttonLabel: 'Export PDF',
            loading: exportingPdf,
            enabled: hasData,
            onTap: onExportPdf,
          ),
          const SizedBox(height: 14),

          _ExportCard(
            icon: Icons.table_view_rounded,
            color: const Color(0xFF10B981),
            title: 'Export CSV Data',
            description:
                'Raw run data + statistical summary table (mean ± std per combo) + FPS timeline. Import into Excel, Python, or MATLAB for further analysis.',
            buttonLabel: 'Export CSV',
            loading: exportingCsv,
            enabled: hasData,
            onTap: onExportCsv,
          ),
          const SizedBox(height: 24),

          // What's included
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Metrics Included in Export',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 12),
                _MetricGroup('Per Run (Raw)', [
                  'Model name & backend type',
                  'Run index & duration (minutes)',
                  'Avg / Min / Max FPS',
                  'Avg / Min / Max Latency (ms)',
                  'Avg / Peak RAM (MB)',
                  'Model size (MB)',
                  'Detection success rate (%)',
                  'FPS stability score',
                  'Total inference count',
                  'Warm-up frame count',
                  'Timestamp & device info',
                ]),
                const SizedBox(height: 10),
                _MetricGroup('Statistical Summary (per combo)', [
                  'Mean FPS ± Std Dev',
                  'Coefficient of Variation (CV%)',
                  'Mean Latency ± Std Dev',
                  'Mean RAM ± Std Dev',
                  'Best & worst run index',
                  'Mean success rate & stability',
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGroup extends StatelessWidget {
  final String title;
  final List<String> items;

  const _MetricGroup(this.title, this.items);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 11,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...items.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF10B981), size: 13),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(m,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ),
                ],
              ),
            )),
      ],
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
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  color: Colors.white54, fontSize: 12, height: 1.5)),
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
                      enabled
                          ? buttonLabel
                          : 'Run a benchmark session first',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared: Empty State
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white12, size: 52),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                  color: Colors.white38,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                  color: Colors.white24, fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
