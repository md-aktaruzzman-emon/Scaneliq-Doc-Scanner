import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';

/// Editorial subtle-surface search field with optional OCR badge and clear button.
class ScaneliqSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onTap;
  final bool readOnly;
  final String hintText;
  final bool showOcrBadge;
  final String query;

  const ScaneliqSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onClear,
    this.onTap,
    this.readOnly = false,
    this.hintText = 'Search titles or recognized text…',
    this.showOcrBadge = true,
    this.query = '',
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasText = query.isNotEmpty || (controller?.text.isNotEmpty ?? false);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: ScaneliqRadius.inputBorderRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: tokens.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: onChanged,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tokens.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: tokens.textSecondary),
              ),
            ),
          ),
          if (hasText && onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: tokens.textSecondary,
                ),
              ),
            )
          else if (showOcrBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: ScaneliqRadius.tagBorderRadius,
                border: Border.all(color: tokens.hairline, width: 1),
              ),
              child: Text(
                'OCR',
                style: ScaneliqTypography.monoStyle(
                  color: tokens.textTertiary,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
