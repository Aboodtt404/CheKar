import 'package:flutter/material.dart';
import '../config/theme.dart';

class CameraOverlay extends StatefulWidget {
  final String arrow;
  const CameraOverlay({super.key, required this.arrow});

  @override
  State<CameraOverlay> createState() => _CameraOverlayState();
}

class _CameraOverlayState extends State<CameraOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      const bracketSize = 36.0;
      const bracketThickness = 3.5;
      const bracketColor = CheKarColors.orange;
      const glowColor = CheKarColors.orange;

      Widget bracket({required AlignmentGeometry alignment, required bool flipX, required bool flipY}) {
        return Align(
          alignment: alignment,
          child: Transform.scale(
            scaleX: flipX ? -1 : 1,
            scaleY: flipY ? -1 : 1,
            child: CustomPaint(
              size: const Size(bracketSize, bracketSize),
              painter: _BracketPainter(
                color: bracketColor,
                thickness: bracketThickness,
                glowColor: glowColor,
              ),
            ),
          ),
        );
      }

      return Stack(
        children: [
          // Top-left bracket
          bracket(alignment: Alignment.topLeft, flipX: false, flipY: false),
          // Top-right bracket
          bracket(alignment: Alignment.topRight, flipX: true, flipY: false),
          // Bottom-left bracket
          bracket(alignment: Alignment.bottomLeft, flipX: false, flipY: true),
          // Bottom-right bracket
          bracket(alignment: Alignment.bottomRight, flipX: true, flipY: true),

          // Direction arrow in center
          Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulse.value,
                  child: child,
                );
              },
              child: Text(
                widget.arrow,
                style: const TextStyle(
                  fontSize: 72,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: CheKarColors.orange,
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final Color glowColor;

  const _BracketPainter({
    required this.color,
    required this.thickness,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = glowColor.withOpacity(0.45)
      ..strokeWidth = thickness + 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // L-shape: vertical line then horizontal line from top-left corner
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) =>
      old.color != color || old.thickness != thickness;
}
