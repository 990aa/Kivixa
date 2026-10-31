import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:kivixa/components/canvas/_canvas_background_painter.dart';
import 'package:kivixa/components/canvas/_canvas_painter.dart';
import 'package:kivixa/components/canvas/_stroke.dart';
import 'package:kivixa/components/canvas/canvas_image.dart';
import 'package:kivixa/components/canvas/image/editor_image.dart';
import 'package:kivixa/data/editor/editor_core_info.dart';
import 'package:kivixa/data/editor/text_box.dart';
import 'package:kivixa/data/prefs.dart';
import 'package:kivixa/data/tools/select.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';

class InnerCanvas extends StatefulWidget {
  const InnerCanvas({
    super.key,
    required this.pageIndex,
    this.redrawPageListenable,
    required this.width,
    required this.height,
    this.isPreview = false,
    this.isPrint = false,
    this.textEditing = false,
    required this.coreInfo,
    required this.currentStroke,
    required this.currentStrokeDetectedShape,
    required this.currentSelection,
    this.setAsBackground,
    this.onRenderObjectChange,
    this.hideBackground = false,
    required this.currentToolIsSelect,
    required this.currentScale,
    this.onTextBoxChanged,
  });

  final int pageIndex;
  final Listenable? redrawPageListenable;
  final double width;
  final double height;

  final bool isPreview;
  final bool isPrint;

  final bool textEditing;
  final EditorCoreInfo coreInfo;
  final Stroke? currentStroke;
  final RecognizedUnistroke? currentStrokeDetectedShape;
  final SelectResult? currentSelection;
  final void Function(EditorImage image)? setAsBackground;
  final ValueChanged<RenderObject>? onRenderObjectChange;

  final bool hideBackground;
  final bool currentToolIsSelect;

  final double currentScale;
  final VoidCallback? onTextBoxChanged;

  static const defaultBackgroundColor = Color(0xFFFCFCFC);

  @override
  State<InnerCanvas> createState() => _InnerCanvasState();
}

class _InnerCanvasState extends State<InnerCanvas> {
  int? _editingTextBox;

