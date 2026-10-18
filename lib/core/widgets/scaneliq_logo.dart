import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/app_theme.dart';

/// Reusable brand logo widget for consistent display across Scaneliq
class ScaneliqLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final BoxFit fit;

  const ScaneliqLogo({
    super.key,
    this.size = 32.0,
    this.borderRadius = 8.0,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/branding/scaneliq_logo.jpg',
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.brandLight,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(
            Icons.document_scanner,
            size: size * 0.65,
            color: AppColors.brandPrimary,
          ),
        ),
      ),
    );
  }
}
