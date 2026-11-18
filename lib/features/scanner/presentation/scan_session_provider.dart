import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import 'package:scaneliq/core/image_processing/image_processing_service.dart';
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
  final Map<String, DateTime> captureTimestamps;

  const ScanSessionState({
    required this.documentId,
    required this.title,
    this.pages = const [],
    this.isProcessing = false,
    this.errorMessage,
    this.captureTimestamps = const {},
  });

  ScanSessionState copyWith({
    String? documentId,
    String? title,
    List<DocumentPage>? pages,
    bool? isProcessing,
    String? errorMessage,
    Map<String, DateTime>? captureTimestamps,
  }) {
    return ScanSessionState(
      documentId: documentId ?? this.documentId,
      title: title ?? this.title,
      pages: pages ?? this.pages,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
      captureTimestamps: captureTimestamps ?? this.captureTimestamps,
    );
  }
}

class ScanSessionNotifier extends Notifier<ScanSessionState> {
  @override
  ScanSessionState build() {
    final now = DateTime.now();
    return ScanSessionState(
      documentId: const Uuid().v4(),
      title:
          'Scan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}',
    );
  }

  /// Initializes a new draft session
  void resetSession([String? newTitle]) {
    final now = DateTime.now();
    final defaultTitle =
        newTitle ??
        'Scan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    state = ScanSessionState(
      documentId: const Uuid().v4(),
      title: defaultTitle,
      pages: [],
    );
  }

  /// Restores a draft session into memory
  void loadDraftSession(ScannedDocument draft) {
    state = ScanSessionState(
      documentId: draft.id,
      title: draft.title,
      pages: draft.pages,
    );
  }

  /// Retakes/replaces a specific page image via document scanner
  Future<bool> retakePage(String pageId) async {
    try {
      final scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: {DocumentFormat.jpeg},
          mode: ScannerMode.full,
          pageLimit: 1,
          isGalleryImport: true,
        ),
      );

      final result = await scanner.scanDocument();
      final images = result.images;
      if (images == null || images.isEmpty) return false;

      final sourceFile = File(images.first);
      return await retakePageWithFile(pageId, sourceFile);
    } catch (_) {
      return false;
    }
  }

  /// Retakes/replaces a specific page with an existing or newly captured image file
  Future<bool> retakePageWithFile(
    String pageId,
    File newImageFile, {
    EditRecipe? recipe,
  }) async {
    try {
      if (!await newImageFile.exists()) return false;

      final existingIndex = state.pages.indexWhere((p) => p.id == pageId);
      final oldProcessedPath = existingIndex != -1
          ? state.pages[existingIndex].processedPath
          : null;

      final ext = _safeImageExtension(newImageFile.path);
      final dims = await _extractImageDimensions(newImageFile);
      final savedOriginal = await AppStorageService.instance.copyToOriginals(
        pageId,
        newImageFile,
        extension: ext,
      );

      // Clean up stale processed preview cache if one existed.
      if (oldProcessedPath != null) {
        final procFile = File(oldProcessedPath);
        if (await procFile.exists()) {
          try {
            PaintingBinding.instance.imageCache.evict(FileImage(procFile));
            await procFile.delete();
          } catch (_) {}
        }
      }

      final updated = state.pages.map((p) {
        if (p.id == pageId) {
          return DocumentPage(
            id: p.id,
            documentId: p.documentId,
            pageOrder: p.pageOrder,
            originalPath: savedOriginal.path,
            processedPath: null,
            editRecipe: recipe ?? const EditRecipe(),
            width: dims?.$1 ?? p.width,
            height: dims?.$2 ?? p.height,
          );
        }
        return p;
      }).toList();

      final updatedTimestamps = Map<String, DateTime>.from(
        state.captureTimestamps,
      )..[pageId] = DateTime.now();

      state = state.copyWith(
        pages: updated,
        captureTimestamps: updatedTimestamps,
      );
      await _persistDraft();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Directly adds a single captured page with optional custom preset recipe
  Future<bool> addCapturedPage(File file, {EditRecipe? recipe}) async {
    try {
      if (!await file.exists()) return false;
      final ext = _safeImageExtension(file.path);
      final dims = await _extractImageDimensions(file);
      final pageId = const Uuid().v4();
      final savedOriginal = await AppStorageService.instance.copyToOriginals(
        pageId,
        file,
        extension: ext,
      );
      final newPage = DocumentPage(
        id: pageId,
        documentId: state.documentId,
        pageOrder: state.pages.length,
        originalPath: savedOriginal.path,
        editRecipe: recipe ?? const EditRecipe(),
        width: dims?.$1,
        height: dims?.$2,
      );
      final updatedTimestamps = Map<String, DateTime>.from(
        state.captureTimestamps,
      )..[pageId] = DateTime.now();

      state = state.copyWith(
        pages: [...state.pages, newPage],
        captureTimestamps: updatedTimestamps,
      );
      await _persistDraft();
      return true;
    } catch (_) {
      return false;
    }
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
          final savedOriginal = await AppStorageService.instance
              .copyToOriginals(pageId, sourceFile);

          final newPage = DocumentPage(
            id: pageId,
            documentId: state.documentId,
            pageOrder: updatedPages.length,
            originalPath: savedOriginal.path,
          );
          updatedPages.add(newPage);
        }
      }

      state = state.copyWith(pages: updatedPages, isProcessing: false);

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

  /// Adds a single page from file
  Future<void> addImportedPage(File file) async {
    await importFiles([file]);
  }

  /// Adds multiple pages from imported files with format/existence validation
  Future<int> importFiles(
    List<File> files, {
    EditRecipe? defaultRecipe,
    bool validateImageHeaders = false,
  }) async {
    final validImages = <DocumentPage>[];
    final updatedTimestamps = Map<String, DateTime>.from(
      state.captureTimestamps,
    );

    for (final file in files) {
      if (!await file.exists()) continue;
      final length = await file.length();
      if (length <= 0) continue;
      final ext = file.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) continue;

      if (validateImageHeaders) {
        try {
          final raf = await file.open();
          final header = await raf.read(32);
          await raf.close();
          if (!AppStorageService.isValidImageBytes(header)) continue;
        } catch (_) {
          continue;
        }
      }

      final pageId = const Uuid().v4();
      final dims = await _extractImageDimensions(file);
      final savedOriginal = await AppStorageService.instance.copyToOriginals(
        pageId,
        file,
        extension: ext == 'jpeg' ? 'jpg' : ext,
      );
      validImages.add(
        DocumentPage(
          id: pageId,
          documentId: state.documentId,
          pageOrder: state.pages.length + validImages.length,
          originalPath: savedOriginal.path,
          editRecipe: defaultRecipe ?? const EditRecipe(),
          width: dims?.$1,
          height: dims?.$2,
        ),
      );
      updatedTimestamps[pageId] = DateTime.now();
    }

    if (validImages.isNotEmpty) {
      state = state.copyWith(
        pages: [...state.pages, ...validImages],
        captureTimestamps: updatedTimestamps,
      );
      await _persistDraft();
    }

    return validImages.length;
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
      for (int i = 0; i < items.length; i++) items[i].copyWith(pageOrder: i),
    ];

    state = state.copyWith(pages: reindexed);
    await _persistDraft();
  }

  /// Updates a page's edit recipe (rotation, filter) and pre-renders processed cache
  Future<void> updatePageRecipe(String pageId, EditRecipe recipe) async {
    String? newProcessedPath;
    final targetPath =
        '${AppStorageService.instance.processedDir.path}/${pageId}_proc.jpg';

    if (!recipe.isDefault) {
      final pageIndex = state.pages.indexWhere((p) => p.id == pageId);
      if (pageIndex != -1) {
        final page = state.pages[pageIndex];
        final origFile = File(page.originalPath);
        if (await origFile.exists()) {
          try {
            final tempPath = '$targetPath.tmp';
            final processedBytes =
                await ImageProcessingService.processImageFileToBytesInIsolate(
                  origFile,
                  recipe,
                  quality: 92,
                );
            final tempFile = File(tempPath);
            await tempFile.writeAsBytes(processedBytes, flush: true);
            final finalFile = await tempFile.rename(targetPath);
            newProcessedPath = finalFile.path;
            // Evict file from Flutter image cache so thumbnails update immediately
            PaintingBinding.instance.imageCache.evict(FileImage(finalFile));
          } catch (_) {
            // Clean up any partial temp file on write failure without altering original
            final leftover = File('$targetPath.tmp');
            if (await leftover.exists()) {
              try {
                await leftover.delete();
              } catch (_) {}
            }
          }
        }
      }
    } else {
      // Recipe was reset to default, clean up processed cache if it exists
      final file = File(targetPath);
      if (await file.exists()) {
        try {
          PaintingBinding.instance.imageCache.evict(FileImage(file));
          await file.delete();
        } catch (_) {}
      }
      newProcessedPath = null;
    }

    final updated = state.pages.map((p) {
      if (p.id == pageId) {
        return DocumentPage(
          id: p.id,
          documentId: p.documentId,
          pageOrder: p.pageOrder,
          originalPath: p.originalPath,
          processedPath: newProcessedPath,
          editRecipe: recipe,
          width: p.width,
          height: p.height,
        );
      }
      return p;
    }).toList();

    state = state.copyWith(pages: updated);
    await _persistDraft();
  }

  /// Duplicates an existing page cleanly without mutating the source original
  Future<bool> duplicatePage(String pageId) async {
    final index = state.pages.indexWhere((p) => p.id == pageId);
    if (index == -1) return false;
    final src = state.pages[index];
    final origFile = File(src.originalPath);
    if (!await origFile.exists()) return false;

    final newId = const Uuid().v4();
    final ext = _safeImageExtension(src.originalPath);
    final copiedOriginal = await AppStorageService.instance.copyToOriginals(
      newId,
      origFile,
      extension: ext,
    );
    final duplicated = DocumentPage(
      id: newId,
      documentId: src.documentId,
      pageOrder: index + 1,
      originalPath: copiedOriginal.path,
      editRecipe: src.editRecipe,
      width: src.width,
      height: src.height,
    );

    final list = List<DocumentPage>.from(state.pages);
    list.insert(index + 1, duplicated);
    final reindexed = [
      for (int i = 0; i < list.length; i++) list[i].copyWith(pageOrder: i),
    ];
    state = state.copyWith(pages: reindexed);
    if (!duplicated.editRecipe.isDefault) {
      await updatePageRecipe(duplicated.id, duplicated.editRecipe);
    } else {
      await _persistDraft();
    }
    return true;
  }

  /// Applies a filter preset to a chosen subset of pages in the session
  Future<void> applyFilterToPages(Set<String> pageIds, PageFilter filter) async {
    for (final page in state.pages) {
      if (!pageIds.contains(page.id)) continue;
      final newRecipe = page.editRecipe.copyWith(
        filter: filter,
        binarization: filter == PageFilter.original
            ? BinarizationMode.none
            : page.editRecipe.binarization,
      );
      await updatePageRecipe(page.id, newRecipe);
    }
  }

  /// Atomically saves multiple edited/reordered pages and persists draft once cleanly.
  Future<void> syncEditedPages(List<DocumentPage> editedPages) async {
    final List<DocumentPage> resolved = [];
    for (int i = 0; i < editedPages.length; i++) {
      final page = editedPages[i];
      final targetPath =
          '${AppStorageService.instance.processedDir.path}/${page.id}_proc.jpg';
      String? newProcessedPath;

      if (!page.editRecipe.isDefault) {
        final origFile = File(page.originalPath);
        if (await origFile.exists()) {
          try {
            final tempPath = '$targetPath.tmp';
            final processedBytes =
                await ImageProcessingService.processImageFileToBytesInIsolate(
                  origFile,
                  page.editRecipe,
                  quality: 92,
                );
            final tempFile = File(tempPath);
            await tempFile.writeAsBytes(processedBytes, flush: true);
            final finalFile = await tempFile.rename(targetPath);
            newProcessedPath = finalFile.path;
            PaintingBinding.instance.imageCache.evict(FileImage(finalFile));
          } catch (_) {
            newProcessedPath = page.processedPath;
          }
        }
      } else {
        final existing = File(targetPath);
        if (await existing.exists()) {
          try {
            PaintingBinding.instance.imageCache.evict(FileImage(existing));
            await existing.delete();
          } catch (_) {}
        }
        newProcessedPath = null;
      }

      resolved.add(
        DocumentPage(
          id: page.id,
          documentId: page.documentId,
          pageOrder: i,
          originalPath: page.originalPath,
          processedPath: newProcessedPath,
          editRecipe: page.editRecipe,
          width: page.width,
          height: page.height,
        ),
      );
    }

    state = state.copyWith(pages: resolved);
    await _persistDraft();
  }

  /// Applies a filter preset across all pages in the current session
  Future<void> applyFilterToAllPages(PageFilter filter) async {
    for (final page in state.pages) {
      final newRecipe = page.editRecipe.copyWith(
        filter: filter,
        binarization: filter == PageFilter.original
            ? BinarizationMode.none
            : page.editRecipe.binarization,
      );
      await updatePageRecipe(page.id, newRecipe);
    }
  }

  /// Removes a page from the active session
  Future<void> removePage(String pageId) async {
    // Evict and clean up processed cache file for this page if it exists
    final targetPath =
        '${AppStorageService.instance.processedDir.path}/${pageId}_proc.jpg';
    final procFile = File(targetPath);
    if (await procFile.exists()) {
      try {
        PaintingBinding.instance.imageCache.evict(FileImage(procFile));
        await procFile.delete();
      } catch (_) {}
    }

    final pageIndex = state.pages.indexWhere((p) => p.id == pageId);
    if (pageIndex != -1) {
      final page = state.pages[pageIndex];
      if (page.processedPath != null && page.processedPath != targetPath) {
        final customProc = File(page.processedPath!);
        if (await customProc.exists()) {
          try {
            PaintingBinding.instance.imageCache.evict(FileImage(customProc));
            await customProc.delete();
          } catch (_) {}
        }
      }
    }

    final remaining = state.pages.where((p) => p.id != pageId).toList();
    final reindexed = [
      for (int i = 0; i < remaining.length; i++)
        remaining[i].copyWith(pageOrder: i),
    ];
    final updatedTimestamps = Map<String, DateTime>.from(
      state.captureTimestamps,
    )..remove(pageId);
    state = state.copyWith(
      pages: reindexed,
      captureTimestamps: updatedTimestamps,
    );
    await _persistDraft();
  }

  /// Replaces all session pages with a single stitched page (e.g., 2-in-1 ID card)
  Future<void> replaceWithSinglePage(File imageFile) async {
    final pageId = const Uuid().v4();
    final dims = await _extractImageDimensions(imageFile);
    final savedOriginal = await AppStorageService.instance.copyToOriginals(
      pageId,
      imageFile,
    );
    final newPage = DocumentPage(
      id: pageId,
      documentId: state.documentId,
      pageOrder: 0,
      originalPath: savedOriginal.path,
      width: dims?.$1,
      height: dims?.$2,
    );
    state = state.copyWith(
      pages: [newPage],
      captureTimestamps: {pageId: DateTime.now()},
    );
    await _persistDraft();
  }

  void updateTitle(String newTitle) {
    state = state.copyWith(title: newTitle);
  }

  static String _safeImageExtension(String filePath) {
    final lower = filePath.split('.').last.toLowerCase();
    if (lower == 'png' || lower == 'webp') return lower;
    return 'jpg';
  }

  static Future<(int, int)?> _extractImageDimensions(File file) async {
    try {
      final length = await file.length();
      // Skip full read solely for dimension lookup if file is huge (>25 MB).
      if (length <= 0 || length > 25 * 1024 * 1024) return null;
      final bytes = await file.readAsBytes();
      final info = img.findDecoderForData(bytes)?.startDecode(bytes);
      if (info != null && info.width > 0 && info.height > 0) {
        return (info.width, info.height);
      }
    } catch (_) {}
    return null;
  }

  Future<void>? _activePersist;

  Future<void> _persistDraft() async {
    while (_activePersist != null) {
      await _activePersist;
    }
    if (state.pages.isEmpty) return;

    final snapshotDoc = ScannedDocument(
      id: state.documentId,
      title: state.title,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      pageCount: state.pages.length,
      isDraft: true,
    );
    final snapshotPages = List<DocumentPage>.from(state.pages);

    final run = AppDatabaseService.instance.saveDocumentWithPages(
      snapshotDoc,
      snapshotPages,
    );
    _activePersist = run;
    try {
      await run;
    } catch (_) {
    } finally {
      if (identical(_activePersist, run)) {
        _activePersist = null;
      }
    }
  }
}

