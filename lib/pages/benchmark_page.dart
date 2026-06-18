import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/detection/services/benchmark_service.dart';
import '../features/detection/services/camera_service.dart';
import '../features/detection/services/yolo_service.dart';
import '../models/benchmark.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// BenchmarkPage — Guided Benchmark Wizard
// ═══════════════════════════════════════════════════════════════════════════════

/// A guided 3-step benchmark wizard:
///   Step 1 — Configure (model, backend, duration)
///   Step 2 — Running  (camera + warm-up + countdown + live HUD)
///   Step 3 — Result   (run summary card with all metrics)
class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({super.key});

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  final _benchmarkSvc = Get.find<DetectionBenchmarkService>();

  // ── Config state ─────────────────────────────────────────────────────────
  String _selectedModel = 'nano'; // 'nano' | 'small'
  String _selectedBackend = 'CPU'; // 'CPU' | 'GPU' | 'NNAPI'
  int _selectedDuration = 1; // minutes

  // ── Step state ───────────────────────────────────────────────────────────
  int _step = 1; // 1=config, 2=running, 3=result

  // ── Running state ────────────────────────────────────────────────────────
  final _yolo = YoloService();
  final _camera = DetectionCameraService();

  bool _isInitializing = false;
  bool _isRunning = false;
  bool _isCancelling = false;

  double _currentFps = 0.0;
  double _currentLatency = 0.0;
  double _currentRam = 0.0;
  int _currentObjects = 0;

  int _warmupRemaining = 30;
  bool _isWarmingUp = true;

  int _secondsRemaining = 60;
  Timer? _countdownTimer;
  Timer? _ramTimer;

  int _inferenceCount = 0;
  DateTime? _fpsWindowStart;

  // ── Result ────────────────────────────────────────────────────────────────
  BenchmarkRun? _lastRun;

  // ── Computed helpers ──────────────────────────────────────────────────────
  String get _modelPath => _selectedModel == 'nano'
      ? 'assets/models/best_yolov8n.tflite'
      : 'assets/models/best_yolov8s.tflite';

  String get _modelDisplayName =>
      _selectedModel == 'nano' ? 'YOLOv8n (Nano)' : 'YOLOv8s (Small)';

  String get _backendDisplayName {
    switch (_selectedBackend) {
      case 'GPU':
        return 'GPU Delegate';
      case 'NNAPI':
        return 'NNAPI Delegate';
      default:
        return 'CPU Backend';
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  Future<void> _cleanup() async {
    _countdownTimer?.cancel();
    _ramTimer?.cancel();
    _isRunning = false;
    await _camera.stopImageStream();
    await _yolo.dispose();
    await _camera.dispose();
  }

  // ── Step 1 → Step 2: Start benchmark ─────────────────────────────────────

  Future<void> _startBenchmark() async {
    setState(() {
      _isInitializing = true;
      _step = 2;
      _secondsRemaining = _selectedDuration * 60;
      _warmupRemaining = 30;
      _isWarmingUp = true;
      _currentFps = 0;
      _currentLatency = 0;
      _currentRam = 0;
    });

    try {
      await _camera.initialize();
      await _yolo.loadModel(_modelPath, backend: _selectedBackend);
      _yolo.frameSkip = _selectedModel == 'nano' ? 1 : 2;

      final activeBackendType = _yolo.activeBackendType;
      final activeBackendStatus = _yolo.activeBackendStatus;

      _benchmarkSvc.startBenchmarkSession(
        modelName: _modelDisplayName,
        backendType: activeBackendType,
        backendStatus: activeBackendStatus,
        durationMinutes: _selectedDuration,
        warmupFrames: 30,
        onComplete: _onBenchmarkTimerComplete,
      );

      _startRamPolling();
      _isRunning = true;
      setState(() => _isInitializing = false);
      await _camera.startImageStream(_onFrame);

      // Start visual countdown after initialization
      _startCountdown();
    } catch (e) {
      debugPrint('[BenchmarkPage] Init error: $e');
      setState(() {
        _isInitializing = false;
        _step = 1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        }
      });
    });
  }

  void _startRamPolling() {
    _ramTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_isRunning) return;
      final ram = await _benchmarkSvc.getMemoryUsageMb();
      if (mounted) setState(() => _currentRam = ram);
    });
  }

  void _onFrame(CameraImage image) async {
    if (!_isRunning) return;

    final sw = Stopwatch()..start();
    final result = await _yolo.runInference(
      image: image,
      confThreshold: 0.5,
    );
    sw.stop();

    if (result == null || !_isRunning) return;

    final latency = sw.elapsedMilliseconds.toDouble();
    _inferenceCount++;
    final now = DateTime.now();
    _fpsWindowStart ??= now;
    final elapsedMs = now.difference(_fpsWindowStart!).inMilliseconds;
    if (elapsedMs >= 1000) {
      final fps = _inferenceCount * 1000.0 / elapsedMs;
      _inferenceCount = 0;
      _fpsWindowStart = now;
      if (mounted) setState(() => _currentFps = fps);
    }

    if (mounted) {
      setState(() {
        _currentLatency = latency;
        _currentObjects = result.length;
        _warmupRemaining = _benchmarkSvc.warmupFramesRemaining;
        _isWarmingUp = _benchmarkSvc.isWarmingUp;
      });
    }

    _benchmarkSvc.recordBenchmarkFrame(
      fps: _currentFps,
      latencyMs: latency,
      ramMb: _currentRam,
      objectCount: result.length,
    );
  }

  void _onBenchmarkTimerComplete() async {
    if (!mounted || !_isRunning) return;
    await _finalizeBenchmark();
  }

  Future<void> _finalizeBenchmark() async {
    _isRunning = false;
    _countdownTimer?.cancel();
    _ramTimer?.cancel();
    await _camera.stopImageStream();

    final sizeMb = await _benchmarkSvc.getModelSizeMb(_modelPath);
    final run = await _benchmarkSvc.finalizeBenchmarkRun(modelSizeMb: sizeMb);

    await _yolo.dispose();
    await _camera.dispose();

    if (mounted) {
      setState(() {
        _lastRun = run;
        _step = 3;
      });
    }
  }

  // ── Cancel benchmark ──────────────────────────────────────────────────────

  Future<void> _cancelBenchmark() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    _isRunning = false;
    _countdownTimer?.cancel();
    _ramTimer?.cancel();
    _benchmarkSvc.cancelBenchmarkSession();
    await _camera.stopImageStream();
    await _yolo.dispose();
    await _camera.dispose();
    if (mounted) {
      setState(() {
        _step = 1;
        _isCancelling = false;
      });
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 1 || _step == 3,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_step == 2) await _cancelBenchmark();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: Text(
            _step == 1
                ? 'Configure Benchmark'
                : _step == 2
                    ? 'Benchmark Running'
                    : 'Benchmark Result',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: _StepIndicator(currentStep: _step),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _step == 1
              ? _ConfigStep(
                  key: const ValueKey(1),
                  selectedModel: _selectedModel,
                  selectedBackend: _selectedBackend,
                  selectedDuration: _selectedDuration,
                  onModelChanged: (v) => setState(() => _selectedModel = v),
                  onBackendChanged: (v) => setState(() => _selectedBackend = v),
                  onDurationChanged: (v) =>
                      setState(() => _selectedDuration = v),
                  onStart: _startBenchmark,
                  isInitializing: _isInitializing,
                )
              : _step == 2
                  ? _RunningStep(
                      key: const ValueKey(2),
                      isInitializing: _isInitializing,
                      modelName: _modelDisplayName,
                      backendName: _backendDisplayName,
                      durationMinutes: _selectedDuration,
                      secondsRemaining: _secondsRemaining,
                      warmupRemaining: _warmupRemaining,
                      isWarmingUp: _isWarmingUp,
                      fps: _currentFps,
                      latency: _currentLatency,
                      ram: _currentRam,
                      objects: _currentObjects,
                      cameraController: _camera.controller,
                      onCancel: _cancelBenchmark,
                      isCancelling: _isCancelling,
                    )
                  : _ResultStep(
                      key: const ValueKey(3),
                      run: _lastRun,
                      onRunAgain: () async {
                        setState(() => _step = 1);
                      },
                      onViewResults: () => Get.back(),
                    ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Step Indicator
// ═══════════════════════════════════════════════════════════════════════════════

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [1, 2, 3].map((step) {
        final isActive = step == currentStep;
        final isDone = step < currentStep;
        final color = isDone || isActive
            ? const Color(0xFF10B981)
            : Colors.white12;
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Step 1 — Configure
// ═══════════════════════════════════════════════════════════════════════════════

class _ConfigStep extends StatelessWidget {
  final String selectedModel;
  final String selectedBackend;
  final int selectedDuration;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<String> onBackendChanged;
  final ValueChanged<int> onDurationChanged;
  final VoidCallback onStart;
  final bool isInitializing;

  const _ConfigStep({
    super.key,
    required this.selectedModel,
    required this.selectedBackend,
    required this.selectedDuration,
    required this.onModelChanged,
    required this.onBackendChanged,
    required this.onDurationChanged,
    required this.onStart,
    required this.isInitializing,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Each benchmark includes a 30-frame warm-up phase excluded from statistics. Run at least 5 times per combination for reliable mean ± std.',
                    style: GoogleFonts.inter(
                        color: Colors.white70, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Model selection
          _SectionLabel('Select Model'),
          const SizedBox(height: 10),
          _SegmentedSelector<String>(
            options: const [
              _SegmentOption('YOLOv8n (Nano)',
                  'nano', Icons.bolt_rounded, Color(0xFF10B981)),
              _SegmentOption('YOLOv8s (Small)',
                  'small', Icons.auto_awesome_rounded, Color(0xFF6366F1)),
            ],
            selected: selectedModel,
            onChanged: onModelChanged,
          ),
          const SizedBox(height: 24),

          // Backend selection
          _SectionLabel('Inference Backend'),
          const SizedBox(height: 10),
          _SegmentedSelector<String>(
            options: const [
              _SegmentOption('CPU', 'CPU',
                  Icons.memory_rounded, Color(0xFF64748B)),
              _SegmentOption('GPU Delegate', 'GPU',
                  Icons.graphic_eq_rounded, Color(0xFFF59E0B)),
              _SegmentOption('NNAPI Delegate', 'NNAPI',
                  Icons.developer_board_rounded, Color(0xFF8B5CF6)),
            ],
            selected: selectedBackend,
            onChanged: onBackendChanged,
          ),
          const SizedBox(height: 24),

          // Duration selection
          _SectionLabel('Benchmark Duration'),
          const SizedBox(height: 10),
          Row(
            children: [1, 3, 5].map((d) {
              final isSelected = selectedDuration == d;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onDurationChanged(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF10B981)
                            : Colors.white12,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$d',
                          style: GoogleFonts.outfit(
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'min',
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Benchmark Summary',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 10),
                _SummaryRow('Model',
                    selectedModel == 'nano' ? 'YOLOv8n (Nano)' : 'YOLOv8s (Small)'),
                _SummaryRow('Backend', selectedBackend == 'CPU'
                    ? 'CPU Backend'
                    : selectedBackend == 'GPU'
                        ? 'GPU Delegate'
                        : 'NNAPI Delegate'),
                _SummaryRow('Duration', '$selectedDuration minute(s)'),
                _SummaryRow('Warm-up', '30 frames (excluded from stats)'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: isInitializing ? null : onStart,
              icon: isInitializing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 22),
              label: Text(
                isInitializing ? 'Initializing...' : 'Start Benchmark',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SegmentOption<T> {
  final String label;
  final T value;
  final IconData icon;
  final Color color;

  const _SegmentOption(this.label, this.value, this.icon, this.color);
}

class _SegmentedSelector<T> extends StatelessWidget {
  final List<_SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const _SegmentedSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final isSelected = opt.value == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(opt.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? opt.color.withValues(alpha: 0.15)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? opt.color : Colors.white12,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(opt.icon,
                      color: isSelected ? opt.color : Colors.white38,
                      size: 18),
                  const SizedBox(height: 4),
                  Text(
                    opt.label,
                    style: TextStyle(
                      color: isSelected ? opt.color : Colors.white54,
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Step 2 — Running
// ═══════════════════════════════════════════════════════════════════════════════

class _RunningStep extends StatelessWidget {
  final bool isInitializing;
  final String modelName;
  final String backendName;
  final int durationMinutes;
  final int secondsRemaining;
  final int warmupRemaining;
  final bool isWarmingUp;
  final double fps;
  final double latency;
  final double ram;
  final int objects;
  final CameraController? cameraController;
  final Future<void> Function() onCancel;
  final bool isCancelling;

  const _RunningStep({
    super.key,
    required this.isInitializing,
    required this.modelName,
    required this.backendName,
    required this.durationMinutes,
    required this.secondsRemaining,
    required this.warmupRemaining,
    required this.isWarmingUp,
    required this.fps,
    required this.latency,
    required this.ram,
    required this.objects,
    required this.cameraController,
    required this.onCancel,
    required this.isCancelling,
  });

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final total = durationMinutes * 60;
    return ((total - secondsRemaining) / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: Color(0xFF10B981), strokeWidth: 2.5),
            SizedBox(height: 16),
            Text('Initializing camera & model…',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        if (cameraController != null)
          CameraPreview(cameraController!)
        else
          Container(color: Colors.black),

        // Warm-up overlay
        if (isWarmingUp)
          Container(
            color: Colors.black.withValues(alpha: 0.55),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: Color(0xFFF59E0B), size: 36),
                  const SizedBox(height: 12),
                  Text('Warm-up Phase',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    '$warmupRemaining frames remaining',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Warm-up frames are excluded from statistics',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

        // Top HUD
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Model + backend
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              modelName,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              backendName,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // Timer
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(secondsRemaining),
                            style: GoogleFonts.outfit(
                              color: secondsRemaining <= 30
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isWarmingUp ? 'WARM-UP' : 'REMAINING',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: isWarmingUp ? null : _progress,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        secondsRemaining <= 30
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom HUD
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.92),
                  Colors.transparent
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live metrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _LiveMetric('FPS',
                        fps > 0 ? fps.toStringAsFixed(1) : '--',
                        const Color(0xFF10B981)),
                    _LiveMetric('Latency',
                        latency > 0
                            ? '${latency.toStringAsFixed(0)}ms'
                            : '--',
                        const Color(0xFF3B82F6)),
                    _LiveMetric(
                        'RAM',
                        ram > 0 ? '${ram.toStringAsFixed(0)}MB' : '--',
                        const Color(0xFFF59E0B)),
                    _LiveMetric('Objects', objects.toString(),
                        const Color(0xFF8B5CF6)),
                  ],
                ),
                const SizedBox(height: 14),
                // Cancel button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFEF4444), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isCancelling ? null : onCancel,
                    icon: isCancelling
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.stop_circle_rounded,
                            color: Color(0xFFEF4444), size: 18),
                    label: Text(
                      isCancelling ? 'Cancelling...' : 'Cancel Benchmark',
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LiveMetric(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Step 3 — Result
// ═══════════════════════════════════════════════════════════════════════════════

class _ResultStep extends StatelessWidget {
  final BenchmarkRun? run;
  final VoidCallback onRunAgain;
  final VoidCallback onViewResults;

  const _ResultStep({
    super.key,
    required this.run,
    required this.onRunAgain,
    required this.onViewResults,
  });

  @override
  Widget build(BuildContext context) {
    if (run == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text('No data recorded',
                style: GoogleFonts.outfit(
                    color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: onRunAgain,
                child: const Text('Try Again')),
          ],
        ),
      );
    }

    final r = run!;
    final isNano = r.modelName.toLowerCase().contains('8n');
    final accent = isNano ? const Color(0xFF10B981) : const Color(0xFF6366F1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Run badge ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.2),
                  const Color(0xFF0F172A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Run #${r.runIndex}',
                        style: GoogleFonts.outfit(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'Benchmark Complete',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  r.modelName,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${r.backendType} Backend  •  ${r.durationMinutes} min  •  ${r.warmupFrames} warmup frames',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                // Hero FPS
                Center(
                  child: Column(
                    children: [
                      Text(
                        r.averageFps.toStringAsFixed(1),
                        style: GoogleFonts.outfit(
                          color: accent,
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      Text(
                        'Average FPS',
                        style: TextStyle(
                            color: accent.withValues(alpha: 0.7),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Metrics grid ───────────────────────────────────────────
          Text('Full Metrics',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _ResultMetricsGrid(run: r, accent: accent),
          const SizedBox(height: 20),

          // ── Device info ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.smartphone_rounded,
                    color: Colors.white24, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.deviceInfo,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(r.androidVersion,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Action buttons ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: accent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onRunAgain,
                  icon: Icon(Icons.replay_rounded, color: accent, size: 18),
                  label: Text('Run Again',
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onViewResults,
                  icon: const Icon(Icons.bar_chart_rounded,
                      color: Colors.white, size: 18),
                  label: const Text('View Results',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultMetricsGrid extends StatelessWidget {
  final BenchmarkRun run;
  final Color accent;

  const _ResultMetricsGrid({required this.run, required this.accent});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item('Avg FPS', run.averageFps.toStringAsFixed(1), 'fps', accent),
      _Item('Min FPS', run.minFps.toStringAsFixed(1), 'fps', Colors.white54),
      _Item('Max FPS', run.maxFps.toStringAsFixed(1), 'fps', Colors.white54),
      _Item('Avg Latency', run.averageLatency.toStringAsFixed(1), 'ms',
          const Color(0xFF3B82F6)),
      _Item('Min Latency', run.minLatency.toStringAsFixed(1), 'ms',
          Colors.white54),
      _Item('Max Latency', run.maxLatency.toStringAsFixed(1), 'ms',
          Colors.white54),
      _Item('Avg RAM', run.averageRam.toStringAsFixed(1), 'MB',
          const Color(0xFFF59E0B)),
      _Item('Peak RAM', run.peakRam.toStringAsFixed(1), 'MB', Colors.white54),
      _Item('Model Size', run.modelSizeMb.toStringAsFixed(2), 'MB',
          Colors.white54),
      _Item('Avg Objects', run.averageObjects.toStringAsFixed(1), 'obj',
          const Color(0xFFEC4899)),
      _Item('Max Objects', run.maxObjects.toString(), 'obj', Colors.white54),
      _Item('Inferences', run.totalInferenceCount.toString(), '',
          Colors.white54),
      _Item('Success Rate',
          (run.detectionSuccessRate * 100).toStringAsFixed(1), '%',
          const Color(0xFF10B981)),
      _Item('FPS Stability',
          (run.fpsStability * 100).toStringAsFixed(1), '%',
          const Color(0xFF8B5CF6)),
      _Item('Duration', '${run.sessionDurationSeconds}s', '', Colors.white54),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.7,
      children: items.map((item) => _ResultCell(item: item)).toList(),
    );
  }
}

class _Item {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _Item(this.label, this.value, this.unit, this.color);
}

class _ResultCell extends StatelessWidget {
  final _Item item;
  const _ResultCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.label,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  item.value,
                  style: GoogleFonts.outfit(
                    color: item.color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item.unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(item.unit,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 9)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
