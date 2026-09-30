"""KFGQPC Hafs words ↔ QUL global word ids (1 … 83,668, ayah markers included).

KFGQPC and QUL segment the text identically except in four ayahs, where one
spells two words joined (or one word split). The override table below makes
the segmentations agree; ``build_words`` asserts the total afterwards.
"""

from dataclasses import dataclass

from .kfgqpc import NBSP, Ayah, mark_number, tokens

QUL_WORDS = 83_668

# (surah, ayah) → (token index, replacement words). An entry with two words
# splits one KFGQPC token; ``None`` merges the token with the next one.
OVERRIDES: dict[tuple[int, int], tuple[int, list[str] | None]] = {
    (15, 7): (0, ["لَّوۡ", "مَا"]),
    (27, 20): (3, ["مَا", "لِيَ"]),
    (36, 22): (0, ["وَمَا", "لِيَ"]),
    (37, 130): (2, None),  # إِلۡ يَاسِينَ is one QUL word
}


@dataclass
class Word:
    id: int
    surah: int
    ayah: int
    position: int  # 1-based within the ayah; the ayah marker comes last
    is_mark: bool
    text: str


def _split_mark(token: str) -> tuple[str, str | None]:
    if mark_number(token) is None:
        return token, None
    body, _, mark = token.rpartition(NBSP)
    return body, mark


def build_words(hafs: list[Ayah]) -> list[Word]:
    words: list[Word] = []
    for a in hafs:
        toks = tokens(a.text)
        if (a.surah, a.ayah) in OVERRIDES:
            i, repl = OVERRIDES[(a.surah, a.ayah)]
            if repl is None:
                toks[i : i + 2] = [toks[i] + " " + toks[i + 1]]
            else:
                toks[i : i + 1] = repl
        texts: list[tuple[str, bool]] = []
        for t in toks:
            body, mark = _split_mark(t)
            if body:
                texts.append((body, False))
            if mark:
                texts.append((mark, True))
        for pos, (text, is_mark) in enumerate(texts, start=1):
            words.append(Word(len(words) + 1, a.surah, a.ayah, pos, is_mark, text))
    if len(words) != QUL_WORDS:
        raise AssertionError(f"word table has {len(words)} words, QUL has {QUL_WORDS}")
    return words


def join_words(words: list[Word]) -> str:
    """Line text: words separated by spaces, ayah marks glued with a NBSP.

    A rub' ornament at the start of an ayah stays attached to its first word,
    exactly as in the KFGQPC data.
    """
    out = ""
    for w in words:
        if not out:
            out = w.text
        elif w.is_mark:
            out += NBSP + w.text
        else:
            out += " " + w.text
    return out