final scanSessionProvider =
    NotifierProvider<ScanSessionNotifier, ScanSessionState>(() {
      return ScanSessionNotifier();
    });

/// Provider for loading all saved documents from SQLite
final documentsListProvider = FutureProvider<List<ScannedDocument>>((
  ref,
) async {
  return await AppDatabaseService.instance.getAllDocuments();
});

/// Provider for loading saved documents supporting optional full-text search query
final searchedDocumentsProvider =
    FutureProvider.family<List<ScannedDocument>, String>((ref, query) async {
      return await AppDatabaseService.instance.getAllDocuments(
        searchQuery: query.trim().isEmpty ? null : query.trim(),
      );
    });

/// Provider to check for an active unfinished draft
final latestDraftProvider = FutureProvider<ScannedDocument?>((ref) async {
  return await AppDatabaseService.instance.getLatestDraft();
});

/// Provider for loading hierarchical folders
final foldersListProvider =
    FutureProvider.family<List<DocumentFolder>, String?>((ref, parentId) async {
      return await AppDatabaseService.instance.getFolders(parentId: parentId);
    });

/// Provider for loading all configured tags
final tagsListProvider = FutureProvider<List<DocumentTag>>((ref) async {
  return await AppDatabaseService.instance.getTags();
});

/// Provider for loading all trashed documents
final trashedDocumentsProvider = FutureProvider<List<ScannedDocument>>((
  ref,
) async {
  return await AppDatabaseService.instance.getAllDocuments(onlyTrashed: true);
});
