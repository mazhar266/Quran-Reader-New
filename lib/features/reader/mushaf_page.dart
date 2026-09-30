import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/prefs/settings.dart';
import '../../domain/models.dart';
import '../../domain/quran_text.dart';
import 'page_geometry.dart';
import 'quran_line.dart';
import 'surah_header.dart';

/// Arabic-Indic digits, as printed in the mushaf.
String arabicDigits(int n) => n.toString().split('').map((d) => String.fromCharCode(0x0660 + int.parse(d))).join();

/// The ayah each word of an ayah line belongs to.
List<AyahKey> wordAyahs(PageLine line) {
  final first = line.first;
  if (first == null || line.text == null) return const [];
  var ayah = first.ayah;
  return [
    for (final w in lineWords(line.text!))
      () {
        final key = AyahKey(first.surah, ayah);
        ayah += ayahEnds(w);
        return key;
      }(),
  ];
}

/// Renders one mushaf page, line by line, at the printed line breaks.
class MushafPageView extends StatelessWidget {
  const MushafPageView({
    super.key,
    required this.mushaf,
    required this.page,
    required this.palette,
    this.fit = FitMode.page,
    this.showInfo = true,
    this.kashida = true,
    this.highlight,
    this.onLongPressAyah,
  });

  final Mushaf mushaf;
  final MushafPage page;
  final PagePalette palette;
  final FitMode fit;
  final bool showInfo;

  /// Justify lines with kashida (see [QuranLine.kashida]).
  final bool kashida;

