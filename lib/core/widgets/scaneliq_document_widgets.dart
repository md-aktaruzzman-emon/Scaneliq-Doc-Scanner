import 'dart:io';

import 'package:flutter/material.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/theme/scaneliq_radius.dart';
import 'package:scaneliq/core/theme/scaneliq_spacing.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'scaneliq_buttons.dart';
import 'scaneliq_content_widgets.dart';

/// Physical 50x66dp A4 paper miniature thumbnail for the editorial stream.
///
/// Always renders genuine crisp paper stock (#FFFFFF) with subtle drop shadow
/// even in Carbon Studio dark mode, showing a real scanned image preview when
/// available on disk or a restrained stylized miniature sheet fallback.
class ScaneliqDocumentThumbnail extends StatelessWidget {
  final ScannedDocument document;
  final double width;
  final double height;

  const ScaneliqDocumentThumbnail({
    super.key,
    required this.document,
    this.width = 50.0,
    this.height = 66.0,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    String? thumbPath;
    if (document.pages.isNotEmpty) {
      final candidate =
          document.pages.first.processedPath ??
          document.pages.first.originalPath;
      if (File(candidate).existsSync()) {
        thumbPath = candidate;
      }
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ScaneliqRadius.sheetBorderRadius,
        border: Border.all(color: tokens.paperBorder, width: 1),
        boxShadow: tokens.paperShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: thumbPath != null
          ? Image.file(
              File(thumbPath),
              fit: BoxFit.cover,
              cacheWidth: 240,
              errorBuilder: (_, _, _) => _MiniaturePaperFallback(document: document),
            )
          : _MiniaturePaperFallback(document: document),
    );
  }
}

class _MiniaturePaperFallback extends StatelessWidget {
  final ScannedDocument document;

  const _MiniaturePaperFallback({required this.document});

  @override
  Widget build(BuildContext context) {
    final hasPdf = document.exportPath != null;

    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  fontSize: 4.8,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF141413),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                height: 2,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 2),
              FractionallySizedBox(
                widthFactor: 0.82,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFF94A3B8),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FractionallySizedBox(
                widthFactor: 0.65,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasPdf
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0052FF),
                    width: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

/// Monospaced metadata line: `[PDF · 4P]` + page summary + formatted date.
class ScaneliqDocumentMetadata extends StatelessWidget {
  final ScannedDocument document;

  const ScaneliqDocumentMetadata({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tagLabel = document.exportPath != null
        ? 'PDF · ${document.pageCount}P'
        : 'SCAN · ${document.pageCount}P';
    final pageText =
        '${document.pageCount} ${document.pageCount == 1 ? 'Page' : 'Pages'}';
    final dateText = _formatEditorialDate(document.modifiedAt);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        ScaneliqStatusLabel(text: tagLabel),
        Text(
          pageText,
          style: TextStyle(
            fontSize: 12,
            color: tokens.textSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          dateText,
          style: TextStyle(
            fontSize: 12,
            color: tokens.textSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  static String _formatEditorialDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');

    if (target == today) {
      return 'Today, $hh:$mm';
    }
    if (target == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

/// Selection circle for batch multi-selection mode.
class ScaneliqSelectionIndicator extends StatelessWidget {
  final bool isSelected;

  const ScaneliqSelectionIndicator({super.key, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? tokens.accent : Colors.transparent,
        border: Border.all(
          color: isSelected ? tokens.accent : tokens.textTertiary,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

/// Editorial document list row separated by a 1px hairline border.
class ScaneliqDocumentRow extends StatelessWidget {
  final ScannedDocument document;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool isSelected;

  const ScaneliqDocumentRow({
    super.key,
    required this.document,
    required this.onTap,
    this.onMoreTap,
    this.onLongPress,
    this.selectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: ScaneliqSpacing.listRowVertical,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.hairline, width: 1)),
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              ScaneliqSelectionIndicator(isSelected: isSelected),
              const SizedBox(width: 12),
            ],
            ScaneliqDocumentThumbnail(document: document),
            const SizedBox(width: ScaneliqSpacing.listRowGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          document.title,
                          style: textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (document.isFavorite) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: tokens.warning,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  ScaneliqDocumentMetadata(document: document),
                ],
              ),
            ),
            if (onMoreTap != null) ...[
              const SizedBox(width: 6),
              ScaneliqIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: 'Document actions',
                color: tokens.textTertiary,
                size: 36,
                onPressed: onMoreTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Featured "Continue working" card showcasing the latest unfinished scan draft
/// with Concept A's physical rotated 2-sheet paper stack.
class ScaneliqFeaturedFolioCard extends StatelessWidget {
  final ScannedDocument draft;
  final VoidCallback onResume;
  final VoidCallback onAddPages;
  final VoidCallback onSavePdf;

  const ScaneliqFeaturedFolioCard({
    super.key,
    required this.draft,
    required this.onResume,
    required this.onAddPages,
    required this.onSavePdf,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final pageCount = draft.pages.isNotEmpty
        ? draft.pages.length
        : draft.pageCount;

    return Material(
      color: tokens.surface,
      borderRadius: ScaneliqRadius.folioBorderRadius,
      child: InkWell(
        onTap: onResume,
        borderRadius: ScaneliqRadius.folioBorderRadius,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: ScaneliqRadius.folioBorderRadius,
            border: Border.all(color: tokens.hairline, width: 1),
          ),
          child: Row(
            children: [
              // Rotated 2-sheet physical paper stack
              SizedBox(
                width: 68,
                height: 88,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Transform.translate(
                        offset: const Offset(3, 1),
                        child: Transform.rotate(
                          angle: 0.07,
                          child: Container(
                            decoration: BoxDecoration(
                              color: tokens.paperBack,
                              borderRadius: ScaneliqRadius.paperBorderRadius,
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ScaneliqDocumentThumbnail(
                        document: draft,
                        width: 68,
                        height: 88,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.accentSoft,
                        borderRadius: ScaneliqRadius.tagBorderRadius,
                      ),
                      child: Text(
                        'UNFINISHED · $pageCount ${pageCount == 1 ? 'PAGE' : 'PAGES'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ScaneliqTypography.monoStyle(
                          color: tokens.accent,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      draft.title,
                      style: textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Edited ${ScaneliqDocumentMetadata._formatEditorialDate(draft.modifiedAt)} · Local Draft',
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        GestureDetector(
                          onTap: onAddPages,
                          child: Text(
                            'Add pages',
                            style: textTheme.labelMedium?.copyWith(
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: onSavePdf,
                          child: Text(
                            'Review & Save',
                            style: textTheme.labelMedium?.copyWith(
                              color: tokens.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
