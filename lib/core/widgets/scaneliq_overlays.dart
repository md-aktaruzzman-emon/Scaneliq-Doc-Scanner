import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';

/// Opens a Concept A editorial bottom sheet with a 36x4dp grab handle
/// and restrained hairline framing.
Future<T?> showScaneliqBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final tokens = context.tokens;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: tokens.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: ScaneliqRadius.modalSheetBorderRadius,
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      return SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: tokens.bg,
            borderRadius: ScaneliqRadius.modalSheetBorderRadius,
            border: Border(top: BorderSide(color: tokens.hairline, width: 1)),
          ),
          padding: EdgeInsets.fromLTRB(
            ScaneliqSpacing.xl,
            10,
            ScaneliqSpacing.xl,
            ScaneliqSpacing.lg + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: tokens.hairline,
                    borderRadius: ScaneliqRadius.pillBorderRadius,
                  ),
                ),
              ),
              Material(type: MaterialType.transparency, child: builder(ctx)),
            ],
          ),
        ),
      );
    },
  );
}

/// Reusable hairline action row for editorial bottom sheets & context menus.
class ScaneliqContextMenuRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Color? titleColor;
  final VoidCallback onTap;

  const ScaneliqContextMenuRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.hairline, width: 1)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: titleColor ?? tokens.textPrimary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontSize: 14.5,
                      color: titleColor ?? tokens.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Editorial confirmation dialog styled with Concept A hairline borders.
Future<bool> showScaneliqConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final tokens = context.tokens;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: isDestructive ? tokens.danger : tokens.accent,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Non-blocking Concept A floating feedback pill message.
void showScaneliqToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(
              label: actionLabel,
              textColor: context.tokens.accent,
              onPressed: onAction,
            )
          : null,
    ),
  );
}
