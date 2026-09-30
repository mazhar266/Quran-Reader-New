"""Minimal WordprocessingML reader: explicit page and line breaks → text lines."""

import zipfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"


@dataclass
class DocxLine:
    text: str
    align: str | None  # w:jc of the paragraph: 'center', 'both', ...


def _paragraph_align(p) -> str | None:
    ppr = p.find(W + "pPr")
    if ppr is None:
        return None
    jc = ppr.find(W + "jc")
    return None if jc is None else jc.get(W + "val")


def read_pages(path: Path) -> list[list[DocxLine]]:
    """Returns pages of lines.

    ``<w:br w:type="page"/>`` starts a new page, a plain ``<w:br/>`` or the end
    of a paragraph ends a line. Empty text before a page break is dropped.
    """
    with zipfile.ZipFile(path) as z:
        root = ET.fromstring(z.read("word/document.xml"))
    body = root.find(W + "body")
    pages: list[list[DocxLine]] = [[]]
    for p in body.iter(W + "p"):
        align = _paragraph_align(p)
        buf: list[str] = []
        for el in p.iter():
            tag = el.tag
            if tag == W + "t":
                buf.append(el.text or "")
            elif tag == W + "tab":
                buf.append(" ")
            elif tag == W + "br":
                if el.get(W + "type") == "page":
                    if "".join(buf).strip():
                        pages[-1].append(DocxLine("".join(buf), align))
                    buf = []
                    pages.append([])
                else:
                    pages[-1].append(DocxLine("".join(buf), align))
                    buf = []
        pages[-1].append(DocxLine("".join(buf), align))
    # Drop empty lines (empty paragraphs, trailing breaks).
    return [[l for l in page if l.text.strip()] for page in pages]


def read_paragraphs(path: Path) -> list[DocxLine]:
    """One entry per paragraph (QUL per-page exports: one paragraph per line)."""
    with zipfile.ZipFile(path) as z:
        root = ET.fromstring(z.read("word/document.xml"))
    body = root.find(W + "body")
    out = []
    for p in body.iter(W + "p"):
        text = "".join(t.text or "" for t in p.iter(W + "t"))
        if text.strip():
            out.append(DocxLine(text, _paragraph_align(p)))
    return out
