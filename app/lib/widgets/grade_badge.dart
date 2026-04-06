import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GradeBadge extends StatefulWidget {
  final String grade;
  final Color color;
  final double size;

  const GradeBadge({super.key, required this.grade, required this.color, this.size = 120});

  @override
  State<GradeBadge> createState() => _GradeBadgeState();
}

class _GradeBadgeState extends State<GradeBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ).value;

        return SizedBox(
          width: s + 24,
          height: s + 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: s + 24,
                height: s + 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.2 * progress),
                      blurRadius: 48,
                      spreadRadius: 16,
                    ),
                  ],
                ),
              ),
              // Animated arc ring
              CustomPaint(
                size: Size(s + 16, s + 16),
                painter: _ArcRingPainter(
                  color: widget.color,
                  progress: progress,
                ),
              ),
              // Inner circle
              Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(0.06),
                  border: Border.all(
                    color: widget.color.withOpacity(0.3),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Opacity(
                    opacity: progress,
                    child: Text(
                      widget.grade,
                      style: GoogleFonts.saira(
                        fontSize: s * 0.42,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArcRingPainter extends CustomPainter {
  final Color color;
  final double progress;

  _ArcRingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track arc (subtle)
    final trackPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Animated arc
    final arcPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );

    // End dot
    if (progress > 0.05) {
      final angle = -math.pi / 2 + 2 * math.pi * progress;
      final dotX = center.dx + radius * math.cos(angle);
      final dotY = center.dy + radius * math.sin(angle);
      canvas.drawCircle(
        Offset(dotX, dotY),
        4,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcRingPainter old) =>
      old.progress != progress || old.color != color;
}
