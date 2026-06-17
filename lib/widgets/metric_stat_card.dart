import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A metric card displaying a label and a `mean ± std` formatted value,
/// with optional min/max secondary row. Used in the Statistics tab.
class MetricStatCard extends StatelessWidget {
  final String label;
  final String meanStdValue;
  final String? minValue;
  final String? maxValue;
  final String? unit;
  final Color accentColor;
  final IconData icon;
  final bool isBest;

  const MetricStatCard({
    super.key,
    required this.label,
    required this.meanStdValue,
    this.minValue,
    this.maxValue,
    this.unit,
    this.accentColor = const Color(0xFF10B981),
    this.icon = Icons.analytics_rounded,
    this.isBest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBest
              ? accentColor.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.06),
          width: isBest ? 1.5 : 1,
        ),
        boxShadow: isBest
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 12,
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isBest)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'BEST',
                    style: GoogleFonts.inter(
                      color: accentColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            meanStdValue,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (unit != null)
            Text(
              unit!,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          if (minValue != null && maxValue != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                _MinMaxChip(label: 'min', value: minValue!, color: Colors.blue),
                const SizedBox(width: 6),
                _MinMaxChip(label: 'max', value: maxValue!, color: Colors.orange),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MinMaxChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MinMaxChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 9,
                fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
