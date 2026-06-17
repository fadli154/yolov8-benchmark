import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/detection_controller.dart';
import 'glass_card.dart';

/// Bottom control panel with sliders, voice toggle, model switch, and scan button.
/// Uses Obx for granular updates — no full-tree rebuilds.
class ControlPanelWidget extends StatelessWidget {
  const ControlPanelWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<DetectionController>();

    return Positioned(
      bottom: 36,
      left: 14,
      right: 14,
      child: Obx(() => GlassCard(
            expanded: c.controlCardExpanded,
            onToggle: () => c.controlCardExpanded.toggle(),
            header: const Text(
              'Controls',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Quick stat row ────────────────────────────────────
                Row(
                  children: [
                    Expanded(child: _StatChip(label: 'Voice', value: c.voiceEnabled.value ? 'ON' : 'OFF', icon: Icons.volume_up_rounded)),
                    Expanded(child: _StatChip(label: 'Speed', value: c.speechRate.value.toStringAsFixed(1), icon: Icons.speed_rounded)),
                    Expanded(child: _StatChip(label: 'Conf', value: c.confThreshold.value.toStringAsFixed(2), icon: Icons.analytics_rounded)),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Sliders ───────────────────────────────────────────
                _SliderRow(
                  icon: Icons.record_voice_over_rounded,
                  label: 'Kecepatan Suara',
                  value: c.speechRate.value,
                  min: 0.2,
                  max: 0.8,
                  onChanged: (v) => c.updateSpeechRate(v),
                ),
                _SliderRow(
                  icon: Icons.timer_rounded,
                  label: 'Jeda Suara',
                  value: c.speakCooldown.value.toDouble(),
                  min: 1000,
                  max: 6000,
                  divisions: 10,
                  onChanged: (v) => c.speakCooldown.value = v.toInt(),
                ),
                _SliderRow(
                  icon: Icons.tune_rounded,
                  label: 'Sensitivity Deteksi',
                  value: c.confThreshold.value,
                  min: 0.2,
                  max: 0.9,
                  onChanged: (v) => c.confThreshold.value = v,
                ),
                const SizedBox(height: 8),

                // ── Backend Selector Dropdown ─────────────────────────
                Row(
                  children: [
                    const Icon(Icons.settings_input_component_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Inference Backend:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: const Color(0xFF1E293B),
                          value: c.selectedBackend.value,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          onChanged: c.isSwitchingModel.value
                              ? null
                              : (String? val) {
                                  if (val != null) {
                                    c.changeBackend(val);
                                  }
                                },
                          items: const [
                            DropdownMenuItem(value: 'CPU', child: Text('CPU')),
                            DropdownMenuItem(value: 'GPU', child: Text('GPU Delegate')),
                            DropdownMenuItem(value: 'NNAPI', child: Text('NNAPI')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Buttons row ───────────────────────────────────────
                Row(
                  children: [
                    // Voice toggle
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => c.voiceEnabled.toggle(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: c.voiceEnabled.value
                                ? const Color(0xFF10B981)
                                : Colors.white30,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(
                          c.voiceEnabled.value
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          size: 15,
                          color: Colors.white70,
                        ),
                        label: Text(
                          c.voiceEnabled.value ? 'Voice ON' : 'Voice OFF',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Model switch
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.currentModelType.value == 'nano'
                              ? const Color(0xFF3730A3)
                              : const Color(0xFF5B21B6),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed:
                            c.isSwitchingModel.value ? null : c.switchModel,
                        icon: Icon(
                          c.isSwitchingModel.value
                              ? Icons.hourglass_top_rounded
                              : Icons.swap_horiz_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        label: Text(
                          c.currentModelType.value == 'nano'
                              ? '→ YOLOv8s'
                              : '→ YOLOv8n',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Scan start/stop ───────────────────────────────────
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.isRealtime.value
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF059669),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: c.isSwitchingModel.value
                        ? null
                        : () {
                            if (c.isRealtime.value) {
                              c.stopRealtime();
                            } else {
                              c.startRealtime();
                            }
                          },
                    icon: Icon(
                      c.isRealtime.value
                          ? Icons.stop_circle_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      c.isRealtime.value ? 'Stop Scan' : 'Start Scan',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          )),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: Colors.white60, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 11)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: const Color(0xFF10B981),
            inactiveTrackColor: Colors.white12,
            thumbColor: const Color(0xFF10B981),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
