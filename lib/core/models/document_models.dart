import 'dart:convert';

/// Folder model for organizing documents hierarchically
class DocumentFolder {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int documentCount;

  const DocumentFolder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    required this.modifiedAt,
    this.documentCount = 0,
  });

  DocumentFolder copyWith({
    String? id,
    String? name,
    String? parentId,
    bool clearParentId = false,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? documentCount,
  }) {
    return DocumentFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      documentCount: documentCount ?? this.documentCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
    };
  }

  factory DocumentFolder.fromMap(
    Map<String, dynamic> map, {
    int documentCount = 0,
  }) {
    return DocumentFolder(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        map['modified_at'] as int,
      ),
      documentCount: documentCount,
    );
  }
}

/// Category/tag model for multi-tagging documents
class DocumentTag {
  final String id;
  final String name;
  final int colorValue;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const DocumentTag({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    required this.modifiedAt,
  });

  DocumentTag copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return DocumentTag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': colorValue,
      'created_at': createdAt.millisecondsSinceEpoch,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
    };
  }

  factory DocumentTag.fromMap(Map<String, dynamic> map) {
    return DocumentTag(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: map['color'] as int? ?? 0xFF2563EB,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        map['modified_at'] as int,
      ),
    );
  }
}

/// Document representation following blueprint schema
class ScannedDocument {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int pageCount;
  final bool isFavorite;
  final bool isDraft;
  final String? exportPath;
  final String? folderId;
  final DateTime? deletedAt;
  final List<DocumentPage> pages;
  final List<DocumentTag> tags;

