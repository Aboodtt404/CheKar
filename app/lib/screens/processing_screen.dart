import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../config/theme.dart';
import '../models/inspection.dart';
import '../providers/inspection_provider.dart';
import '../widgets/noise_background.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  final String inspectionId;
  const ProcessingScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _counterRingController;
  late AnimationController _pulseController;
  late AnimationController _percentController;

  Timer? _stepTimer;
  int _activeStep = 0;
  int _displayPercent = 0;
  bool _navigated = false;

  static final List<Map<String, dynamic>> _steps = [
    {'label': 'تحليل الصور', 'icon': Iconsax.camera},
    {'label': 'كشف الخبطات والخدوش', 'icon': Iconsax.flash_1},
    {'label': 'فحص الدهان والحوادث', 'icon': Iconsax.brush_1},
    {'label': 'تقييم حالة العربية', 'icon': Iconsax.shield_tick},
    {'label': 'إعداد التقرير', 'icon': Iconsax.document_text},
  ];

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _counterRingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _percentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inspectionProvider.notifier).startPolling();
    });

    _startStepTimer();
  }

  void _startStepTimer() {
    _stepTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        if (_activeStep < _steps.length - 1) {
          _activeStep++;
        }
        final target = math.min(95, (_activeStep + 1) * 19);
        _displayPercent = target;
      });
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _counterRingController.dispose();
    _pulseController.dispose();
    _percentController.dispose();
    _stepTimer?.cancel();
    ref.read(inspectionProvider.notifier).stopPolling();
    super.dispose();
  }

  void _handleStatusChange(InspectionStatus status) {
    if (_navigated) return;
    if (status == InspectionStatus.completed) {
      _navigated = true;
      setState(() => _displayPercent = 100);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) context.go('/report/${widget.inspectionId}');
      });
    } else if (status == InspectionStatus.failed) {
      _navigated = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inspState = ref.watch(inspectionProvider);

    final current = inspState.current;
    if (current != null && !_navigated) {
      if (current.status == InspectionStatus.completed ||
          current.status == InspectionStatus.failed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleStatusChange(current.status);
        });
      }
    }

    final failed = current?.status == InspectionStatus.failed && _navigated;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CheKarColors.darkDeep,
        body: NoiseBackground(
          child: Stack(
            children: [
              // Asymmetric orange glow
              Positioned(
                top: -120,
                left: -80,
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        CheKarColors.orange.withOpacity(0.15),
                        CheKarColors.orange.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: failed
                    ? _buildErrorState()
                    : _buildProcessingState(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 64),
          _buildSpinningRing(),
          const SizedBox(height: 36),
          _buildStatusText(),
          const SizedBox(height: 40),
          _buildStepList(),
        ],
      ),
    );
  }

  Widget _buildSpinningRing() {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Orange halo
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: CheKarColors.orange.withOpacity(0.2),
                  blurRadius: 48,
                  spreadRadius: 12,
                ),
              ],
            ),
          ),

          // Counter-rotating outer ring
          AnimatedBuilder(
            animation: _counterRingController,
            builder: (_, __) => Transform.rotate(
              angle: -_counterRingController.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(180, 180),
                painter: _SubtleRingPainter(
                  color: CheKarColors.orange.withOpacity(0.1),
                  strokeWidth: 3,
                ),
              ),
            ),
          ),

          // Main spinning ring
          AnimatedBuilder(
            animation: _ringController,
            builder: (_, __) => Transform.rotate(
              angle: _ringController.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(160, 160),
                painter: _SpinningRingPainter(
                  baseColor: CheKarColors.darkCard,
                  arcColor: CheKarColors.orange,
                  strokeWidth: 10,
                ),
              ),
            ),
          ),

          // Center percentage
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_displayPercent%',
                style: GoogleFonts.saira(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: CheKarColors.orange,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    return Column(
      children: [
        Text(
          'جاري فحص العربية...',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'الذكاء الاصطناعي بيحلل الصور',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.35),
          ),
        ),
      ],
    );
  }

  Widget _buildStepList() {
    return Column(
      children: List.generate(_steps.length, (i) {
        final state = i < _activeStep
            ? _StepState.done
            : i == _activeStep
                ? _StepState.active
                : _StepState.pending;
        return _StepRow(
          label: _steps[i]['label'] as String,
          icon: _steps[i]['icon'] as IconData,
          stepState: state,
          pulseAnimation: _pulseController,
        );
      }),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CheKarColors.scoreBad.withOpacity(0.12),
              ),
              child: const Icon(
                Iconsax.close_circle,
                color: CheKarColors.scoreBad,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'حصل مشكلة',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              ref.read(inspectionProvider).current?.error ?? 'الفحص اتوقف بسبب خطأ. حاول تاني.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white.withOpacity(0.4),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CheKarColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  'ارجع للرئيسية',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step state ──────────────────────────────────────────────────────────────

enum _StepState { done, active, pending }

// ── Step row ────────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final _StepState stepState;
  final Animation<double> pulseAnimation;

  const _StepRow({
    required this.label,
    required this.icon,
    required this.stepState,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = stepState == _StepState.done;
    final isActive = stepState == _StepState.active;

    Color circleColor;
    Color iconColor;
    Color textColor;

    if (isDone) {
      circleColor = CheKarColors.scoreGood.withOpacity(0.15);
      iconColor = CheKarColors.scoreGood;
      textColor = Colors.white.withOpacity(0.35);
    } else if (isActive) {
      circleColor = CheKarColors.orange.withOpacity(0.15);
      iconColor = CheKarColors.orange;
      textColor = Colors.white;
    } else {
      circleColor = Colors.white.withOpacity(0.04);
      iconColor = Colors.white.withOpacity(0.15);
      textColor = Colors.white.withOpacity(0.15);
    }

    Widget circle = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: circleColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: isDone
          ? Icon(Iconsax.tick_circle, color: iconColor, size: 20)
          : Icon(icon, color: iconColor, size: 20),
    );

    if (isActive) {
      circle = AnimatedBuilder(
        animation: pulseAnimation,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: CheKarColors.orange
                    .withOpacity(0.25 * pulseAnimation.value),
                blurRadius: 14 + 6 * pulseAnimation.value,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
        child: circle,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          circle,
          const SizedBox(width: 14),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
          if (isDone) ...[
            const Spacer(),
            Icon(Iconsax.tick_circle, size: 14, color: CheKarColors.scoreGood.withOpacity(0.5)),
          ],
        ],
      ),
    );
  }
}

// ── Custom painters ─────────────────────────────────────────────────────────

class _SpinningRingPainter extends CustomPainter {
  final Color baseColor;
  final Color arcColor;
  final double strokeWidth;

  _SpinningRingPainter({
    required this.baseColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, basePaint);

    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi / 2, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _SpinningRingPainter old) =>
      old.baseColor != baseColor ||
      old.arcColor != arcColor ||
      old.strokeWidth != strokeWidth;
}

class _SubtleRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _SubtleRingPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, 0, math.pi * 0.6, false, paint);
    canvas.drawArc(rect, math.pi * 0.8, math.pi * 0.6, false, paint);
    canvas.drawArc(rect, math.pi * 1.6, math.pi * 0.3, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SubtleRingPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
