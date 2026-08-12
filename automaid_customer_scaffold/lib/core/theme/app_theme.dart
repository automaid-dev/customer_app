import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand tokens pulled directly from the LaundryBar mark — not a generic
/// Material default palette. Blue is the mascot's body and the dominant
/// brand color; yellow is the background wedge color, used as an accent
/// (CTAs, highlights) rather than a base, since a yellow-dominant UI
/// would fight with the legibility this app actually needs (forms,
/// receipts, addresses). Red appears in the logo outline only — kept as
/// a rare, deliberate accent (e.g. destructive actions) rather than a
/// UI color, so it doesn't compete with yellow for attention.
class AppColors {
  AppColors._();

  static const blue = Color(0xFF1565C0);
  static const blueDark = Color(0xFF0D47A1);
  static const yellow = Color(0xFFFFC72C);
  static const red = Color(0xFFE53935);
  static const background = Color(0xFFF7F9FC);
  static const ink = Color(0xFF1A1A2E);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      secondary: AppColors.yellow,
      error: AppColors.red,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    // Baloo 2 is a rounded, friendly display face — matches the LaundryBar
    // mascot's cartoon personality — used with restraint for headings only.
    // Body text stays on the system face for density/readability on forms,
    // receipts, and lists where a playful face would slow reading down.
    final headlineFace = GoogleFonts.baloo2TextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: Typography.material2021().black.copyWith(
            displayLarge: headlineFace.displayLarge,
            displayMedium: headlineFace.displayMedium,
            displaySmall: headlineFace.displaySmall,
            headlineLarge: headlineFace.headlineLarge,
            headlineMedium: headlineFace.headlineMedium,
            headlineSmall: headlineFace.headlineSmall,
            titleLarge: headlineFace.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            titleMedium: headlineFace.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: headlineFace.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          side: const BorderSide(color: AppColors.blue),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.blue, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.blue.withValues(alpha: 0.08),
        labelStyle: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
