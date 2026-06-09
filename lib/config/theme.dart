import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Core Palette ──
  static const Color primary = Color(0xFF735C00);
  static const Color primaryContainer = Color(0xFFFACC15); // Taxi Yellow
  static const Color onPrimaryContainer = Color(0xFF6C5700);
  static const Color gold = Color(0xFFFACC15);
  static const Color goldDark = Color(0xFFF59E0B);

  // ── Surface Hierarchy (stacked paper) ──
  static const Color surface = Color(0xFFFCF9F6);
  static const Color surfaceBright = Color(0xFFFFFEFC);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF7F4F0);
  static const Color surfaceContainer = Color(0xFFF1EDE8);
  static const Color surfaceContainerHigh = Color(0xFFEBE7E2);
  static const Color surfaceContainerHighest = Color(0xFFE5E1DC);

  // ── Text ──
  static const Color onSurface = Color(0xFF1C1C1A);
  static const Color secondary = Color(0xFF5F5E5E);
  static const Color darkText = Color(0xFF1C1C1A);
  static const Color greyText = Color(0xFF5F5E5E);

  // ── Outline ──
  static const Color outlineVariant = Color(0xFFC9C5BE);

  // ── Legacy compat (used in other screens) ──
  static const Color cream = Color(0xFFFCF9F6);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF3F4F6);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color cardBg = Color(0xFFFFFBF0);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color mintGreen = Color(0xFF4CAF50);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color footerBg = Color(0xFF1C1C1A);
  static const Color primaryDark = Color(0xFF0F0F1E);
  static const Color primaryLight = Color(0xFF2D2D4A);

  /// Ghost border: outline-variant at 15% opacity.
  static Color get ghostBorder => outlineVariant.withValues(alpha: 0.15);

  /// Ambient shadow for floating elements.
  static List<BoxShadow> get ambientShadow => [
        BoxShadow(
          color: onSurface.withValues(alpha: 0.08),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];

  /// Glassmorphism decoration for floating overlays.
  static BoxDecoration glassDecoration({
    double opacity = 0.82,
    double blur = 20,
    double radius = 24,
  }) {
    return BoxDecoration(
      color: surfaceContainerLowest.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// CTA gradient (primary to primaryContainer).
  static const LinearGradient ctaGradient = LinearGradient(
    colors: [Color(0xFFFACC15), Color(0xFFFFE066)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get theme {
    final voiceFont = GoogleFonts.plusJakartaSans;
    final dataFont = GoogleFonts.workSans;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        primary: primary,
        primaryContainer: primaryContainer,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: surface,
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: voiceFont(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.02),
        displayMedium: voiceFont(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.02),
        headlineLarge: voiceFont(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.02),
        headlineMedium: voiceFont(fontSize: 18, fontWeight: FontWeight.w700),
        headlineSmall: voiceFont(fontSize: 16, fontWeight: FontWeight.w700),
        titleLarge: voiceFont(fontSize: 16, fontWeight: FontWeight.w700),
        titleMedium: voiceFont(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: voiceFont(fontSize: 14, height: 1.4),
        bodyMedium: voiceFont(fontSize: 13),
        bodySmall: voiceFont(fontSize: 11),
        labelMedium: dataFont(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3),
        labelSmall: dataFont(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: voiceFont(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: voiceFont(fontSize: 14, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineVariant.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineVariant.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: dataFont(fontSize: 11, color: secondary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        color: surfaceContainerLowest,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
