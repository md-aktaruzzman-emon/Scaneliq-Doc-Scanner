import 'dart:convert';

/// Document representation following blueprint schema
class ScannedDocument {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int pageCount;
  final bool isFavorite;
  final String? exportPath;
  final List<DocumentPage> pages;

  const ScannedDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.modifiedAt,
    this.pageCount = 0,
    this.isFavorite = false,
    this.exportPath,
    this.pages = const [],
  });

  ScannedDocument copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? pageCount,
    bool? isFavorite,
    String? exportPath,
    List<DocumentPage>? pages,
  }) {
    return ScannedDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      pageCount: pageCount ?? this.pageCount,
      isFavorite: isFavorite ?? this.isFavorite,
      exportPath: exportPath ?? this.exportPath,
      pages: pages ?? this.pages,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
      'page_count': pageCount,
      'is_favorite': isFavorite ? 1 : 0,
      'export_path': exportPath,
    };
  }

  factory ScannedDocument.fromMap(Map<String, dynamic> map, {List<DocumentPage> pages = const []}) {
    return ScannedDocument(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(map['modified_at'] as int),
      pageCount: map['page_count'] as int? ?? 0,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      exportPath: map['export_path'] as String?,
      pages: pages,
    );
  }
}

/// Page representation with non-destructive edit recipe
class DocumentPage {
  final String id;
  final String documentId;
  final int pageOrder;
  final String originalPath;
  final String? processedPath;
  final EditRecipe editRecipe;
  final int? width;
  final int? height;

  const DocumentPage({
    required this.id,
    required this.documentId,
    required this.pageOrder,
    required this.originalPath,
    this.processedPath,
    this.editRecipe = const EditRecipe(),
    this.width,
    this.height,
  });

  DocumentPage copyWith({
    String? id,
    String? documentId,
    int? pageOrder,
    String? originalPath,
    String? processedPath,
    EditRecipe? editRecipe,
    int? width,
    int? height,
  }) {
    return DocumentPage(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageOrder: pageOrder ?? this.pageOrder,
      originalPath: originalPath ?? this.originalPath,
      processedPath: processedPath ?? this.processedPath,
      editRecipe: editRecipe ?? this.editRecipe,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'page_order': pageOrder,
      'original_path': originalPath,
      'processed_path': processedPath,
      'edit_recipe_json': jsonEncode(editRecipe.toMap()),
      'width': width,
      'height': height,
    };
  }

  factory DocumentPage.fromMap(Map<String, dynamic> map) {
    EditRecipe recipe = const EditRecipe();
    if (map['edit_recipe_json'] != null) {
      try {
        final decoded = jsonDecode(map['edit_recipe_json'] as String) as Map<String, dynamic>;
        recipe = EditRecipe.fromMap(decoded);
      } catch (_) {}
    }

    return DocumentPage(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      pageOrder: map['page_order'] as int,
      originalPath: map['original_path'] as String,
      processedPath: map['processed_path'] as String?,
      editRecipe: recipe,
      width: map['width'] as int?,
      height: map['height'] as int?,
    );
  }
}

enum PageFilter { original, grayscale, blackAndWhite }

/// Non-destructive edit recipe
class EditRecipe {
  final int rotationDegrees;
  final PageFilter filter;
  final double brightness;
  final double contrast;

  const EditRecipe({
    this.rotationDegrees = 0,
    this.filter = PageFilter.original,
    this.brightness = 0.0,
    this.contrast = 1.0,
  });

  EditRecipe copyWith({
    int? rotationDegrees,
    PageFilter? filter,
    double? brightness,
    double? contrast,
  }) {
    return EditRecipe(
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      filter: filter ?? this.filter,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rotationDegrees': rotationDegrees,
      'filter': filter.name,
      'brightness': brightness,
      'contrast': contrast,
    };
  }

  factory EditRecipe.fromMap(Map<String, dynamic> map) {
    return EditRecipe(
      rotationDegrees: map['rotationDegrees'] as int? ?? 0,
      filter: PageFilter.values.firstWhere(
        (e) => e.name == map['filter'],
        orElse: () => PageFilter.original,
      ),
      brightness: (map['brightness'] as num?)?.toDouble() ?? 0.0,
      contrast: (map['contrast'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
