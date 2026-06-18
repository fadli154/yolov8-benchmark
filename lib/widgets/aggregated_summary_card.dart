import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/benchmark.dart';
import '../services/statistics_service.dart';

/// Summary card for one model+backend aggregated result.
/// Shows run count, mean FPS ± std, mean latency, mean RAM.
class AggregatedSummaryCard extends StatelessWidget {
  final BenchmarkAggregated agg;
  final bool isFastest;
  final bool isLowestLatency;
  final bool isLowestRam;

  const AggregatedSummaryCard({
    super.key,
    required this.agg,
    this.isFastest = false,
    this.isLowestLatency = false,
    this.isLowestRam = false,
  });

  Color get _accentColor {
    final isNano = agg.modelName.toLowerCase().contains('8n');
    return isNano ? const Color(0xFF10B981) : const Color(0xFF6366F1);
  }

  Color _backendColor(String backend) {
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
    final accent = _accentColor;
    final bColor = _backendColor(agg.backendType);
    final hasMultipleRuns = agg.runCount > 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFastest
              ? accent.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.07),
          width: isFastest ? 1.5 : 1,
        ),
        boxShadow: isFastest
            ? [BoxShadow(color: accent.withValues(alpha: 0.1), blurRadius: 16)]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  agg.modelName.toLowerCase().contains('8n')
                      ? Icons.bolt_rounded
                      : Icons.auto_awesome_rounded,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agg.modelName,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: bColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: bColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            agg.backendType,
                            style: TextStyle(
                              color: bColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${agg.runCount} run${agg.runCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Badge column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isFastest) _Badge('⚡ Fastest', accent),
                  if (isLowestLatency)
                    _Badge('⏱ Low Latency', const Color(0xFF3B82F6)),
                  if (isLowestRam)
                    _Badge('🧠 Low RAM', const Color(0xFFF59E0B)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Main metrics row ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MetricColumn(
                  label: 'Avg FPS',
                  value: hasMultipleRuns
                      ? StatisticsService.formatMeanStd(agg.meanFps, agg.stdFps)
                      : agg.meanFps.toStringAsFixed(1),
                  color: accent,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _MetricColumn(
                  label: 'Latency',
                  value: hasMultipleRuns
                      ? '${agg.meanLatency.toStringAsFixed(1)}±${agg.stdLatency.toStringAsFixed(1)} ms'
                      : '${agg.meanLatency.toStringAsFixed(1)} ms',
                  color: Colors.white70,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _MetricColumn(
                  label: 'RAM',
                  value: hasMultipleRuns
                      ? '${agg.meanRam.toStringAsFixed(0)}±${agg.stdRam.toStringAsFixed(0)} MB'
                      : '${agg.meanRam.toStringAsFixed(0)} MB',
                  color: Colors.white70,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _MetricColumn(
                  label: 'Avg Objects',
                  value: agg.meanObjects.toStringAsFixed(1),
                  color: const Color(0xFFEC4899),
                ),
              ),
            ],
          ),
          if (hasMultipleRuns) ...[
            const SizedBox(height: 12),
            // CV + Stability row
            Row(
              children: [
                _SmallStat('CV FPS', '${agg.cvFps.toStringAsFixed(1)}%'),
                const SizedBox(width: 12),
                _SmallStat('Stability',
                    '${(agg.meanFpsStability * 100).toStringAsFixed(1)}%'),
                const SizedBox(width: 12),
                _SmallStat('Success',
                    '${(agg.meanSuccessRate * 100).toStringAsFixed(1)}%'),
                const Spacer(),
                _SmallStat('Model', '${agg.modelSizeMb.toStringAsFixed(1)} MB'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricColumn(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;

  const _SmallStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(children: [
        TextSpan(
          text: '$label: ',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        TextSpan(
          text: value,
          style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
      ]),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.07),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
