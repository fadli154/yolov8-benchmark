import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/benchmark.dart';

/// Expandable card for a single BenchmarkRun.
/// Collapsed: shows model, backend, FPS, date.
/// Expanded: shows full metrics grid.
class RunHistoryCard extends StatefulWidget {
  final BenchmarkRun run;
  final Color accentColor;

  const RunHistoryCard({
    super.key,
    required this.run,
    this.accentColor = const Color(0xFF10B981),
  });

  @override
  State<RunHistoryCard> createState() => _RunHistoryCardState();
}

class _RunHistoryCardState extends State<RunHistoryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animCtrl;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotateAnim = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final isNano = run.modelName.toLowerCase().contains('8n');
    final color = isNano ? const Color(0xFF10B981) : const Color(0xFF6366F1);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          // ── Collapsed header ─────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Run number badge
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '#${run.runIndex}',
                      style: GoogleFonts.outfit(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Model + backend
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          run.modelName,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            _BackendBadge(backend: run.backendType),
                            const SizedBox(width: 6),
                            Text(
                              '${run.durationMinutes} min',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Key metrics
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${run.averageFps.toStringAsFixed(1)} FPS',
                        style: GoogleFonts.outfit(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        run.runTimestamp.toString().substring(5, 16),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  RotationTransition(
                    turns: _rotateAnim,
                    child: const Icon(Icons.expand_more_rounded,
                        color: Colors.white38, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded details ─────────────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: Colors.white.withValues(alpha: 0.07)),
                  const SizedBox(height: 6),
                  _MetricsGrid(run: run, color: color),
                  const SizedBox(height: 10),
                  // Device info
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.smartphone_rounded,
                            color: Colors.white24, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${run.deviceInfo} • ${run.androidVersion}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final BenchmarkRun run;
  final Color color;

  const _MetricsGrid({required this.run, required this.color});

  @override
  Widget build(BuildContext context) {
    final items = [
      _GridItem('Avg FPS', run.averageFps.toStringAsFixed(1), 'fps'),
      _GridItem('Min FPS', run.minFps.toStringAsFixed(1), 'fps'),
      _GridItem('Max FPS', run.maxFps.toStringAsFixed(1), 'fps'),
      _GridItem('Avg Latency', run.averageLatency.toStringAsFixed(1), 'ms'),
      _GridItem('Min Latency', run.minLatency.toStringAsFixed(1), 'ms'),
      _GridItem('Max Latency', run.maxLatency.toStringAsFixed(1), 'ms'),
      _GridItem('Avg RAM', run.averageRam.toStringAsFixed(1), 'MB'),
      _GridItem('Peak RAM', run.peakRam.toStringAsFixed(1), 'MB'),
      _GridItem('Model Size', run.modelSizeMb.toStringAsFixed(2), 'MB'),
      _GridItem('Inferences', run.totalInferenceCount.toString(), ''),
      _GridItem(
          'Success Rate', (run.detectionSuccessRate * 100).toStringAsFixed(1), '%'),
      _GridItem(
          'Stability', (run.fpsStability * 100).toStringAsFixed(1), '%'),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: items.map((item) => _GridCell(item: item, color: color)).toList(),
    );
  }
}

class _GridItem {
  final String label;
  final String value;
  final String unit;
  const _GridItem(this.label, this.value, this.unit);
}

class _GridCell extends StatelessWidget {
  final _GridItem item;
  final Color color;

  const _GridCell({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.label,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  item.value,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item.unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(
                    item.unit,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackendBadge extends StatelessWidget {
  final String backend;

  const _BackendBadge({required this.backend});

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
      child: Text(
        backend,
        style: TextStyle(
          color: _color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
