import 'package:flutter/material.dart';

import 'scaneliq_colors.dart';

/// Centralized `ThemeExtension` carrying every Concept A token so widgets
/// can consume `context.tokens` cleanly in both Light and Dark themes.
@immutable
class ScaneliqTokens extends ThemeExtension<ScaneliqTokens> {
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
  final List<BoxShadow> paperShadow;
  final List<BoxShadow> floatingShadow;

  const ScaneliqTokens({
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
    required this.paperShadow,
    required this.floatingShadow,
  });

  factory ScaneliqTokens.fromPalette(
    ScaneliqColorPalette palette, {
    required bool isDark,
  }) {
    return ScaneliqTokens(
      bg: palette.bg,
      surface: palette.surface,
      surfaceSubtle: palette.surfaceSubtle,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      textTertiary: palette.textTertiary,
      hairline: palette.hairline,
      accent: palette.accent,
      accentSecondary: palette.accentSecondary,
      accentSoft: palette.accentSoft,
      badgeBg: palette.badgeBg,
      badgeFg: palette.badgeFg,
      navGlass: palette.navGlass,
      paperBorder: palette.paperBorder,
      paperBack: palette.paperBack,
      success: palette.success,
      successSoft: palette.successSoft,
      warning: palette.warning,
      warningSoft: palette.warningSoft,
      danger: palette.danger,
      dangerSoft: palette.dangerSoft,
      info: palette.info,
      infoSoft: palette.infoSoft,
      paperShadow: isDark
          ? const [
              BoxShadow(
                color: Color(0x8C000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0x12141413),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x0F141413),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
      floatingShadow: [
        BoxShadow(
          color: palette.accent.withValues(alpha: isDark ? 0.36 : 0.30),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static final light = ScaneliqTokens.fromPalette(
    ScaneliqColorPalette.light,
    isDark: false,
  );

  static final dark = ScaneliqTokens.fromPalette(
    ScaneliqColorPalette.dark,
    isDark: true,
  );

  @override
  ScaneliqTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? hairline,
    Color? accent,
    Color? accentSecondary,
    Color? accentSoft,
    Color? badgeBg,
    Color? badgeFg,
    Color? navGlass,
    Color? paperBorder,
    Color? paperBack,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    List<BoxShadow>? paperShadow,
    List<BoxShadow>? floatingShadow,
  }) {
    return ScaneliqTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      hairline: hairline ?? this.hairline,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      accentSoft: accentSoft ?? this.accentSoft,
      badgeBg: badgeBg ?? this.badgeBg,
      badgeFg: badgeFg ?? this.badgeFg,
      navGlass: navGlass ?? this.navGlass,
      paperBorder: paperBorder ?? this.paperBorder,
      paperBack: paperBack ?? this.paperBack,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      paperShadow: paperShadow ?? this.paperShadow,
      floatingShadow: floatingShadow ?? this.floatingShadow,
    );
  }

  @override
  ScaneliqTokens lerp(ThemeExtension<ScaneliqTokens>? other, double t) {
    if (other is! ScaneliqTokens) return this;
    return ScaneliqTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      badgeBg: Color.lerp(badgeBg, other.badgeBg, t)!,
      badgeFg: Color.lerp(badgeFg, other.badgeFg, t)!,
      navGlass: Color.lerp(navGlass, other.navGlass, t)!,
      paperBorder: Color.lerp(paperBorder, other.paperBorder, t)!,
      paperBack: Color.lerp(paperBack, other.paperBack, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      paperShadow: t < 0.5 ? paperShadow : other.paperShadow,
      floatingShadow: t < 0.5 ? floatingShadow : other.floatingShadow,
    );
  }
}

/// Convenient context accessor with safe fallback so isolated widgets work
/// smoothly even inside bare MaterialApp harnesses.
extension ScaneliqThemeContext on BuildContext {
  ScaneliqTokens get tokens {
    final ext = Theme.of(this).extension<ScaneliqTokens>();
    if (ext != null) return ext;
    return Theme.of(this).brightness == Brightness.dark
        ? ScaneliqTokens.dark
        : ScaneliqTokens.light;
  }
}
