"""Line layout for the books: word units, kashida and justification.

A Python port of the app's rendering rules (lib/domain/quran_text.dart,
lib/domain/kashida.dart, lib/features/reader/quran_line.dart) so the books
and the app fill lines the same way: spaces grow a little, the rest of the
slack elongates letter joins with tatweel at each word's best kashida place.

All widths are in em; measurements come from HarfBuzz (Pillow + Raqm where
Pillow has it, uharfbuzz otherwise), which matches Chromium's shaping to
within 0.0003 em for these fonts.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

TATWEEL = "\u0640"
_LETTER = re.compile("[\u0621-\u064a\u0671-\u06d3\uf61f]")
_SPACING = re.compile("[\u0621-\u064a\u0660-\u0669\u0671-\u06d3\uf500-\uf61f]")

# ---------------------------------------------------------------- segmentation


def line_tokens(text: str) -> list[str]:
    """The line's space-separated tokens (ayah marks and the rub' ornament are
    glued to their word with U+00A0)."""
    return [t for t in text.split(" ") if t]


def token_groups(tokens: list[str]) -> list[list[int]]:
    """Token indices per justification unit: a token without an Arabic letter
    (a detached pause sign, an ayah marker) stays with the word before it."""
    groups: list[list[int]] = []
    for i, token in enumerate(tokens):
        if groups and not _LETTER.search(token):
            groups[-1].append(i)
        else:
            groups.append([i])
    return groups


def line_words(text: str) -> list[str]:
    """Justification units: words split on plain spaces; a token without an
    Arabic letter stays with the word before it."""
    tokens = line_tokens(text)
    return [" ".join(tokens[i] for i in g) for g in token_groups(tokens)]


def _is_ayah_end(c: int) -> bool:
    return (
        0xFC00 <= c <= 0xFD1D
        or 0xF500 <= c <= 0xF61E
        or 0xF631 <= c <= 0xF63D
        or (0xF681 <= c <= 0xF693 and c != 0xF68F)
    )


def ayah_ends(word: str) -> int:
    return sum(1 for ch in word if _is_ayah_end(ord(ch)))


def trailing_overhang(word: str) -> bool:
    """True when the word ends with a detached pause sign (IndoPak text writes
    some after a space), whose ink overhangs the word's advance."""
    space = word.rfind(" ")
    return space >= 0 and not _SPACING.search(word[space + 1 :])


# ---------------------------------------------------------------- kashida

_RIGHT = {
    0x0622, 0x0623, 0x0624, 0x0625, 0x0627, 0x0629, 0x062F, 0x0630, 0x0631, 0x0632, 0x0648,
    0x0671, 0x0672, 0x0673, 0x0675, 0x0676, 0x0677, 0x06C0, 0x06C3, 0x06C4, 0x06C5, 0x06C6,
    0x06C7, 0x06C8, 0x06C9, 0x06CA, 0x06CB, 0x06CD, 0x06CF, 0x06D2, 0x06D3, 0x06D5, 0x06EE, 0x06EF,
    0xF61F,
}
_LAM, _HEH = 0x0644, 0x0647
_ALEFS = {0x0622, 0x0623, 0x0625, 0x0627, 0x0671, 0x0672, 0x0673, 0x0675, 0xF61F}
_SEENS = {0x0633, 0x0634, 0x0635, 0x0636}
_BEFORE_FINAL_1 = {0x0629, 0x0647, 0x062F, 0x0630, 0x06C1, 0x06C3, 0x06D5}
_BEFORE_FINAL_2 = _ALEFS | {0x0637, 0x0638, 0x0644, 0x0643, 0x06A9, 0x06AF}


def _is_mark(c: int) -> bool:
    return (
        0x0610 <= c <= 0x061A
        or 0x064B <= c <= 0x065F
        or c == 0x0670
        or 0x06D6 <= c <= 0x06DC
        or 0x06DF <= c <= 0x06E4
        or c in (0x06E7, 0x06E8)
        or 0x06EA <= c <= 0x06ED
    )


def _joining(c: int) -> str:
    if _is_mark(c):
        return "mark"
    if c in _RIGHT or 0x0688 <= c <= 0x0699:
        return "right"
    if c == 0x0640:
        return "dual"
    if (
        (0x0620 <= c <= 0x064A and c not in (0x0621, 0x0640))
        or c in (0x066E, 0x066F, 0x06C1, 0x06C2, 0x06CC, 0x06CE, 0x06D0, 0x06D1, 0x06FF)
        or 0x0678 <= c <= 0x0687
        or 0x069A <= c <= 0x06BF
        or 0x06FA <= c <= 0x06FC
    ):
        return "dual"
    return "none"


