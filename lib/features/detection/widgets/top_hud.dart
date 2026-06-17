import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/detection_controller.dart';
import 'glass_card.dart';

/// Top HUD showing model name, status dot, and live metrics.
/// Uses Obx — only this widget rebuilds when metrics change.
class TopHudWidget extends StatelessWidget {
  const TopHudWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<DetectionController>();

    return Positioned(
      top: 52,
      left: 16,
      right: 16,
      child: Obx(() {
        final switching = c.isSwitchingModel.value;
        final realtime = c.isRealtime.value;
        final dotColor = switching
            ? const Color(0xFFF59E0B)
            : realtime
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444);

        return GlassCard(
          expanded: c.topCardExpanded,
          onToggle: () => c.topCardExpanded.toggle(),
          header: Row(
            children: [
              // Animated status dot
              _PulseDot(color: dotColor, active: realtime && !switching),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  switching
                      ? 'Memuat ${c.modelDisplayName}…'
                      : realtime
                          ? c.modelDisplayName
                          : 'Deteksi berhenti',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${c.yoloResults.length} obj',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (realtime && !switching) ...[
                const Divider(color: Colors.white10, height: 10),
                // Active backend status display
                Row(
                  children: [
                    const Icon(Icons.developer_board_rounded,
                        color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      c.activeBackendStatus.value,
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ── Metrics row ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetricBadge(
                      label: 'FPS',
                      value: c.currentFps.value.toStringAsFixed(1),
                      unit: ' fps',
                      color: _fpsColor(c.currentFps.value),
                    ),
                    _MetricBadge(
                      label: 'Latency',
                      value: c.currentLatency.value.toStringAsFixed(0),
                      unit: ' ms',
                      color: _latencyColor(c.currentLatency.value),
                    ),
                    _MetricBadge(
                      label: 'RAM',
                      value: c.currentRam.value.toStringAsFixed(0),
                      unit: ' MB',
                      color: Colors.white70,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        );
      }),
    );
  }

  Color _fpsColor(double fps) {
    if (fps < 8) return const Color(0xFFEF4444);
    if (fps < 15) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  Color _latencyColor(double ms) {
    if (ms > 150) return const Color(0xFFEF4444);
    if (ms > 80) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MetricBadge({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(unit, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

/// Animated pulsing status dot.
class _PulseDot extends StatefulWidget {
  final Color color;
  final bool active;

  const _PulseDot({required this.color, required this.active});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        width: 8 + _anim.value * 4,
        height: 8 + _anim.value * 4,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.7 + _anim.value * 0.3),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
