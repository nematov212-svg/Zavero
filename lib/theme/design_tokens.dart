import 'package:flutter/material.dart';

/// Centralized Design Tokens for Family Cafe POS.
/// Provides one single source of truth for colors, typography, spacing,
/// radii, shadows, and responsive breakpoints across all platforms
/// (Android, iOS, Windows, macOS, Linux, Web).
class AppTokens {
  AppTokens._();

  // ── 1. BRAND & THEME COLORS ──────────────────────────────────
  static const Color primary = Color(0xFF0F1E30);
  static const Color primaryDark = Color(0xFF0A1320);
  static const Color secondary = Color(0xFF1E293B);

  // Accent Amber/Gold (Family Cafe Branding)
  static const Color accent = Color(0xFFFFB300);
  static const Color accentWarm = Color(0xFFF59E0B);
  static const Color accentHover = Color(0xFFFFC107);

  // Backgrounds & Surfaces
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color bgDark = Color(0xFF0F172A);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceElevatedLight = Colors.white;
  static const Color surfaceElevatedDark = Color(0xFF273549);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF0F1E30);
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedLight = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerLight = Color(0xFFF1F5F9);
  static const Color dividerDark = Color(0x1FFFFFFF);

  // Functional Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0xFFE8F8F0);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0xFFFFEBEB);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoBg = Color(0xFFEEF4FF);

  // ── 2. SPACING SCALE ───────────────────────────────────────────
  static const double spaceXXS = 2.0;
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 12.0;
  static const double spaceLG = 16.0;
  static const double spaceXL = 20.0;
  static const double spaceXXL = 24.0;
  static const double space3XL = 32.0;
  static const double space4XL = 40.0;

  // ── 3. CORNER RADIUS ───────────────────────────────────────────
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusFull = 999.0;

  static final BorderRadius borderRadiusXS = BorderRadius.circular(radiusXS);
  static final BorderRadius borderRadiusSM = BorderRadius.circular(radiusSM);
  static final BorderRadius borderRadiusMD = BorderRadius.circular(radiusMD);
  static final BorderRadius borderRadiusLG = BorderRadius.circular(radiusLG);
  static final BorderRadius borderRadiusXL = BorderRadius.circular(radiusXL);
  static final BorderRadius borderRadiusXXL = BorderRadius.circular(radiusXXL);
  static final BorderRadius borderRadiusFull = BorderRadius.circular(radiusFull);

  // ── 4. SHADOWS & ELEVATIONS ────────────────────────────────────
  static final List<BoxShadow> shadowCardLight = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static final List<BoxShadow> shadowCardDark = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  // ── 5. RESPONSIVE BREAKPOINTS ──────────────────────────────────
  static const double breakpointMobile = 640.0;
  static const double breakpointTablet = 1024.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < breakpointMobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= breakpointMobile && width < breakpointTablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= breakpointTablet;

  // ── 6. ANIMATION TIMINGS ───────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);
  static const Curve curveDefault = Curves.easeInOut;
}

/// Centralized ThemeData builder implementing the unified cross-platform
/// design language for Family Cafe POS.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppTokens.bgLight,
      primaryColor: AppTokens.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTokens.accentWarm,
        brightness: Brightness.light,
        primary: AppTokens.primary,
        secondary: AppTokens.accentWarm,
        surface: AppTokens.surfaceLight,
        error: AppTokens.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppTokens.surfaceLight,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.borderRadiusLG,
          side: const BorderSide(color: AppTokens.borderLight, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppTokens.borderRadiusMD,
          borderSide: const BorderSide(color: AppTokens.borderLight, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTokens.borderRadiusMD,
          borderSide: const BorderSide(color: AppTokens.borderLight, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTokens.borderRadiusMD,
          borderSide: const BorderSide(color: AppTokens.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppTokens.borderRadiusMD,
          borderSide: const BorderSide(color: AppTokens.error, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppTokens.borderRadiusMD),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.primary,
          side: const BorderSide(color: AppTokens.borderLight, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppTokens.borderRadiusMD),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppTokens.borderRadiusXL),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusXL)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTokens.primary,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTokens.borderRadiusMD),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppTokens.bgDark,
      primaryColor: AppTokens.accent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTokens.accentWarm,
        brightness: Brightness.dark,
        primary: AppTokens.accent,
        secondary: AppTokens.accentWarm,
        surface: AppTokens.surfaceDark,
        error: AppTokens.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppTokens.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.borderRadiusLG,
          side: const BorderSide(color: AppTokens.borderDark, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.surfaceElevatedDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppTokens.borderRadiusMD,
          borderSide: const BorderSide(color: AppTokens.borderDark, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTokens.borderRadiusMD,
          borderSide: const BorderSide(color: AppTokens.borderDark, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTokens.borderRadiusMD,
          borderSide: const BorderSide(color: AppTokens.accent, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.accent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppTokens.borderRadiusMD),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.accent,
          side: const BorderSide(color: AppTokens.accent, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppTokens.borderRadiusMD),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTokens.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: AppTokens.borderRadiusXL),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppTokens.surfaceDark,
        modalBackgroundColor: AppTokens.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusXL)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTokens.surfaceElevatedDark,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTokens.borderRadiusMD),
      ),
    );
  }
}

