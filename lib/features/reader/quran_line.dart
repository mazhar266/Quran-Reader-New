import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../domain/kashida.dart';
import '../../domain/quran_text.dart';

/// One printed line of a mushaf page.
///
/// Flutter never justifies the last line of a paragraph, and every printed
/// line is a one-line paragraph, so this widget lays the words out itself:
/// each word is shaped on its own (Arabic shaping never crosses a space) and
/// placed right to left. A justified line is filled the way printed mushafs
/// do it: the spaces grow a little and the rest of the slack elongates the
/// joins between letters with kashida (tatweel), spread over the words'
/// best kashida places. A line that is naturally wider than the box first
/// tightens its spaces, then is squeezed horizontally instead of wrapping, so
/// line breaks always match the print.
class QuranLine extends LeafRenderObjectWidget {
  const QuranLine({
    super.key,
    required this.text,
    required this.style,
    required this.height,
    this.centered = false,
    this.kashida = true,
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

  /// Justify with kashida; when false only the spaces grow.
  final bool kashida;

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
    kashida: kashida,
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
      ..kashida = kashida
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
    required this._kashida,
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

  bool _kashida;
  set kashida(bool value) {
    if (value == _kashida) return;
    _kashida = value;
    _disposeJustified();
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
    _disposeJustified();
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

  List<String>? _texts;

  /// The words as written.
  List<TextPainter>? _painters;

  /// The words as painted: [_painters], with elongated copies of the words
  /// that received kashida for [_justifiedWidth].
  List<TextPainter>? _shown;
  final List<TextPainter> _elongated = [];
  double? _justifiedWidth;

  double _spaceWidth = 0;
  double _tatweelWidth = 0;

  // Layout results, in unscaled coordinates.
  final List<double> _lefts = [];
  double _scaleX = 1;
  double _originX = 0;

  LongPressGestureRecognizer? _longPress;
  Offset? _pressPosition;

  TextPainter _shape(String s) => TextPainter(
    text: TextSpan(text: s, style: _style),
    textDirection: TextDirection.rtl,
    textScaler: TextScaler.noScaling,
  )..layout();

  List<TextPainter> get _words {
    if (_painters != null) return _painters!;
    final space = _shape(' ');
    final tatweel = _shape(kashidaTatweel);
    _spaceWidth = space.width;
    _tatweelWidth = tatweel.width;
    space.dispose();
    tatweel.dispose();
    final texts = _texts = lineWords(_text);
    return _painters = [for (final w in texts) _shape(w)];
  }

  void _disposeJustified() {
    for (final p in _elongated) {
      p.dispose();
    }
    _elongated.clear();
    _shown = null;
    _justifiedWidth = null;
  }

  void _disposePainters() {
    _disposeJustified();
    for (final p in _painters ?? const <TextPainter>[]) {
      p.dispose();
    }
    _painters = null;
    _texts = null;
  }

  /// Words to paint in a box [width] wide, elongated with kashida if needed.
  ///
  /// A tatweel's width depends on the letters around it (the font switches a
  /// letter to a flatter joining form), so the kashida are added in rounds:
  /// each round measures what the previous one gained and tops up from that.
  List<TextPainter> _justify(double width) {
    final words = _words;
    if (_justifiedWidth == width && _shown != null) return _shown!;
    _disposeJustified();
    _justifiedWidth = width;
    final n = words.length;
    if (!_kashida || _centered || n < 2 || _tatweelWidth <= 0) return _shown = words;

    final inked = words.fold<double>(0, (s, p) => s + p.width);
    // The spaces take the first quarter-space of growth each; kashida the rest.
    final target = width - inked - _spaceWidth * 1.25 * (n - 1);
    if (target < _tatweelWidth * 0.4) return _shown = words;

    final texts = _texts!;
    final points = [for (final t in texts) kashidaPoints(t)];
    final order = [
      for (var i = 0; i < n; i++)
        if (points[i].isNotEmpty) i,
    ]..sort((a, b) => points[a].first.priority - points[b].first.priority);
    if (order.isEmpty) return _shown = words;

    var counts = List.filled(n, 0);
    var shaped = List.of(words);
    double gained(List<TextPainter> ws) => ws.fold<double>(0, (s, p) => s + p.width) - inked;
    // Overshoot the spaces can still absorb: they may shrink to 3/4 of normal.
    final limit = target + _spaceWidth * 0.5 * (n - 1);
    // Estimated width one more tatweel adds; a first tatweel usually adds
    // less than its own advance because the letter before it flattens.
    var unit = _tatweelWidth * 0.6;
    for (var round = 0; round < 6; round++) {
      final before = gained(shaped);
      var add = ((target - before) / unit).floor();
      var accepted = false;
      // A round that overshoots is retried with half as many tatweels.
      while (add > 0 && !accepted) {
        final next = _distribute(counts, order, add);
        final placed = next.fold<int>(0, (s, c) => s + c) - counts.fold<int>(0, (s, c) => s + c);
        if (placed == 0) break;
        final trial = [
          for (var i = 0; i < n; i++)
            if (next[i] == counts[i])
              shaped[i]
            else
              (_elongated..add(_shape(elongate(texts[i], next[i], points[i])))).last,
        ];
        final after = gained(trial);
        if (after > limit) {
          add = placed ~/ 2;
          continue;
        }
        accepted = true;
        counts = next;
        shaped = trial;
        if (after > before) unit = (after - before) / placed;
      }
      if (!accepted) break;
    }
    return _shown = shaped;
  }

  /// [counts] plus [add] tatweels dealt round-robin over [order] (best words
  /// first), so elongation is spread over the line.
  static List<int> _distribute(List<int> counts, List<int> order, int add) {
    final next = List.of(counts);
    for (var progress = true; add > 0 && progress;) {
      progress = false;
      for (final i in order) {
        if (add == 0) break;
        if (next[i] < maxKashidaPerWord) {
          next[i]++;
          add--;
          progress = true;
        }
      }
    }
    return next;
  }

  /// Most tatweels one word receives (about 1–1.5 em).
  static const maxKashidaPerWord = 5;

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
    _lefts.clear();
    if (_words.isEmpty) return;
    // Keep a pause sign that hangs off the last word inside the box.
    final width = size.width - _trailingOverhang;
    final words = _justify(width);
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
    _gap = gap;

    // Right-to-left: the first word touches the right edge of the used span,
    // which is centred in the box when the line is not justified.
    final span = used * _scaleX;
    _originX = size.width - (width - span) / 2;
    var x = used;
    for (final p in words) {
      x -= p.width;
      _lefts.add(x);
      x -= gap;
    }
  }

  /// Room for a detached pause sign ending the line (IndoPak text writes
  /// some after a space, so its ink overhangs the word's advance).
  double get _trailingOverhang {
    final last = _texts?.lastOrNull;
    final space = last?.lastIndexOf(' ') ?? -1;
    if (last == null || space < 0 || _spacing.hasMatch(last.substring(space + 1))) return 0;
    return (_style.fontSize ?? 14) * 0.3;
  }

  /// Characters with an advance of their own: letters, digits, ayah circles.
  static final _spacing = RegExp('[\u0621-\u064A\u0660-\u0669\u0671-\u06D3\uF500-\uF61F]');

  double _gap = 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    final words = _shown ?? const <TextPainter>[];
    if (words.isEmpty || _lefts.length != words.length) return;
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
    final words = _shown ?? const <TextPainter>[];
    if (words.isEmpty || _lefts.length != words.length) return -1;
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

  /// Space between words after justification, before any squeeze (tests).
  @visibleForTesting
  double get gap => _gap;

  /// Tatweels added to justify the line (tests).
  @visibleForTesting
  int get kashidaCount =>
      [for (final p in _shown ?? const <TextPainter>[]) (p.text! as TextSpan).text!]
          .join()
          .split('')
          .where((c) => c == kashidaTatweel)
          .length -
      _text.split('').where((c) => c == kashidaTatweel).length;
}
