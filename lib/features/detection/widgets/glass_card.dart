import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Optimized glass card — NO BackdropFilter (zero GPU compositing cost).
/// Uses RepaintBoundary to isolate card repaints from camera repaints.
/// Collapse/expand uses AnimatedSize which is lighter than AnimatedCrossFade.
class GlassCard extends StatelessWidget {
  final Widget header;
  final Widget child;
  final RxBool expanded;
  final VoidCallback onToggle;
  final EdgeInsets padding;

  const GlassCard({
    super.key,
    required this.header,
    required this.child,
    required this.expanded,
    required this.onToggle,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          // Semi-transparent dark — premium look without BackdropFilter GPU cost
          color: const Color(0xD00A1628),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Tappable header ────────────────────────────────────────
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(
                    children: [
                      Expanded(child: header),
                      Obx(() => AnimatedRotation(
                            turns: expanded.value ? 0.0 : 0.5,
                            duration: const Duration(milliseconds: 220),
                            child: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              // ── Collapsible body ───────────────────────────────────────
              Obx(() => AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOut,
                    child: expanded.value
                        ? Padding(padding: padding, child: child)
                        : const SizedBox.shrink(),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
