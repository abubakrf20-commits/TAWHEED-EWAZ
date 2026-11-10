# -*- coding: utf-8 -*-
"""«شرح ریاض الصالحین» — the six Word volumes -> one standalone database.

The edition is the full commentary of علامه محمد بن صالح العثیمین on ریاض
الصالحین (ترجمه و نگارش: محمد ابراهیم کیانی), printed in six volumes that carry
the whole book: **19 کتاب**, **372 باب** and every پانوشت of the translation.

This script reads all six volumes and writes one database with the same shape as
`taraghib.db`:

* `books`     — the edition itself: one row. The book's own chain (کتاب › باب)
               is not a second level of the app's فهرست, so the کتاب each باب
               belongs to travels in `chapters.part` instead — exactly what the
               حدیث sections' list draws a group header from.
* `chapters`  — one row per باب, `chapter_index` = 1..372 (what the reader
               fetches by), `printed_number` = the number the page prints.
* `hadiths`   — one row per narration, `arabic` = the Arabic matn, the Persian
               translation under it, and then the شرح, one paragraph per line.
               The number is continuous (1..N) because this edition restarts
               its own numbering in every باب and later volumes switch to the
               global numbering — neither is a usable row id.
* `preambles` — the verses and the translator's lines printed between a باب
               heading and its first narration.
* `footnotes` — every پانوشت of the Word file, anchored to the exact line of
               the text its marker sits on (`anchor_line`), so the reader prints
               it under its own text instead of collecting them at the end.
* `matter_sections` / `matter_paragraphs` — the front matter of the first
               volume: درآمدی بر کتاب, the two biographies and مقدمه‌ی مؤلف.

Volume furniture (covers, publisher footers, the tables of contents of all six
volumes, «پایان جلد») is dropped: it is the binding, not the book.

Usage:
    python tools/riyad_to_sqlite.py [--out-dir DIR]
"""

import argparse
import gzip
import os
import re
import shutil
import sys

from docx import Document

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from docx_book import BookDb, clean_note, para_text_refs, read_footnotes  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OUT = os.path.join(ROOT, "TAWHEED-EWAZ", "riyad")
SOURCES = [os.path.join(ROOT, f"sharh-reyaz-al-salehin-{n}-Word.docx")
           for n in range(1, 7)]

TOC_STYLES = {"toc 1", "toc 2"}
HEADING_STYLES = {"تیتر و ابواب", "تیتر دوم"}
BOOK_STYLES = {"کتاب", "کتاب ها"}

# «1- کتاب: ادب» — the edition numbers its kits 1..19 from the fourth volume.
BOOK_RE = re.compile(r"^\s*(\d{1,2})\s*[-\u2013\u2014]\s*کتاب\s*[:：]?\s*(.*)$")
# «84- باب: حیا …» — and five ببs that lost the word «باب» («223- امر به …»).
BAB_RE = re.compile(
    r"^\s*(\d{1,4})\s*[-\u2013\u2014]\s*(?:باب\s*[:：]?\s*)?(.*)$", re.S)
NUM_RE = re.compile(r"^\s*(\d{1,4})\s*[-\u2013\u2014]\s*(.*)$", re.S)
SEP_RE = re.compile(r"^[\s*\u066d\u2022.·]+$")
WS_RE = re.compile(r"[ \t\u00a0]+")
EMPTY_PARENS = re.compile(r"\(\s*\)")
REF_RE = re.compile(r"^\[[^\[\]]+\]$")
# a narration opens with its chain: «عَنْ أبي هريرة», «وعَنْ عائشة», «رواه
# البخاري», or the edition's «الثاني/الثالث …» continuations of one story.
MATN_OPEN = re.compile(
    r"^\s*(?:و?(?:ال)?\s*(?:عن|رواه)|(?:ال)?ثان[يىی]|(?:ال)?ثالث|"
    r"(?:ال)?رابع|(?:ال)?خامس|(?:ال)?سادس|(?:ال)?سابع|(?:ال)?ثامن|"
    r"(?:ال)?تاسع|(?:ال)?عاشر|(?:ال)?حادي\s*ع?شر)")
