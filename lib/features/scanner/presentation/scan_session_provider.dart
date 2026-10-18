import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:uuid/uuid.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/core/storage/app_storage_service.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';

/// Active scan session state
class ScanSessionState {
  final String documentId;
  final String title;
  final List<DocumentPage> pages;
  final bool isProcessing;
  final String? errorMessage;

  const ScanSessionState({
    required this.documentId,
    required this.title,
    this.pages = const [],
    this.isProcessing = false,
    this.errorMessage,
  });

  ScanSessionState copyWith({
    String? documentId,
    String? title,
    List<DocumentPage>? pages,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return ScanSessionState(
      documentId: documentId ?? this.documentId,
      title: title ?? this.title,
      pages: pages ?? this.pages,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
    );
  }
}

class ScanSessionNotifier extends Notifier<ScanSessionState> {
  @override
  ScanSessionState build() {
    final now = DateTime.now();
    return ScanSessionState(
      documentId: const Uuid().v4(),
      title: 'Scan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}',
    );
  }

  /// Initializes a new draft session
  void resetSession([String? newTitle]) {
    final now = DateTime.now();
    final defaultTitle = newTitle ??
        'Scan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    state = ScanSessionState(
      documentId: const Uuid().v4(),
      title: defaultTitle,
      pages: [],
    );
  }

  /// Launches the document scanner hardware/service and captures pages
  Future<bool> startScannerCapture() async {
    try {
      state = state.copyWith(isProcessing: true, errorMessage: null);

      final scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: {DocumentFormat.jpeg},
          mode: ScannerMode.full,
          pageLimit: 50,
          isGalleryImport: true,
        ),
      );

      final result = await scanner.scanDocument();
      final images = result.images;

      if (images == null || images.isEmpty) {
        state = state.copyWith(isProcessing: false);
        return false;
      }

      final List<DocumentPage> updatedPages = List.from(state.pages);

      for (final imagePath in images) {
        final sourceFile = File(imagePath);
        if (await sourceFile.exists()) {
          final pageId = const Uuid().v4();
          final savedOriginal = await AppStorageService.instance.copyToOriginals(pageId, sourceFile);

          final newPage = DocumentPage(
            id: pageId,
            documentId: state.documentId,
            pageOrder: updatedPages.length,
            originalPath: savedOriginal.path,
          );
          updatedPages.add(newPage);
        }
      }

      state = state.copyWith(
        pages: updatedPages,
        isProcessing: false,
      );

      // Persist draft immediately
      await _persistDraft();
      return true;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Scanning was cancelled or encountered an error: $e',
      );
      return false;
    }
  }

  /// Adds a page directly from image bytes (e.g. file import)
  Future<void> addImportedPage(File file) async {
    final pageId = const Uuid().v4();
    final savedOriginal = await AppStorageService.instance.copyToOriginals(pageId, file);

    final newPage = DocumentPage(
      id: pageId,
      documentId: state.documentId,
      pageOrder: state.pages.length,
      originalPath: savedOriginal.path,
    );

    state = state.copyWith(
      pages: [...state.pages, newPage],
    );

    await _persistDraft();
  }

  /// Reorders pages in the active session
  Future<void> reorderPages(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final List<DocumentPage> items = List.from(state.pages);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Update order indices
    final reindexed = [
      for (int i = 0; i < items.length; i++) items[i].copyWith(pageOrder: i)
    ];

    state = state.copyWith(pages: reindexed);
    await _persistDraft();
  }

  /// Updates a page's edit recipe (rotation, filter)
  Future<void> updatePageRecipe(String pageId, EditRecipe recipe) async {
    final updated = state.pages.map((p) {
      if (p.id == pageId) {
        return p.copyWith(editRecipe: recipe);
      }
      return p;
    }).toList();

    state = state.copyWith(pages: updated);
    await _persistDraft();
  }

  /// Removes a page from the active session
  Future<void> removePage(String pageId) async {
    final remaining = state.pages.where((p) => p.id != pageId).toList();
    final reindexed = [
      for (int i = 0; i < remaining.length; i++) remaining[i].copyWith(pageOrder: i)
    ];
    state = state.copyWith(pages: reindexed);
    await _persistDraft();
  }

  void updateTitle(String newTitle) {
    state = state.copyWith(title: newTitle);
  }

  Future<void> _persistDraft() async {
    if (state.pages.isEmpty) return;
    final now = DateTime.now();
    final doc = ScannedDocument(
      id: state.documentId,
      title: state.title,
      createdAt: now,
      modifiedAt: now,
      pageCount: state.pages.length,
    );
    await AppDatabaseService.instance.saveDocumentWithPages(doc, state.pages);
  }
}

final scanSessionProvider = NotifierProvider<ScanSessionNotifier, ScanSessionState>(() {
  return ScanSessionNotifier();
});

/// Provider for loading all saved documents from SQLite
final documentsListProvider = FutureProvider<List<ScannedDocument>>((ref) async {
  return await AppDatabaseService.instance.getAllDocuments();
});
