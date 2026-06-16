import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../models/benchmark.dart';

/// All benchmark charts for journal comparison.
/// Displays: Bar Chart, Line Chart, Pie Chart, Radar Chart.
class BenchmarkChartWidget extends StatefulWidget {
  final ModelBenchmarkData? nanoData;
  final ModelBenchmarkData? smallData;

  const BenchmarkChartWidget({
    super.key,
    required this.nanoData,
    required this.smallData,
  });

  @override
  State<BenchmarkChartWidget> createState() => _BenchmarkChartWidgetState();
}

class _BenchmarkChartWidgetState extends State<BenchmarkChartWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              _BarChartTab(nanoData: widget.nanoData, smallData: widget.smallData),
              _LineChartTab(nanoData: widget.nanoData, smallData: widget.smallData),
              _PieChartTab(nanoData: widget.nanoData, smallData: widget.smallData),
              _RadarChartTab(nanoData: widget.nanoData, smallData: widget.smallData),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(color: _nanoColor, label: 'YOLOv8n'),
            const SizedBox(width: 20),
            _LegendItem(color: _smallColor, label: 'YOLOv8s'),
          ],
        ),
      ],
    );
  }
}

// ── Colors ────────────────────────────────────────────────────────────────────
const _nanoColor = Color(0xFF10B981);   // emerald
const _smallColor = Color(0xFF6366F1);  // indigo

// ── Bar Chart ─────────────────────────────────────────────────────────────────

class _BarChartTab extends StatelessWidget {
  final ModelBenchmarkData? nanoData;
  final ModelBenchmarkData? smallData;

  const _BarChartTab({required this.nanoData, required this.smallData});

  @override
  Widget build(BuildContext context) {
    if (nanoData == null && smallData == null) return _NoDataPlaceholder();

    final metrics = [
      ('FPS', nanoData?.averageFps ?? 0, smallData?.averageFps ?? 0),
      ('Latency\n(ms)', nanoData?.averageLatency ?? 0, smallData?.averageLatency ?? 0),
      ('RAM\n(MB)', nanoData?.averageRam ?? 0, smallData?.averageRam ?? 0),
      ('Size\n(MB)', nanoData?.modelSizeMb ?? 0, smallData?.modelSizeMb ?? 0),
    ];

    final maxY = metrics.map((m) => max(m.$2, m.$3)).reduce(max) * 1.3;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF0F172A),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? 'YOLOv8n' : 'YOLOv8s';
              return BarTooltipItem(
                '$label\n${rod.toY.toStringAsFixed(1)}',
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
                if (idx >= metrics.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    metrics[idx].$1,
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
              reservedSize: 36,
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
          horizontalInterval: 50,
          getDrawingHorizontalLine: _whiteGridLine,
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(metrics.length, (i) {
          return BarChartGroupData(
            x: i,
            barsSpace: 6,
            barRods: [
              if (nanoData != null)
                BarChartRodData(
                  toY: metrics[i].$2,
                  color: _nanoColor,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              if (smallData != null)
                BarChartRodData(
                  toY: metrics[i].$3,
                  color: _smallColor,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Line Chart ────────────────────────────────────────────────────────────────

class _LineChartTab extends StatelessWidget {
  final ModelBenchmarkData? nanoData;
  final ModelBenchmarkData? smallData;

  const _LineChartTab({required this.nanoData, required this.smallData});

  @override
  Widget build(BuildContext context) {
    if (nanoData == null && smallData == null) return _NoDataPlaceholder();

    final List<LineChartBarData> lines = [];

    if (nanoData != null) {
      final pts = _toSpots(nanoData!.fpsTimeline);
      if (pts.isNotEmpty) {
        lines.add(LineChartBarData(
          spots: pts,
          isCurved: true,
          color: _nanoColor,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: _nanoColor.withValues(alpha: 0.08),
          ),
        ));
      }
    }

    if (smallData != null) {
      final pts = _toSpots(smallData!.fpsTimeline);
      if (pts.isNotEmpty) {
        lines.add(LineChartBarData(
          spots: pts,
          isCurved: true,
          color: _smallColor,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: _smallColor.withValues(alpha: 0.08),
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
  final ModelBenchmarkData? nanoData;
  final ModelBenchmarkData? smallData;

  const _PieChartTab({required this.nanoData, required this.smallData});

  @override
  State<_PieChartTab> createState() => _PieChartTabState();
}

class _PieChartTabState extends State<_PieChartTab> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.nanoData == null && widget.smallData == null) {
      return _NoDataPlaceholder();
    }

    // Show relative metric distribution across models for available data
    // Pie = FPS proportion for each model (share of total combined FPS)
    final nFps = widget.nanoData?.averageFps ?? 0.0;
    final sFps = widget.smallData?.averageFps ?? 0.0;
    final total = nFps + sFps;
    final hasTotal = total > 0;

    final sections = <PieChartSectionData>[];

    if (widget.nanoData != null && hasTotal) {
      sections.add(PieChartSectionData(
        value: nFps,
        title: 'n: ${(nFps / total * 100).toStringAsFixed(0)}%',
        color: _nanoColor,
        radius: _touchedIndex == 0 ? 90 : 75,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    if (widget.smallData != null && hasTotal) {
      sections.add(PieChartSectionData(
        value: sFps,
        title: 's: ${(sFps / total * 100).toStringAsFixed(0)}%',
        color: _smallColor,
        radius: _touchedIndex == 1 ? 90 : 75,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    return Column(
      children: [
        const Text('FPS Share — YOLOv8n vs YOLOv8s',
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
              sectionsSpace: 3,
              centerSpaceRadius: 55,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'n=${nFps.toStringAsFixed(1)} fps  |  s=${sFps.toStringAsFixed(1)} fps',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}

// ── Radar Chart ───────────────────────────────────────────────────────────────

class _RadarChartTab extends StatelessWidget {
  final ModelBenchmarkData? nanoData;
  final ModelBenchmarkData? smallData;

  const _RadarChartTab({required this.nanoData, required this.smallData});

  /// Normalize metrics to 0–10 scale for radar.
  List<RadarEntry> _entries(ModelBenchmarkData? data) {
    if (data == null) {
      return List.generate(4, (_) => const RadarEntry(value: 0));
    }
    // Speed: avg FPS, capped at 30 FPS = 10
    final speed = (data.averageFps / 30 * 10).clamp(0.0, 10.0);
    // Accuracy: detection success rate * 10
    final accuracy = (data.detectionSuccessRate * 10).clamp(0.0, 10.0);
    // Memory efficiency: inverse RAM usage (512 MB = worst)
    final memory = ((1 - (data.averageRam / 512).clamp(0.0, 1.0)) * 10);
    // Stability: FPS stability * 10
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
    if (nanoData == null && smallData == null) return _NoDataPlaceholder();

    final dataSets = <RadarDataSet>[];

    if (nanoData != null) {
      dataSets.add(RadarDataSet(
        fillColor: _nanoColor.withValues(alpha: 0.18),
        borderColor: _nanoColor,
        entryRadius: 4,
        borderWidth: 2,
        dataEntries: _entries(nanoData),
      ));
    }

    if (smallData != null) {
      dataSets.add(RadarDataSet(
        fillColor: _smallColor.withValues(alpha: 0.18),
        borderColor: _smallColor,
        entryRadius: 4,
        borderWidth: 2,
        dataEntries: _entries(smallData),
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
            'Belum ada data benchmark.\nJalankan deteksi terlebih dahulu.',
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
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}

FlLine _whiteGridLine(double v) =>
    const FlLine(color: Colors.white10, strokeWidth: 0.5);
