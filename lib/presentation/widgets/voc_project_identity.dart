import 'package:flutter/material.dart';
import '../../core/utils/voc_display_utils.dart';

class VocProjectIdentity extends StatelessWidget {
  const VocProjectIdentity({super.key, required this.project});
  final String project;

  @override
  Widget build(BuildContext context) {
    final identity = VocDisplayUtils.projectIdentity(project);
    final name = identity.projectName.isEmpty ? '미지정' : identity.projectName;
    final number = identity.number.isEmpty ? '미지정' : identity.number;
    final theme = Theme.of(context);
    return Wrap(spacing: 12, runSpacing: 3, children: [
      Text('프로젝트: $name', style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant)),
      Text('번호: $number', style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
    ]);
  }
}
