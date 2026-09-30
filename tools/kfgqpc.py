"""KFGQPC riwayah packages → page lines and ayah rows (rendering mode 'unicode').

The whole-mushaf Word document of each package gives the exact 15-line
Madinah layout (explicit page and line breaks); the JSON data gives ayah
metadata (juz, plain text) and is used to validate the lines.
"""

import json
import re
from dataclasses import dataclass, field

from . import docx
from .extract import find_one, kfgqpc_package

RUB = "۞"  # ۞
NBSP = "\u00a0"
MARK_BASE = 0xFC00  # ayah n ↦ U+FC00 + n − 1

_DIGITS = re.compile(r"[ \u00a0]*([٠-٩]+)")
_SPLIT = re.compile(r" +")
_HEADER = re.compile(r"^سُورَةُ ")
# بسم, sometimes with a shadda on the ba (idgham with the previous surah end).
_BASMALA = re.compile("^\u0628[\u0650\u0651]+\u0633[\u06e1\u0652]\u0645\u0650 ")


@dataclass(frozen=True)
class Riwayah:
    id: str
    name: str
    name_ar: str
    zip: str
    font_src: str  # file under resources/qul/fonts/<name>/<name>
    font_asset: str  # file name under assets/fonts/
    family: str  # family declared in pubspec.yaml
    ayahs: int
    edition: str
    sort: int


RIWAYAT = [
    Riwayah("madinah_hafs", "Madinah Mushaf · Hafs", "مصحف المدينة · رواية حفص عن عاصم",
            "UthmanicHafs_v2-0.zip", "UthmanicHafs_V22.ttf", "KFGQPC-Hafs.ttf", "KFGQPC Hafs",
            6236, "Hafs ‘an ‘Āṣim · KFGQPC Uthmanic Hafs v2.0 text, font v2.2", 10),
    Riwayah("madinah_warsh", "Madinah Mushaf · Warsh", "مصحف المدينة · رواية ورش عن نافع",
            "UthmanicWarsh_v2-1.zip", "uthmanic-warsh-v21.ttf", "KFGQPC-Warsh.ttf", "KFGQPC Warsh",
            6214, "Warsh ‘an Nāfi‘ · KFGQPC Uthmanic Warsh v2.1", 20),
    Riwayah("madinah_qaloun", "Madinah Mushaf · Qaloun", "مصحف المدينة · رواية قالون عن نافع",
            "UthmanicQaloun_v2-1.zip", "uthmanic-qaloun-v21.ttf", "KFGQPC-Qaloun.ttf", "KFGQPC Qaloun",
            6214, "Qālūn ‘an Nāfi‘ · KFGQPC Uthmanic Qaloun v2.1", 30),
    Riwayah("madinah_douri", "Madinah Mushaf · Douri", "مصحف المدينة · رواية الدوري عن أبي عمرو",
            "UthmanicDouri_v2-0.zip", "uthmanic-douri-v20.ttf", "KFGQPC-Douri.ttf", "KFGQPC Douri",
            6217, "al-Dūrī ‘an Abī ‘Amr · KFGQPC Uthmanic Douri v2.0", 40),
    Riwayah("madinah_shuba", "Madinah Mushaf · Shu'bah", "مصحف المدينة · رواية شعبة عن عاصم",
            "UthmanicShuba_v2-0.zip", "uthmanic-shuba-v20.ttf", "KFGQPC-Shuba.ttf", "KFGQPC Shuba",
            6236, "Shu‘bah ‘an ‘Āṣim · KFGQPC Uthmanic Shuba v2.0", 50),
    Riwayah("madinah_sousi", "Madinah Mushaf · Sousi", "مصحف المدينة · رواية السوسي عن أبي عمرو",
            "UthmanicSousi_v2-0.zip", "uthmanic-sousi-v20.ttf", "KFGQPC-Sousi.ttf", "KFGQPC Sousi",
            6217, "al-Sūsī ‘an Abī ‘Amr · KFGQPC Uthmanic Sousi v2.0", 60),
]


@dataclass
class Line:
    page: int
    line: int
    kind: str  # 'ayah' | 'surah' | 'basmala'
    centered: bool
    surah: int | None
    text: str
    first: tuple[int, int] | None = None  # (surah, ayah)
    last: tuple[int, int] | None = None


@dataclass
class Ayah:
    surah: int
    ayah: int
    juz: int
    text: str
    text_plain: str
    page: int = 0
    line_start: int = 0
    page_end: int = 0
    line_end: int = 0
    tokens: list[str] = field(default_factory=list)


def mark(n: int) -> str:
    return chr(MARK_BASE + n - 1)


def mark_number(token: str) -> int | None:
    """Ayah number if the token ends with an ayah mark (``word\u00a0<mark>``)."""
    last = ord(token[-1])
    if MARK_BASE <= last <= MARK_BASE + 285:
        return last - MARK_BASE + 1
    return None


