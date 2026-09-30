import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Calligraphic surah header: the ornamental frame from `quran-common`
/// (U+E000) with the surah name glyph from `surah-name-v2` in its middle.
class SurahHeader extends StatelessWidget {
  const SurahHeader({
    super.key,
    required this.surah,
    required this.width,
    required this.height,
    required this.frameColor,
    required this.inkColor,
    this.basmala,
    this.basmalaStyle,
  });

  final int surah;
  final double width;
  final double height;
  final Color frameColor;
  final Color inkColor;

  /// When set, the basmala is drawn under the frame in the same slot
  /// (Indopak prints, where the basmala belongs to the surah heading).
  final String? basmala;
  final TextStyle? basmalaStyle;

  /// Advance of the frame glyph, in em.
  static const _frameAdvance = 8240 / 1024;

  /// `surah-name-v2` maps surah n to U+E000 + n, except surah 102 (U+E102).
  static String nameGlyph(int surah) => String.fromCharCode(surah == 102 ? 0xE102 : 0xE000 + surah);

  static const frameGlyph = '\uE000';

  @override
  Widget build(BuildContext context) {
    final frameHeight = basmala == null ? height : height * 0.58;
    final size = math.min(width * 0.98 / _frameAdvance, frameHeight * 0.92);
    final frame = SizedBox(
      width: width,
      height: frameHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            frameGlyph,
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontFamily: 'QuranCommon', fontSize: size, color: frameColor, height: 1),
          ),
          Text(
            nameGlyph(surah),
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontFamily: 'SurahNameV2', fontSize: size * 0.82, color: inkColor, height: 1),
          ),
        ],
      ),
    );
    if (basmala == null) return frame;
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          frame,
          Expanded(
            child: Center(
              child: Text(
                basmala!,
                textDirection: TextDirection.rtl,
                textScaler: TextScaler.noScaling,
                maxLines: 1,
                style: basmalaStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
