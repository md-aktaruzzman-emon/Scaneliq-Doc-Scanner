import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:scaneliq/core/theme/scaneliq_colors.dart';
import 'package:scaneliq/core/theme/scaneliq_tokens.dart';
import 'package:scaneliq/core/theme/scaneliq_typography.dart';
import 'package:scaneliq/features/pdf/data/advanced_pdf_service.dart';

enum PdfAnnotationTool {
  select,
  highlight,
  underline,
  freehand,
  note,
  shape,
  eraser,
}

/// Manages per-document normalized PDF annotations with multi-step Undo / Redo.
class PdfAnnotationController extends ChangeNotifier {
  List<PdfAnnotationItem> _items = const [];
  final List<List<PdfAnnotationItem>> _undoStack = [];
  final List<List<PdfAnnotationItem>> _redoStack = [];

  PdfAnnotationTool _tool = PdfAnnotationTool.highlight;
  PdfShapeKind _shapeKind = PdfShapeKind.rectangle;
  Color _color = ScaneliqColorPalette.light.accent;
  double _strokeWidth = 3.0;
  double _opacity = 0.85;
  String? _selectedId;

  List<PdfAnnotationItem> get items => List.unmodifiable(_items);
  PdfAnnotationTool get tool => _tool;
  PdfShapeKind get shapeKind => _shapeKind;
  Color get color => _color;
  double get strokeWidth => _strokeWidth;
  double get opacity => _opacity;
  String? get selectedId => _selectedId;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  List<PdfAnnotationItem> itemsForPage(int pageIndex) {
    return _items.where((e) => e.pageIndex == pageIndex).toList();
  }

  PdfAnnotationItem? get selectedItem {
    if (_selectedId == null) return null;
    for (final item in _items) {
      if (item.id == _selectedId) return item;
    }
    return null;
  }

  void setTool(PdfAnnotationTool tool) {
    if (_tool == tool) return;
    _tool = tool;
    notifyListeners();
  }

  void setShapeKind(PdfShapeKind kind) {
    _shapeKind = kind;
    _tool = PdfAnnotationTool.shape;
    notifyListeners();
  }

  void setColor(Color color) {
    _color = color;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _strokeWidth = width.clamp(1.0, 12.0);
    notifyListeners();
  }

  void setOpacity(double opacity) {
    _opacity = opacity.clamp(0.15, 1.0);
    notifyListeners();
  }

  void selectItem(String? id) {
    _selectedId = id;
    notifyListeners();
  }

  void addItem(PdfAnnotationItem item, {bool select = false}) {
    _pushUndo();
    final withId = item.id == null
        ? item.copyWith(id: 'ann_${DateTime.now().microsecondsSinceEpoch}')
        : item;
    _items = [..._items, withId];
    if (select) _selectedId = withId.id;
    notifyListeners();
  }

  void updateItem(
    String id,
    PdfAnnotationItem updated, {
    bool recordHistory = true,
  }) {
    if (recordHistory) _pushUndo();
    _items = [for (final e in _items) e.id == id ? updated : e];
    notifyListeners();
  }

  void removeItem(String id) {
    _pushUndo();
    _items = _items.where((e) => e.id != id).toList();
    if (_selectedId == id) _selectedId = null;
    notifyListeners();
  }

  void clearPage(int pageIndex) {
    if (_items.every((e) => e.pageIndex != pageIndex)) return;
    _pushUndo();
    _items = _items.where((e) => e.pageIndex != pageIndex).toList();
    _selectedId = null;
    notifyListeners();
  }

  void clearAll() {
    if (_items.isEmpty) return;
    _pushUndo();
    _items = const [];
    _selectedId = null;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _redoStack.add(List<PdfAnnotationItem>.from(_items));
    _items = _undoStack.removeLast();
    _selectedId = null;
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _undoStack.add(List<PdfAnnotationItem>.from(_items));
    _items = _redoStack.removeLast();
    _selectedId = null;
    notifyListeners();
  }

  void _pushUndo() {
    _undoStack.add(List<PdfAnnotationItem>.from(_items));
    if (_undoStack.length > 40) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }
}

