"""Tajwid colours for the Hafs books.

Source: QUL's export of the KFGQPC "QPC Hafs tajweed" text
(``resources/qul/qpc-hafs-tajweed.json.zip``): every word of the Hafs mushaf
with inline ``<rule class=…>`` markup over the letters a rule applies to, in
18 classes. The palette is the standard one of quran.com and QUL (and of the
Quran Researcher app).

The annotated text is not encoded like the books' texts: KFGQPC Hafs v2.2 and
the IndoPak text of the Gaba print differ from it in the sukun and madd code
points, hamza forms, yeh / alef maqsura, zero-width joiners, and the IndoPak
print writes some small alefs out in full. So rules are moved onto each book's
own text letter by letter: both texts of an ayah are reduced to their base
letters, the two sequences are aligned, every annotated letter hands its rule
to the letter it aligns with, and the rule then colours that letter together
with the marks on it. Pause signs, ayah marks and ornaments stay black.
"""

from __future__ import annotations

import difflib
import json
import re
import zipfile
from dataclasses import dataclass

from ..paths import QUL
from .layout import ayah_ends, line_tokens

RESOURCE = QUL / "qpc-hafs-tajweed.json.zip"


@dataclass(frozen=True)
class Rule:
    slug: str
    name: str
    arabic: str
    colour: str
    counts: str = ""  # harakat the letter is held, where the rule prescribes a length


RULES = [
    Rule("ham_wasl", "Hamzat al-wasl", "همزة وصل", "#AAAAAA"),
    Rule("slnt", "Silent letter", "حرف لا ينطق", "#AAAAAA"),
    Rule("laam_shamsiyah", "Lam shamsiyyah", "لام شمسية", "#AAAAAA"),
    Rule("madda_normal", "Normal madd", "مد طبيعي", "#537FFF", "2"),
    Rule("madda_permissible", "Permissible madd", "مد جائز", "#4050FF", "2, 4 or 6"),
    Rule("madda_necessary", "Necessary madd", "مد لازم", "#000EBC", "6"),
    Rule("madda_obligatory_monfasel", "Obligatory madd, munfasil", "مد منفصل", "#2144C1", "4–5"),
    Rule("madda_obligatory_mottasel", "Obligatory madd, muttasil", "مد واجب متصل", "#2144C1", "4–5"),
    Rule("qalaqah", "Qalqalah", "قلقلة", "#DD0008"),
    Rule("ghunnah", "Ghunnah", "غنة", "#FF7E1E", "2"),
    Rule("ikhafa", "Ikhfa", "إخفاء", "#9400A8", "2"),
    Rule("ikhafa_shafawi", "Ikhfa shafawi", "إخفاء شفوي", "#D500B7", "2"),
    Rule("idgham_ghunnah", "Idgham with ghunnah", "إدغام بغنة", "#169200", "2"),
    Rule("idgham_wo_ghunnah", "Idgham without ghunnah", "إدغام بغير غنة", "#169200"),
    Rule("idgham_shafawi", "Idgham shafawi", "إدغام شفوي", "#58B800"),
    Rule("iqlab", "Iqlab", "إقلاب", "#26BFFD", "2"),
    Rule("idgham_mutajanisayn", "Idgham mutajanisayn", "إدغام متجانسين", "#00897B"),
    Rule("idgham_mutaqaribayn", "Idgham mutaqaribayn", "إدغام متقاربين", "#00695C"),
]
RULE_BY_SLUG = {r.slug: r for r in RULES}
COLOUR = {r.slug: r.colour for r in RULES}
MADD = {r.slug for r in RULES if r.slug.startswith("madda")}

# Legend rows (rules sharing a colour share a row): slugs, label, length.
LEGEND = [
    (("ham_wasl", "slnt", "laam_shamsiyah"), "Not pronounced", "hamzat al-wasl, silent letter, lam shamsiyyah"),
    (("madda_normal",), "Normal madd", "2 counts"),
    (("madda_permissible",), "Permissible madd", "2, 4 or 6 counts"),
    (("madda_obligatory_mottasel", "madda_obligatory_monfasel"), "Obligatory madd", "muttasil, munfasil · 4–5 counts"),
    (("madda_necessary",), "Necessary madd", "6 counts"),
    (("ghunnah",), "Ghunnah", "2 counts"),
    (("ikhafa",), "Ikhfa", "2 counts"),
    (("ikhafa_shafawi",), "Ikhfa shafawi", "2 counts"),
    (("iqlab",), "Iqlab", "2 counts"),
    (("idgham_ghunnah", "idgham_wo_ghunnah"), "Idgham", "with ghunnah, without ghunnah"),
    (("idgham_shafawi",), "Idgham shafawi", ""),
    (("idgham_mutajanisayn",), "Idgham mutajanisayn", ""),
    (("idgham_mutaqaribayn",), "Idgham mutaqaribayn", ""),
    (("qalaqah",), "Qalqalah", ""),
]


# ---------------------------------------------------------------- the annotation