  @override
  void didUpdateWidget(covariant InnerCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.textEditing && _editingTextBox != null) {
      _editingTextBox = null;
    }
  }

  void _createTextBox(Offset position) {
    if (widget.coreInfo.readOnly) return;
    final page = widget.coreInfo.pages[widget.pageIndex];
    final box = EditorTextBox(
      rect: Rect.fromLTWH(
        position.dx.clamp(0, widget.width - 240),
        position.dy.clamp(0, widget.height - 80),
        240,
        80,
      ),
    );
    page.textBoxes.add(box);
    _editingTextBox = page.textBoxes.length - 1;
    widget.onTextBoxChanged?.call();
    setState(() {});
  }

  void _finishEditing() {
    if (_editingTextBox == null) return;
    setState(() => _editingTextBox = null);
    widget.onTextBoxChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final Brightness brightness = Theme.brightnessOf(context);
    final invert =
        stows.editorAutoInvert.value && brightness == Brightness.dark;
    final Color backgroundColor =
        widget.coreInfo.backgroundColor ?? InnerCanvas.defaultBackgroundColor;

    if (widget.coreInfo.pages.isEmpty) {
      return SizedBox(width: widget.width, height: widget.height);
    }

    final page = widget.coreInfo.pages[widget.pageIndex];
    final legacyQuill = page.quill.controller.document.isEmpty()
        ? null
        : Positioned(
            top: 0,
            left: 0,
            width: widget.width,
            height: widget.height,
            child: IgnorePointer(
              child: QuillEditor(
                controller: page.quill.controller,
                config: QuillEditorConfig(
                  scrollable: false,
                  autoFocus: false,
                  expands: true,
                  showCursor: false,
                  padding: EdgeInsets.only(
                    top: widget.coreInfo.lineHeight * 1.2,
                    left: widget.coreInfo.lineHeight * 0.5,
                    right: widget.coreInfo.lineHeight * 0.5,
                    bottom: widget.coreInfo.lineHeight * 0.5,
                  ),
                ),
                scrollController: ScrollController(),
                focusNode: page.quill.focusNode,
              ),
            ),
          );

    return RepaintBoundary(
      child: CustomPaint(
        painter: CanvasBackgroundPainter(
          invert: invert,
          backgroundColor: () {
            if (page.backgroundImage != null) {
              return Colors.white;
            } else if (widget.hideBackground) {
              return InnerCanvas.defaultBackgroundColor;
            } else {
              return backgroundColor;
            }
          }(),
          backgroundPattern: () {
            if (page.backgroundImage != null) {
              return CanvasBackgroundPattern.none;
            } else if (widget.hideBackground) {
              return CanvasBackgroundPattern.none;
            } else {
              return widget.coreInfo.backgroundPattern;
            }
          }(),
          lineHeight: widget.coreInfo.lineHeight,
          lineThickness: widget.coreInfo.lineThickness,
          primaryColor: colorScheme.primary,
          secondaryColor: colorScheme.secondary,
        ),
        foregroundPainter: CanvasPainter(
          repaint: widget.redrawPageListenable,
          invert: invert,
          strokes: page.strokes,
          laserStrokes: page.laserStrokes,
          currentStroke: widget.currentStroke,
          currentSelection: widget.currentSelection,
          primaryColor: colorScheme.primary,
          page: page,
          showPageIndicator:
              !widget.isPreview &&
              (!widget.isPrint || stows.printPageIndicators.value),
          pageIndex: widget.pageIndex,
          totalPages: widget.coreInfo.pages.length,
          currentScale: widget.currentScale,
        ),
        isComplex: true,
        willChange: true,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: DeferredPointerHandler(
            child: Stack(
              children: [
                if (page.backgroundImage != null)
                  CanvasImage(
                    filePath: widget.coreInfo.filePath,
                    image: page.backgroundImage!,
                    pageSize: Size(widget.width, widget.height),
                    setAsBackground: null,
                    isBackground: true,
                    readOnly: true,
                  ),
                ?legacyQuill,
                if (widget.textEditing)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (details) {
                        if (_editingTextBox != null) {
                          _finishEditing();
                        } else {
                          _createTextBox(details.localPosition);
                        }
                      },
                    ),
                  ),
                for (int i = 0; i < page.textBoxes.length; i++)
                  _TextBoxWidget(
                    key: ValueKey(page.textBoxes[i]),
                    box: page.textBoxes[i],
                    editing: _editingTextBox == i,
                    readOnly: widget.coreInfo.readOnly,
                    onChanged: () {
                      page.redrawStrokes();
                      widget.onTextBoxChanged?.call();
                    },
                    onEdit: () => setState(() => _editingTextBox = i),
                    onDelete: () {
                      page.textBoxes.removeAt(i);
                      if (_editingTextBox == i) _editingTextBox = null;
                      widget.onTextBoxChanged?.call();
                      setState(() {});
                    },
                  ),
                for (int i = 0; i < page.images.length; i++)
                  CanvasImage(
                    filePath: widget.coreInfo.filePath,
                    image: page.images[i],
                    pageSize: Size(widget.width, widget.height),
                    setAsBackground: widget.setAsBackground,
                    readOnly:
                        widget.coreInfo.readOnly || !widget.currentToolIsSelect,
                    selected:
                        widget.currentSelection?.images.contains(
                          page.images[i],
                        ) ??
                        false,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextBoxWidget extends StatefulWidget {
  const _TextBoxWidget({
    super.key,
    required this.box,
    required this.editing,
    required this.readOnly,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final EditorTextBox box;
  final bool editing;
  final bool readOnly;
  final VoidCallback onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_TextBoxWidget> createState() => _TextBoxWidgetState();
}

class _TextBoxWidgetState extends State<_TextBoxWidget> {
  late final _controller = TextEditingController(text: widget.box.text);
  late final _sizeController = TextEditingController(
    text: widget.box.fontSize.round().toString(),
  );

  static const _fonts = ['Dekko', 'Roboto', 'serif', 'monospace', 'cursive'];

  @override
  void didUpdateWidget(covariant _TextBoxWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.box.text) _controller.text = widget.box.text;
  }

  @override
  void dispose() {
    _controller.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: widget.box.rect.left,
    top: widget.box.rect.top,
    width: widget.box.rect.width,
    height: widget.box.rect.height,
    child: GestureDetector(
      onTap: widget.onEdit,
      onLongPress: widget.onEdit,
      onSecondaryTapUp: (details) async {
        final action = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx,
            details.globalPosition.dy,
          ),
          items: const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        );
        if (!mounted) return;
        if (action == 'edit') widget.onEdit();
        if (action == 'delete') widget.onDelete();
      },
      onPanUpdate: widget.readOnly
          ? null
          : (details) {
              widget.box.rect = widget.box.rect.shift(details.delta);
              widget.onChanged();
              setState(() {});
            },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: widget.editing
                ? BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : null,
            child: widget.editing
                ? TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLines: null,
                    expands: true,
                    onChanged: (value) {
                      widget.box.text = value;
                      widget.onChanged();
                    },
                    style: TextStyle(
                      fontFamily: widget.box.fontFamily,
                      fontSize: widget.box.fontSize,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Type text',
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  )
                : Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      widget.box.text,
                      style: TextStyle(
                        fontFamily: widget.box.fontFamily,
                        fontSize: widget.box.fontSize,
                      ),
                    ),
                  ),
          ),
          if (widget.editing) ...[
            Positioned(
              top: -42,
              left: 0,
              child: Material(
                elevation: 3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: _fonts.contains(widget.box.fontFamily)
                          ? widget.box.fontFamily
                          : _fonts.first,
                      items: _fonts
                          .map(
                            (font) => DropdownMenuItem(
                              value: font,
                              child: Text(font),
                            ),
                          )
                          .toList(),
                      onChanged: (font) {
                        if (font == null) return;
                        widget.box.fontFamily = font;
                        widget.onChanged();
                        setState(() {});
                      },
                    ),
                    SizedBox(
                      width: 52,
                      child: TextField(
                        controller: _sizeController,
                        keyboardType: TextInputType.number,
                        onSubmitted: (value) {
                          final size = double.tryParse(value);
                          if (size == null || size <= 0) return;
                          widget.box.fontSize = size;
                          widget.onChanged();
                          setState(() {});
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete text box',
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -8,
              bottom: -8,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  widget.box.rect = Rect.fromLTWH(
                    widget.box.rect.left,
                    widget.box.rect.top,
                    (widget.box.rect.width + details.delta.dx).clamp(80, 1200),
                    (widget.box.rect.height + details.delta.dy).clamp(40, 1200),
                  );
                  widget.onChanged();
                  setState(() {});
                },
                child: const Icon(Icons.open_in_full, size: 18),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
