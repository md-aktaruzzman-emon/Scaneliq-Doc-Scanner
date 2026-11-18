import 'dart:convert';
import 'dart:typed_data';

import 'package:scaneliq/core/models/document_models.dart';

/// Value-equality helper for comparing two [EditRecipe] instances accurately.
bool editRecipesEqual(EditRecipe a, EditRecipe b) {
  return jsonEncode(a.toMap()) == jsonEncode(b.toMap());
}

/// Per-page operation-based undo/redo history storing lightweight [EditRecipe]
/// snapshots without duplicating full-resolution image buffers in memory.
class EditHistoryStack {
  final List<EditRecipe> _undoStack = [];
  final List<EditRecipe> _redoStack = [];
  EditRecipe _current;

  EditHistoryStack(EditRecipe initial) : _current = initial;

  EditRecipe get current => _current;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get undoDepth => _undoStack.length;
  int get redoDepth => _redoStack.length;

  /// Records a new [EditRecipe] if it differs from [current], clearing redo history.
  bool record(EditRecipe next) {
    if (editRecipesEqual(_current, next)) return false;
    _undoStack.add(_current);
    // Cap history per page cleanly at 40 entries to stay constant-memory.
    if (_undoStack.length > 40) {
      _undoStack.removeAt(0);
    }
    _current = next;
    _redoStack.clear();
    return true;
  }

  /// Replaces [current] during live slider dragging without pushing intermediate ticks,
  /// after an optional [beginContinuousEdit] anchor snapshot.
  EditRecipe? _dragAnchor;

  void beginContinuousEdit() {
    _dragAnchor ??= _current;
  }

  void previewContinuousEdit(EditRecipe draft) {
    _current = draft;
  }

  void commitContinuousEdit() {
    final anchor = _dragAnchor;
    _dragAnchor = null;
    if (anchor == null) return;
    if (!editRecipesEqual(anchor, _current)) {
      _undoStack.add(anchor);
      if (_undoStack.length > 40) {
        _undoStack.removeAt(0);
      }
      _redoStack.clear();
    }
  }

  EditRecipe? undo() {
    if (_undoStack.isEmpty) return null;
    _redoStack.add(_current);
    _current = _undoStack.removeLast();
    return _current;
  }

  EditRecipe? redo() {
    if (_redoStack.isEmpty) return null;
    _undoStack.add(_current);
    _current = _redoStack.removeLast();
    return _current;
  }
}

/// Manages independent undo/redo stacks and cached downsampled preview buffers
/// across all pages in a multi-page editing session.
class MultiPageEditHistory {
  final Map<String, EditHistoryStack> _stacks = {};
  final Map<String, Uint8List> _cachedBasePreviewBytes = {};

  EditHistoryStack stackFor(DocumentPage page) {
    return _stacks.putIfAbsent(page.id, () => EditHistoryStack(page.editRecipe));
  }

  Uint8List? cachedBaseBytesFor(String pageId) =>
      _cachedBasePreviewBytes[pageId];

  void cacheBaseBytes(String pageId, Uint8List bytes) {
    // Keep at most 8 downsampled preview buffers resident cleanly.
    if (_cachedBasePreviewBytes.length >= 8 &&
        !_cachedBasePreviewBytes.containsKey(pageId)) {
      _cachedBasePreviewBytes.remove(_cachedBasePreviewBytes.keys.first);
    }
    _cachedBasePreviewBytes[pageId] = bytes;
  }

  void clear() {
    _stacks.clear();
    _cachedBasePreviewBytes.clear();
  }
}
