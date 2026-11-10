# -*- coding: utf-8 -*-
"""Shared support for building the standalone hadith-book databases.

The databases built here follow the exact schema of the shipped
`taraghib/taraghib.db` (the 29-book edition the app reads as
کتاب → باب → حدیث, with its مقدمه/خاتمه sections, the publisher's notices
between a heading and its first entry, and every پانوشت stored with the text it
is printed against). `taraghib.db` is the reference: any database that answers
the same queries can be served by the same reader.

Two pieces live here:

* `read_footnotes()` / `para_text_refs()` — a Word document as a paragraph
  stream **with its footnote anchors intact**. Word keeps the notes in
  `word/footnotes.xml` and marks each anchor inside `word/document.xml` with
  `<w:footnoteReference w:id="N"/>`, so a paragraph carries a
  `(offset, note_id)` pair for every anchor and a note can be placed on the
  exact line of the text it marks.
* `BookDb` — the schema above, created in one place so three books cannot
  drift apart.
"""
import os
import sqlite3
import zipfile
from xml.etree import ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"

SCHEMA = """
PRAGMA journal_mode = DELETE;
PRAGMA encoding = 'UTF-8';

CREATE TABLE books (
  id INTEGER PRIMARY KEY,
  book_no INTEGER,
  sort_order INTEGER NOT NULL,
  title_arabic TEXT NOT NULL,
  title_persian TEXT NOT NULL,
  title_english TEXT NOT NULL,
  hadith_count INTEGER,
  chapter_count INTEGER,
  volume INTEGER,
  source_arabic_para INTEGER,
  source_para INTEGER,
  group_title TEXT
);

CREATE TABLE chapters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter_index INTEGER,
  printed_number INTEGER,
  name_arabic TEXT,
  name_persian TEXT,
  name_english TEXT,
  note TEXT,
  note_arabic TEXT,
  volume INTEGER,
  source_arabic_para INTEGER,
  source_para INTEGER,
  part TEXT,
  is_bab INTEGER,
  FOREIGN KEY (book_id) REFERENCES books(id)
);

CREATE TABLE hadiths (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  hadith_number INTEGER,
  chapter_id INTEGER,
  arabic TEXT NOT NULL,
  narrator_english TEXT,
  text_english TEXT,
  volume INTEGER,
  source_para INTEGER,
  FOREIGN KEY (book_id) REFERENCES books(id)
);

CREATE TABLE matter_sections (
  id INTEGER PRIMARY KEY,
  key TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  source_title TEXT,
  volume INTEGER,
  sort_order INTEGER NOT NULL
);

CREATE TABLE matter_paragraphs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  section_id INTEGER NOT NULL,
  para_order INTEGER NOT NULL,
  arabic TEXT NOT NULL,
  style TEXT,
  source_para INTEGER,
  source_ref TEXT,
  FOREIGN KEY (section_id) REFERENCES matter_sections(id)
);

CREATE TABLE footnotes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  footnote_no TEXT,
  text TEXT NOT NULL,
  volume INTEGER,
  anchor_kind TEXT NOT NULL,
  book_id INTEGER,
  chapter_id INTEGER,
  hadith_id INTEGER,
  section_id INTEGER,
  preamble_id INTEGER,
  source_para INTEGER,
  anchor_line INTEGER,
  sort_order INTEGER NOT NULL
);

CREATE TABLE preambles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER,
  chapter_id INTEGER,
  volume INTEGER,
  kind TEXT NOT NULL,
  heading_i0 INTEGER,
  para_order INTEGER NOT NULL,
  arabic TEXT NOT NULL,
  style TEXT,
  source_para INTEGER
);

CREATE INDEX idx_chapters_book ON chapters(book_id);
CREATE INDEX idx_hadiths_book ON hadiths(book_id);
CREATE INDEX idx_hadiths_chapter ON hadiths(chapter_id);
CREATE INDEX idx_hadiths_number ON hadiths(hadith_number);
CREATE INDEX idx_footnotes_book ON footnotes(book_id);
CREATE INDEX idx_footnotes_chapter ON footnotes(chapter_id);
CREATE INDEX idx_footnotes_hadith ON footnotes(hadith_id);
CREATE INDEX idx_footnotes_section ON footnotes(section_id);
CREATE INDEX idx_footnotes_preamble ON footnotes(preamble_id);
CREATE INDEX idx_matter_paragraphs_section ON matter_paragraphs(section_id);
CREATE INDEX idx_preambles_book ON preambles(book_id);
CREATE INDEX idx_preambles_chapter ON preambles(chapter_id);
"""


def para_text_refs(p_el):
    """`(text, [(offset, note_id), …])` of one `w:p` element."""
    out = []
    refs = []
    length = 0
    for el in p_el.iter():
        tag = el.tag
        if tag == W + "t":
            piece = el.text or ""
            out.append(piece)
            length += len(piece)
        elif tag == W + "tab":
            out.append("\t")
            length += 1
        elif tag == W + "br":
            out.append("\n")
            length += 1
        elif tag == W + "footnoteReference":
            refs.append((length, int(el.get(W + "id"))))
    return "".join(out), refs


def _note_text(node):
    out = []
    for el in node.iter():
        if el.tag == W + "t":
            out.append(el.text or "")
        elif el.tag == W + "br":
            out.append("\n")
    return "".join(out).strip()