@lru_cache(maxsize=None)
def kashida_points(word: str) -> tuple[tuple[int, int], ...]:
    """(offset, priority) places where tatweels may be inserted, best first.

    Priorities: 1 after seen/sad; 2 before a final ta marbuta/heh/dal; 3 before
    a final alef/tah/lam/kaf; 4 before another final letter; 5 inside the
    word. Never inside lam-alef or the lam-lam-heh of the name of Allah.
    """
    clusters: list[list[int]] = []  # [base, end]
    for i, ch in enumerate(word):
        c = ord(ch)
        if _joining(c) == "mark" and clusters:
            clusters[-1][1] = i + 1
        else:
            clusters.append([c, i + 1])
    bases = [c[0] for c in clusters]
    for i in range(len(bases) - 2):
        if bases[i] == _LAM and bases[i + 1] == _LAM and bases[i + 2] == _HEH:
            return ()
    last_letter = -1
    for i, (base, _) in enumerate(clusters):
        if _joining(base) in ("dual", "right"):
            last_letter = i
        elif last_letter >= 0:
            break
    points = []
    for i in range(len(clusters) - 1):
        a, b = clusters[i], clusters[i + 1]
        if _joining(a[0]) != "dual" or _joining(b[0]) not in ("dual", "right"):
            continue
        if a[0] == _LAM and b[0] in _ALEFS:
            continue
        if a[0] == 0x0640 or b[0] == 0x0640:
            continue
        final = i + 1 == last_letter
        if a[0] in _SEENS:
            p = 1
        elif final and b[0] in _BEFORE_FINAL_1:
            p = 2
        elif final and b[0] in _BEFORE_FINAL_2:
            p = 3
        elif final:
            p = 4
        else:
            p = 5
        points.append((a[1], p))
    points.sort(key=lambda x: (x[1], -x[0]))
    return tuple(points)


