import 'dart:io';
import 'package:flutter/material.dart';
import 'package:scaneliq/core/models/document_models.dart';

class EditPageScreen extends StatefulWidget {
  final DocumentPage page;
  final Function(EditRecipe) onApply;

  const EditPageScreen({
    super.key,
    required this.page,
    required this.onApply,
  });

  @override
  State<EditPageScreen> createState() => _EditPageScreenState();
}

class _EditPageScreenState extends State<EditPageScreen> {
  late int _rotation;
  late PageFilter _filter;

  @override
  void initState() {
    super.initState();
    _rotation = widget.page.editRecipe.rotationDegrees;
    _filter = widget.page.editRecipe.filter;
  }

  void _rotateClockwise() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
  }

  void _reset() {
    setState(() {
      _rotation = 0;
      _filter = PageFilter.original;
    });
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.page.processedPath ?? widget.page.originalPath;
    final file = File(imagePath);

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Page ${widget.page.pageOrder + 1}'),
        actions: [
          TextButton(
            onPressed: () {
              final newRecipe = widget.page.editRecipe.copyWith(
                rotationDegrees: _rotation,
                filter: _filter,
              );
              widget.onApply(newRecipe);
              Navigator.pop(context);
            },
            child: const Text(
              'Apply',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: file.existsSync()
                  ? Transform.rotate(
                      angle: _rotation * 3.141592653589793 / 180,
                      child: ColorFiltered(
                        colorFilter: _filter == PageFilter.grayscale
                            ? const ColorFilter.matrix([
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0,      0,      0,      1, 0,
                              ])
                            : _filter == PageFilter.blackAndWhite
                                ? const ColorFilter.matrix([
                                    1.5, 0, 0, 0, -50,
                                    0, 1.5, 0, 0, -50,
                                    0, 0, 1.5, 0, -50,
                                    0, 0, 0, 1, 0,
                                  ])
                                : const ColorFilter.mode(
                                    Colors.transparent,
                                    BlendMode.multiply,
                                  ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            file,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    )
                  : const Center(child: Text('Image file missing')),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton.outlined(
                      icon: const Icon(Icons.rotate_right),
                      tooltip: 'Rotate 90°',
                      onPressed: _rotateClockwise,
                    ),
                    IconButton.outlined(
                      icon: const Icon(Icons.restore),
                      tooltip: 'Reset Original',
                      onPressed: _reset,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<PageFilter>(
                  segments: const [
                    ButtonSegment(
                      value: PageFilter.original,
                      label: Text('Original'),
                      icon: Icon(Icons.photo_outlined),
                    ),
                    ButtonSegment(
                      value: PageFilter.grayscale,
                      label: Text('Grayscale'),
                      icon: Icon(Icons.filter_b_and_w),
                    ),
                    ButtonSegment(
                      value: PageFilter.blackAndWhite,
                      label: Text('B&W'),
                      icon: Icon(Icons.contrast),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _filter = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