/// Interactive canvas overlay for drawing Highlights, Underlines, Freehand Ink,
/// Notes, Shapes, and positioning/resizing Visual Signatures over a PDF page.
class PdfAnnotationOverlay extends StatefulWidget {
  final PdfAnnotationController controller;
  final int pageIndex;
  final Future<String?> Function(String? initialText) onRequestNoteText;

  const PdfAnnotationOverlay({
    super.key,
    required this.controller,
    required this.pageIndex,
    required this.onRequestNoteText,
  });

  @override
  State<PdfAnnotationOverlay> createState() => _PdfAnnotationOverlayState();
}

class _PdfAnnotationOverlayState extends State<PdfAnnotationOverlay> {
  Offset? _dragStart;
  Offset? _dragCurrent;
  List<Offset> _activeStroke = [];
  String? _movingId;
  Offset? _lastMoveNorm;

  Offset _toNorm(Offset local, Size size) {
    return Offset(
      (local.dx / math.max(1.0, size.width)).clamp(0.0, 1.0),
      (local.dy / math.max(1.0, size.height)).clamp(0.0, 1.0),
    );
  }

  PdfAnnotationItem? _hitTest(Offset norm) {
    final pageItems = widget.controller.itemsForPage(widget.pageIndex).reversed;
    for (final item in pageItems) {
      if (item.type == PdfAnnotationType.freehand && item.points.isNotEmpty) {
        for (final pt in item.points) {
          if ((pt - norm).distance <= 0.045) return item;
        }
      } else {
        final rect = Rect.fromLTWH(
          item.x - 0.02,
          item.y - 0.02,
          item.width + 0.04,
          item.height + 0.04,
        );
        if (rect.contains(norm)) return item;
      }
    }
    return null;
  }

  Future<void> _handleTapUp(TapUpDetails details, Size size) async {
    final norm = _toNorm(details.localPosition, size);
    final tool = widget.controller.tool;

    if (tool == PdfAnnotationTool.eraser) {
      final hit = _hitTest(norm);
      if (hit?.id != null) widget.controller.removeItem(hit!.id!);
      return;
    }

    if (tool == PdfAnnotationTool.note) {
      final hit = _hitTest(norm);
      if (hit != null && hit.type == PdfAnnotationType.text && hit.id != null) {
        final edited = await widget.onRequestNoteText(hit.text);
        if (edited != null && edited.trim().isNotEmpty) {
          widget.controller.updateItem(
            hit.id!,
            hit.copyWith(text: edited.trim()),
          );
        }
        return;
      }
      final text = await widget.onRequestNoteText(null);
      if (text != null && text.trim().isNotEmpty) {
        widget.controller.addItem(
          PdfAnnotationItem(
            type: PdfAnnotationType.text,
            pageIndex: widget.pageIndex,
            x: (norm.dx - 0.14).clamp(0.02, 0.72),
            y: (norm.dy - 0.03).clamp(0.02, 0.90),
            width: 0.28,
            height: 0.07,
            text: text.trim(),
            fontSize: 13.0,
            color: widget.controller.color,
            normalized: true,
          ),
          select: true,
        );
      }
      return;
    }

    if (tool == PdfAnnotationTool.select) {
      final hit = _hitTest(norm);
      widget.controller.selectItem(hit?.id);
      if (hit != null && hit.type == PdfAnnotationType.text && hit.id != null) {
        final edited = await widget.onRequestNoteText(hit.text);
        if (edited != null && edited.trim().isNotEmpty) {
          widget.controller.updateItem(
            hit.id!,
            hit.copyWith(text: edited.trim()),
          );
        }
      }
    }
  }

