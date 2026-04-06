import 'dart:math';
import 'package:flutter/material.dart';

class NoiseBackground extends StatelessWidget {
  final Widget child;
  final double opacity;
  const NoiseBackground({super.key, required this.child, this.opacity = 0.04});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      child,
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _NoisePainter(opacity: opacity)))),
    ]);
  }
}

class _NoisePainter extends CustomPainter {
  final double opacity;
  _NoisePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint()..strokeWidth = 1;
    for (int i = 0; i < (size.width * size.height * 0.03).toInt(); i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final brightness = random.nextInt(255);
      paint.color = Color.fromRGBO(brightness, brightness, brightness, opacity);
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
