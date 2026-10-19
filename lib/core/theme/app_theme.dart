import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Scaneliq design tokens defined in Master Blueprint Section 0.1
/// and UX Redesign Specification Section 4.1.
class AppColors {
  // Brand tokens
  static const Color brandPrimary = Color(0xFF2563EB); // Royal Blue
  static const Color primary = brandPrimary;
  static const Color brandPrimaryPressed = Color(0xFF1D4ED8);
  static const Color brandDeep = Color(0xFF021642); // Deep Navy
  static const Color brandAccent = Color(0xFF00F0FF); // Electric Cyan
  static const Color brandLight = Color(0xFFEFF6FF); // Soft Blue Tint

  // Layered Light Theme Surfaces (Material 3 Tonal Rhythm)
  static const Color surface0Light = Color(0xFFF7F9FC); // Canvas Background
  static const Color appBackgroundLight = surface0Light;
  static const Color surface1Light = Color(0xFFFFFFFF); // Cards & Sheets
  static const Color surfaceLight = surface1Light;
  static const Color surface2Light = Color(
    0xFFF1F5F9,
  ); // Inputs, Pills & Secondary
  static const Color surface3Light = Color(0xFFE4E7EC); // Dividers & Borders

  // Light Theme Typography
  static const Color textPrimaryLight = Color(0xFF101828); // Slate 900
  static const Color textSecondaryLight = Color(0xFF667085); // Slate 500
  static const Color textTertiaryLight = Color(0xFF98A2B3); // Slate 400
  static const Color borderLight = Color(0xFFE4E7EC);
  static const Color borderSubtleLight = Color(0xFFE4E7EC);

  // Layered Dark Theme Surfaces
  static const Color surface0Dark = Color(0xFF090D16); // Deep Midnight Canvas
  static const Color appBackgroundDark = surface0Dark;
  static const Color surface1Dark = Color(
    0xFF131B2E,
  ); // Navy Slate Cards & Sheets
  static const Color surfaceDark = surface1Dark;
  static const Color surface2Dark = Color(
    0xFF1E293B,
  ); // Slate 800 Inputs & Pills
  static const Color surface3Dark = Color(
    0xFF293548,
  ); // Slate 700 Borders & Dividers

  // Dark Theme Typography
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color textTertiaryDark = Color(0xFF64748B); // Slate 500
  static const Color borderDark = Color(0xFF1E293B);
  static const Color borderSubtleDark = Color(0xFF1E293B);

  // Semantic Status Tokens (Accessible & Strict)
  static const Color success = Color(0xFF16803C); // Green check ONLY
  static const Color warning = Color(0xFFB54708); // Amber alert
  static const Color error = Color(
    0xFFB42318,
  ); // Destructive / Irreversible action ONLY
  static const Color focus = Color(0xFF0EA5E9); // Focus Sky Blue

  // Strict 4-Color Categorical Palette (Tags & Folders ONLY - Never for Status)
  static const Color tagBlue = Color(0xFF2563EB); // General / Study
  static const Color tagGreen = Color(0xFF16803C); // Finance / Receipts
  static const Color tagAmber = Color(0xFFB54708); // Work / Priority
  static const Color tagPurple = Color(0xFF7C3AED); // Legal / Personal
}

/// Consolidated Material 3 Application Theme for Scaneliq
class AppTheme {
  static final String? _interFont = GoogleFonts.inter().fontFamily;
  static final String? _bengaliFont = GoogleFonts.notoSansBengali().fontFamily;
  static final List<String> _fontFallbacks = [
    ?_bengaliFont,
    'Roboto',
    'sans-serif',
  ];

