import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PriorityChip extends StatelessWidget {
  final String priority;
  const PriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        _label(priority),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _label(String p) {
    switch (p) {
      case 'HIGH':
        return '높음';
      case 'MEDIUM':
        return '보통';
      case 'LOW':
        return '낮음';
      default:
        return p;
    }
  }
}
