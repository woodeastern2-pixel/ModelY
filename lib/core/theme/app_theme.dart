import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Restrained enterprise design system for AI VOC Assistant.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final visual = isDark ? AppVisualColors.dark : AppVisualColors.light;
    final primary = isDark ? const Color(0xFF8E90FF) : AppPalette.indigo;
    final onSurface = isDark ? const Color(0xFFF2F3F7) : AppPalette.ink;
    final surface = isDark ? AppPalette.darkSurface : AppPalette.white;
    final muted = visual.mutedSurface;
    final outline = isDark ? AppPalette.darkOutline : const Color(0xFFD9DCE5);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.indigo,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF30326E) : const Color(0xFFE8E8FF),
      onPrimaryContainer:
          isDark ? const Color(0xFFF0F0FF) : const Color(0xFF30316F),
      secondary: isDark ? const Color(0xFF55CDBE) : AppPalette.teal,
      onSecondary: isDark ? const Color(0xFF062E29) : Colors.white,
      secondaryContainer:
          isDark ? const Color(0xFF163D3A) : const Color(0xFFDDF6F1),
      onSecondaryContainer:
          isDark ? const Color(0xFFC8FFF7) : const Color(0xFF095B52),
      tertiary: isDark ? const Color(0xFFF2B45F) : AppPalette.amber,
      error: isDark ? const Color(0xFFFF8C8C) : AppPalette.red,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: isDark ? const Color(0xFF0B0E15) : Colors.white,
      surfaceContainerLow:
          isDark ? const Color(0xFF111520) : const Color(0xFFFAFAFC),
      surfaceContainer: muted,
      surfaceContainerHigh:
          isDark ? const Color(0xFF22283A) : const Color(0xFFE9EBF1),
      surfaceContainerHighest:
          isDark ? const Color(0xFF2A3145) : const Color(0xFFE1E4EC),
      onSurfaceVariant:
          isDark ? const Color(0xFFB8BECD) : const Color(0xFF626879),
      outline: outline,
      outlineVariant:
          isDark ? const Color(0xFF252B3B) : const Color(0xFFE8EAF0),
    );

    final textTheme = _textTheme(onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [visual],
      scaffoldBackgroundColor: visual.canvas,
      canvasColor: visual.canvas,
      fontFamily: 'Pretendard',
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 68,
        backgroundColor: surface,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSpacing.lg,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        shape: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      chipTheme: ChipThemeData(
        elevation: 0,
        backgroundColor: muted,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? primary
                : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: visual.navigation,
        indicatorColor: primary.withValues(alpha: 0.2),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: visual.navigationMuted),
      ),
      dialogTheme: DialogThemeData(
        elevation: 12,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 16,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.panel),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFFF1F2F6) : AppPalette.ink,
        contentTextStyle: TextStyle(
          color: isDark ? AppPalette.ink : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: scheme.outlineVariant,
        linearMinHeight: 5,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFFF4F5F8) : AppPalette.ink,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        textStyle: TextStyle(
          color: isDark ? AppPalette.ink : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color color) {
    TextStyle style(
      double size,
      FontWeight weight, {
      double? height,
      double? letterSpacing,
    }) {
      return TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        fontFamily: 'Pretendard',
        fontFamilyFallback: const ['Noto Sans KR', 'Segoe UI'],
      );
    }

    return TextTheme(
      displayLarge: style(
        44,
        FontWeight.w800,
        height: 1.1,
        letterSpacing: -1.4,
      ),
      displayMedium: style(
        36,
        FontWeight.w800,
        height: 1.12,
        letterSpacing: -1.1,
      ),
      displaySmall: style(
        30,
        FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.8,
      ),
      headlineLarge: style(
        28,
        FontWeight.w700,
        height: 1.18,
        letterSpacing: -0.7,
      ),
      headlineMedium: style(
        24,
        FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.55,
      ),
      headlineSmall: style(
        21,
        FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.4,
      ),
      titleLarge: style(19, FontWeight.w700, height: 1.3, letterSpacing: -0.3),
      titleMedium: style(
        16,
        FontWeight.w700,
        height: 1.35,
        letterSpacing: -0.15,
      ),
      titleSmall: style(14, FontWeight.w700, height: 1.35),
      bodyLarge: style(16, FontWeight.w400, height: 1.55, letterSpacing: -0.1),
      bodyMedium: style(14, FontWeight.w400, height: 1.5),
      bodySmall: style(12, FontWeight.w400, height: 1.45),
      labelLarge: style(14, FontWeight.w700, height: 1.25),
      labelMedium: style(12, FontWeight.w600, height: 1.25),
      labelSmall: style(11, FontWeight.w600, height: 1.2, letterSpacing: 0.1),
    );
  }

  static Color priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
      case 'CRITICAL':
        return AppPalette.red;
      case 'MEDIUM':
        return AppPalette.amber;
      case 'LOW':
        return AppPalette.teal;
      default:
        return const Color(0xFF7B8191);
    }
  }

  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return AppPalette.indigo;
      case 'IN_PROGRESS':
        return AppPalette.amber;
      case 'RESOLVED':
        return AppPalette.teal;
      case 'REJECTED':
        return AppPalette.red;
      case 'DRAFT':
        return const Color(0xFF8A90A0);
      default:
        return const Color(0xFF7B8191);
    }
  }

  static Color urgencyColor(String urgency) => priorityColor(urgency);

  static Color confidenceColor(double score) {
    if (score >= 0.8) return AppPalette.teal;
    if (score >= 0.6) return AppPalette.amber;
    return AppPalette.red;
  }
}