# QUL mixes unquoted and quoted class attributes, rules nest, and one tag
# (13:37) carries a leaked tooltip attribute; one entity (&gt; in 32:3) is
# dropped before the offsets are counted.
_TAG = re.compile(r"<rule class=['\"]?([a-z_0-9]+)['\"]?[^>]*>|</rule>")
_ENTITY = re.compile(r"&[a-zA-Z]+;|&#\d+;")
_DIGITS = re.compile(r"[٠-٩]+")

Span = tuple[int, int, str]  # [start, end) in code points, rule


def parse(marked: str) -> tuple[str, list[Span]]:
    """Plain text and rule spans of one annotated word; nested rules come out
    inner first, so the first span covering a letter is the most specific."""
    marked = _ENTITY.sub("", marked)
    out, spans, stack, pos, last = [], [], [], 0, 0
    for m in _TAG.finditer(marked):
        head = marked[last : m.start()]
        out.append(head)
        pos += len(head)
        last = m.end()
        if m.group(1):
            stack.append((m.group(1), pos))
        elif stack:
            rule, start = stack.pop()
            spans.append((start, pos, rule))
    out.append(marked[last:])
    pos += len(marked) - last
    for rule, start in stack:  # unclosed: to the end of the word
        spans.append((start, pos, rule))
    return "".join(out), spans


def load_annotation(path=RESOURCE) -> dict[tuple[int, int], tuple[str, list[Span]]]:
    """Per ayah: its annotated words joined by spaces (the ayah number
    dropped) and the rule spans over that text."""
    with zipfile.ZipFile(path) as z:
        words = json.loads(z.read(z.namelist()[0]).decode("utf-8"))
    by_ayah: dict[tuple[int, int], list[tuple[int, str]]] = {}
    for key, w in words.items():
        s, a, n = (int(x) for x in key.split(":"))
        by_ayah.setdefault((s, a), []).append((n, w["text"]))
    out = {}
    for key, items in by_ayah.items():
        texts: list[str] = []
        spans: list[Span] = []
        pos = 0
        for _, marked in sorted(items):
            text, sp = parse(marked)
            if _DIGITS.fullmatch(text):
                continue
            if texts:
                pos += 1  # the joining space
            texts.append(text)
            spans.extend((a + pos, b + pos, r) for a, b, r in sp)
            pos += len(text)
        out[key] = (" ".join(texts), spans)
    return out


# ---------------------------------------------------------------- letters

# Letter shapes the two texts write differently, folded for the alignment.
_FOLD = str.maketrans({
    "ی": "ي", "ى": "ي", "ئ": "ي", "ٮ": "ي",  # yeh forms
    "ٱ": "ا", "أ": "ا", "إ": "ا", "آ": "ا", "": "ا",  # alefs
    "ؤ": "و", "ڪ": "ك", "ک": "ك", "ۃ": "ة", "ھ": "ه",
    "ہ": "ه",
})

# Signs that keep the ink colour inside a coloured word: pause signs, the
# rub' and sajdah ornaments, margin ornaments and annotations of the IndoPak font.
_NEUTRAL = {
    0x0614, 0x0615, 0x0617, 0x06D6, 0x06D7, 0x06D8, 0x06D9, 0x06DA, 0x06DB, 0x06DC, 0x06DE, 0x06E9,
    0x06EA, 0x06EB, 0x06EC, 0xF650, 0xF651, 0xF652, 0xF653, 0xF662, 0xF663, 0xF664, 0xF68F,
    0xE000, 0xE001, 0xE00E,
}


def is_letter(c: str) -> bool:
    o = ord(c)
    return (0x0621 <= o <= 0x064A and o != 0x0640) or o in (0x066E, 0x066F) or 0x0671 <= o <= 0x06D3 or o == 0xF61F


def _attaches(c: str) -> bool:
    """A mark or sign drawn on the letter before it."""
    o = ord(c)
    return (
        0x0610 <= o <= 0x061A
        or 0x064B <= o <= 0x065F
        or o == 0x0670
        or 0x06D6 <= o <= 0x06ED
        or o == 0x0640
        or o in (0x200B, 0x200C, 0x200D, 0x200F, 0xFEFF)
        or 0x08D3 <= o <= 0x08FF
        or (0xE000 <= o <= 0xF8FF and not ayah_ends(c) and o != 0xF61F)
    )


