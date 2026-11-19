import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';

/// Primary pill CTA styled with Concept A International Ultramarine (#0052FF / #3B82F6).
class ScaneliqPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final double height;

  const ScaneliqPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    this.height = 46.0,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: tokens.accent,
        disabledBackgroundColor: tokens.accent.withValues(alpha: 0.55),
        foregroundColor: Colors.white,
        minimumSize: Size(expand ? double.infinity : 0, height),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: ScaneliqRadius.pillBorderRadius,
        ),
        textStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ] else if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );

    return button;
  }
}

/// Secondary bordered surface button matching Concept A hairline geometry.
class ScaneliqSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final double height;

  const ScaneliqSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.height = 44.0,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: tokens.surface,
        foregroundColor: tokens.textPrimary,
        minimumSize: Size(expand ? double.infinity : 0, height),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: BorderSide(color: tokens.hairline, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: ScaneliqRadius.pillBorderRadius,
        ),
        textStyle: textTheme.labelLarge,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: tokens.textPrimary),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Compact inline editorial link/action button (e.g., "Resume draft", "All files").
class ScaneliqTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const ScaneliqTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final resolvedColor = color ?? tokens.accent;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: resolvedColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: resolvedColor),
      ),
      child: Text(label),
    );
  }
}

/// 40x40dp circular accessible header/action icon hit target.
class ScaneliqIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;
  final bool hasBorder;
  final double size;

  const ScaneliqIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.hasBorder = false,
    this.size = ScaneliqSpacing.minTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final btn = Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        shape: CircleBorder(
          side: hasBorder
              ? BorderSide(color: tokens.hairline, width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 19, color: color ?? tokens.textPrimary),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// Destructive button strictly reserved for Trash / Reset / Irreversible actions.
class ScaneliqDestructiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  const ScaneliqDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: tokens.dangerSoft,
        foregroundColor: tokens.danger,
        minimumSize: Size(expand ? double.infinity : 0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(
          borderRadius: ScaneliqRadius.pillBorderRadius,
        ),
      ),
      icon: icon != null
          ? Icon(icon, size: 18, color: tokens.danger)
          : const SizedBox.shrink(),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: tokens.danger),
      ),
    );
  }
}