DIACRITICS = re.compile(r"[\u064B-\u065F\u0670\u0640\u06D6-\u06ED]")
# the four cover/publisher blocks the print edition repeats in every volume
PUBLISHER = ("mowahedin", "aqeedeh", "نظارت علمی", "گروه علمی فرهنگی",
             "بازنشر این کتاب", "منبع:", "تماس با ما", "کتابخانه الکترونیکی")

HONORIFICS = {
    "$": "رضي الله عنه",
    "&": "رضي الله عنها",
    "#": "رضي الله عنهم",
}


def clean(text):
    """A source line as it is read: no print footnote numbers, no symbols."""
    t = (text or "").replace("\u00a0", " ")
    t = EMPTY_PARENS.sub("", t)
    t = re.sub(r"\(\s*\d{1,3}\s*\)", "", t)
    for sym, rep in HONORIFICS.items():
        t = re.sub(rf"(?<=[\u0600-\u06FF])\s*{re.escape(sym)}", f" {rep}", t)
        t = t.replace(sym, "")
    return WS_RE.sub(" ", t).strip()


def looks_like_matn(rest):
    return bool(MATN_OPEN.match(DIACRITICS.sub("", rest or "")))


def is_publisher_line(text):
    low = text.lower()
    return any(marker in low for marker in PUBLISHER)


