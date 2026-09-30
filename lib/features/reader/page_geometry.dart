import 'dart:math' as math;

import '../../core/prefs/settings.dart';
import '../../domain/models.dart';

/// Font size and line pitch of a page laid out in a given box (plan §3.4).
class PageGeometry {
  const PageGeometry({
    required this.fontSize,
    required this.pitch,
    required this.textWidth,
    required this.contentHeight,
  });

  /// Computes the geometry for [mushaf] in a text area of [width] × [height].
  ///
  /// `fontSize = width / K` fills the width. With [FitMode.page] the font is
  /// also limited so that all lines fit the height at the minimum pitch
  /// `L × fontSize`. The remaining height spreads the lines apart, up to
  /// [maxPitch] em, like the generous leading of a printed page.
  factory PageGeometry.of(Mushaf mushaf, double width, double height, FitMode fit) {
    final lines = mushaf.linesPerPage;
    var fontSize = width / mushaf.fontScale;
    if (fit == FitMode.page) {
      fontSize = math.min(fontSize, height / (lines * mushaf.lineScale));
    }
    final minPitch = fontSize * mushaf.lineScale;
    final pitch = math.max(minPitch, math.min(height / lines, fontSize * maxPitch));
    return PageGeometry(
      fontSize: fontSize,
      pitch: pitch,
      textWidth: math.min(width, fontSize * mushaf.fontScale),
      contentHeight: pitch * lines,
    );
  }

  static const maxPitch = 3.0;

  final double fontSize;

  /// Distance between line slots.
  final double pitch;

  /// Width that justified lines fill.
  final double textWidth;

  /// Height of all line slots together.
  final double contentHeight;
}
