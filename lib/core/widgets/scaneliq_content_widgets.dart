import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'scaneliq_buttons.dart';

/// Semantic tone variants for monospaced status & metadata pills.
enum ScaneliqStatusTone { neutral, accent, success, warning, danger }

/// Restrained section title with optional inline action or status label.
class ScaneliqSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  const ScaneliqSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            title,
            style: textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null)
          trailing!
        else if (actionLabel != null && onAction != null)
          ScaneliqTextButton(label: actionLabel!, onPressed: onAction),
      ],
    );
  }
}

/// Data model for a single editorial scope tab (e.g., Recent 42, Starred 7).
class ScaneliqScopeItem {
  final String label;
  final int? count;

  const ScaneliqScopeItem({required this.label, this.count});
}

/// Underline scope tabs anchored on top of a 1px hairline border.
class ScaneliqScopeTabs extends StatelessWidget {
  final List<ScaneliqScopeItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? trailing;

  const ScaneliqScopeTabs({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.hairline, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    _ScopeTabButton(
                      item: items[i],
                      isSelected: i == selectedIndex,
                      tokens: tokens,
                      textTheme: textTheme,
                      onTap: () => onSelected(i),
                    ),
                  ],
                ],
              ),
            ),
          ),
            ?trailing,
          ],
      ),
    );
  }
}

class _ScopeTabButton extends StatelessWidget {
  final ScaneliqScopeItem item;
  final bool isSelected;
  final ScaneliqTokens tokens;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _ScopeTabButton({
    required this.item,
    required this.isSelected,
    required this.tokens,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? tokens.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: textTheme.labelLarge?.copyWith(
                color: isSelected ? tokens.textPrimary : tokens.textTertiary,
              ),
            ),
            if (item.count != null) ...[
              const SizedBox(width: 4),
              Text(
                '${item.count}',
                style: ScaneliqTypography.monoStyle(
                  color: tokens.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Architectural 1px horizontal divider using Concept A warm hairline.
class ScaneliqHairlineDivider extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const ScaneliqHairlineDivider({super.key, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: 1,
      color: context.tokens.hairline,
    );
  }
}

/// Monospaced metadata pill label (e.g. `PDF · 12P`, `OCR · BN`, `BETA`).
class ScaneliqStatusLabel extends StatelessWidget {
  final String text;
  final ScaneliqStatusTone tone;

  const ScaneliqStatusLabel({
    super.key,
    required this.text,
    this.tone = ScaneliqStatusTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (bg, fg) = switch (tone) {
      ScaneliqStatusTone.neutral => (tokens.surfaceSubtle, tokens.textSecondary),
      ScaneliqStatusTone.accent => (tokens.accentSoft, tokens.accent),
      ScaneliqStatusTone.success => (tokens.successSoft, tokens.success),
      ScaneliqStatusTone.warning => (tokens.warningSoft, tokens.warning),
      ScaneliqStatusTone.danger => (tokens.dangerSoft, tokens.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: ScaneliqRadius.tagBorderRadius,
      ),
      child: Text(
        text,
        style: ScaneliqTypography.monoStyle(color: fg, fontSize: 10),
      ),
    );
  }
}

/// Editorial empty state with calm icon frame and optional primary CTA.
class ScaneliqEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const ScaneliqEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: ScaneliqSpacing.xl,
          vertical: ScaneliqSpacing.base,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.hairline),
              ),
              child: Icon(icon, size: 28, color: tokens.accent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                description,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            if (primaryActionLabel != null && onPrimaryAction != null) ...[
              const SizedBox(height: 20),
              ScaneliqPrimaryButton(
                label: primaryActionLabel!,
                onPressed: onPrimaryAction,
                icon: Icons.camera_alt_outlined,
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 8),
              ScaneliqTextButton(
                label: secondaryActionLabel!,
                onPressed: onSecondaryAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centered editorial loading indicator using Ultramarine accent.
class ScaneliqLoadingIndicator extends StatelessWidget {
  final String? message;

  const ScaneliqLoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