class Builder:
    def __init__(self, db):
        self.db = db
        self.book_id = db.book(
            "شرح ریاض الصالحین",
            book_no=1,
            title_arabic="ریاض الصالحین",
            title_english="Riyad al-Salihin")
        self.kitab_no = None
        self.kitab_title = ""
        self.chapter = None
        self.entry = None
        self.matter = None
        self.seq = 0
        self.chapter_count = 0
        self.just_opened = False
        self.stats = {"chapters": 0, "hadiths": 0, "preambles": 0,
                      "footnotes": 0, "matter_sections": 0,
                      "matter_paras": 0, "dropped": [], "rejects": [],
                      "empty_chapters": []}

    # ── footnotes ────────────────────────────────────────────────────
    def add_footnote(self, *, text, printed, kind, volume, book_id=None,
                     chapter_id=None, hadith_id=None, section_id=None,
                     preamble_id=None, source_para=None, anchor_line=None,
                     order=0):
        note = clean_note(text)
        if not note:
            return
        self.db.footnote(
            text=note, anchor_kind=kind, volume=volume,
            footnote_no=str(printed) if printed else None,
            book_id=book_id, chapter_id=chapter_id, hadith_id=hadith_id,
            section_id=section_id, preamble_id=preamble_id,
            source_para=source_para, anchor_line=anchor_line, sort_order=order)
        self.stats["footnotes"] += 1

    # ── matter sections ─────────────────────────────────────────────
    def open_matter(self, key, title, volume):
        self.close_entry()
        sid = self.db.matter_section(key, "intro", title, volume=volume)
        self.matter = {"id": sid, "order": 0}
        self.stats["matter_sections"] += 1

    def add_matter_line(self, text, refs, volume, para):
        if self.matter is None:
            self.open_matter(f"intro_{self.stats['matter_sections'] + 1}",
                             "درآمد", volume)
        self.matter["order"] += 1
        order = self.matter["order"]
        self.db.matter_paragraph(self.matter["id"], order, text,
                                 source_para=para)
        self.stats["matter_paras"] += 1
        for nid, printed, note in refs:
            self.add_footnote(
                text=note, printed=printed, kind="intro", volume=volume,
                section_id=self.matter["id"], source_para=para, order=nid)

    # ── rows ─────────────────────────────────────────────────────────
    def open_kitab(self, number, title, refs, volume, para):
        self.close_entry()
        self.kitab_no = int(number) if number else None
        self.kitab_title = title.strip()
        for nid, printed, note in refs:
            self.add_footnote(
                text=note, printed=printed, kind="book_heading",
                volume=volume, book_id=self.book_id, source_para=para,
                order=nid)

    def open_chapter(self, printed, title, refs, volume, para):
        self.close_entry()
        self.chapter_count += 1
        part = ""
        if self.kitab_title:
            label = f"کتاب {self.kitab_no}" if self.kitab_no else "کتاب"
            part = f"{label}: {self.kitab_title}"
        cid = self.db.chapter(
            self.book_id, self.chapter_count, title or "باب",
            printed_number=int(printed) if printed else None,
            volume=volume, source_para=para, part=part or None, is_bab=1)
        self.chapter = {"id": cid, "printed": printed, "preambles": 0,
                        "narrations": 0, "title": title, "volume": volume}
        self.stats["chapters"] += 1
        self.just_opened = True
        for nid, printed_no, note in refs:
            self.add_footnote(
                text=note, printed=printed_no, kind="chapter_heading",
                volume=volume, book_id=self.book_id, chapter_id=cid,
                source_para=para, order=nid)

    def append_title(self, text):
        self.chapter["title"] = f"{self.chapter['title']} {text}".strip()
        self.db.con.execute(
            "UPDATE chapters SET name_persian = ? WHERE id = ?",
            (self.chapter["title"], self.chapter["id"]))

    def add_preamble(self, text, refs, volume, para):
        self.chapter["preambles"] += 1
        order = self.chapter["preambles"]
        pid = self.db.preamble(
            book_id=self.book_id, chapter_id=self.chapter["id"],
            volume=volume, kind="chapter_preamble", para_order=order,
            arabic=text, source_para=para)
        self.stats["preambles"] += 1
        for nid, printed, note in refs:
            self.add_footnote(
                text=note, printed=printed, kind="chapter_preamble",
                volume=volume, book_id=self.book_id,
                chapter_id=self.chapter["id"], preamble_id=pid,
                source_para=para, order=nid)

    def start_entry(self, number, first_line, refs, volume, para):
        self.close_entry()
        self.chapter["narrations"] += 1
        self.entry = {"number": number, "matn": first_line,
                      "matn_refs": refs, "pre": [], "post": [],
                      "sharh": False, "volume": volume, "source_para": para}

    def feed_body(self, text, refs):
        """A content line of the open narration: translation or شرح."""
        if not self.entry:
            return
        if text in ("شرح", "شرح:"):
            self.entry["sharh"] = True
            return
        target = self.entry["post"] if self.entry["sharh"] else self.entry["pre"]
        if (target and REF_RE.match(text) and len(text) < 45):
            # «[البقرة: ١٢٧]» printed on the line after its verse
            prev_text, prev_refs = target[-1]
            target[-1] = (f"{prev_text} {text}", prev_refs)
            return
        target.append((text, refs))

    def close_entry(self):
        e, self.entry = self.entry, None
        if e is None or self.chapter is None:
            return
        # assemble the reader's text: matn, translation, then the شرح
        out = [(e["matn"], e["matn_refs"])]
        if e["pre"]:
            out.append(("", []))
            out.extend(e["pre"])
        if e["post"]:
            out.append(("", []))
            out.append(("شرح و توضیح:", []))
            out.extend(e["post"])
        out = [(t, r) for t, r in out if t or r]
        if not out:
            return
        hid = self.db.hadith(
            self.book_id, e["number"], self.chapter["id"],
            "\n".join(t for t, _ in out), volume=e["volume"],
            source_para=e["source_para"])
        self.stats["hadiths"] += 1
        anchor = -1
        for line, refs in out:
            if not line:
                continue
            anchor += 1
            for nid, printed, note in refs:
                self.add_footnote(
                    text=note, printed=printed, kind="hadith",
                    volume=e["volume"], hadith_id=hid,
                    chapter_id=self.chapter["id"], book_id=self.book_id,
                    source_para=e["source_para"], anchor_line=anchor,
                    order=nid)

    # ── documents ────────────────────────────────────────────────────
    def parse_volume(self, volume, path, front_matter=False):
        doc = Document(path)
        notes = read_footnotes(path)
        # flatten to (text, style, notes, paragraph index); a paragraph may pack
        # several lines behind a soft break, and every line keeps the notes of
        # its own paragraph.
        flat = []
        for i, para in enumerate(doc.paragraphs):
            text, refs = para_text_refs(para._p)
            style = para.style.name if para.style is not None else ""
            here = [(nid, *notes[nid]) for _off, nid in refs if nid in notes]
            for line in text.split("\n"):
                flat.append((clean(line), style, here, i))

        # The volume's own فهرست is the only place the source states which
        # front-matter headings are top-level: «نکته‌ی اول» and «استادان او»
        # are paragraphs *inside* «درآمدی بر کتاب» / «زندگانی امام نووی», not
        # sections of their own.
        toc1 = {self._toc_title(t) for t, s, _r, _p in flat if s == "toc 1"}
        last_toc = max((i for i, (t, s, _r, _p) in enumerate(flat)
                        if s in TOC_STYLES), default=-1)
        for text, style, refs, para in flat[last_toc + 1:]:
            if not text:
                continue
            if style in TOC_STYLES:
                continue
            if is_publisher_line(text):
                continue
            if text == "فهرست مطالب":
                self.stats["dropped"].append((volume, para, text))
                continue
            if SEP_RE.match(text):
                # «***» ends a printed block, not the narration: the شرح of a
                # hadith continues past it (the editor separates passages, not
                # hadiths). Closing here moved that commentary to the top of
                # the باب as a notice, out of reading order.
                self.just_opened = False
                continue

            book = BOOK_RE.match(text)
            if book and style in BOOK_STYLES:
                self.open_kitab(book.group(1), book.group(2), refs, volume, para)
                self.just_opened = False
                continue

            bab = BAB_RE.match(text)
            if bab and style in HEADING_STYLES:
                self.open_chapter(bab.group(1), bab.group(2), refs, volume, para)
                continue

            if self.just_opened and style in HEADING_STYLES \
                    and len(text) < 200 and not NUM_RE.match(text) \
                    and not BAB_RE.match(text):
                # a باب title that wrapped onto the next paragraph
                self.append_title(text)
                self.just_opened = False
                continue

            if self.chapter is None:
                if front_matter:
                    if (style in HEADING_STYLES and len(text) < 120
                            and not NUM_RE.match(text)
                            and self._toc_title(text) in toc1):
                        self.open_matter(
                            f"intro_{self.stats['matter_sections'] + 1}",
                            text, volume)
                        continue
                    self.add_matter_line(text, refs, volume, para)
                continue

            self.just_opened = False
            num = NUM_RE.match(text)
            if num and self._starts_narration(num, style):
                self.seq += 1
                self.start_entry(self.seq, clean(num.group(2)), refs, volume,
                                 para)
                continue
            if self.entry is not None:
                self.feed_body(text, refs)
            else:
                self.add_preamble(text, refs, volume, para)

        self.close_entry()
        self.chapter = None

    @staticmethod
    def _toc_title(line):
        """A فهرست line without its page number, as the heading prints it."""
        return re.sub(r"\s*\t?\s*\d+\s*$", "", line or "").strip()

    def _starts_narration(self, num, style):
        digits = num.group(1)
        rest = clean(num.group(2))
        if not rest:
            return False
        if len(digits) <= 3 and (style == "احادیث" or looks_like_matn(rest)):
            return True
        if len(digits) > 3 or int(digits) >= 200:
            return looks_like_matn(rest)
        return False


