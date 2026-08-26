import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class VocStatusChip extends StatelessWidget {
  final String status;
  const VocStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _label(String s) {
    switch (s) {
      case 'OPEN':
        return '미처리';
      case 'IN_PROGRESS':
        return '처리중';
      case 'RESOLVED':
        return '해결';
      case 'REJECTED':
        return '반려';
      default:
        return s;
    }
  }
}
