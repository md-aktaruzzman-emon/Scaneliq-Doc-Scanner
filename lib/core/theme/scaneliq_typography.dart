import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Concept A typography hierarchy.
///
/// Headings: Instrument Sans · Body: Inter + Noto Sans Bengali · Meta: JetBrains Mono
class ScaneliqTypography {
  static String? get headingFontFamily {
    try {
      return GoogleFonts.instrumentSans().fontFamily;
    } catch (_) {
      return null;
    }
  }

  static String? get bodyFontFamily {
    try {
      return GoogleFonts.inter().fontFamily;
    } catch (_) {
      return null;
    }
  }

  static String? get monoFontFamily {
    try {
      return GoogleFonts.jetBrainsMono().fontFamily;
    } catch (_) {
      return 'monospace';
    }
  }

  static String? get _bengaliFallback {
    try {
      return GoogleFonts.notoSansBengali().fontFamily;
    } catch (_) {
      return null;
    }
  }

  static List<String> get fontFallbacks => [
    ?bodyFontFamily,
    ?_bengaliFallback,
    'Roboto',
    'sans-serif',
  ];

  static TextTheme buildTextTheme({
    required Color primaryText,
    required Color secondaryText,
    required Color tertiaryText,
  }) {
    final headFont = headingFontFamily;
    final bodyFont = bodyFontFamily;
    final fallbacks = fontFallbacks;

    return TextTheme(
      // Display (Hero editorial headlines)
      displaySmall: TextStyle(
        fontFamily: headFont,
        fontFamilyFallback: fallbacks,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.15,
        color: primaryText,
      ),
      // Brand wordmark / Screen Display Title
      headlineLarge: TextStyle(
        fontFamily: headFont,
        fontFamilyFallback: fallbacks,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
        height: 1.2,
        color: primaryText,
      ),
      // Screen Sub-title
      headlineMedium: TextStyle(
        fontFamily: headFont,
        fontFamilyFallback: fallbacks,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.25,
        color: primaryText,
      ),
      // Featured folio card title
      titleLarge: TextStyle(
        fontFamily: headFont,
        fontFamilyFallback: fallbacks,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: primaryText,
      ),
      // Document stream row title
      titleMedium: TextStyle(
        fontFamily: headFont,
        fontFamilyFallback: fallbacks,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        height: 1.35,
        color: primaryText,
      ),
      // Editorial section title
      titleSmall: TextStyle(
        fontFamily: headFont,
        fontFamilyFallback: fallbacks,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.0,
        height: 1.3,
        color: secondaryText,
      ),
      // Body Large
      bodyLarge: TextStyle(
        fontFamily: bodyFont,
        fontFamilyFallback: fallbacks,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: primaryText,
      ),
      // Body Medium (Search inputs & standard UI copy)
      bodyMedium: TextStyle(
        fontFamily: bodyFont,
        fontFamilyFallback: fallbacks,
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: secondaryText,
      ),
      // Body Small (Metadata & subtitles)
      bodySmall: TextStyle(
        fontFamily: bodyFont,
        fontFamilyFallback: fallbacks,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: secondaryText,
      ),
      // Label Large (Scope tabs, Primary buttons)
      labelLarge: TextStyle(
        fontFamily: headFont,
        fontFamilyFallback: fallbacks,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.05,
        color: primaryText,
      ),
      // Label Medium (Inline actions & captions)
      labelMedium: TextStyle(
        fontFamily: bodyFont,
        fontFamilyFallback: fallbacks,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondaryText,
      ),
      // Label Small (Bottom nav labels & captions)
      labelSmall: TextStyle(
        fontFamily: bodyFont,
        fontFamilyFallback: fallbacks,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: tertiaryText,
      ),
    ).apply(displayColor: primaryText);
  }

  /// Monospaced metadata style for file sizes, page counts, badges, & timestamps.
  static TextStyle monoStyle({
    required Color color,
    double fontSize = 10.5,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0.2,
  }) {
    return TextStyle(
      fontFamily: monoFontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