def build(sources, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    raw = os.path.join(out_dir, "ryadalsalihin.db")
    db = BookDb(raw)
    b = Builder(db)
    for idx, path in enumerate(sources, 1):
        b.parse_volume(idx, path, front_matter=(idx == 1))
    b.close_entry()
    db.finalize()
    con = db.con

    books = con.execute("SELECT COUNT(*) FROM books").fetchone()[0]
    chapters = con.execute("SELECT COUNT(*) FROM chapters").fetchone()[0]
    hadiths = con.execute("SELECT COUNT(*) FROM hadiths").fetchone()[0]
    lo, hi = con.execute(
        "SELECT MIN(hadith_number), MAX(hadith_number) FROM hadiths").fetchone()
    # A volume opens on a باب before the first «کتاب» heading, so those rows
    # were written with no chain and the reader drew them without their
    # «کتاب N» label (83 of 372 in the first build). The printed order decides:
    # a باب that precedes its کتاب heading belongs to that کتاب, so each
    # unlabelled row borrows the label of the next labelled one in the file.
    unlabelled = con.execute(
        "SELECT COUNT(*) FROM chapters WHERE part IS NULL OR trim(part) = ''"
    ).fetchone()[0]
    if unlabelled:
        con.execute(
            "UPDATE chapters SET part = (SELECT c2.part FROM chapters c2 "
            "WHERE c2.chapter_index > chapters.chapter_index AND c2.part IS "
            "NOT NULL AND trim(c2.part) <> '' ORDER BY c2.chapter_index "
            "LIMIT 1) WHERE part IS NULL OR trim(part) = ''")
        # A tail left after the last labelled باب keeps the label of the last
        # chain it followed, never an empty one.
        con.execute(
            "UPDATE chapters SET part = (SELECT c2.part FROM chapters c2 "
            "WHERE c2.chapter_index < chapters.chapter_index AND c2.part IS "
            "NOT NULL AND trim(c2.part) <> '' ORDER BY c2.chapter_index "
            "DESC LIMIT 1) WHERE part IS NULL OR trim(part) = ''")
        left = con.execute(
            "SELECT COUNT(*) FROM chapters WHERE part IS NULL OR "
            "trim(part) = ''").fetchone()[0]
        print(f"chain      : {unlabelled} باب adopted its کتاب (left {left})")

    orphans = con.execute(
        "SELECT COUNT(*) FROM hadiths h LEFT JOIN chapters c ON c.id = "
        "h.chapter_id WHERE c.id IS NULL").fetchone()[0]
    bad_anchor = con.execute(
        "SELECT COUNT(*) FROM footnotes f JOIN hadiths h ON h.id = f.hadith_id "
        "WHERE f.anchor_line IS NOT NULL AND (f.anchor_line < 0 OR "
        "f.anchor_line >= length(h.arabic) - length(replace(h.arabic, "
        "char(10), '')) + 1)").fetchone()[0]
    empty = con.execute(
        "SELECT COUNT(*) FROM chapters c WHERE NOT EXISTS (SELECT 1 FROM "
        "hadiths h WHERE h.chapter_id = c.id)").fetchone()[0]
    fails = con.execute(
        "SELECT chapter_index, name_persian FROM chapters c WHERE NOT EXISTS "
        "(SELECT 1 FROM hadiths h WHERE h.chapter_id = c.id)").fetchall()
    assert orphans == 0, f"{orphans} orphan rows"
    assert bad_anchor == 0, f"{bad_anchor} footnotes outside their text"
    con.commit()
    con.close()

    gz = os.path.join(out_dir, "ryadalsalihin.db.gz")
    with open(raw, "rb") as fin, gzip.GzipFile(gz, "wb", compresslevel=9) as f:
        shutil.copyfileobj(fin, f)
    os.remove(raw)

    print(f"books      : {books}")
    print(f"chapters   : {chapters} ({empty} without a narration)")
    print(f"hadiths    : {hadiths} numbered {lo}..{hi}")
    print(f"preambles  : {b.stats['preambles']}")
    print(f"footnotes  : {b.stats['footnotes']}  (anchors inside their text)")
    print(f"matters    : {b.stats['matter_sections']} / "
          f"{b.stats['matter_paras']} paragraphs")
    print(f"dropped    : {len(b.stats['dropped'])} binding lines")
    if fails:
        print(f"empty babs : {fails}")
    print(f"written    : {gz} ({os.path.getsize(gz):,} bytes)")
    return b


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out-dir", default=DEFAULT_OUT)
    args = ap.parse_args()
    for src in SOURCES:
        if not os.path.exists(src):
            raise SystemExit(f"source not found: {src}")
    build(SOURCES, args.out_dir)


if __name__ == "__main__":
    main()