def tokens(text: str) -> list[str]:
    return [t for t in _SPLIT.split(text.strip(" ")) if t]


def normalise_token(t: str) -> str:
    """Comparison form: without the rub' ornament and invisible marks."""
    return t.replace(RUB + NBSP, "").replace(RUB, "").replace("\u200f", "").replace("\u200d", "")


_STRIP = re.compile(
    "[ؐ-ًؚ-ٰٟۖ-ۭـ\u200d\u200f"
    + chr(MARK_BASE) + "-" + chr(MARK_BASE + 285) + "]"
)


def plain(text: str) -> str:
    """Diacritics-free fallback spelling for riwayat without an imla'i column."""
    t = text.replace(RUB, " ").replace(NBSP, " ").replace("ٱ", "ا")
    t = _STRIP.sub("", t)
    return re.sub(r"\s+", " ", t).strip()


def _convert_numbers(text: str) -> str:
    def repl(m: re.Match) -> str:
        n = int("".join(str(ord(c) - 0x0660) for c in m.group(1)))
        return NBSP + mark(n)

    return _DIGITS.sub(repl, text).strip(" ")


def load_json(r: Riwayah) -> tuple[list[Ayah], list[dict]]:
    pkg = kfgqpc_package(r.zip)
    rows = json.loads(find_one(pkg, "*.json").read_text(encoding="utf-8-sig"))
    ayahs = []
    for row in rows:
        text = row["aya_text"].strip(" ")
        # 2:286 in some packages has a plain space before its mark.
        text = re.sub(" +([" + chr(MARK_BASE) + "-" + chr(MARK_BASE + 285) + "])$", NBSP + r"\1", text)
        n = int(row["aya_no"])
        if mark_number(text) != n:
            # One Shu'bah row lacks its mark.
            text = text + NBSP + mark(n)
        text_plain = row.get("aya_text_emlaey") or plain(text)
        a = Ayah(int(row["sura_no"]), n, int(row["jozz"]), text, text_plain.strip())
        a.tokens = [normalise_token(t) for t in tokens(text)]
        a.tokens = [t for t in a.tokens if t]
        ayahs.append(a)
    return ayahs, rows


def load_lines(r: Riwayah) -> list[Line]:
    pkg = kfgqpc_package(r.zip)
    pages = docx.read_pages(find_one(pkg, "*.docx"))
    out: list[Line] = []
    surah = 0
    for pi, page in enumerate(pages, start=1):
        for li, dl in enumerate(page, start=1):
            raw = dl.text.strip(" ")
            centered = dl.align == "center"
            has_number = bool(re.search("[٠-٩]", raw))
            if centered and not has_number and _HEADER.match(raw):
                surah += 1
                out.append(Line(pi, li, "surah", True, surah, raw))
            elif centered and not has_number and _BASMALA.match(raw) and out and out[-1].kind == "surah":
                out.append(Line(pi, li, "basmala", True, surah, raw))
            else:
                out.append(Line(pi, li, "ayah", centered, None, _convert_numbers(raw)))
    return out


def assign_ayahs(lines: list[Line], ayahs: list[Ayah]) -> list[str]:
    """Sets first/last ayah keys on ayah lines and page/line spans on ayahs.

    Returns a list of problems (empty when the docx agrees with the JSON).
    """
    by_key = {(a.surah, a.ayah): a for a in ayahs}
    problems: list[str] = []
    seen: dict[tuple[int, int], list[str]] = {}
    surah, ayah = 0, 1
    for ln in lines:
        if ln.kind == "surah":
            surah, ayah = ln.surah, 1
            continue
        if ln.kind == "basmala":
            continue
        ln.first = (surah, ayah)
        for t in tokens(ln.text):
            key = (surah, ayah)
            a = by_key.get(key)
            if a is None:
                problems.append(f"p{ln.page} l{ln.line}: unknown ayah {key}")
                continue
            if not a.page:
                a.page, a.line_start = ln.page, ln.line
            a.page_end, a.line_end = ln.page, ln.line
            nt = normalise_token(t)
            if nt:
                seen.setdefault(key, []).append(nt)
            n = mark_number(t)
            if n is not None:
                if n != ayah:
                    problems.append(f"p{ln.page} l{ln.line}: mark {n} while expecting {key}")
                ln.last = (surah, n)
                ayah = n + 1
            else:
                ln.last = (surah, ayah)
    for a in ayahs:
        got = seen.get((a.surah, a.ayah))
        if got != a.tokens:
            if got is None or len(got) != len(a.tokens):
                problems.append(f"{a.surah}:{a.ayah} token count docx {len(got or [])} json {len(a.tokens)}")
            else:
                diff = sum(1 for x, y in zip(got, a.tokens) if x != y)
                problems.append(f"{a.surah}:{a.ayah} {diff} token(s) spelled differently")
    return problems
