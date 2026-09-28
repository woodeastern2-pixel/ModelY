import 'package:flutter/material.dart';

/// Shared visual constants for the AI VOC responsive workspace.
abstract final class AppBreakpoints {
  static const double mobile = 720;
  static const double expandedNavigation = 1180;
  static const double wideContent = 1440;
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadii {
  static const double small = 8;
  static const double control = 10;
  static const double card = 14;
  static const double panel = 18;
}

abstract final class AppPalette {
  static const Color ink = Color(0xFF151824);
  static const Color cloud = Color(0xFFF4F5F8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color indigo = Color(0xFF5B5CE2);
  static const Color indigoDark = Color(0xFF4446C7);
  static const Color teal = Color(0xFF0F9F8F);
  static const Color amber = Color(0xFFD97706);
  static const Color red = Color(0xFFD84A4A);
  static const Color navigation = Color(0xFF10131F);
  static const Color navigationMuted = Color(0xFF9EA5B8);

  static const Color darkCanvas = Color(0xFF0C0F17);
  static const Color darkSurface = Color(0xFF141824);
  static const Color darkSurfaceMuted = Color(0xFF1B2030);
  static const Color darkOutline = Color(0xFF30374A);
}

@immutable
class AppVisualColors extends ThemeExtension<AppVisualColors> {
  const AppVisualColors({
    required this.canvas,
    required this.elevatedSurface,
    required this.mutedSurface,
    required this.navigation,
    required this.onNavigation,
    required this.navigationMuted,
    required this.success,
    required this.warning,
  });

  final Color canvas;
  final Color elevatedSurface;
  final Color mutedSurface;
  final Color navigation;
  final Color onNavigation;
  final Color navigationMuted;
  final Color success;
  final Color warning;

  static const light = AppVisualColors(
    canvas: AppPalette.cloud,
    elevatedSurface: AppPalette.white,
    mutedSurface: Color(0xFFF0F1F5),
    navigation: AppPalette.navigation,
    onNavigation: Color(0xFFF7F8FC),
    navigationMuted: AppPalette.navigationMuted,
    success: AppPalette.teal,
    warning: AppPalette.amber,
  );

  static const dark = AppVisualColors(
    canvas: AppPalette.darkCanvas,
    elevatedSurface: AppPalette.darkSurface,
    mutedSurface: AppPalette.darkSurfaceMuted,
    navigation: Color(0xFF080A10),
    onNavigation: Color(0xFFF3F4F8),
    navigationMuted: Color(0xFF929AAF),
    success: Color(0xFF45C7B6),
    warning: Color(0xFFF2B45F),
  );

  @override
  AppVisualColors copyWith({
    Color? canvas,
    Color? elevatedSurface,
    Color? mutedSurface,
    Color? navigation,
    Color? onNavigation,
    Color? navigationMuted,
    Color? success,
    Color? warning,
  }) {
    return AppVisualColors(
      canvas: canvas ?? this.canvas,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      navigation: navigation ?? this.navigation,
      onNavigation: onNavigation ?? this.onNavigation,
      navigationMuted: navigationMuted ?? this.navigationMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppVisualColors lerp(covariant AppVisualColors? other, double t) {
    if (other == null) return this;
    return AppVisualColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      mutedSurface: Color.lerp(mutedSurface, other.mutedSurface, t)!,
      navigation: Color.lerp(navigation, other.navigation, t)!,
      onNavigation: Color.lerp(onNavigation, other.onNavigation, t)!,
      navigationMuted: Color.lerp(navigationMuted, other.navigationMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppVisualColors get visualColors =>
      Theme.of(this).extension<AppVisualColors>() ?? AppVisualColors.light;
}
