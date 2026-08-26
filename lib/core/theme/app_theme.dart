import 'package:flutter/material.dart';

/// AI VOC Intelligence Platform의 현대적 디자인 시스템
/// Material Design 3 기반 (2024 트렌드)
/// - 라이트 모드: 밝고 깨끗한 인터페이스 (AX 최적화)
/// - 다크 모드: 눈 편한 다크 인터페이스
/// - Primary: Modern Blue (#2563EB) - 신뢰성, 기술성
/// - Secondary: Rich Violet (#7C3AED) - AI, 혁신성
/// - Tertiary: Emerald Green (#10B981) - 효율성, 해결
/// - Accent: Amber (#F59E0B) - 긴급도, 주의
class AppTheme {
  AppTheme._();

  // ==================== 라이트 모드 색상 ====================
  // 주 색상 팔레트
  static const Color _lightPrimaryColor = Color(0xFF2563EB); // Modern Blue
  static const Color _lightSecondaryColor = Color(0xFF7C3AED); // Rich Violet
  static const Color _lightTertiaryColor = Color(0xFF10B981); // Emerald Green
  static const Color _lightErrorColor = Color(0xFFDC2626); // Deep Red
  static const Color _lightWarningColor = Color(0xFFF59E0B); // Warm Amber
  static const Color _lightSuccessColor = Color(0xFF059669); // True Green
  
  // 라이트 중립 색상 (밝은 배경)
  static const Color _lightSurface = Color(0xFFFFFFFF); // Pure White
  static const Color _lightSurfaceLight = Color(0xFFFBFCFE); // Almost white
  static const Color _lightSurfaceVariant = Color(0xFFF8FAFC); // Light blue-gray
  static const Color _lightOnSurface = Color(0xFF0F172A); // Almost black
  static const Color _lightOutline = Color(0xFFCBD5E1); // Light gray
  
  // ==================== 다크 모드 색상 ====================
  static const Color _darkPrimaryColor = Color(0xFF60A5FA); // Lighter Blue
  static const Color _darkSecondaryColor = Color(0xFFC4B5FD); // Lighter Violet
  static const Color _darkTertiaryColor = Color(0xFF6EE7B7); // Lighter Green
  static const Color _darkErrorColor = Color(0xFFFCA5A5); // Lighter Red
  static const Color _darkWarningColor = Color(0xFFFCD34D); // Lighter Amber
  static const Color _darkSuccessColor = Color(0xFF6EE7B7); // Lighter Green
  
