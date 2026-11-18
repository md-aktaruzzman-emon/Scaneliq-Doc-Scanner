import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/app_theme.dart';

/// Reusable brand logo widget for consistent display across Scaneliq.
class ScaneliqLogo extends StatelessWidget {
  static const String masterAssetPath =
      'assets/branding/scaneliq_logo_master.png';

  final double size;
  final double? borderRadius;
  final BoxFit fit;
  final bool showBorder;

  const ScaneliqLogo({
    super.key,
    this.size = 32.0,
    this.borderRadius,
    this.fit = BoxFit.contain,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? 0.0;

    final imageWidget = Image.asset(
      masterAssetPath,
      width: size,
      height: size,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.brandLight,
          borderRadius: BorderRadius.circular(
            effectiveRadius > 0 ? effectiveRadius : (size * 0.22),
          ),
        ),
        child: Icon(
          Icons.document_scanner,
          size: size * 0.65,
          color: AppColors.brandPrimary,
        ),
      ),
    );

    if (effectiveRadius > 0) {
      final clipped = ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: imageWidget,
      );
      if (!showBorder) return clipped;
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: Border.all(
            color: isDark ? const Color(0x3838BDF8) : const Color(0x1F031837),
            width: 0.75,
          ),
        ),
        position: DecorationPosition.foreground,
        child: clipped,
      );
    }
    return imageWidget;
  }
}