def transfer(annotated: str, spans: list[Span], text: str) -> tuple[list[str | None], dict]:
    """The rule on every character of ``text`` (a book's text of an ayah),
    from the rules on the letters of ``annotated`` (QUL's text of it).

    Returns the per-character rules and alignment figures: ``ratio`` of
    letters matched, ``lost`` annotated letters with a rule that found no
    letter, ``coloured`` letters of ``text``.
    """
    a_pos = [i for i, c in enumerate(annotated) if is_letter(c)]
    b_pos = [i for i, c in enumerate(text) if is_letter(c)]
    a_key, b_key = annotated.translate(_FOLD), text.translate(_FOLD)
    sm = difflib.SequenceMatcher(None, [a_key[i] for i in a_pos], [b_key[i] for i in b_pos], autojunk=False)

    # Rules on the annotated letters; inner spans come first and win.
    a_rule: list[str | None] = [None] * len(a_pos)
    for start, end, rule in spans:
        covered = [k for k, i in enumerate(a_pos) if start <= i < end]
        if not covered:  # marks only (a madd sign, a shadda): the letter they sit on
            k = next((k for k in range(len(a_pos) - 1, -1, -1) if a_pos[k] < start), None)
            if k is None:
                k = next((k for k, i in enumerate(a_pos) if i >= end), None)
            covered = [k] if k is not None else []
        for k in covered:
            if a_rule[k] is None:
                a_rule[k] = rule

    # Onto the book's letters.
    b_rule: list[str | None] = [None] * len(b_pos)
    matched_a = [False] * len(a_pos)
    matched_b = [False] * len(b_pos)
    aligned = 0
    for i, j, n in sm.get_matching_blocks():
        aligned += n
        for k in range(n):
            b_rule[j + k] = a_rule[i + k]
            matched_a[i + k] = matched_b[j + k] = True
    # A letter the annotation does not have (an alef the IndoPak print writes
    # out where the Madinah text has a small alef): a madd continues over it,
    # as does a rule that holds on both sides of it, within the same word.
    for j in range(len(b_pos)):
        if matched_b[j]:
            continue
        prev = next((k for k in range(j - 1, -1, -1) if matched_b[k]), None)
        nxt = next((k for k in range(j + 1, len(b_pos)) if matched_b[k]), None)
        pr = b_rule[prev] if prev is not None and " " not in text[b_pos[prev] : b_pos[j]] else None
        nr = b_rule[nxt] if nxt is not None and " " not in text[b_pos[j] : b_pos[nxt]] else None
        if pr is not None and (pr == nr or pr in MADD):
            b_rule[j] = pr

    # Letters to characters: a letter's marks share its colour.
    out: list[str | None] = [None] * len(text)
    current = None
    k = 0
    for i, c in enumerate(text):
        if is_letter(c):
            current = b_rule[k]
            k += 1
            out[i] = current
        elif _attaches(c):
            if ord(c) not in _NEUTRAL:
                out[i] = current
        else:
            current = None
    info = {
        "ratio": aligned / max(1, max(len(a_pos), len(b_pos))),
        "lost": sum(1 for k, r in enumerate(a_rule) if r and not matched_a[k]),
        "coloured": sum(1 for r in b_rule if r),
    }
    return out, info


# ---------------------------------------------------------------- per mushaf


class Tajweed:
    """Per-token colours of one mushaf's lines (``line_colours``) and of any
    text of an ayah (``text_colours``, used for the basmala rows)."""

    def __init__(self, content, mushaf_id: str):
        self.annotation = load_annotation()
        self._lines: dict[tuple[int, int], list[list[str | None] | None]] = {}
        self.stats: dict = {"ayahs": 0, "letters_coloured": 0, "letters_lost": 0, "weak_alignments": []}
        per_ayah: dict[tuple[int, int], list[tuple[int, int, int, str]]] = {}
        for r in content.lines(mushaf_id):
            if r["kind"] != "ayah" or not r["text"]:
                continue
            tokens = line_tokens(r["text"])
            self._lines[(r["page"], r["line"])] = [None] * len(tokens)
            key = (r["first_surah"], r["first_ayah"])
            for i, t in enumerate(tokens):
                per_ayah.setdefault(key, []).append((r["page"], r["line"], i, t))
                key = (key[0], key[1] + ayah_ends(t))
        for key, items in per_ayah.items():
            if key not in self.annotation:
                raise KeyError(f"no tajwid annotation for ayah {key}")
            cols, info = self._colours(" ".join(t for *_, t in items), key)
            for (page, line, i, _), c in zip(items, cols):
                self._lines[(page, line)][i] = c
            self.stats["letters_coloured"] += info["coloured"]
            self.stats["letters_lost"] += info["lost"]
            if info["ratio"] < 0.9:
                self.stats["weak_alignments"].append((key, round(info["ratio"], 2)))
        self.stats["ayahs"] = len(per_ayah)

    def _colours(self, text: str, key: tuple[int, int]) -> tuple[list[list[str | None]], dict]:
        annotated, spans = self.annotation[key]
        rules, info = transfer(annotated, spans, text)
        out, pos = [], 0
        for t in text.split(" "):
            if t:
                out.append(rules[pos : pos + len(t)])
            pos += len(t) + 1
        return out, info

    def line_colours(self, page: int, line: int) -> list[list[str | None] | None]:
        """Per token of the line (``line_tokens``), the rule on each character."""
        return self._lines[(page, line)]

    def text_colours(self, text: str, key: tuple[int, int]) -> list[list[str | None]]:
        """Per token of ``text``, which is the book's text of ayah ``key``."""
        return self._colours(text, key)[0]
