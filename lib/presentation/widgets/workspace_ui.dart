import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

class WorkspaceMetric {
  const WorkspaceMetric({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;
}

/// Shared operational header used by VOC and AI workspaces.
class WorkspaceHero extends StatelessWidget {
  const WorkspaceHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    this.metrics = const [],
    this.actions = const [],
    this.dark = true,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final List<WorkspaceMetric> metrics;
  final List<Widget> actions;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = dark ? Colors.white : colors.onSurface;
    final secondary = dark ? const Color(0xFFB9BED0) : colors.onSurfaceVariant;
    final background = dark
        ? (theme.brightness == Brightness.dark
            ? const Color(0xFF202637)
            : AppPalette.ink)
        : context.visualColors.elevatedSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.1)
              : colors.outlineVariant,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 840;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF5B5CE2)
                          : colors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: dark ? Colors.white : colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    eyebrow.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: dark ? const Color(0xFFBFC2FF) : colors.primary,
                      letterSpacing: 1.15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: secondary,
                    height: 1.5,
                  ),
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: actions,
                ),
              ],
            ],
          );

          final signal = metrics.isEmpty
              ? const SizedBox.shrink()
              : _WorkspaceMetrics(
                  metrics: metrics,
                  dark: dark,
                  horizontal: horizontal,
                );

          if (!horizontal) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                if (metrics.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  signal,
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              if (metrics.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xl),
                SizedBox(width: 360, child: signal),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WorkspaceMetrics extends StatelessWidget {
  const _WorkspaceMetrics({
    required this.metrics,
    required this.dark,
    required this.horizontal,
  });

  final List<WorkspaceMetric> metrics;
  final bool dark;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.065)
            : context.visualColors.mutedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.1)
              : colors.outlineVariant,
        ),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: metrics
            .map(
              (metric) => SizedBox(
                width: horizontal ? 96 : 84,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: dark
                                ? const Color(0xFFB9BED0)
                                : colors.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      metric.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: metric.color ??
                                (dark ? Colors.white : colors.onSurface),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    super.key,
    required this.child,
    this.title,
    this.description,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final String? title;
  final String? description;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasHeader = title != null || description != null || icon != null;
    return Container(
      decoration: BoxDecoration(
        color: context.visualColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        if (description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            description!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    trailing!,
                  ],
                ],
              ),
            ),
          if (hasHeader) Divider(color: colors.outlineVariant),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
