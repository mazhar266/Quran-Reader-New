/// Kashida (tatweel, U+0640) placement for justifying Arabic lines.
///
/// Printed mushafs fill a line by elongating the joins between letters rather
/// than by widening the spaces. [kashidaPoints] finds where a word may be
/// elongated without breaking its shaping, best places first, following the
/// usual Arabic justification priorities (after seen/sad, before a final
/// ta marbuta/heh/dal, before a final alef/lam/kaf, before other final
/// letters, then inside the word).
library;

const kashidaTatweel = '\u0640';

enum _Joining { dual, right, none, mark }

// Letters that join only to the letter before them (Unicode ArabicShaping "R").
const _rightJoining = {
  0x0622, 0x0623, 0x0624, 0x0625, 0x0627, 0x0629, 0x062F, 0x0630, 0x0631, 0x0632, 0x0648, //
  0x0671, 0x0672, 0x0673, 0x0675, 0x0676, 0x0677, 0x06C0, 0x06C3, 0x06C4, 0x06C5, 0x06C6, //
  0x06C7, 0x06C8, 0x06C9, 0x06CA, 0x06CB, 0x06CD, 0x06CF, 0x06D2, 0x06D3, 0x06D5, 0x06EE, 0x06EF,
  0xF61F, // IndoPak alif with wasla (AlQuran IndoPak private use)
};

bool _isMark(int c) =>
    (c >= 0x0610 && c <= 0x061A) ||
    (c >= 0x064B && c <= 0x065F) ||
    c == 0x0670 ||
    (c >= 0x06D6 && c <= 0x06DC) ||
    (c >= 0x06DF && c <= 0x06E4) ||
    c == 0x06E7 ||
    c == 0x06E8 ||
    (c >= 0x06EA && c <= 0x06ED);

_Joining _joining(int c) {
  if (_isMark(c)) return _Joining.mark;
  if (_rightJoining.contains(c) || (c >= 0x0688 && c <= 0x0699)) return _Joining.right;
  if (c == 0x0640) return _Joining.dual;
  if ((c >= 0x0620 && c <= 0x064A && c != 0x0621 && c != 0x0640) ||
      c == 0x066E ||
      c == 0x066F ||
      (c >= 0x0678 && c <= 0x0687) ||
      (c >= 0x069A && c <= 0x06BF) ||
      c == 0x06C1 ||
      c == 0x06C2 ||
      c == 0x06CC ||
      c == 0x06CE ||
      c == 0x06D0 ||
      c == 0x06D1 ||
      (c >= 0x06FA && c <= 0x06FC) ||
      c == 0x06FF) {
    return _Joining.dual;
  }
  return _Joining.none;
}

const _lam = 0x0644;
const _heh = 0x0647;
const _alefs = {0x0622, 0x0623, 0x0625, 0x0627, 0x0671, 0x0672, 0x0673, 0x0675, 0xF61F};
const _seens = {0x0633, 0x0634, 0x0635, 0x0636};
const _beforeFinal1 = {0x0629, 0x0647, 0x062F, 0x0630, 0x06C1, 0x06C3, 0x06D5};
const _beforeFinal2 = {..._alefs, 0x0637, 0x0638, 0x0644, 0x0643, 0x06A9, 0x06AF};

class _Cluster {
  _Cluster(this.base, this.start, this.end);

  final int base;
  final int start;

  /// Index just after the base letter and its marks.
  int end;
}

/// A place where a word may be elongated.
class KashidaPoint {
  const KashidaPoint(this.offset, this.priority);

  /// String offset at which tatweels are inserted.
  final int offset;

  /// 1 (best) … 5.
  final int priority;

  @override
  bool operator ==(Object other) => other is KashidaPoint && other.offset == offset && other.priority == priority;

  @override
  int get hashCode => Object.hash(offset, priority);

  @override
  String toString() => 'KashidaPoint($offset, p$priority)';
}

/// Places in [word] where tatweels may be inserted, best first.
List<KashidaPoint> kashidaPoints(String word) {
  final clusters = <_Cluster>[];
  for (var i = 0; i < word.length; i++) {
    final c = word.codeUnitAt(i);
    if (_joining(c) == _Joining.mark && clusters.isNotEmpty) {
      clusters.last.end = i + 1;
    } else {
      clusters.add(_Cluster(c, i, i + 1));
    }
  }

  // The lam-lam-heh of the name of Allah is one ligature: leave such words alone.
  final bases = [for (final c in clusters) c.base];
  for (var i = 0; i + 2 < bases.length; i++) {
    if (bases[i] == _lam && bases[i + 1] == _lam && bases[i + 2] == _heh) return const [];
  }

  // The last letter of the word proper (before an ayah mark or ornament).
  var lastLetter = -1;
  for (var i = 0; i < clusters.length; i++) {
    final j = _joining(clusters[i].base);
    if (j == _Joining.dual || j == _Joining.right) {
      lastLetter = i;
    } else if (lastLetter >= 0) {
      break;
    }
  }

  final points = <KashidaPoint>[];
  for (var i = 0; i + 1 < clusters.length; i++) {
    final a = clusters[i];
    final b = clusters[i + 1];
    if (_joining(a.base) != _Joining.dual) continue;
    final jb = _joining(b.base);
    if (jb != _Joining.dual && jb != _Joining.right) continue;
    if (a.base == _lam && _alefs.contains(b.base)) continue; // lam-alef ligature
    if (a.base == 0x0640 || b.base == 0x0640) continue; // already elongated
    final isFinal = i + 1 == lastLetter;
    final priority = _seens.contains(a.base)
        ? 1
        : isFinal && _beforeFinal1.contains(b.base)
        ? 2
        : isFinal && _beforeFinal2.contains(b.base)
        ? 3
        : isFinal
        ? 4
        : 5;
    points.add(KashidaPoint(a.end, priority));
  }
  // Best priority first; among equals, the later place (nearer the word end).
  points.sort((x, y) => x.priority != y.priority ? x.priority - y.priority : y.offset - x.offset);
  return points;
}

/// [word] with [count] tatweels spread over its best kashida points.
///
/// Up to two points are used; the better one gets the larger share.
String elongate(String word, int count, [List<KashidaPoint>? points]) {
  if (count <= 0) return word;
  final at = [for (final p in points ?? kashidaPoints(word)) p.offset];
  if (at.isEmpty) return word;
  final shares = <int, int>{at[0]: at.length == 1 || count < 3 ? count : (count + 1) ~/ 2};
  if (at.length > 1 && count >= 3) shares[at[1]] = count ~/ 2;
  final offsets = shares.keys.toList()..sort((a, b) => b - a);
  var out = word;
  for (final o in offsets) {
    out = out.substring(0, o) + kashidaTatweel * shares[o]! + out.substring(o);
  }
  return out;
}
