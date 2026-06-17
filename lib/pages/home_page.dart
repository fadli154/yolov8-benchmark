import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/detection/pages/detection_page.dart';
import 'benchmark_page.dart';
import 'compare_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // ── App icon ring ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: const Icon(Icons.recycling_rounded,
                    color: Color(0xFF10B981), size: 72),
              ),
              const SizedBox(height: 32),

              // ── Title ────────────────────────────────────────────────
              Text(
                'Smart Waste Detector',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Android Mobile Benchmark · YOLOv8 TFLite',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              // Backend chips
              Wrap(
                spacing: 6,
                children: ['CPU', 'GPU Delegate', 'NNAPI Delegate']
                    .map((b) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            b,
                            style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ))
                    .toList(),
              ),
              const Spacer(),

              // ── Section: Real-time Detection ─────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'REAL-TIME DETECTION',
                  style: GoogleFonts.inter(
                    color: Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              _ModelButton(
                label: 'Detect with YOLOv8n',
                description:
                    'Fastest · Lower resource · Recommended for mid-range',
                icon: Icons.bolt_rounded,
                gradient: const [Color(0xFF059669), Color(0xFF10B981)],
                onTap: () => Get.to(
                  () => const DetectionPage(modelType: 'nano'),
                  transition: Transition.downToUp,
                  duration: const Duration(milliseconds: 300),
                ),
              ),
              const SizedBox(height: 12),
              _ModelButton(
                label: 'Detect with YOLOv8s',
                description:
                    'Higher accuracy · More CPU/RAM · For flagship devices',
                icon: Icons.auto_awesome_rounded,
                gradient: const [Color(0xFF4338CA), Color(0xFF6366F1)],
                onTap: () => Get.to(
                  () => const DetectionPage(modelType: 'small'),
                  transition: Transition.downToUp,
                  duration: const Duration(milliseconds: 300),
                ),
              ),
              const SizedBox(height: 20),

              // ── Section: Benchmark ────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'BENCHMARKING',
                  style: GoogleFonts.inter(
                    color: Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Run Benchmark — primary benchmark action
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: () => Get.to(
                    () => const BenchmarkPage(),
                    transition: Transition.rightToLeft,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488)
                              .withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                              Icons.science_rounded,
                              color: Colors.white,
                              size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Run Benchmark',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                'Timed run · Warm-up · Mean ± Std stats',
                                style: GoogleFonts.inter(
                                  color:
                                      Colors.white.withValues(alpha: 0.75),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // View Results — compare page
              OutlinedButton.icon(
                onPressed: () => Get.to(
                  () => const ComparePage(),
                  transition: Transition.rightToLeft,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(
                      color: Color(0xFF10B981), width: 1.5),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                icon: const Icon(Icons.bar_chart_rounded, size: 20),
                label: Text(
                  'View Results & Compare',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Model Detection Button ────────────────────────────────────────────────────

class _ModelButton extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ModelButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 14),
          ]),
        ),
      ),
    );
  }
}
