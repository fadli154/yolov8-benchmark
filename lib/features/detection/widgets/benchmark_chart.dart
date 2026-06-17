import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../models/benchmark.dart';

/// All benchmark charts for journal comparison.
/// Displays: Bar Chart, Line Chart, Pie Chart, Radar Chart.
class BenchmarkChartWidget extends StatefulWidget {
  final List<ModelBenchmarkData> history;

  const BenchmarkChartWidget({
    super.key,
    required this.history,
  });

  @override
  State<BenchmarkChartWidget> createState() => _BenchmarkChartWidgetState();
}

class _BenchmarkChartWidgetState extends State<BenchmarkChartWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _selectedModelFilter = 'All'; // 'All', 'YOLOv8n', 'YOLOv8s'
  String _selectedBackendFilter = 'All'; // 'All', 'CPU', 'GPU', 'NNAPI'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Apply filters to history ─────────────────────────────────────────────
    final filtered = widget.history.where((run) {
      final matchesModel = _selectedModelFilter == 'All' ||
          run.modelName.toLowerCase().contains(_selectedModelFilter.toLowerCase());
      final matchesBackend = _selectedBackendFilter == 'All' ||
          run.backendType.toUpperCase() == _selectedBackendFilter.toUpperCase();
      return matchesModel && matchesBackend;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters Row
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedModelFilter,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    onChanged: (v) => setState(() => _selectedModelFilter = v!),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('Semua Model')),
                      DropdownMenuItem(value: 'YOLOv8n', child: Text('YOLOv8n (Nano)')),
                      DropdownMenuItem(value: 'YOLOv8s', child: Text('YOLOv8s (Small)')),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBackendFilter,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    onChanged: (v) => setState(() => _selectedBackendFilter = v!),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('Semua Backend')),
                      DropdownMenuItem(value: 'CPU', child: Text('CPU')),
                      DropdownMenuItem(value: 'GPU', child: Text('GPU')),
                      DropdownMenuItem(value: 'NNAPI', child: Text('NNAPI')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF10B981),
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFF10B981),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Bar'),
              Tab(text: 'Line'),
              Tab(text: 'Pie'),
              Tab(text: 'Radar'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabController,
            children: [
              _BarChartTab(history: filtered),
              _LineChartTab(history: filtered),
              _PieChartTab(history: filtered),
              _RadarChartTab(history: filtered),
            ],
          ),
        ),
        const SizedBox(height: 14),
        
        // Legend
        Center(
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: filtered.map((run) {
              return _LegendItem(
                color: _getRunColor(run),
                label: '${run.modelName} (${run.backendType})',
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Colors ────────────────────────────────────────────────────────────────────

Color _getRunColor(ModelBenchmarkData run) {
  final name = run.modelName.toLowerCase();
  final backend = run.backendType.toUpperCase();
  if (name.contains('8n') || name.contains('nano')) {
    if (backend == 'GPU') return const Color(0xFF10B981); // Emerald (Green)
    if (backend == 'NNAPI') return const Color(0xFF34D399); // Mint
    return const Color(0xFF047857); // Dark Green (CPU)
  } else {
    if (backend == 'GPU') return const Color(0xFF6366F1); // Indigo (Purple-Blue)
    if (backend == 'NNAPI') return const Color(0xFF818CF8); // Light Indigo/Blue
    return const Color(0xFF4338CA); // Dark Indigo (CPU)
  }
}

// ── Bar Chart ─────────────────────────────────────────────────────────────────

class _BarChartTab extends StatelessWidget {
  final List<ModelBenchmarkData> history;

  const _BarChartTab({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return _NoDataPlaceholder();

    final List<double> allValues = [];
    for (final run in history) {
      allValues.add(run.averageFps);
      allValues.add(run.averageLatency);
      allValues.add(run.averageRam);
      allValues.add(run.modelSizeMb);
    }
    final maxY = (allValues.isEmpty ? 10.0 : allValues.reduce(max)) * 1.25;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF0F172A),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (rodIndex >= history.length) return null;
              final run = history[rodIndex];
              return BarTooltipItem(
                '${run.modelName} (${run.backendType})\n${rod.toY.toStringAsFixed(1)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                final titles = ['FPS', 'Latency\n(ms)', 'RAM\n(MB)', 'Size\n(MB)'];
                if (idx < 0 || idx >= titles.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    titles[idx],
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(
          show: true,
          horizontalInterval: 100,
          getDrawingHorizontalLine: _whiteGridLine,
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(4, (i) {
          return BarChartGroupData(
            x: i,
            barsSpace: 4,
            barRods: List.generate(history.length, (runIndex) {
              final run = history[runIndex];
              double toY = 0.0;
              if (i == 0) toY = run.averageFps;
              if (i == 1) toY = run.averageLatency;
              if (i == 2) toY = run.averageRam;
              if (i == 3) toY = run.modelSizeMb;
              return BarChartRodData(
                toY: toY,
                color: _getRunColor(run),
                width: history.length > 5 ? 5 : 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              );
            }),
          );
        }),
      ),
    );
  }
}

// ── Line Chart ────────────────────────────────────────────────────────────────

class _LineChartTab extends StatelessWidget {
  final List<ModelBenchmarkData> history;

  const _LineChartTab({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return _NoDataPlaceholder();

    final List<LineChartBarData> lines = [];

    for (int runIndex = 0; runIndex < history.length; runIndex++) {
      final run = history[runIndex];
      final pts = _toSpots(run.fpsTimeline);
      if (pts.isNotEmpty) {
        lines.add(LineChartBarData(
          spots: pts,
          isCurved: true,
          color: _getRunColor(run),
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: _getRunColor(run).withValues(alpha: 0.04),
          ),
        ));
      }
    }

    if (lines.isEmpty) return _NoDataPlaceholder();

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF0F172A),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                if (spot.barIndex >= history.length) return null;
                final run = history[spot.barIndex];
                return LineTooltipItem(
                  '${run.modelName} (${run.backendType})\n${spot.y.toStringAsFixed(1)} FPS',
                  TextStyle(color: _getRunColor(run), fontSize: 10, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Frame Sample', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ),
            sideTitles: const SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('FPS', style: TextStyle(color: Colors.white38, fontSize: 10)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(
          show: true,
          getDrawingHorizontalLine: _whiteGridLine,
          getDrawingVerticalLine: _whiteGridLine,
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: lines,
      ),
    );
  }

  List<FlSpot> _toSpots(List<double> data) {
    return List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]));
  }
}

// ── Pie Chart ─────────────────────────────────────────────────────────────────

class _PieChartTab extends StatefulWidget {
  final List<ModelBenchmarkData> history;

  const _PieChartTab({required this.history});

  @override
  State<_PieChartTab> createState() => _PieChartTabState();
}

class _PieChartTabState extends State<_PieChartTab> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) {
      return _NoDataPlaceholder();
    }

    final totalFps = widget.history.map((e) => e.averageFps).fold(0.0, (a, b) => a + b);
    final hasTotal = totalFps > 0;

    final sections = <PieChartSectionData>[];

    for (int i = 0; i < widget.history.length; i++) {
      final run = widget.history[i];
      final fps = run.averageFps;
      final pct = hasTotal ? (fps / totalFps * 100) : 0.0;
      
      sections.add(PieChartSectionData(
        value: fps,
        title: '${run.modelName.replaceAll('YOLOv8', '')} (${run.backendType})\n${pct.toStringAsFixed(0)}%',
        color: _getRunColor(run),
        radius: _touchedIndex == i ? 85 : 70,
        titleStyle: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    return Column(
      children: [
        const Text('FPS Distribution by Run',
            style: TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 8),
        Expanded(
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = -1;
                    } else {
                      _touchedIndex =
                          response.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 45,
              sections: sections,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Radar Chart ───────────────────────────────────────────────────────────────

class _RadarChartTab extends StatelessWidget {
  final List<ModelBenchmarkData> history;

  const _RadarChartTab({required this.history});

  List<RadarEntry> _entries(ModelBenchmarkData data) {
    final speed = (data.averageFps / 30 * 10).clamp(0.0, 10.0);
    final accuracy = (data.detectionSuccessRate * 10).clamp(0.0, 10.0);
    final memory = ((1 - (data.averageRam / 512).clamp(0.0, 1.0)) * 10);
    final stability = (data.fpsStability * 10).clamp(0.0, 10.0);
    return [
      RadarEntry(value: speed),
      RadarEntry(value: accuracy),
      RadarEntry(value: memory),
      RadarEntry(value: stability),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return _NoDataPlaceholder();

    final dataSets = <RadarDataSet>[];

    for (final run in history) {
      dataSets.add(RadarDataSet(
        fillColor: _getRunColor(run).withValues(alpha: 0.12),
        borderColor: _getRunColor(run),
        entryRadius: 3,
        borderWidth: 1.5,
        dataEntries: _entries(run),
      ));
    }

    return RadarChart(
      RadarChartData(
        dataSets: dataSets,
        radarBackgroundColor: Colors.transparent,
        radarBorderData: const BorderSide(color: Colors.white24, width: 1),
        gridBorderData: const BorderSide(color: Colors.white12, width: 1),
        tickCount: 4,
        ticksTextStyle:
            const TextStyle(color: Colors.transparent, fontSize: 8),
        tickBorderData: const BorderSide(color: Colors.white12),
        getTitle: (index, angle) {
          const titles = ['Speed', 'Accuracy', 'Memory\nEfficiency', 'Stability'];
          return RadarChartTitle(
            text: titles[index % 4],
            angle: 0,
          );
        },
        titlePositionPercentageOffset: 0.15,
        titleTextStyle:
            const TextStyle(color: Colors.white70, fontSize: 10),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _NoDataPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded, color: Colors.white24, size: 48),
          SizedBox(height: 10),
          Text(
            'Belum ada data benchmark untuk filter ini.\nJalankan deteksi terlebih dahulu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}

FlLine _whiteGridLine(double v) =>
    const FlLine(color: Colors.white10, strokeWidth: 0.5);