  // 다크 중립 색상
  static const Color _darkSurface = Color(0xFF0F172A); // Deep navy
  static const Color _darkSurfaceHigh = Color(0xFF1E293B); // Navy
  static const Color _darkSurfaceVariant = Color(0xFF334155); // Slate
  static const Color _darkOnSurface = Color(0xFFF1F5F9); // Almost white
  static const Color _darkOutline = Color(0xFF64748B); // Gray

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // 색상 스킴 정의 (라이트 모드)
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: _lightPrimaryColor,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDEEAF8),
      onPrimaryContainer: const Color(0xFF001850),
      secondary: _lightSecondaryColor,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFEDDEFF),
      onSecondaryContainer: const Color(0xFF2D1047),
      tertiary: _lightTertiaryColor,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFD2F7ED),
      onTertiaryContainer: const Color(0xFF003828),
      error: _lightErrorColor,
      onError: Colors.white,
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFF5F0000),
      background: _lightSurface,
      onBackground: _lightOnSurface,
      surface: _lightSurface,
      onSurface: _lightOnSurface,
      surfaceVariant: _lightSurfaceVariant,
      onSurfaceVariant: const Color(0xFF475569),
      outline: _lightOutline,
      outlineVariant: const Color(0xFFE0E7FF),
      scrim: Colors.black,
      inverseSurface: const Color(0xFF1E293B),
      inversePrimary: const Color(0xFF60A5FA),
    ),
    
    // 앱바 테마
    appBarTheme: const AppBarTheme(
      backgroundColor: _lightPrimaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.15,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    
    // 카드 테마
    cardTheme: CardThemeData(
      elevation: 0,
      color: _lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _lightOutline, width: 1),
      ),
      surfaceTintColor: _lightPrimaryColor,
      margin: const EdgeInsets.all(0),
    ),
    
    // 입력 필드 테마
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightOutline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightOutline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightPrimaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightErrorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightErrorColor, width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 14),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIconColor: const Color(0xFF475569),
      suffixIconColor: const Color(0xFF475569),
    ),
    
    // 버튼 테마 (라이트)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightPrimaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _lightPrimaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _lightPrimaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: const BorderSide(color: _lightPrimaryColor, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _lightPrimaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    
    // 칩 테마
    chipTheme: ChipThemeData(
      backgroundColor: _lightSurfaceVariant,
      selectedColor: _lightPrimaryColor,
      disabledColor: const Color(0xFFE2E8F0),
      side: const BorderSide(color: _lightOutline),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _lightOnSurface,
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    
    // 플로팅 액션 버튼 테마
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _lightPrimaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    
    // 다이얼로그 테마
    dialogTheme: DialogThemeData(
      backgroundColor: _lightSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _lightOnSurface,
        letterSpacing: 0.15,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF475569),
        letterSpacing: 0.25,
      ),
    ),
    
    // 바텀 시트 테마
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _lightSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    
    // 진행률 표시기 테마
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      linearMinHeight: 4,
      linearTrackColor: _lightOutline,
      color: _lightPrimaryColor,
    ),
    
    // 구분선 테마
    dividerTheme: const DividerThemeData(
      color: _lightOutline,
      thickness: 1,
      space: 16,
      indent: 0,
      endIndent: 0,
    ),
    
    // 탭 바 테마
    tabBarTheme: TabBarThemeData(
      indicatorSize: TabBarIndicatorSize.label,
      indicator: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _lightPrimaryColor, width: 3),
        ),
      ),
      unselectedLabelColor: const Color(0xFF94A3B8),
      labelColor: _lightPrimaryColor,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    
    // 스캐폴드 백그라운드
    scaffoldBackgroundColor: _lightSurface,
    
    // 텍스트 테마 (라이트)
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: _lightOnSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: _lightOnSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: _lightOnSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: _lightOnSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: _lightOnSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: _lightOnSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: _lightOnSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: _lightOnSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: _lightOnSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: _lightOnSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: _lightOnSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: _lightOnSurface,
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // 색상 스킴 정의 (다크 모드)
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: _darkPrimaryColor,
      onPrimary: const Color(0xFF001850),
      primaryContainer: const Color(0xFF1E40AF),
      onPrimaryContainer: const Color(0xFFDEEAF8),
      secondary: _darkSecondaryColor,
      onSecondary: const Color(0xFF2D1047),
      secondaryContainer: const Color(0xFF4A235A),
      onSecondaryContainer: const Color(0xFFEDDEFF),
      tertiary: _darkTertiaryColor,
      onTertiary: const Color(0xFF003828),
      tertiaryContainer: const Color(0xFF00574B),
      onTertiaryContainer: const Color(0xFFD2F7ED),
      error: _darkErrorColor,
      onError: const Color(0xFF5F0000),
      errorContainer: const Color(0xFF8B0000),
      onErrorContainer: const Color(0xFFFEE2E2),
      background: _darkSurface,
      onBackground: _darkOnSurface,
      surface: _darkSurfaceHigh,
      onSurface: _darkOnSurface,
      surfaceVariant: _darkSurfaceVariant,
      onSurfaceVariant: const Color(0xFFCBD5E1),
      outline: _darkOutline,
      outlineVariant: const Color(0xFF475569),
      scrim: Colors.black,
      inverseSurface: const Color(0xFFF1F5F9),
      inversePrimary: _lightPrimaryColor,
    ),
    
    // 앱바 테마 (다크)
    appBarTheme: const AppBarTheme(
      backgroundColor: _darkSurfaceHigh,
      foregroundColor: _darkOnSurface,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _darkOnSurface,
        letterSpacing: 0.15,
      ),
      iconTheme: IconThemeData(color: _darkOnSurface),
    ),
    
    // 카드 테마 (다크)
    cardTheme: CardThemeData(
      elevation: 0,
      color: _darkSurfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _darkOutline, width: 1),
      ),
      surfaceTintColor: _darkPrimaryColor,
      margin: const EdgeInsets.all(0),
    ),
    
    // 입력 필드 테마 (다크)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _darkOutline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _darkOutline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _darkPrimaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _darkErrorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _darkErrorColor, width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIconColor: const Color(0xFFCBD5E1),
      suffixIconColor: const Color(0xFFCBD5E1),
    ),
    
    // 버튼 테마 (다크)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkPrimaryColor,
        foregroundColor: const Color(0xFF001850),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _darkPrimaryColor,
        foregroundColor: const Color(0xFF001850),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _darkPrimaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: const BorderSide(color: _darkPrimaryColor, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _darkPrimaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    
    // 칩 테마 (다크)
    chipTheme: ChipThemeData(
      backgroundColor: _darkSurfaceVariant,
      selectedColor: _darkPrimaryColor,
      disabledColor: const Color(0xFF475569),
      side: const BorderSide(color: _darkOutline),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _darkOnSurface,
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF001850),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    
    // 플로팅 액션 버튼 테마 (다크)
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _darkPrimaryColor,
      foregroundColor: const Color(0xFF001850),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    
    // 다이얼로그 테마 (다크)
    dialogTheme: DialogThemeData(
      backgroundColor: _darkSurfaceHigh,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _darkOnSurface,
        letterSpacing: 0.15,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFFCBD5E1),
        letterSpacing: 0.25,
      ),
    ),
    
    // 바텀 시트 테마 (다크)
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _darkSurfaceHigh,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    
    // 진행률 표시기 테마 (다크)
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      linearMinHeight: 4,
      linearTrackColor: _darkSurfaceVariant,
      color: _darkPrimaryColor,
    ),
    
    // 구분선 테마 (다크)
    dividerTheme: const DividerThemeData(
      color: _darkOutline,
      thickness: 1,
      space: 16,
      indent: 0,
      endIndent: 0,
    ),
    
    // 탭 바 테마 (다크)
    tabBarTheme: TabBarThemeData(
      indicatorSize: TabBarIndicatorSize.label,
      indicator: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _darkPrimaryColor, width: 3),
        ),
      ),
      unselectedLabelColor: const Color(0xFF94A3B8),
      labelColor: _darkPrimaryColor,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    
    // 스캐폴드 백그라운드 (다크)
    scaffoldBackgroundColor: _darkSurface,
    
    // 텍스트 테마 (다크)
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: _darkOnSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: _darkOnSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: _darkOnSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: _darkOnSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: _darkOnSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: _darkOnSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: _darkOnSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: _darkOnSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: _darkOnSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: _darkOnSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: _darkOnSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: _darkOnSurface,
      ),
    ),
  );

  // ==================== 헬퍼 메서드 ====================
  
  /// 우선순위에 따른 색상 반환 (라이트 모드 기준)
  static Color priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
      case 'CRITICAL':
        return _lightErrorColor;
      case 'MEDIUM':
        return _lightWarningColor;
      case 'LOW':
        return _lightSuccessColor;
      default:
        return Colors.grey;
    }
  }

  /// 상태에 따른 색상 반환 (라이트 모드 기준)
  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return _lightPrimaryColor;
      case 'IN_PROGRESS':
        return _lightWarningColor;
      case 'RESOLVED':
        return _lightSuccessColor;
      case 'REJECTED':
        return _lightErrorColor;
      case 'DRAFT':
        return const Color(0xFFCBD5E1);
      default:
        return Colors.grey;
    }
  }

  /// 긴급도에 따른 색상 반환 (라이트 모드 기준)
  static Color urgencyColor(String urgency) {
    switch (urgency.toUpperCase()) {
      case 'CRITICAL':
        return _lightErrorColor;
      case 'HIGH':
        return _lightWarningColor;
      case 'MEDIUM':
        return _lightSecondaryColor;
      case 'LOW':
        return _lightTertiaryColor;
      default:
        return Colors.grey;
    }
  }

  /// AI 신뢰도에 따른 색상 (점수 0-1, 라이트 모드 기준)
  static Color confidenceColor(double score) {
    if (score >= 0.8) return _lightSuccessColor;
    if (score >= 0.6) return _lightWarningColor;
    return _lightErrorColor;
  }
}
