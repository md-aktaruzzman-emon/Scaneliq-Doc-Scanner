import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';
import 'package:scaneliq/features/pdf/data/pdf_service.dart';

/// Service to merge multiple scanned documents into a new consolidated PDF document
class BatchMergeService {
  static BatchMergeService? _instance;
  static BatchMergeService get instance => _instance ??= BatchMergeService._();
  BatchMergeService._();

  /// Merges a list of ScannedDocuments in the provided order into a new document and PDF
  Future<ScannedDocument> mergeDocuments({
    required List<ScannedDocument> sourceDocuments,
    required String outputTitle,
    String? folderId,
  }) async {
    if (sourceDocuments.length < 2) {
      throw ArgumentError('At least 2 documents are required to merge.');
    }

    final sanitizedTitle = outputTitle.trim().isEmpty
        ? 'Merged_Document'
        : outputTitle.trim();
    final newDocId = const Uuid().v4();
    final now = DateTime.now();

    // 1. Collect all pages from source documents in exact user order
    final List<DocumentPage> combinedPages = [];
    int orderIndex = 0;

    for (final doc in sourceDocuments) {
      // If doc has no loaded pages, load full document from database
      List<DocumentPage> docPages = doc.pages;
      if (docPages.isEmpty) {
        final fullDoc = await AppDatabaseService.instance.getDocument(doc.id);
        if (fullDoc != null) {
          docPages = fullDoc.pages;
        }
      }

      for (final p in docPages) {
        final newPageId = const Uuid().v4();
        combinedPages.add(
          DocumentPage(
            id: newPageId,
            documentId: newDocId,
            pageOrder: orderIndex++,
            originalPath: p.originalPath,
            processedPath: p.processedPath,
            editRecipe: p.editRecipe,
            width: p.width,
            height: p.height,
          ),
        );
      }
    }

    if (combinedPages.isEmpty) {
      throw StateError('Cannot merge: selected documents contain 0 pages.');
    }

    // 2. Instantiate new document
    final newDoc = ScannedDocument(
      id: newDocId,
      title: sanitizedTitle,
      createdAt: now,
      modifiedAt: now,
      pageCount: combinedPages.length,
      folderId: folderId,
    );

    // 3. Generate multi-page PDF via unified PdfService engine
    final File pdfFile = await PdfService.generatePdf(
      document: newDoc,
      pages: combinedPages,
      customTitle: sanitizedTitle,
    );

    // 4. Save new merged document and pages to database
    final finalizedDoc = newDoc.copyWith(exportPath: pdfFile.path);
    await AppDatabaseService.instance.saveDocumentWithPages(
      finalizedDoc,
      combinedPages,
    );

    // Source documents remain 100% untouched and preserved
    return finalizedDoc;
  }
}
