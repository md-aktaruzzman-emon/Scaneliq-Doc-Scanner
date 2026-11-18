import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scaneliq_colors.dart';
import 'scaneliq_radius.dart';
import 'scaneliq_spacing.dart';
import 'scaneliq_tokens.dart';
import 'scaneliq_typography.dart';

/// Backward-compatible alias class mapping existing feature screens onto the
/// approved Concept A (Editorial Gallery Minimal) palette without breaking
/// compilation across un-refactored feature screens.
class AppColors {
  // Primary Concept A brand accents (International Ultramarine)
  static const Color brandPrimary = Color(0xFF0052FF);
  static const Color primary = brandPrimary;
  static const Color brandPrimaryPressed = Color(0xFF003EC7);
  static const Color brandDeep = Color(0xFF141413);
  static const Color brandAccent = Color(0xFF3B82F6);
  static const Color brandLight = Color(0x140052FF);

  // Light Theme Surfaces — Gallery Alabaster
  static const Color surface0Light = Color(0xFFFAF9F6);
  static const Color appBackgroundLight = surface0Light;
  static const Color surface1Light = Color(0xFFFFFFFF);
  static const Color surfaceLight = surface1Light;
  static const Color surface2Light = Color(0xFFF2F0EB);
  static const Color surface3Light = Color(0xFFE6E4DD);

  // Light Theme Typography
  static const Color textPrimaryLight = Color(0xFF141413);
  static const Color textSecondaryLight = Color(0xFF5C5B57);
  static const Color textTertiaryLight = Color(0xFF8C8A84);
  static const Color borderLight = Color(0xFFE6E4DD);
  static const Color borderSubtleLight = Color(0xFFE6E4DD);

  // Dark Theme Surfaces — Carbon Studio
  static const Color surface0Dark = Color(0xFF0D0E11);
  static const Color appBackgroundDark = surface0Dark;
  static const Color surface1Dark = Color(0xFF15171C);
  static const Color surfaceDark = surface1Dark;
  static const Color surface2Dark = Color(0xFF1C1F26);
  static const Color surface3Dark = Color(0xFF23262F);

  // Dark Theme Typography
  static const Color textPrimaryDark = Color(0xFFF4F4F6);
  static const Color textSecondaryDark = Color(0xFF9CA0AB);
  static const Color textTertiaryDark = Color(0xFF636773);
  static const Color borderDark = Color(0xFF23262F);
  static const Color borderSubtleDark = Color(0xFF23262F);

  // Semantic Status Tokens
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFB45309);
  static const Color error = Color(0xFFDC2626);
  static const Color focus = Color(0xFF0052FF);

  // Restrained Categorical Palette (Tags & Folders ONLY)
  static const Color tagBlue = Color(0xFF0052FF);
  static const Color tagGreen = Color(0xFF059669);
  static const Color tagAmber = Color(0xFFB45309);
  static const Color tagPurple = Color(0xFF6D28D9);
}

/// Consolidated Material 3 Themes for Scaneliq (Concept A: Editorial Gallery Minimal).
class AppTheme {
  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    palette: ScaneliqColorPalette.light,
    tokens: ScaneliqTokens.light,
  );

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    palette: ScaneliqColorPalette.dark,
    tokens: ScaneliqTokens.dark,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ScaneliqColorPalette palette,
    required ScaneliqTokens tokens,
  }) {
    final isDark = brightness == Brightness.dark;
    final textTheme = ScaneliqTypography.buildTextTheme(
      primaryText: palette.textPrimary,
      secondaryText: palette.textSecondary,
      tertiaryText: palette.textTertiary,
    );

    final overlayStyle = isDark
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Color(0xFF0D0E11),
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarDividerColor: Color(0xFF23262F),
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFFFAF9F6),
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarDividerColor: Color(0xFFE6E4DD),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: ScaneliqTypography.bodyFontFamily,
      fontFamilyFallback: ScaneliqTypography.fontFallbacks,
      primaryColor: palette.accent,
      scaffoldBackgroundColor: palette.bg,
      textTheme: textTheme,
      extensions: [tokens],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.accent,
        onPrimary: Colors.white,
        secondary: palette.accentSecondary,
        onSecondary: isDark ? palette.bg : Colors.white,
        tertiary: palette.accentSecondary,
        onTertiary: Colors.white,
        error: palette.danger,
        onError: Colors.white,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainerLowest: palette.bg,
        surfaceContainerLow: palette.surface,
        surfaceContainer: palette.surfaceSubtle,
        surfaceContainerHigh: palette.surfaceSubtle,
        surfaceContainerHighest: palette.surfaceSubtle,
        outline: palette.hairline,
        outlineVariant: palette.hairline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: IconThemeData(color: palette.textPrimary, size: 20),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.navGlass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: ScaneliqSpacing.bottomNavHeight,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? palette.textPrimary : palette.textTertiary,
            size: 21,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: ScaneliqTypography.bodyFontFamily,
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? palette.textPrimary : palette.textTertiary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: ScaneliqRadius.folioBorderRadius,
          side: BorderSide(color: palette.hairline, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: ScaneliqRadius.pillBorderRadius,
          ),
          textStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.surface,
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(0, 44),
          side: BorderSide(color: palette.hairline, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: ScaneliqRadius.pillBorderRadius,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          textStyle: textTheme.labelMedium?.copyWith(color: palette.accent),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textTertiary),
        border: OutlineInputBorder(
          borderRadius: ScaneliqRadius.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ScaneliqRadius.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ScaneliqRadius.inputBorderRadius,
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.hairline,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: ScaneliqRadius.buttonBorderRadius,
          side: BorderSide(color: palette.hairline, width: 1),
        ),
        titleTextStyle: textTheme.headlineMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: ScaneliqRadius.modalSheetBorderRadius,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textPrimary,
        contentTextStyle: textTheme.bodySmall?.copyWith(
          color: palette.bg,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: ScaneliqRadius.inputBorderRadius,
        ),
      ),
    );
  }
}

/// Persisted ThemeMode controller using existing SharedPreferences dependency.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _prefKey = 'scaneliq_theme_mode';

  @override
  ThemeMode build() {
    _loadSavedPreference();
    return ThemeMode.system;
  }

  Future<void> _loadSavedPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'light') {
        state = ThemeMode.light;
      } else if (saved == 'dark') {
        state = ThemeMode.dark;
      } else if (saved == 'system') {
        state = ThemeMode.system;
      }
    } catch (_) {
      // Keep safe default ThemeMode.system in restricted test harnesses.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_prefKey, value);
    } catch (_) {
      // Ignore storage failures in ephemeral test bindings.
    }
  }

  /// Toggles cleanly between Gallery Alabaster (Light) and Carbon Studio (Dark).
  Future<void> toggleLightDark(Brightness currentPlatformBrightness) async {
    final effectiveDark =
        state == ThemeMode.dark ||
        (state == ThemeMode.system &&
            currentPlatformBrightness == Brightness.dark);
    await setThemeMode(effectiveDark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});