  static TextTheme _buildTextTheme(Color primaryText, Color secondaryText) {
    return TextTheme(
      // Display / Screen Title (24-28sp, Medium/SemiBold)
      headlineLarge: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: primaryText,
        letterSpacing: -0.4,
        fontFamily: _interFont,
        fontFamilyFallback: _fontFallbacks,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primaryText,
        letterSpacing: -0.2,
        fontFamily: _interFont,
        fontFamilyFallback: _fontFallbacks,
      ),
      // Section Header (18-20sp, SemiBold)
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryText,
        letterSpacing: -0.1,
        fontFamily: _interFont,
        fontFamilyFallback: _fontFallbacks,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primaryText,
        letterSpacing: 0.0,
        fontFamily: _interFont,
        fontFamilyFallback: _fontFallbacks,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: secondaryText,
        letterSpacing: 0.1,
        fontFamily: _interFont,
        fontFamilyFallback: _fontFallbacks,
      ),
      // Body (14-16sp, Regular)
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: primaryText,
        height: 1.45,
        fontFamily: _interFont,
        fontFamilyFallback: _fontFallbacks,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondaryText,
        height: 1.4,
        fontFamily: _interFont,
        fontFamilyFallback: _fontFallbacks,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryText,
        height: 1.35,
        fontFamily: _interFont,
        fontFamilyFallback: _fontFallbacks,
      ),
      // Buttons / Labels (14-16sp, SemiBold)
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
        letterSpacing: 0.1,
        fontFamily: _interFont,
        fontFamilyFallback: _fontFallbacks,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondaryText,
        letterSpacing: 0.1,
        fontFamily: _interFont,
        fontFamilyFallback: _fontFallbacks,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondaryText,
        letterSpacing: 0.2,
        fontFamily: _interFont,
        fontFamilyFallback: _fontFallbacks,
      ),
    );
  }

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme(
      AppColors.textPrimaryLight,
      AppColors.textSecondaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: _interFont,
      fontFamilyFallback: _fontFallbacks,
      primaryColor: AppColors.brandPrimary,
      scaffoldBackgroundColor: AppColors.surface0Light,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandPrimary,
        onPrimary: Colors.white,
        secondary: AppColors.brandDeep,
        onSecondary: Colors.white,
        tertiary: AppColors.brandAccent,
        surface: AppColors.surface1Light,
        onSurface: AppColors.textPrimaryLight,
        surfaceContainerHighest: AppColors.surface2Light,
        outline: AppColors.borderSubtleLight,
        outlineVariant: AppColors.surface3Light,
        error: AppColors.error,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface0Light,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface1Light,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        height: 68,
        indicatorColor: AppColors.brandLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.brandPrimary, size: 24);
          }
          return const IconThemeData(
            color: AppColors.textSecondaryLight,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brandPrimary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryLight,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface1Light,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSubtleLight, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandPrimary,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(
            color: AppColors.borderSubtleLight,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2Light,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          color: AppColors.textTertiaryLight,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.brandPrimary,
            width: 1.5,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface2Light,
        selectedColor: AppColors.brandLight,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimaryLight,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.brandPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.transparent),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surface3Light,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface1Light,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface1Light,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimaryLight,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = _buildTextTheme(
      AppColors.textPrimaryDark,
      AppColors.textSecondaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: _interFont,
      fontFamilyFallback: _fontFallbacks,
      primaryColor: AppColors.brandPrimary,
      scaffoldBackgroundColor: AppColors.surface0Dark,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brandPrimary,
        onPrimary: Colors.white,
        secondary: AppColors.brandAccent,
        onSecondary: AppColors.brandDeep,
        surface: AppColors.surface1Dark,
        onSurface: AppColors.textPrimaryDark,
        surfaceContainerHighest: AppColors.surface2Dark,
        outline: AppColors.borderSubtleDark,
        outlineVariant: AppColors.surface3Dark,
        error: AppColors.error,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface0Dark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface1Dark,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        height: 68,
        indicatorColor: AppColors.surface2Dark,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.brandAccent, size: 24);
          }
          return const IconThemeData(
            color: AppColors.textSecondaryDark,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brandAccent,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryDark,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface1Dark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSubtleDark, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandAccent,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: AppColors.borderSubtleDark, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2Dark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          color: AppColors.textTertiaryDark,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.brandAccent,
            width: 1.5,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface2Dark,
        selectedColor: AppColors.surface3Dark,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimaryDark,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.brandAccent,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.transparent),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surface3Dark,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface1Dark,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface1Dark,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface2Dark,
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
