import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../domain/quran_text.dart';

/// One printed line of a mushaf page.
///
/// Flutter never justifies the last line of a paragraph, and every printed
/// line is a one-line paragraph, so this widget lays the words out itself:
/// each word is shaped on its own (Arabic shaping never crosses a space) and
/// the slack is shared evenly between the words, right to left. A line that
/// is naturally wider than the box is squeezed horizontally instead of
/// wrapping, so line breaks always match the print.
class QuranLine extends LeafRenderObjectWidget {
  const QuranLine({
    super.key,
    required this.text,
    required this.style,
    required this.height,
    this.centered = false,
    this.highlight = const {},
    this.highlightColor = const Color(0x00000000),
    this.onLongPressWord,
  });

  final String text;

  /// Font family, size and colour of the words.
  final TextStyle style;

  /// Height of the line slot; the text is centred vertically in it.
  final double height;
  final bool centered;

  /// Indexes (into [lineWords]) of words painted with [highlightColor] behind.
  final Set<int> highlight;
  final Color highlightColor;
  final ValueChanged<int>? onLongPressWord;

  @override
  RenderQuranLine createRenderObject(BuildContext context) => RenderQuranLine(
    text: text,
    style: style,
    lineHeight: height,
    centered: centered,
    highlight: highlight,
    highlightColor: highlightColor,
    onLongPressWord: onLongPressWord,
  );

  @override
  void updateRenderObject(BuildContext context, RenderQuranLine renderObject) {
    renderObject
      ..text = text
      ..style = style
      ..lineHeight = height
      ..centered = centered
      ..highlight = highlight
      ..highlightColor = highlightColor
      ..onLongPressWord = onLongPressWord;
  }
}

class RenderQuranLine extends RenderBox {
  RenderQuranLine({
    required this._text,
    required this._style,
    required this._lineHeight,
    required this._centered,
    required this._highlight,
    required this._highlightColor,
    this._onLongPressWord,
  });

  String _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    _disposePainters();
    markNeedsLayout();
  }

  TextStyle _style;
  set style(TextStyle value) {
    if (value == _style) return;
    final layoutChanged = value.fontFamily != _style.fontFamily || value.fontSize != _style.fontSize;
    _style = value;
    _disposePainters();
    layoutChanged ? markNeedsLayout() : markNeedsPaint();
  }

  double _lineHeight;
  set lineHeight(double value) {
    if (value == _lineHeight) return;
    _lineHeight = value;
    markNeedsLayout();
  }

  bool _centered;
  set centered(bool value) {
    if (value == _centered) return;
    _centered = value;
    markNeedsLayout();
  }

  Set<int> _highlight;
  set highlight(Set<int> value) {
    if (setEquals(value, _highlight)) return;
    _highlight = value;
    markNeedsPaint();
  }

  Color _highlightColor;
  set highlightColor(Color value) {
    if (value == _highlightColor) return;
    _highlightColor = value;
    markNeedsPaint();
  }

  ValueChanged<int>? _onLongPressWord;
  set onLongPressWord(ValueChanged<int>? value) => _onLongPressWord = value;

  List<TextPainter>? _painters;
  double _spaceWidth = 0;

  // Layout results, in unscaled coordinates.
  final List<double> _lefts = [];
  double _scaleX = 1;
  double _originX = 0;

  LongPressGestureRecognizer? _longPress;
  Offset? _pressPosition;

  List<TextPainter> get _words {
    if (_painters != null) return _painters!;
    TextPainter shape(String s) => TextPainter(
      text: TextSpan(text: s, style: _style),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
    )..layout();
    final space = shape(' ');
    _spaceWidth = space.width;
    space.dispose();
    return _painters = [for (final w in lineWords(_text)) shape(w)];
  }

  void _disposePainters() {
    for (final p in _painters ?? const <TextPainter>[]) {
      p.dispose();
    }
    _painters = null;
  }

  double get _naturalWidth {
    final words = _words;
    if (words.isEmpty) return 0;
    return words.fold<double>(0, (s, p) => s + p.width) + _spaceWidth * (words.length - 1);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _naturalWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => _naturalWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _lineHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _lineHeight;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(Size(constraints.hasBoundedWidth ? constraints.maxWidth : _naturalWidth, _lineHeight));

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    final words = _words;
    _lefts.clear();
    if (words.isEmpty) return;

    final width = size.width;
    final inked = words.fold<double>(0, (s, p) => s + p.width);
    final n = words.length;
    final minGap = _spaceWidth * 0.5;
    var gap = _spaceWidth;
    var used = inked + gap * (n - 1);
    _scaleX = 1;

    if (!_centered && n > 1) {
      gap = (width - inked) / (n - 1);
      if (gap < minGap) {
        gap = minGap;
        used = inked + gap * (n - 1);
        _scaleX = width / used;
      } else {
        used = width;
      }
    } else if (used > width) {
      _scaleX = width / used;
    }

    // Right-to-left: the first word touches the right edge of the used span,
    // which is centred in the box when the line is not justified.
    final span = used * _scaleX;
    _originX = width - (width - span) / 2;
    var x = used;
    for (final p in words) {
      x -= p.width;
      _lefts.add(x);
      x -= gap;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final words = _words;
    if (words.isEmpty) return;
    final canvas = context.canvas;
    final usedWidth = _lefts.isEmpty ? 0 : words.first.width + _lefts.first;
    canvas.save();
    canvas.translate(offset.dx + _originX - usedWidth * _scaleX, offset.dy);
    if (_scaleX != 1) canvas.scale(_scaleX, 1);
    final top = (size.height - words.first.height) / 2;
    if (_highlight.isNotEmpty) {
      final paint = Paint()..color = _highlightColor;
      final pad = _spaceWidth * 0.3;
      for (final i in _highlight) {
        if (i < 0 || i >= words.length) continue;
        final rect = Rect.fromLTWH(_lefts[i] - pad, 0, words[i].width + 2 * pad, size.height);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.height * 0.15)), paint);
      }
    }
    for (var i = 0; i < words.length; i++) {
      words[i].paint(canvas, Offset(_lefts[i], top));
    }
    canvas.restore();
  }

  /// Index of the word under [local] (a position inside this box), or -1.
  int wordIndexAt(Offset local) {
    final words = _words;
    if (words.isEmpty || _lefts.isEmpty) return -1;
    final usedWidth = words.first.width + _lefts.first;
    final x = (local.dx - (_originX - usedWidth * _scaleX)) / _scaleX;
    var best = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < words.length; i++) {
      final left = _lefts[i];
      final right = left + words[i].width;
      final d = x < left ? left - x : (x > right ? x - right : 0.0);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (_onLongPressWord == null) return;
    if (event is PointerDownEvent) {
      _pressPosition = entry.localPosition;
      _longPress ??= LongPressGestureRecognizer(debugOwner: this)
        ..onLongPress = () {
          final index = wordIndexAt(_pressPosition ?? Offset.zero);
          if (index >= 0) _onLongPressWord?.call(index);
        };
      _longPress!.addPointer(event);
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = _text
      ..textDirection = TextDirection.rtl;
  }

  @override
  void detach() {
    _longPress?.dispose();
    _longPress = null;
    super.detach();
  }

  @override
  void dispose() {
    _disposePainters();
    super.dispose();
  }

  @visibleForTesting
  double get scaleX => _scaleX;

  @visibleForTesting
  int get wordCount => _words.length;
}