def kashida_shares(word: str, count: int) -> dict[int, int]:
    """How ``count`` tatweels are shared over the word's (up to two) best
    places: {offset: tatweels inserted there}."""
    points = kashida_points(word)
    if count <= 0 or not points:
        return {}
    shares = {points[0][0]: count if len(points) == 1 or count < 3 else (count + 1) // 2}
    if len(points) > 1 and count >= 3:
        shares[points[1][0]] = count // 2
    return shares


def elongate(word: str, count: int) -> str:
    """The word with ``count`` tatweels over its (up to two) best places."""
    out = word
    for offset, n in sorted(kashida_shares(word, count).items(), reverse=True):
        out = out[:offset] + TATWEEL * n + out[offset:]
    return out


def elongate_colours(colours: list, word: str, count: int) -> list:
    """Per-character colours of ``elongate(word, count)``: each inserted
    tatweel takes the colour of the letter it extends."""
    out = list(colours)
    for offset, n in sorted(kashida_shares(word, count).items(), reverse=True):
        out[offset:offset] = [out[offset - 1] if offset > 0 else None] * n
    return out


# ---------------------------------------------------------------- measurement


class _RaqmEngine:
    """HarfBuzz through Pillow + Raqm (Linux builds of Pillow)."""

    SIZE = 1000

    def __init__(self, font: Path):
        from PIL import ImageFont

        self.font = ImageFont.truetype(str(font), self.SIZE, layout_engine=ImageFont.Layout.RAQM)

    def width(self, text: str) -> float:
        return self.font.getlength(text, direction="rtl", language="ar") / self.SIZE


class _HarfBuzzEngine:
    """HarfBuzz through uharfbuzz (Pillow's Windows and macOS wheels lack Raqm)."""

    def __init__(self, font: Path):
        import uharfbuzz as hb

        self.hb = hb
        face = hb.Face(hb.Blob.from_file_path(str(font)))
        self.font = hb.Font(face)
        self.upem = face.upem

    def width(self, text: str) -> float:
        buf = self.hb.Buffer()
        buf.add_str(text)
        buf.direction = "rtl"
        buf.script = "Arab"
        buf.language = "ar"
        self.hb.shape(self.font, buf)
        return sum(p.x_advance for p in buf.glyph_positions) / self.upem


def _has_raqm() -> bool:
    try:
        from PIL import features

        return bool(features.check("raqm"))
    except ImportError:
        return False


class Measure:
    """Advance widths in em, cached, for one font file."""

    def __init__(self, font: Path):
        self.engine = _RaqmEngine(font) if _has_raqm() else _HarfBuzzEngine(font)
        self._cache: dict[str, float] = {}
        self.space = self.width(" ")
        self.tatweel = self.width(TATWEEL)

    def width(self, text: str) -> float:
        w = self._cache.get(text)
        if w is None:
            w = self._cache[text] = self.engine.width(text)
        return w


# ---------------------------------------------------------------- justification

MAX_KASHIDA_PER_WORD = 5


@dataclass
class Line:
    """A laid-out line: words (possibly elongated) and their right offsets."""

    words: list[str]
    widths: list[float]
    offsets: list[float] = field(default_factory=list)  # distance of each word's right edge from the line's right edge (em)
    scale: float = 1.0  # horizontal squeeze (< 1 for the rare too-wide line)
    kashida: int = 0
    colours: list[list | None] | None = None  # per word: per-character tajwid rule, or None

    @property
    def span(self) -> float:
        """Width of the laid-out line in em, before any squeeze."""
        return self.offsets[-1] + self.widths[-1] if self.words else 0.0


def justify(units: list[str], width: float, m: Measure, *, centered: bool = False, kashida: bool = True,
            right_inset: float = 0.0, colours: list[list | None] | None = None) -> Line:
    """Lays out ``units`` in a line ``width`` em wide.

    Justified lines grow their spaces by a quarter and fill the rest with
    kashida added in measured rounds (a tatweel adds less than its own advance
    where the letter before it flattens); a round that overshoots what the
    spaces can absorb is retried with fewer tatweels. A line too wide even
    with half spaces is squeezed horizontally. Centred lines keep normal
    spaces. ``right_inset`` keeps room at the line's left end (in RTL) for a
    detached pause sign's overhang. ``colours`` (per unit, per character) are
    carried onto the elongated words.
    """
    n = len(units)
    if n == 0:
        return Line([], [])
    width -= right_inset
    s = m.space
    words = list(units)
    widths = [m.width(w) for w in words]
    inked = sum(widths)
    added = 0
    counts = [0] * n
    if kashida and not centered and n > 1:
        target = width - inked - s * 1.25 * (n - 1)
        if target >= m.tatweel * 0.4:
            points = [kashida_points(w) for w in units]
            order = sorted((i for i in range(n) if points[i]), key=lambda i: points[i][0][1])
            limit = target + s * 0.5 * (n - 1)
            unit = m.tatweel * 0.6
            gained = 0.0
            for _ in range(6):
                add = int((target - gained) // unit)
                accepted = False
                while add > 0 and not accepted:
                    nxt = list(counts)
                    left = add
                    progress = True
                    while left and progress:
                        progress = False
                        for i in order:
                            if not left:
                                break
                            if nxt[i] < MAX_KASHIDA_PER_WORD:
                                nxt[i] += 1
                                left -= 1
                                progress = True
                    placed = sum(nxt) - sum(counts)
                    if placed == 0:
                        break
                    trial = [elongate(units[i], nxt[i]) if nxt[i] else units[i] for i in range(n)]
                    trial_w = [m.width(w) for w in trial]
                    after = sum(trial_w) - inked
                    if after > limit:
                        add = placed // 2
                        continue
                    accepted = True
                    if after > gained:
                        unit = (after - gained) / placed
                    counts, words, widths, gained = nxt, trial, trial_w, after
                if not accepted:
                    break
            added = sum(counts)

    total = sum(widths)
    gap = s
    used = total + gap * (n - 1)
    scale = 1.0
    if not centered and n > 1:
        gap = (width - total) / (n - 1)
        if gap < s * 0.5:
            gap = s * 0.5
            used = total + gap * (n - 1)
            scale = width / used
        else:
            used = width
    elif used > width:
        scale = width / used
    offsets = []
    x = 0.0
    for w in widths:
        offsets.append(x)
        x += w + gap
    line = Line(words, widths, offsets, scale, added)
    if colours is not None:
        line.colours = [None if c is None else elongate_colours(c, units[i], counts[i]) for i, c in enumerate(colours)]
    if centered or n == 1:
        # Centre the used span in the full width (offsets are from the right).
        shift = (width + right_inset - used * scale) / 2 / scale
        line.offsets = [o + shift for o in offsets]
    return line
