import 'package:flutter/material.dart';

/// Official Concept A (Editorial Gallery Minimal) semantic color palettes.
///
/// Extracted directly from the approved Gallery Alabaster (Light) and
/// Carbon Studio (Dark) design tokens.
@immutable
class ScaneliqColorPalette {
  final Color bg;
  final Color surface;
  final Color surfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color hairline;
  final Color accent;
  final Color accentSecondary;
  final Color accentSoft;
  final Color badgeBg;
  final Color badgeFg;
  final Color navGlass;
  final Color paperBorder;
  final Color paperBack;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  const ScaneliqColorPalette({
    required this.bg,
    required this.surface,
    required this.surfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.hairline,
    required this.accent,
    required this.accentSecondary,
    required this.accentSoft,
    required this.badgeBg,
    required this.badgeFg,
    required this.navGlass,
    required this.paperBorder,
    required this.paperBack,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
  });

  /// Light Mode — Gallery Alabaster (#FAF9F6).
  static const light = ScaneliqColorPalette(
    bg: Color(0xFFFAF9F6),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF2F0EB),
    textPrimary: Color(0xFF141413),
    textSecondary: Color(0xFF5C5B57),
    textTertiary: Color(0xFF8C8A84),
    hairline: Color(0xFFE6E4DD),
    accent: Color(0xFF0052FF), // International Ultramarine
    accentSecondary: Color(0xFF141413), // Monochrome Studio Black
    accentSoft: Color(0x140052FF), // 8% Ultramarine tint
    badgeBg: Color(0xFF141413),
    badgeFg: Color(0xFFFFFFFF),
    navGlass: Color(0xE0FAF9F6), // 88% Gallery Alabaster frosted glass
    paperBorder: Color(0xFFD8D6CE),
    paperBack: Color(0xFFE2E8F0),
    success: Color(0xFF059669),
    successSoft: Color(0x1A059669),
    warning: Color(0xFFB45309),
    warningSoft: Color(0x1AB45309),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0x1ADC2626),
    info: Color(0xFF0052FF),
    infoSoft: Color(0x140052FF),
  );

  /// Dark Mode — Carbon Studio (#0D0E11).
  static const dark = ScaneliqColorPalette(
    bg: Color(0xFF0D0E11),
    surface: Color(0xFF15171C),
    surfaceSubtle: Color(0xFF1C1F26),
    textPrimary: Color(0xFFF4F4F6),
    textSecondary: Color(0xFF9CA0AB),
    textTertiary: Color(0xFF636773),
    hairline: Color(0xFF23262F),
    accent: Color(0xFF3B82F6),
    accentSecondary: Color(0xFF60A5FA),
    accentSoft: Color(0x243B82F6), // 14% Ultramarine glow tint
    badgeBg: Color(0xFF262A34),
    badgeFg: Color(0xFFE5E7EB),
    navGlass: Color(0xE00D0E11), // 88% Carbon Studio frosted glass
    paperBorder: Color(0xFFD8D6CE),
    paperBack: Color(0xFF2A2E39),
    success: Color(0xFF34D399),
    successSoft: Color(0x2434D399),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0x24FBBF24),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0x24F87171),
    info: Color(0xFF3B82F6),
    infoSoft: Color(0x243B82F6),
  );

  /// Permanent Optical Camera Studio surfaces (always dark).
  static const cameraStudioBg = Color(0xFF090A0D);
  static const cameraStageBg = Color(0xFF101218);
  static const cameraStageBorder = Color(0xFF222632);
}
