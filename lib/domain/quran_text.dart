/// Word segmentation of a printed line, shared by layout and hit-testing.
library;

final _arabicLetter = RegExp('[\u0621-\u064A\u0671-\u06D3\uF61F]');

/// KFGQPC ayah-end marks: ayah n is U+FC00 + n − 1.
bool _isUthmaniMark(int c) => c >= 0xFC00 && c <= 0xFD1D;

/// AlQuran IndoPak ayah-end circles and their annotated variants
/// (see tools/qul.py, `GABA_ENDS`).
bool _isIndopakMark(int c) =>
    (c >= 0xF500 && c <= 0xF61E) || (c >= 0xF631 && c <= 0xF63D) || (c >= 0xF681 && c <= 0xF693 && c != 0xF68F);

bool _isAyahEnd(int c) => _isUthmaniMark(c) || _isIndopakMark(c);

/// Splits a line into the units that justification spaces apart.
///
/// Words are separated by plain spaces (the ayah mark and the rub' ornament
/// are glued to their word with a no-break space). A token without any Arabic
/// letter (a detached pause sign or ayah circle in IndoPak text) stays with
/// the word before it so justification never pulls them apart.
List<String> lineWords(String text) {
  final out = <String>[];
  for (final token in text.split(' ')) {
    if (token.isEmpty) continue;
    if (out.isNotEmpty && !_arabicLetter.hasMatch(token)) {
      out[out.length - 1] = '${out.last} $token';
    } else {
      out.add(token);
    }
  }
  return out;
}

/// Number of ayah-end marks in [word].
int ayahEnds(String word) => word.runes.where(_isAyahEnd).length;