  /// Ayah drawn with a highlight behind its words.
  final AyahKey? highlight;
  final void Function(PageLine line, AyahKey ayah)? onLongPressAyah;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.paper,
      child: DefaultTextStyle(
        style: TextStyle(color: palette.ink),
        child: LayoutBuilder(
          builder: (context, c) {
            final hPad = (c.maxWidth * 0.02).clamp(4.0, 28.0);
            final infoHeight = showInfo ? (c.maxHeight * 0.045).clamp(16.0, 34.0) : 0.0;
            final vPad = (c.maxHeight * 0.012).clamp(4.0, 16.0);
            final areaWidth = c.maxWidth - 2 * hPad;
            final areaHeight = c.maxHeight - 2 * (infoHeight + vPad);
            final geo = PageGeometry.of(mushaf, areaWidth, areaHeight, fit);

            Widget block = _Lines(
              mushaf: mushaf,
              kashida: kashida,
              page: page,
              geo: geo,
              palette: palette,
              highlight: highlight,
              onLongPressAyah: onLongPressAyah,
            );
            if (geo.contentHeight > areaHeight + 0.5) {
              block = SingleChildScrollView(child: block);
            } else {
              block = Center(child: block);
            }
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              child: Column(
                children: [
                  if (showInfo) _TopInfo(page: page, height: infoHeight, width: geo.textWidth, palette: palette),
                  Expanded(child: block),
                  if (showInfo)
                    SizedBox(
                      height: infoHeight,
                      child: Center(
                        child: Text(
                          arabicDigits(page.page),
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: infoHeight * 0.55,
                            // The KFGQPC font draws page numbers in an ornament;
                            // it is bundled with every mushaf.
                            fontFamily: 'KFGQPC Hafs',
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopInfo extends StatelessWidget {
  const _TopInfo({required this.page, required this.height, required this.width, required this.palette});

  final MushafPage page;
  final double height;
  final double width;
  final PagePalette palette;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: palette.muted, fontSize: height * 0.8, height: 1);
    return SizedBox(
      height: height,
      width: width,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              SurahHeader.nameGlyph(page.surah),
              textScaler: TextScaler.noScaling,
              style: style.copyWith(fontFamily: 'SurahNameV2'),
            ),
            Text(
              String.fromCharCode(0xE000 + page.juz),
              textScaler: TextScaler.noScaling,
              style: style.copyWith(fontFamily: 'QuranCommon'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({
    required this.mushaf,
    required this.kashida,
    required this.page,
    required this.geo,
    required this.palette,
    required this.highlight,
    required this.onLongPressAyah,
  });

  final Mushaf mushaf;
  final bool kashida;
  final MushafPage page;
  final PageGeometry geo;
  final PagePalette palette;
  final AyahKey? highlight;
  final void Function(PageLine line, AyahKey ayah)? onLongPressAyah;

  @override
  Widget build(BuildContext context) {
    final lines = page.lines;
    final lastSlot = lines.fold<int>(0, (m, l) => math.max(m, l.line));
    var fontSize = geo.fontSize;
    var pitch = geo.pitch;
    var top = 0.0;
    if (page.page <= 2) {
      // The opening pages hold a few lines in a decorated block. Where they
      // are all short centred lines (Madinah prints), set them as large as
      // the screen allows; then centre the block vertically.
      final allCentered = lines.every((l) => l.kind != LineKind.ayah || l.centered);
      if (allCentered) {
        final widest = lines
            .where((l) => l.kind != LineKind.surah)
            .map((l) => _naturalWidth(l.text ?? mushaf.basmala, fontSize))
            .fold<double>(1, math.max);
        final byWidth = fontSize * geo.textWidth * 0.94 / widest;
        final byHeight = geo.contentHeight / lastSlot / mushaf.lineScale;
        fontSize = math.max(fontSize, math.min(byWidth, byHeight));
        pitch = math.min(geo.contentHeight / lastSlot, fontSize * PageGeometry.maxPitch);
      }
      top = (geo.contentHeight - pitch * lastSlot) / 2;
    }
    final style = TextStyle(fontFamily: mushaf.fontFamily, fontSize: fontSize, color: palette.ink);
    final highlightColor = palette.frame.withValues(alpha: palette.brightness == Brightness.dark ? 0.35 : 0.18);

    return SizedBox(
      width: geo.textWidth,
      height: geo.contentHeight,
      child: Stack(
        children: [
          for (final line in lines)
            Positioned(
              top: top + (line.line - 1) * pitch,
              left: 0,
              right: 0,
              height: pitch,
              child: _line(line, style, pitch, highlightColor),
            ),
        ],
      ),
    );
  }

  double _naturalWidth(String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: mushaf.fontFamily, fontSize: fontSize),
      ),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  Widget _line(PageLine line, TextStyle style, double pitch, Color highlightColor) {
    switch (line.kind) {
      case LineKind.surah:
        final hasBasmalaRow = page.lines.any((l) => l.kind == LineKind.basmala && l.surah == line.surah);
        final withBasmala = mushaf.headerBasmala && line.surah != 1 && line.surah != 9 && !hasBasmalaRow;
        return SurahHeader(
          surah: line.surah!,
          width: geo.textWidth,
          height: pitch,
          frameColor: palette.frame,
          inkColor: palette.ink,
          basmala: withBasmala ? mushaf.basmala : null,
          basmalaStyle: style.copyWith(fontSize: style.fontSize! * 0.8),
        );
      case LineKind.basmala:
        return QuranLine(text: line.text ?? mushaf.basmala, style: style, height: pitch, centered: true);
      case LineKind.ayah:
        final ayahs = wordAyahs(line);
        final highlighted = highlight == null
            ? const <int>{}
            : {
                for (var i = 0; i < ayahs.length; i++)
                  if (ayahs[i] == highlight) i,
              };
        return QuranLine(
          text: line.text ?? '',
          style: style,
          height: pitch,
          centered: line.centered,
          kashida: kashida,
          highlight: highlighted,
          highlightColor: highlightColor,
          onLongPressWord: onLongPressAyah == null || ayahs.isEmpty
              ? null
              : (i) => onLongPressAyah!(line, ayahs[math.min(i, ayahs.length - 1)]),
        );
    }
  }
}
