import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/benchmark.dart';
import '../services/statistics_service.dart';

/// Auto-generated conclusion card for the Summary tab.
/// Highlights the best model/backend for each key metric.
class ConclusionCard extends StatelessWidget {
  final Map<String, BenchmarkAggregated> aggregated;

  const ConclusionCard({super.key, required this.aggregated});

  @override
  Widget build(BuildContext context) {
    if (aggregated.isEmpty) {
      return _EmptyConclusion();
    }

    final fastest = StatisticsService.fastestCombo(aggregated);
    final lowLat = StatisticsService.lowestLatencyCombo(aggregated);
    final lowRam = StatisticsService.lowestRamCombo(aggregated);
    final stable = StatisticsService.mostStableCombo(aggregated);
    final bestSuccess = StatisticsService.bestSuccessRateCombo(aggregated);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D3320),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_rounded,
                    color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Research Conclusion',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (fastest != null)
            _ConclusionRow(
              icon: Icons.speed_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Fastest',
              value:
                  '${fastest.modelName} + ${fastest.backendType}',
              detail:
                  '${StatisticsService.formatMeanStd(fastest.meanFps, fastest.stdFps)} FPS',
            ),
          if (lowLat != null)
            _ConclusionRow(
              icon: Icons.timer_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: 'Lowest Latency',
              value: '${lowLat.modelName} + ${lowLat.backendType}',
              detail:
                  '${StatisticsService.formatMeanStd(lowLat.meanLatency, lowLat.stdLatency)} ms',
            ),
          if (lowRam != null)
            _ConclusionRow(
              icon: Icons.memory_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Lowest RAM',
              value: '${lowRam.modelName} + ${lowRam.backendType}',
              detail: '${lowRam.meanRam.toStringAsFixed(1)} MB avg',
            ),
          if (stable != null)
            _ConclusionRow(
              icon: Icons.show_chart_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Most Stable FPS',
              value: '${stable.modelName} + ${stable.backendType}',
              detail:
                  '${(stable.meanFpsStability * 100).toStringAsFixed(1)}% stability',
            ),
          if (bestSuccess != null)
            _ConclusionRow(
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFFEC4899),
              title: 'Best Detection Rate',
              value:
                  '${bestSuccess.modelName} + ${bestSuccess.backendType}',
              detail:
                  '${(bestSuccess.meanSuccessRate * 100).toStringAsFixed(1)}% success',
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _recommendation(fastest, lowRam),
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 11.5,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _recommendation(
      BenchmarkAggregated? fastest, BenchmarkAggregated? lowRam) {
    final parts = <String>[];
    if (fastest != null) {
      parts.add(
          '${fastest.modelName} with ${fastest.backendType} delegate achieves the highest throughput (${fastest.meanFps.toStringAsFixed(1)} FPS avg), making it optimal for real-time deployment on Android.');
    }
    if (lowRam != null && lowRam.groupKey != fastest?.groupKey) {
      parts.add(
          '${lowRam.modelName} with ${lowRam.backendType} uses the least memory (${lowRam.meanRam.toStringAsFixed(0)} MB avg), recommended for memory-constrained devices.');
    }
    if (parts.isEmpty) {
      return 'Run more benchmark sessions across different model/backend combinations to generate a recommendation.';
    }
    return parts.join(' ');
  }
}

class _ConclusionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String detail;

  const _ConclusionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.87),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            detail,
            style: TextStyle(
              color: iconColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConclusion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          const Icon(Icons.science_rounded, color: Colors.white24, size: 36),
          const SizedBox(height: 10),
          Text(
            'No benchmark data yet',
            style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Run benchmarks across multiple model/backend combinations to see automatic research conclusions here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: Colors.white38, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}