def read_footnotes(path):
    """{note_id: (printed_no, text)} for one Word document.

    The separator/continuation pseudo notes Word always writes are dropped and
    `printed_no` counts the remaining notes in document order — the number the
    page prints beside the marker.
    """
    with zipfile.ZipFile(path) as z:
        if "word/footnotes.xml" not in z.namelist():
            return {}
        root = ET.fromstring(z.read("word/footnotes.xml"))
        notes = {}
        for node in root.iter(W + "footnote"):
            if node.get(W + "type") in ("separator", "continuationSeparator",
                                        "continuationNotice"):
                continue
            notes[int(node.get(W + "id"))] = _note_text(node)
    ordered = sorted(notes)
    printed = {nid: n for n, nid in enumerate(ordered, start=1)}
    return {nid: (printed[nid], notes[nid]) for nid in ordered}


def clean_note(text):
    """A پانوشت as it is printed: the leading dash bullet is a typing habit."""
    t = (text or "").replace("\u00a0", " ").strip()
    while t[:1] in ("-", "–", "—", "•"):
        t = t[1:].lstrip()
    t = t.replace("()", "")
    return " ".join(t.split())


class BookDb:
    """Thin writer for the schema above; every insert returns its row id."""

    def __init__(self, path):
        if os.path.exists(path):
            os.remove(path)
        self.con = sqlite3.connect(path)
        self.con.executescript(SCHEMA)
        self._book_order = 0
        self._section_order = 0

    def book(self, title_persian, *, book_no=None, volume=None,
             title_arabic="", title_english="", group_title=None,
             source_para=None):
        self._book_order += 1
        cur = self.con.execute(
            "INSERT INTO books (book_no, sort_order, title_arabic, "
            "title_persian, title_english, hadith_count, chapter_count, "
            "volume, source_arabic_para, source_para, group_title) "
            "VALUES (?,?,?,?,?,0,0,?,?,?,?)",
            (book_no, self._book_order, title_arabic, title_persian,
             title_english, volume, None, source_para, group_title))
        return cur.lastrowid

    def chapter(self, book_id, chapter_index, name_persian, *,
                printed_number=None, volume=None, source_para=None,
                name_arabic="", part=None, is_bab=1):
        """One فهرست row.

        `part` is the reader's only view of the book's own chain (مقصد › کتاب ›
        فصل) because the list has a single level: the section draws a group
        header whenever this label changes, so it must be written here rather
        than re-derived in the UI. `is_bab` separates a row the edition printed
        as a باب from a division heading that carries no باب (the section shows
        the second as a فصل). Both are nullable so a database built before they
        existed still opens — the reader falls back to «everything is a باب».
        """
        # These editions print one heading per division, and the callers pass it
        # in `name_persian`. The reader reads `name_arabic`, so an empty one
        # would list a blank باب — both columns name the same printed line.
        name_arabic = name_arabic or name_persian or ""
        cur = self.con.execute(
            "INSERT INTO chapters (book_id, chapter_index, printed_number, "
            "name_arabic, name_persian, name_english, note, note_arabic, "
            "volume, source_arabic_para, source_para, part, is_bab) "
            "VALUES (?,?,?,?,?,'',NULL,NULL,?,NULL,?,?,?)",
            (book_id, chapter_index, printed_number, name_arabic,
             name_persian, volume, source_para, part,
             1 if is_bab else 0))
        return cur.lastrowid

    def hadith(self, book_id, number, chapter_id, arabic, *, volume=None,
               source_para=None):
        cur = self.con.execute(
            "INSERT INTO hadiths (book_id, hadith_number, chapter_id, arabic, "
            "narrator_english, text_english, volume, source_para) "
            "VALUES (?,?,?,?,'','',?,?)",
            (book_id, number, chapter_id, arabic, volume, source_para))
        return cur.lastrowid

    def matter_section(self, key, kind, title, *, source_title=None,
                       volume=None):
        self._section_order += 1
        cur = self.con.execute(
            "INSERT INTO matter_sections (key, kind, title, source_title, "
            "volume, sort_order) VALUES (?,?,?,?,?,?)",
            (key, kind, title, source_title or title, volume,
             self._section_order * 10))
        return cur.lastrowid

    def matter_paragraph(self, section_id, order, arabic, *, style="",
                         source_para=None):
        cur = self.con.execute(
            "INSERT INTO matter_paragraphs (section_id, para_order, arabic, "
            "style, source_para, source_ref) VALUES (?,?,?,?,?,NULL)",
            (section_id, order, arabic, style, source_para))
        return cur.lastrowid

    def preamble(self, *, book_id=None, chapter_id=None, volume=None,
                 kind="chapter_preamble", heading_i0=None, para_order=1,
                 arabic="", style="", source_para=None):
        cur = self.con.execute(
            "INSERT INTO preambles (book_id, chapter_id, volume, kind, "
            "heading_i0, para_order, arabic, style, source_para) "
            "VALUES (?,?,?,?,?,?,?,?,?)",
            (book_id, chapter_id, volume, kind, heading_i0, para_order,
             arabic, style, source_para))
        return cur.lastrowid

    def footnote(self, *, text, anchor_kind, volume=None, footnote_no=None,
                 book_id=None, chapter_id=None, hadith_id=None,
                 section_id=None, preamble_id=None, source_para=None,
                 anchor_line=None, sort_order=0):
        self.con.execute(
            "INSERT INTO footnotes (footnote_no, text, volume, anchor_kind, "
            "book_id, chapter_id, hadith_id, section_id, preamble_id, "
            "source_para, anchor_line, sort_order) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (footnote_no, text, volume, anchor_kind, book_id, chapter_id,
             hadith_id, section_id, preamble_id, source_para, anchor_line,
             sort_order))

    def finalize(self):
        self.con.execute(
            "UPDATE books SET hadith_count = (SELECT COUNT(*) FROM hadiths h "
            "WHERE h.book_id = books.id), chapter_count = (SELECT COUNT(*) "
            "FROM chapters c WHERE c.book_id = books.id)")
        self.con.commit()

    def close(self):
        self.con.close()
