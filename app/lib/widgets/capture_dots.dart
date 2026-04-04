import 'package:flutter/material.dart';
import '../config/theme.dart';

class CaptureDots extends StatelessWidget {
  final int total;
  final int current; // 0-indexed

  const CaptureDots({super.key, required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    // If total is large, limit visible dots to avoid overflow
    final maxVisible = 10;
    final showAll = total <= maxVisible;

    // For large totals, show a windowed view around current
    int start = 0;
    int end = total;
    if (!showAll) {
      start = (current - 4).clamp(0, total - maxVisible);
      end = (start + maxVisible).clamp(0, total);
    }

    final dots = List.generate(end - start, (i) {
      final index = start + i;
      return _buildDot(index);
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: dots,
    );
  }

  Widget _buildDot(int index) {
    final bool isDone = index < current;
    final bool isCurrent = index == current;
    final bool isRemaining = index > current;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isCurrent ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isDone
            ? CheKarColors.orange
            : isCurrent
                ? Colors.white
                : Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : isDone
                ? [
                    BoxShadow(
                      color: CheKarColors.orange.withOpacity(0.4),
                      blurRadius: 4,
                    ),
                  ]
                : null,
      ),
    );
  }
}