  const ScannedDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.modifiedAt,
    this.pageCount = 0,
    this.isFavorite = false,
    this.isDraft = false,
    this.exportPath,
    this.folderId,
    this.deletedAt,
    this.pages = const [],
    this.tags = const [],
  });

  bool get isTrashed => deletedAt != null;

  ScannedDocument copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? pageCount,
    bool? isFavorite,
    bool? isDraft,
    String? exportPath,
    String? folderId,
    bool clearFolderId = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    List<DocumentPage>? pages,
    List<DocumentTag>? tags,
  }) {
    return ScannedDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      pageCount: pageCount ?? this.pageCount,
      isFavorite: isFavorite ?? this.isFavorite,
      isDraft: isDraft ?? this.isDraft,
      exportPath: exportPath ?? this.exportPath,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      pages: pages ?? this.pages,
      tags: tags ?? this.tags,
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
      'is_draft': isDraft ? 1 : 0,
      'export_path': exportPath,
      'folder_id': folderId,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
    };
  }

  factory ScannedDocument.fromMap(
    Map<String, dynamic> map, {
    List<DocumentPage> pages = const [],
    List<DocumentTag> tags = const [],
  }) {
    return ScannedDocument(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        map['modified_at'] as int,
      ),
      pageCount: map['page_count'] as int? ?? 0,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      isDraft: (map['is_draft'] as int? ?? 0) == 1,
      exportPath: map['export_path'] as String?,
      folderId: map['folder_id'] as String?,
      deletedAt: map['deleted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int)
          : null,
      pages: pages,
      tags: tags,
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
        final decoded = jsonDecode(
          map['edit_recipe_json'] as String,
        ) as Map<String, dynamic>;
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

enum PageFilter {
  original,
  grayscale,
  blackAndWhite,
  whiteboard,
  enhancedText,
  colorBoost,
}

enum BinarizationMode { none, otsu, sauvola }

/// Normalized 4-point quadrilateral for perspective homography correction
class PerspectiveQuad {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;
  final double x4;
  final double y4;

  const PerspectiveQuad({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.x3,
    required this.y3,
    required this.x4,
    required this.y4,
  });

  /// Standard unit rectangle (0,0) -> (1,0) -> (1,1) -> (0,1)
  static const standard = PerspectiveQuad(
    x1: 0.0,
    y1: 0.0,
    x2: 1.0,
    y2: 0.0,
    x3: 1.0,
    y3: 1.0,
    x4: 0.0,
    y4: 1.0,
  );

  bool get isStandard =>
      x1 == 0.0 &&
      y1 == 0.0 &&
      x2 == 1.0 &&
      y2 == 0.0 &&
      x3 == 1.0 &&
      y3 == 1.0 &&
      x4 == 0.0 &&
      y4 == 1.0;

  /// Checks if coordinates are within [0, 1] and form a strictly convex quadrilateral
  bool isValidConvex() {
    if (x1 < 0.0 ||
        x1 > 1.0 ||
        y1 < 0.0 ||
        y1 > 1.0 ||
        x2 < 0.0 ||
        x2 > 1.0 ||
        y2 < 0.0 ||
        y2 > 1.0 ||
        x3 < 0.0 ||
        x3 > 1.0 ||
        y3 < 0.0 ||
        y3 > 1.0 ||
        x4 < 0.0 ||
        x4 > 1.0 ||
        y4 < 0.0 ||
        y4 > 1.0) {
      return false;
    }

    double cp(double ax, double ay, double bx, double by) => ax * by - ay * bx;
    final cp1 = cp(x2 - x1, y2 - y1, x3 - x2, y3 - y2);
    final cp2 = cp(x3 - x2, y3 - y2, x4 - x3, y4 - y3);
    final cp3 = cp(x4 - x3, y4 - y3, x1 - x4, y1 - y4);
    final cp4 = cp(x1 - x4, y1 - y4, x2 - x1, y2 - y1);

    const eps = 1e-6;
    final allPositive = cp1 > eps && cp2 > eps && cp3 > eps && cp4 > eps;
    final allNegative = cp1 < -eps && cp2 < -eps && cp3 < -eps && cp4 < -eps;
    return allPositive || allNegative;
  }

  Map<String, dynamic> toMap() => {
    'x1': x1,
    'y1': y1,
    'x2': x2,
    'y2': y2,
    'x3': x3,
    'y3': y3,
    'x4': x4,
    'y4': y4,
  };

  factory PerspectiveQuad.fromMap(Map<String, dynamic> map) => PerspectiveQuad(
    x1: (map['x1'] as num).toDouble(),
    y1: (map['y1'] as num).toDouble(),
    x2: (map['x2'] as num).toDouble(),
    y2: (map['y2'] as num).toDouble(),
    x3: (map['x3'] as num).toDouble(),
    y3: (map['y3'] as num).toDouble(),
    x4: (map['x4'] as num).toDouble(),
    y4: (map['y4'] as num).toDouble(),
  );

  PerspectiveQuad copyWith({
    double? x1,
    double? y1,
    double? x2,
    double? y2,
    double? x3,
    double? y3,
    double? x4,
    double? y4,
  }) {
    return PerspectiveQuad(
      x1: x1 ?? this.x1,
      y1: y1 ?? this.y1,
      x2: x2 ?? this.x2,
      y2: y2 ?? this.y2,
      x3: x3 ?? this.x3,
      y3: y3 ?? this.y3,
      x4: x4 ?? this.x4,
      y4: y4 ?? this.y4,
    );
  }
}

/// Non-destructive patch descriptor for manual hole-punch / finger cleanup
class CleanupPatch {
  final double x; // Normalized 0..1
  final double y; // Normalized 0..1
  final double radius; // Normalized radius
  final String type; // 'holePunch' | 'finger' | 'erase'

  const CleanupPatch({
    required this.x,
    required this.y,
    required this.radius,
    this.type = 'holePunch',
  });

  Map<String, dynamic> toMap() => {
    'x': x,
    'y': y,
    'radius': radius,
    'type': type,
  };

  factory CleanupPatch.fromMap(Map<String, dynamic> map) => CleanupPatch(
    x: (map['x'] as num).toDouble(),
    y: (map['y'] as num).toDouble(),
    radius: (map['radius'] as num).toDouble(),
    type: map['type'] as String? ?? 'holePunch',
  );
}

/// Non-destructive edit recipe
class EditRecipe {
  final int rotationDegrees;
  final PageFilter filter;
  final double brightness;
  final double contrast;
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;
  final PerspectiveQuad? perspectiveQuad;
  final BinarizationMode binarization;
  final bool shadowCorrection;
  final List<CleanupPatch> cleanupPatches;
  final int recipeVersion;

  const EditRecipe({
    this.rotationDegrees = 0,
    this.filter = PageFilter.original,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.cropLeft = 0.0,
    this.cropTop = 0.0,
    this.cropRight = 1.0,
    this.cropBottom = 1.0,
    this.perspectiveQuad,
    this.binarization = BinarizationMode.none,
    this.shadowCorrection = false,
    this.cleanupPatches = const [],
    this.recipeVersion = 2,
  });

  bool get hasCrop =>
      cropLeft > 0.0 || cropTop > 0.0 || cropRight < 1.0 || cropBottom < 1.0;

  bool get hasPerspective =>
      perspectiveQuad != null &&
      !perspectiveQuad!.isStandard &&
      perspectiveQuad!.isValidConvex();

  bool get hasCleanup => cleanupPatches.isNotEmpty;

  EditRecipe copyWith({
    int? rotationDegrees,
    PageFilter? filter,
    double? brightness,
    double? contrast,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
    PerspectiveQuad? perspectiveQuad,
    bool clearPerspectiveQuad = false,
    BinarizationMode? binarization,
    bool? shadowCorrection,
    List<CleanupPatch>? cleanupPatches,
    int? recipeVersion,
  }) {
    return EditRecipe(
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      filter: filter ?? this.filter,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      cropLeft: cropLeft ?? this.cropLeft,
      cropTop: cropTop ?? this.cropTop,
      cropRight: cropRight ?? this.cropRight,
      cropBottom: cropBottom ?? this.cropBottom,
      perspectiveQuad: clearPerspectiveQuad
          ? null
          : (perspectiveQuad ?? this.perspectiveQuad),
      binarization: binarization ?? this.binarization,
      shadowCorrection: shadowCorrection ?? this.shadowCorrection,
      cleanupPatches: cleanupPatches ?? this.cleanupPatches,
      recipeVersion: recipeVersion ?? this.recipeVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rotationDegrees': rotationDegrees,
      'filter': filter.name,
      'brightness': brightness,
      'contrast': contrast,
      'cropLeft': cropLeft,
      'cropTop': cropTop,
      'cropRight': cropRight,
      'cropBottom': cropBottom,
      if (perspectiveQuad != null) 'perspectiveQuad': perspectiveQuad!.toMap(),
      'binarization': binarization.name,
      'shadowCorrection': shadowCorrection,
      'cleanupPatches': cleanupPatches.map((p) => p.toMap()).toList(),
      'recipeVersion': recipeVersion,
    };
  }

  factory EditRecipe.fromMap(Map<String, dynamic> map) {
    PerspectiveQuad? quad;
    if (map['perspectiveQuad'] is Map<String, dynamic>) {
      quad = PerspectiveQuad.fromMap(
        map['perspectiveQuad'] as Map<String, dynamic>,
      );
    }

    final cleanupList = <CleanupPatch>[];
    if (map['cleanupPatches'] is List) {
      for (final item in map['cleanupPatches'] as List) {
        if (item is Map<String, dynamic>) {
          cleanupList.add(CleanupPatch.fromMap(item));
        }
      }
    }

    return EditRecipe(
      rotationDegrees: map['rotationDegrees'] as int? ?? 0,
      filter: PageFilter.values.firstWhere(
        (e) => e.name == map['filter'],
        orElse: () => PageFilter.original,
      ),
      brightness: (map['brightness'] as num?)?.toDouble() ?? 0.0,
      contrast: (map['contrast'] as num?)?.toDouble() ?? 1.0,
      cropLeft: (map['cropLeft'] as num?)?.toDouble() ?? 0.0,
      cropTop: (map['cropTop'] as num?)?.toDouble() ?? 0.0,
      cropRight: (map['cropRight'] as num?)?.toDouble() ?? 1.0,
      cropBottom: (map['cropBottom'] as num?)?.toDouble() ?? 1.0,
      perspectiveQuad: quad,
      binarization: BinarizationMode.values.firstWhere(
        (e) => e.name == map['binarization'],
        orElse: () => BinarizationMode.none,
      ),
      shadowCorrection: map['shadowCorrection'] as bool? ?? false,
      cleanupPatches: cleanupList,
      recipeVersion: map['recipeVersion'] as int? ?? 1,
    );
  }
}