  void _handlePanStart(DragStartDetails details, Size size) {
    final norm = _toNorm(details.localPosition, size);
    final tool = widget.controller.tool;

    if (tool == PdfAnnotationTool.select) {
      final hit = _hitTest(norm);
      if (hit?.id != null && hit!.type != PdfAnnotationType.freehand) {
        widget.controller.selectItem(hit.id);
        _movingId = hit.id;
        _lastMoveNorm = norm;
      }
      return;
    }

    if (tool == PdfAnnotationTool.eraser) {
      final hit = _hitTest(norm);
      if (hit?.id != null) widget.controller.removeItem(hit!.id!);
      return;
    }

    setState(() {
      _dragStart = norm;
      _dragCurrent = norm;
      if (tool == PdfAnnotationTool.freehand) {
        _activeStroke = [norm];
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    final norm = _toNorm(details.localPosition, size);
    final tool = widget.controller.tool;

    if (tool == PdfAnnotationTool.select &&
        _movingId != null &&
        _lastMoveNorm != null) {
      final item = widget.controller.selectedItem;
      if (item != null && item.id == _movingId) {
        final dx = norm.dx - _lastMoveNorm!.dx;
        final dy = norm.dy - _lastMoveNorm!.dy;
        _lastMoveNorm = norm;
        widget.controller.updateItem(
          item.id!,
          item.copyWith(
            x: (item.x + dx).clamp(0.0, 1.0 - item.width),
            y: (item.y + dy).clamp(0.0, 1.0 - item.height),
          ),
          recordHistory: false,
        );
      }
      return;
    }

    if (tool == PdfAnnotationTool.eraser) {
      final hit = _hitTest(norm);
      if (hit?.id != null) widget.controller.removeItem(hit!.id!);
      return;
    }

    if (_dragStart == null) return;
    setState(() {
      _dragCurrent = norm;
      if (tool == PdfAnnotationTool.freehand) {
        if (_activeStroke.isEmpty ||
            (_activeStroke.last - norm).distance > 0.004) {
          _activeStroke = [..._activeStroke, norm];
        }
      }
    });
  }

  void _handlePanEnd(DragEndDetails _) {
    final tool = widget.controller.tool;
    _movingId = null;
    _lastMoveNorm = null;

    if (_dragStart == null || _dragCurrent == null) {
      setState(() {
        _dragStart = null;
        _dragCurrent = null;
        _activeStroke = [];
      });
      return;
    }

    final a = _dragStart!;
    final b = _dragCurrent!;

    if (tool == PdfAnnotationTool.freehand && _activeStroke.length >= 2) {
      widget.controller.addItem(
        PdfAnnotationItem(
          type: PdfAnnotationType.freehand,
          pageIndex: widget.pageIndex,
          x: 0,
          y: 0,
          width: 0,
          height: 0,
          points: _activeStroke,
          color: widget.controller.color,
          strokeWidth: widget.controller.strokeWidth,
          opacity: widget.controller.opacity,
          normalized: true,
        ),
      );
    } else if (tool == PdfAnnotationTool.highlight &&
        (a - b).distance > 0.015) {
      final left = math.min(a.dx, b.dx);
      final top = math.min(a.dy, b.dy);
      final w = (a.dx - b.dx).abs().clamp(0.03, 1.0);
      final h = (a.dy - b.dy).abs().clamp(0.022, 0.25);
      widget.controller.addItem(
        PdfAnnotationItem(
          type: PdfAnnotationType.highlight,
          pageIndex: widget.pageIndex,
          x: left,
          y: top,
          width: w,
          height: h,
          color: widget.controller.color,
          opacity: 0.38,
          normalized: true,
        ),
      );
    } else if (tool == PdfAnnotationTool.underline &&
        (a.dx - b.dx).abs() > 0.02) {
      final left = math.min(a.dx, b.dx);
      final w = (a.dx - b.dx).abs().clamp(0.04, 1.0);
      widget.controller.addItem(
        PdfAnnotationItem(
          type: PdfAnnotationType.underline,
          pageIndex: widget.pageIndex,
          x: left,
          y: a.dy,
          width: w,
          height: 0.008,
          color: widget.controller.color,
          strokeWidth: widget.controller.strokeWidth,
          normalized: true,
        ),
      );
    } else if (tool == PdfAnnotationTool.shape && (a - b).distance > 0.02) {
      final kind = widget.controller.shapeKind;
      final bool directed =
          kind == PdfShapeKind.line || kind == PdfShapeKind.arrow;
      widget.controller.addItem(
        PdfAnnotationItem(
          type: PdfAnnotationType.shape,
          pageIndex: widget.pageIndex,
          x: directed ? a.dx : math.min(a.dx, b.dx),
          y: directed ? a.dy : math.min(a.dy, b.dy),
          width: directed
              ? (b.dx - a.dx)
              : (a.dx - b.dx).abs().clamp(0.03, 1.0),
          height: directed
              ? (b.dy - a.dy)
              : (a.dy - b.dy).abs().clamp(0.03, 1.0),
          shapeKind: kind,
          color: widget.controller.color,
          strokeWidth: widget.controller.strokeWidth,
          opacity: widget.controller.opacity,
          normalized: true,
        ),
      );
    }

    setState(() {
      _dragStart = null;
      _dragCurrent = null;
      _activeStroke = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final items = widget.controller.itemsForPage(widget.pageIndex);
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) => _handleTapUp(d, size),
              onPanStart: (d) => _handlePanStart(d, size),
              onPanUpdate: (d) => _handlePanUpdate(d, size),
              onPanEnd: _handlePanEnd,
              child: CustomPaint(
                size: size,
                painter: _PdfAnnotationPainter(
                  items: items,
                  selectedId: widget.controller.selectedId,
                  activeTool: widget.controller.tool,
                  activeShape: widget.controller.shapeKind,
                  activeColor: widget.controller.color,
                  activeStrokeWidth: widget.controller.strokeWidth,
                  dragStart: _dragStart,
                  dragCurrent: _dragCurrent,
                  activeStroke: _activeStroke,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PdfAnnotationPainter extends CustomPainter {
  final List<PdfAnnotationItem> items;
  final String? selectedId;
  final PdfAnnotationTool activeTool;
  final PdfShapeKind activeShape;
  final Color activeColor;
  final double activeStrokeWidth;
  final Offset? dragStart;
  final Offset? dragCurrent;
  final List<Offset> activeStroke;

  _PdfAnnotationPainter({
    required this.items,
    required this.selectedId,
    required this.activeTool,
    required this.activeShape,
    required this.activeColor,
    required this.activeStrokeWidth,
    required this.dragStart,
    required this.dragCurrent,
    required this.activeStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in items) {
      final px = item.normalized ? item.x * size.width : item.x;
      final py = item.normalized ? item.y * size.height : item.y;
      final pw = item.normalized ? item.width * size.width : item.width;
      final ph = item.normalized ? item.height * size.height : item.height;

      switch (item.type) {
        case PdfAnnotationType.highlight:
          final paint = Paint()
            ..color = item.color.withValues(alpha: 0.36)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(px, py, pw, math.max(10, ph)),
              const Radius.circular(3),
            ),
            paint,
          );
          break;
        case PdfAnnotationType.underline:
          final paint = Paint()
            ..color = item.color.withValues(alpha: item.opacity)
            ..strokeWidth = item.strokeWidth
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(px, py + ph), Offset(px + pw, py + ph), paint);
          break;
        case PdfAnnotationType.freehand:
          if (item.points.length >= 2) {
            final paint = Paint()
              ..color = item.color.withValues(alpha: item.opacity)
              ..strokeWidth = item.strokeWidth
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke;
            final path = Path()
              ..moveTo(
                item.points.first.dx * size.width,
                item.points.first.dy * size.height,
              );
            for (int i = 1; i < item.points.length; i++) {
              path.lineTo(
                item.points[i].dx * size.width,
                item.points[i].dy * size.height,
              );
            }
            canvas.drawPath(path, paint);
          }
          break;
        case PdfAnnotationType.shape:
          final paint = Paint()
            ..color = item.color.withValues(alpha: item.opacity)
            ..strokeWidth = item.strokeWidth
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          _drawShape(canvas, paint, item.shapeKind, px, py, pw, ph);
          break;
        case PdfAnnotationType.text:
          final rect = Rect.fromLTWH(
            px,
            py,
            math.max(96, pw),
            math.max(30, ph),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            Paint()..color = item.color.withValues(alpha: 0.14),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            Paint()
              ..color = item.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
          final tp = TextPainter(
            text: TextSpan(
              text: item.text ?? '',
              style: TextStyle(
                color: item.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 2,
            ellipsis: '...',
          )..layout(maxWidth: rect.width - 10);
          tp.paint(canvas, Offset(rect.left + 6, rect.top + 6));
          break;
        case PdfAnnotationType.signature:
          final rect = Rect.fromLTWH(px, py, pw, ph);
          canvas.save();
          canvas.translate(rect.center.dx, rect.center.dy);
          canvas.rotate(item.rotationDegrees * math.pi / 180.0);
          final box = Rect.fromCenter(
            center: Offset.zero,
            width: rect.width,
            height: rect.height,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(box, const Radius.circular(6)),
            Paint()
              ..color = ScaneliqColorPalette.light.accent.withValues(
                alpha: 0.12,
              ),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(box, const Radius.circular(6)),
            Paint()
              ..color = ScaneliqColorPalette.light.accent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
          final tp = TextPainter(
            text: TextSpan(
              text: 'VISUAL SIGNATURE',
              style: TextStyle(
                color: ScaneliqColorPalette.light.accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: rect.width - 8);
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
          canvas.restore();
          break;
      }

      if (item.id != null &&
          item.id == selectedId &&
          item.type != PdfAnnotationType.freehand) {
        final selRect = Rect.fromLTWH(
          px - 3,
          py - 3,
          pw.abs() + 6,
          ph.abs() + 6,
        );
        canvas.drawRect(
          selRect,
          Paint()
            ..color = ScaneliqColorPalette.light.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // Live interactive stroke/shape preview
    if (activeTool == PdfAnnotationTool.freehand && activeStroke.length >= 2) {
      final paint = Paint()
        ..color = activeColor
        ..strokeWidth = activeStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(
          activeStroke.first.dx * size.width,
          activeStroke.first.dy * size.height,
        );
      for (int i = 1; i < activeStroke.length; i++) {
        path.lineTo(
          activeStroke[i].dx * size.width,
          activeStroke[i].dy * size.height,
        );
      }
      canvas.drawPath(path, paint);
    } else if (dragStart != null && dragCurrent != null) {
      final a = Offset(dragStart!.dx * size.width, dragStart!.dy * size.height);
      final b = Offset(
        dragCurrent!.dx * size.width,
        dragCurrent!.dy * size.height,
      );
      if (activeTool == PdfAnnotationTool.highlight) {
        canvas.drawRect(
          Rect.fromPoints(a, b),
          Paint()..color = activeColor.withValues(alpha: 0.35),
        );
      } else if (activeTool == PdfAnnotationTool.underline) {
        canvas.drawLine(
          Offset(a.dx, a.dy),
          Offset(b.dx, a.dy),
          Paint()
            ..color = activeColor
            ..strokeWidth = activeStrokeWidth
            ..strokeCap = StrokeCap.round,
        );
      } else if (activeTool == PdfAnnotationTool.shape) {
        _drawShape(
          canvas,
          Paint()
            ..color = activeColor
            ..strokeWidth = activeStrokeWidth
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
          activeShape,
          (activeShape == PdfShapeKind.line ||
                  activeShape == PdfShapeKind.arrow)
              ? a.dx
              : math.min(a.dx, b.dx),
          (activeShape == PdfShapeKind.line ||
                  activeShape == PdfShapeKind.arrow)
              ? a.dy
              : math.min(a.dy, b.dy),
          (activeShape == PdfShapeKind.line ||
                  activeShape == PdfShapeKind.arrow)
              ? (b.dx - a.dx)
              : (a.dx - b.dx).abs(),
          (activeShape == PdfShapeKind.line ||
                  activeShape == PdfShapeKind.arrow)
              ? (b.dy - a.dy)
              : (a.dy - b.dy).abs(),
        );
      }
    }
  }

  void _drawShape(
    Canvas canvas,
    Paint paint,
    PdfShapeKind kind,
    double px,
    double py,
    double pw,
    double ph,
  ) {
    switch (kind) {
      case PdfShapeKind.rectangle:
        canvas.drawRect(Rect.fromLTWH(px, py, pw, ph), paint);
        break;
      case PdfShapeKind.circle:
        canvas.drawOval(Rect.fromLTWH(px, py, pw, ph), paint);
        break;
      case PdfShapeKind.line:
        canvas.drawLine(Offset(px, py), Offset(px + pw, py + ph), paint);
        break;
      case PdfShapeKind.arrow:
        final start = Offset(px, py);
        final end = Offset(px + pw, py + ph);
        canvas.drawLine(start, end, paint);
        final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
        const headLen = 12.0;
        const headAngle = 0.52;
        canvas.drawLine(
          end,
          Offset(
            end.dx - headLen * math.cos(angle - headAngle),
            end.dy - headLen * math.sin(angle - headAngle),
          ),
          paint,
        );
        canvas.drawLine(
          end,
          Offset(
            end.dx - headLen * math.cos(angle + headAngle),
            end.dy - headLen * math.sin(angle + headAngle),
          ),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PdfAnnotationPainter oldDelegate) => true;
}

/// Concept A floating Annotation Toolbar docked above the canvas / bottom bar.
class PdfAnnotationToolbar extends StatelessWidget {
  final PdfAnnotationController controller;
  final VoidCallback onSavePdf;
  final VoidCallback onClose;
  final bool isSaving;
  final VoidCallback? onClearCurrentPage;

  const PdfAnnotationToolbar({
    super.key,
    required this.controller,
    required this.onSavePdf,
    required this.onClose,
    this.isSaving = false,
    this.onClearCurrentPage,
  });

  static const _swatches = <Color>[
    Color(0xFF0052FF), // Ultramarine
    Color(0xFFF59E0B), // Highlight Amber
    Color(0xFFDC2626), // Crimson
    Color(0xFF059669), // Emerald
    Color(0xFF18181B), // Obsidian
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selected = controller.selectedItem;
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(top: BorderSide(color: tokens.hairline)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top action row: Undo, Redo, Colors, Delete Selected, Save
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Undo Annotation',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 34,
                      ),
                      icon: Icon(
                        Icons.undo_rounded,
                        size: 19,
                        color: controller.canUndo
                            ? tokens.textPrimary
                            : tokens.textTertiary.withValues(alpha: 0.45),
                      ),
                      onPressed: controller.canUndo ? controller.undo : null,
                    ),
                    IconButton(
                      tooltip: 'Redo Annotation',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 34,
                      ),
                      icon: Icon(
                        Icons.redo_rounded,
                        size: 19,
                        color: controller.canRedo
                            ? tokens.textPrimary
                            : tokens.textTertiary.withValues(alpha: 0.45),
                      ),
                      onPressed: controller.canRedo ? controller.redo : null,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final c in _swatches) ...[
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => controller.setColor(c),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: controller.color == c
                                          ? tokens.textPrimary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (selected?.id != null)
                      IconButton(
                        tooltip: 'Delete Selected',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 34,
                        ),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: tokens.danger,
                        ),
                        onPressed: () => controller.removeItem(selected!.id!),
                      )
                    else if (onClearCurrentPage != null)
                      IconButton(
                        tooltip: 'Clear Page',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 34,
                        ),
                        icon: Icon(
                          Icons.layers_clear_outlined,
                          size: 19,
                          color: tokens.textSecondary,
                        ),
                        onPressed: onClearCurrentPage,
                      ),
                    IconButton(
                      tooltip: 'Close Annotate',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 34,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 19),
                      onPressed: onClose,
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: isSaving || controller.items.isEmpty
                          ? null
                          : onSavePdf,
                      child: Text(
                        isSaving ? 'Saving...' : 'Save PDF',
                        style: TextStyle(
                          fontFamily: ScaneliqTypography.bodyFontFamily,
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Shape sub-selector + stroke width slider when drawing ink/shape
                if (controller.tool == PdfAnnotationTool.shape ||
                    controller.tool == PdfAnnotationTool.freehand ||
                    controller.tool == PdfAnnotationTool.underline)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        if (controller.tool == PdfAnnotationTool.shape) ...[
                          _ShapeChip(
                            label: 'Rect',
                            selected:
                                controller.shapeKind == PdfShapeKind.rectangle,
                            onTap: () =>
                                controller.setShapeKind(PdfShapeKind.rectangle),
                          ),
                          const SizedBox(width: 6),
                          _ShapeChip(
                            label: 'Circle',
                            selected:
                                controller.shapeKind == PdfShapeKind.circle,
                            onTap: () =>
                                controller.setShapeKind(PdfShapeKind.circle),
                          ),
                          const SizedBox(width: 6),
                          _ShapeChip(
                            label: 'Arrow',
                            selected:
                                controller.shapeKind == PdfShapeKind.arrow,
                            onTap: () =>
                                controller.setShapeKind(PdfShapeKind.arrow),
                          ),
                          const SizedBox(width: 6),
                          _ShapeChip(
                            label: 'Line',
                            selected: controller.shapeKind == PdfShapeKind.line,
                            onTap: () =>
                                controller.setShapeKind(PdfShapeKind.line),
                          ),
                        ],
                        Expanded(
                          child: Row(
                            children: [
                              const SizedBox(width: 6),
                              Text(
                                'Size',
                                style: ScaneliqTypography.monoStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 10.5,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2.5,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    activeTrackColor: tokens.accent,
                                    thumbColor: tokens.accent,
                                  ),
                                  child: Slider(
                                    min: 1.5,
                                    max: 10.0,
                                    value: controller.strokeWidth.clamp(
                                      1.5,
                                      10.0,
                                    ),
                                    onChanged: controller.setStrokeWidth,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Horizontal scrollable markup tool picker
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ToolButton(
                        icon: Icons.near_me_outlined,
                        label: 'Select',
                        selected: controller.tool == PdfAnnotationTool.select,
                        onTap: () =>
                            controller.setTool(PdfAnnotationTool.select),
                      ),
                      const SizedBox(width: 6),
                      _ToolButton(
                        icon: Icons.border_color_outlined,
                        label: 'Highlight',
                        selected:
                            controller.tool == PdfAnnotationTool.highlight,
                        onTap: () =>
                            controller.setTool(PdfAnnotationTool.highlight),
                      ),
                      const SizedBox(width: 6),
                      _ToolButton(
                        icon: Icons.format_underlined_rounded,
                        label: 'Underline',
                        selected:
                            controller.tool == PdfAnnotationTool.underline,
                        onTap: () =>
                            controller.setTool(PdfAnnotationTool.underline),
                      ),
                      const SizedBox(width: 6),
                      _ToolButton(
                        icon: Icons.gesture_rounded,
                        label: 'Ink Draw',
                        selected: controller.tool == PdfAnnotationTool.freehand,
                        onTap: () =>
                            controller.setTool(PdfAnnotationTool.freehand),
                      ),
                      const SizedBox(width: 6),
                      _ToolButton(
                        icon: Icons.sticky_note_2_outlined,
                        label: 'Text Note',
                        selected: controller.tool == PdfAnnotationTool.note,
                        onTap: () => controller.setTool(PdfAnnotationTool.note),
                      ),
                      const SizedBox(width: 6),
                      _ToolButton(
                        icon: Icons.category_outlined,
                        label: 'Shapes',
                        selected: controller.tool == PdfAnnotationTool.shape,
                        onTap: () =>
                            controller.setTool(PdfAnnotationTool.shape),
                      ),
                      const SizedBox(width: 6),
                      _ToolButton(
                        icon: Icons.auto_fix_normal_outlined,
                        label: 'Eraser',
                        selected: controller.tool == PdfAnnotationTool.eraser,
                        onTap: () =>
                            controller.setTool(PdfAnnotationTool.eraser),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? tokens.accent : tokens.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? tokens.accent : tokens.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: ScaneliqTypography.bodyFontFamily,
                color: selected ? tokens.accent : tokens.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShapeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ShapeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? tokens.accent : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? tokens.accent : tokens.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: ScaneliqTypography.bodyFontFamily,
            color: selected ? Colors.white : tokens.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
