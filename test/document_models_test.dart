import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaneliq/core/models/document_models.dart';

void main() {
  group('Document Models & Serialization Tests', () {
    test('EditRecipe serialization to/from JSON and copyWith', () {
      const recipe = EditRecipe(
        rotationDegrees: 180,
        filter: PageFilter.blackAndWhite,
        brightness: 0.2,
        contrast: 1.4,
      );

      final jsonStr = jsonEncode(recipe.toMap());
      final decodedMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = EditRecipe.fromMap(decodedMap);

      expect(restored.rotationDegrees, equals(180));
      expect(restored.filter, equals(PageFilter.blackAndWhite));
      expect(restored.brightness, closeTo(0.2, 0.001));
      expect(restored.contrast, closeTo(1.4, 0.001));

      final modified = restored.copyWith(
        rotationDegrees: 270,
        filter: PageFilter.grayscale,
      );
      expect(modified.rotationDegrees, equals(270));
      expect(modified.filter, equals(PageFilter.grayscale));
      expect(modified.brightness, closeTo(0.2, 0.001));
    });

    test('DocumentPage serialization to/from database map', () {
      final page = DocumentPage(
        id: 'page_uuid_001',
        documentId: 'doc_uuid_999',
        pageOrder: 2,
        originalPath: '/data/user/0/com.scaneliq/originals/page_uuid_001.jpg',
        processedPath: '/data/user/0/com.scaneliq/processed/page_uuid_001.jpg',
        editRecipe: const EditRecipe(
          rotationDegrees: 90,
          filter: PageFilter.grayscale,
          brightness: -0.1,
          contrast: 1.2,
        ),
        width: 1080,
        height: 1920,
      );

      final map = page.toMap();
      expect(map['id'], equals('page_uuid_001'));
      expect(map['document_id'], equals('doc_uuid_999'));
      expect(map['page_order'], equals(2));
      expect(map['width'], equals(1080));
      expect(map['height'], equals(1920));

      final restored = DocumentPage.fromMap(map);
      expect(restored.id, equals('page_uuid_001'));
      expect(restored.documentId, equals('doc_uuid_999'));
      expect(restored.pageOrder, equals(2));
      expect(
        restored.originalPath,
        equals('/data/user/0/com.scaneliq/originals/page_uuid_001.jpg'),
      );
      expect(
        restored.processedPath,
        equals('/data/user/0/com.scaneliq/processed/page_uuid_001.jpg'),
      );
      expect(restored.editRecipe.rotationDegrees, equals(90));
      expect(restored.editRecipe.filter, equals(PageFilter.grayscale));
    });

    test('ScannedDocument serialization and draft status flags', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc_001',
        title: 'Meeting Notes Scan',
        createdAt: now,
        modifiedAt: now,
        pageCount: 3,
        isFavorite: true,
        isDraft: false,
        exportPath: '/storage/exports/Meeting_Notes.pdf',
      );

      final map = doc.toMap();
      expect(map['id'], equals('doc_001'));
      expect(map['title'], equals('Meeting Notes Scan'));
      expect(map['is_favorite'], equals(1));
      expect(map['is_draft'], equals(0));
      expect(map['export_path'], equals('/storage/exports/Meeting_Notes.pdf'));

      final restored = ScannedDocument.fromMap(map);
      expect(restored.id, equals('doc_001'));
      expect(restored.isFavorite, isTrue);
      expect(restored.isDraft, isFalse);
      expect(restored.exportPath, equals('/storage/exports/Meeting_Notes.pdf'));

      // Test draft flag transition
      final asDraft = doc.copyWith(isDraft: true);
      expect(asDraft.isDraft, isTrue);
      expect(asDraft.toMap()['is_draft'], equals(1));
    });
  });
}
