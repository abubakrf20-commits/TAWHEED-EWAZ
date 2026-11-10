# -*- coding: utf-8 -*-
"""«معالم السنه النبویه» — the four Word volumes -> one standalone database.

The book is a summary of fourteen classical hadith collections
(جمع وترتیب: شیخ صالح أحمد الشامي · ترجمه وتعلیق: شاکر الذهبي), printed in four
volumes. This script reads **all four** and writes one database with the same
shape as `taraghib.db`:

    مقصد › کتاب › فصل › باب › حدیث

* `books`     — one row per «کتاب» division, with the مقصد it belongs to in
                `group_title`, so the list can paint the book's own structure.
* `chapters`  — one row per باب, `printed_number` = the number the page prints
                (it restarts every فصل), `chapter_index` = its place in the book
                (what the reader fetches by).
* `hadiths`   — one row per numbered narration, `arabic` = the Arabic matn and
                the Persian translation that follows it, one line each; the
                number is the continuous number the reader shows (1..N), because
                the printed numbering repeats and skips values.
* `preambles` — the translator's lines printed between a باب heading and its
                first narration.
* `footnotes` — every پانوشت of the Word file, anchored to the exact line of
                the text its marker sits on (`anchor_line`), so the reader
                prints it under its own text instead of collecting them at the
                end of the book.
* `matter_sections` / `matter_paragraphs` — مقدمه‌ی مترجم، مقدمه‌ی مؤلف،
                درآمدِ کتاب and the خاتمه, which are not numbered hadiths.

Volume-end furniture («پایان جلد (1)»، «پایان.»، «ختم مقصد …») and the tables of
contents are dropped: they are the binding, not the book.

Usage:
    python tools/maalim_to_sqlite.py [--out-dir DIR]
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
DEFAULT_OUT = os.path.join(ROOT, "TAWHEED-EWAZ", "maalim")
SOURCES = [os.path.join(ROOT, f"معالم السنه النبویه {n}.docx")
           for n in (1, 2, 3, 4)]

# The edition's own last number: its introduction promises 3,921 narrations
# across the four volumes, and the printed page numbers run 1..3921 (with gaps
# the source never printed and a handful of twice-printed numbers). A line that
# prints a number past this is a typo in the Word file — four of them exist
# (3963, 4225, 4329, 7334) — and takes the running position instead of moving
# the book's ceiling to 7334.
PRINTED_TOTAL = 3921

ORDINAL_WORD = {
    1: "اول", 2: "دوم", 3: "سوم", 4: "چهارم", 5: "پنجم", 6: "ششم",
    7: "هفتم", 8: "هشتم", 9: "نهم", 10: "دهم", 11: "یازدهم", 12: "دوازدهم",
    13: "سیزدهم", 14: "چهاردهم",
}

ORDINALS = {
    "اول": 1, "نخست": 1, "دوم": 2, "سوم": 3, "چهارم": 4, "پنجم": 5,
    "ششم": 6, "هفتم": 7, "هشتم": 8, "نهم": 9, "دهم": 10, "یازدهم": 11,
    "دوازدهم": 12, "سیزدهم": 13, "چهاردهم": 14, "پانزدهم": 15,
    "شانزدهم": 16, "هفدهم": 17, "هجدهم": 18, "نوزدهم": 19, "بیستم": 20,
}

TOC_LEADER = re.compile(r"\.{4,}\s*/\s*\d+\s*$")
HEAD_RE = re.compile(
    r"^\s*[\(（]?\s*(مقصد|کتاب|فصل)\s*([^:：)）]{0,24})[\)）]?\s*[:：]?\s*(.*)$")
BAB_RE = re.compile(r"^\s*(\d{1,4})\s*[-\u2013\u2014]\s*باب\s*[:：]?\s*(.*)$")
BAB_NONUM_RE = re.compile(r"^\s*باب\s*[:：]\s*(.+)$")
NUM_RE = re.compile(r"^\s*(\d{1,4})\s*([-\u2013\u2014.:\u0640])\s*(.*)$", re.S)
# «پایان.» alone closes a باب; «ختم/پایان کتاب|فصل|مقصد» closes a division;
# «پایان جلد …» closes a volume. None of them is book content.
CHAPTER_END_RE = re.compile(
    r"^\s*(?:پایان\s*\.?\s*$|(?:پایان|ختم)\s+فصل)")
BOOK_END_RE = re.compile(
    r"^\s*(?:ختم|پایان)\s+(?:کتاب|مقصد|جزء|الجزء|بخش)")
VOLUME_END_RE = re.compile(r"^\s*پایان\s*جلد")
TRANSLATION_END = re.compile(r"^\s*پایان\s*ترجمه")
SEP_RE = re.compile(r"^[\s*\u066d\u2022.·]+$")
WS_RE = re.compile(r"[ \t\u00a0]+")
EMPTY_PARENS = re.compile(r"\(\s*\)")
MATN_HINT = re.compile(
    r"^\s*(?:و?عن|قال|رواه|روى|أن|ان|حدثنا|حدثني|أخبرنا|اخبرنا|"
    r"الحديث|وفي|باب)")
TRANSLATION_HINT = re.compile(r"^\s*ترجمه")
DIACRITICS = re.compile(r"[\u064B-\u065F\u0670\u0640]")
TATWEEL = "\u0640"


def clean(text):
    t = EMPTY_PARENS.sub("", text or "")
    t = WS_RE.sub(" ", t).strip()
    return t


def squash(text):
    """A comparison key that ignores the Persian/Arabic letter variants."""
    t = text.replace("\u200c", " ").replace("ي", "ی").replace("ك", "ک")
    return " ".join(t.split())


def strip_quotes(title):
    t = title.strip()
    t = re.sub(r"^[«\"'\(\[]+", "", t)
    t = re.sub(r"[»\"'.،\)\]]+$", "", t)
    return t.strip()


def ordinal_of(word):
    return ORDINALS.get(word.strip(" .:："))


def is_toc(line):
    # فهرست entries end with a dotted leader and «/page»; a body line never does
    return bool(TOC_LEADER.search(line))


class Builder:
    def __init__(self, db, root_id):
        self.db = db
        # `books.id` of the single row this database holds — every chapter and
        # hadith of the edition hangs off it.
        self.root_id = root_id
        # One continuous فهرست: the edition's own «کتاب» divisions live in
        # `chapters.part`, so every باب of the whole book takes the next index.
        self.chapter_no = 0
        self.group_title = ""
        self.group_title_only = ""
        self.pending_group_no = ""
        self.group_pending_title = ""
        self.last_book_no = None
        self.book = None
        self.fasl = ""
        self.fasl_no = ""
        self.chapter = None
        self.entry = None
        self.matter = None
        self.last_no = 0
        self.last_printed = 0
        self.pending_pre = []
        self.group_notes = []     # a مقصد title's notes, handed to its first book
        self.orphan_refs = []     # notes parked before a chapter existed
        self.anomalies = []
        self.rejects = []
        self.stats = {"books": 0, "chapters": 0, "hadiths": 0,
                      "preambles": 0, "footnotes": 0, "matter_paras": 0,
                      "matter_sections": 0, "implicit_books": [],
                      "dropped": []}

    # ── flushing ─────────────────────────────────────────────────────
    def close_entry(self):
        e, self.entry = self.entry, None
        if e is None or self.chapter is None:
            return
        lines = [ln for ln, _ in e["lines"] if ln]
        if not lines:
            return
        # The row carries the number the page prints, not a running counter:
        # a reader looking for «حدیث ۱۰۶۸» must land on the same narration the
        # printed book numbers 1068. A number the source file skips stays
        # absent — the jump dialog says so — instead of renumbering its
        # neighbours and shifting every later reference.
        printed = e.get("printed")
        if not printed or printed < 1 or printed > PRINTED_TOTAL:
            printed = e["number"]
        hid = self.db.hadith(
            self.book["id"], printed,
            self.chapter["id"],
            "\n".join(lines), volume=e["volume"], source_para=e["source_para"])
        self.stats["hadiths"] += 1
        anchor = -1
        for text, refs in e["lines"]:
            if not text:
                continue
            anchor += 1
            for nid, printed, note in refs:
                self.add_footnote(
                    text=note, printed=printed, kind="hadith",
                    volume=e["volume"], hadith_id=hid,
                    chapter_id=self.chapter["id"], book_id=self.book["id"],
                    source_para=e["source_para"], anchor_line=anchor,
                    order=nid)

    def close_chapter(self):
        self.close_entry()
        self.chapter = None

    def close_book(self):
        self.close_chapter()
        self.book = None
        self.fasl = ""
        self.fasl_no = ""
        self.pending_pre = []

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

    # ── matter sections ──────────────────────────────────────────────
    def open_matter(self, key, title, volume, kind="intro"):
        self.close_book()
        sid = self.db.matter_section(key, kind, title, volume=volume)
        self.matter = {"id": sid, "order": 0, "kind": kind}
        self.stats["matter_sections"] += 1

    def add_matter_line(self, text, refs, volume, para_index):
        if self.matter is None:
            return
        self.matter["order"] += 1
        order = self.matter["order"]
        self.db.matter_paragraph(self.matter["id"], order, text,
                                 source_para=para_index)
        self.stats["matter_paras"] += 1
        for nid, printed, note in refs:
            self.add_footnote(
                text=note, printed=printed, kind=self.matter["kind"],
                volume=volume, section_id=self.matter["id"],
                source_para=order, order=nid)

    # ── documents ────────────────────────────────────────────────────
    def parse_volume(self, volume, path, skip_until=0):
        doc = Document(path)
        notes = read_footnotes(path)
        texts = []
        refs_by_i = []
        for p in doc.paragraphs:
            text, refs = para_text_refs(p._p)
            texts.append(clean(text))
            refs_by_i.append([(nid, *notes[nid]) for _off, nid in refs
                              if nid in notes])

        toc = [i for i, t in enumerate(texts) if t and is_toc(t)]
        start = (toc[-1] + 1) if toc else 0
        # Volume 1 opens with the translator's, the author's and the editor's
        # introductions, which `_parse_front_matter` has already written. Reading
        # them a second time here left their پانوشت‌ها with no chapter to hang
        # on, so the next باب adopted them — the first باب («ارکان اسلام و
        # ایمان») then showed a dozen مقدمه notes above its narrations.
        if skip_until > start:
            start = skip_until
        # The page prints a Persian translation under every narration, so a
        # numbered line followed by one is a narration even where the printed
        # number repeats or steps back (the source does both).
        next_text = [""] * len(texts)
        nxt = ""
        for i in range(len(texts) - 1, -1, -1):
            next_text[i] = nxt
            if texts[i]:
                nxt = texts[i]

        pending = None
        boundary = True
        for i in range(start, len(texts)):
            text = texts[i]
            if not text:
                continue
            if is_toc(text):
                continue
            if TRANSLATION_END.match(text):
                # The translation ends here; the translator's closing note is
                # خاتمه, not the last باب.
                self.close_book()
                self.open_matter("khatimah", "خاتمه", volume, kind="khatimah")
                boundary = True
                continue
            if VOLUME_END_RE.match(text) or CHAPTER_END_RE.match(text) or \
                    BOOK_END_RE.match(text):
                self.stats["dropped"].append((volume, i, text[:50]))
                self._park_refs(refs_by_i[i], volume, i)
                if BOOK_END_RE.match(text) or VOLUME_END_RE.match(text):
                    self.close_book_tail()
                else:
                    self.close_chapter()
                boundary = True
                continue
            if SEP_RE.match(text):
                self._park_refs(refs_by_i[i], volume, i)
                boundary = True
                continue
            if self.matter is not None:
                if text != "توجه!":
                    self.add_matter_line(text, refs_by_i[i], volume, i)
                continue

            head = HEAD_RE.match(text)
            if head and self._is_heading(head):
                kind = head.group(1)
                number_word = head.group(2).strip(" :：.")
                title = clean(head.group(3).strip(" :：."))
                if kind == "مقصد":
                    self.close_book()
                    self.pending_group_no = number_word
                    self.group_title_only = strip_quotes(title)
                    self.group_pending_title = strip_quotes(title)
                    if title:
                        self.group_title = self._compose_group(
                            number_word, title)
                    self.group_notes = list(refs_by_i[i])
                    self.last_book_no = None
                    pending = ("مقصد", number_word)
                elif kind == "کتاب":
                    self.close_chapter()
                    self.fasl = ""
                    self.fasl_no = ""
                    book_no = ordinal_of(number_word)
                    # The edition is ONE book in the app's library; the 49
                    # «کتاب»s of its own chain live in `chapters.part`, which is
                    # the label the section's single-level list heads a group
                    # with. Writing them as `books` rows made the section show
                    # one of 49 slices, because it lists one book's chapters.
                    self.book = {
                        "id": self.root_id,
                        "title": strip_quotes(title),
                        "volume": volume, "heading": clean(text),
                        "no_word": number_word, "row": False,
                    }
                    self.stats["books"] += 1
                    for nid, printed, note in [*self.group_notes,
                                               *refs_by_i[i]]:
                        self.add_footnote(
                            text=note, printed=printed, kind="book_heading",
                            volume=volume, book_id=self.book["id"],
                            source_para=i, order=nid)
                    self.group_notes = []
                    self.last_book_no = book_no if book_no is not None else self.last_book_no
                    pending = ("کتاب",)
                else:
                    self.close_chapter()
                    self._park_refs(refs_by_i[i], volume, i)
                    self.fasl = strip_quotes(title)
                    self.fasl_no = number_word
                    pending = ("فصل", number_word, strip_quotes(title))
                boundary = True
                continue

            if pending:
                what = pending[0]
                # A heading that already printed its own title (the usual case:
                # «فصل دوم: …» on one line) leaves `pending` set, and the next
                # paragraph was then consumed as that title — swallowing the
                # chapter's first narration when it happened to sit right under
                # the heading. Numbered lines are never titles: send them back
                # to the normal reader instead of eating them.
                structural = (self._is_structural(text, boundary)
                              or self._is_numbered_line(text))
                if what == "مقصد":
                    self.group_title_only = strip_quotes(text)
                    self.group_pending_title = strip_quotes(text)
                    self.group_title = self._compose_group(
                        self.pending_group_no, strip_quotes(text))
                elif what == "کتاب":
                    if self.book is not None and not structural:
                        self._set_book_title(strip_quotes(text))
                        for nid, printed, note in refs_by_i[i]:
                            self.add_footnote(
                                text=note, printed=printed,
                                kind="book_heading", volume=volume,
                                book_id=self.book["id"], source_para=i,
                                order=nid)
                elif not structural:
                    self.fasl = strip_quotes(text)
                    if what == "فصل" and len(pending) > 1:
                        self.fasl_no = pending[1]
                pending = None
                if structural:
                    # the heading carried no title of its own: fall through and
                    # let the line be read as what it is
                    if what == "کتاب" and self.book is not None:
                        self._set_book_title(self._fallback_book_title())
                else:
                    boundary = True
                    continue

            if (boundary and self.book is not None and len(text) <= 60
                    and not re.match(r"^\s*\d", text)
                    and self._next_is_book_head(next_text, i)):
                # a مقصد title printed without its «مقصد …» label
                self.group_title_only = strip_quotes(text)
                self.group_pending_title = strip_quotes(text)
                boundary = True
                continue

            if self._is_running_head(text):
                self.stats["dropped"].append((volume, i, text[:50]))
                self._park_refs(refs_by_i[i], volume, i)
                continue

            bab = BAB_RE.match(text)
            if bab:
                self.start_chapter(bab.group(1), bab.group(2), volume, i,
                                   refs_by_i[i])
                boundary = True
                continue
            bab2 = BAB_NONUM_RE.match(text)
            if bab2:
                self.start_chapter(None, bab2.group(1), volume, i, refs_by_i[i])
                boundary = True
                continue

            num = NUM_RE.match(text)
            if num:
                n = int(num.group(1))
                sep = num.group(2)
                rest = clean(num.group(3))
                digits = len(num.group(1))
                followed = TRANSLATION_HINT.match(next_text[i]) is not None
                if (boundary and digits <= 3 and not followed and rest
                        and sep != TATWEEL
                        and self._is_narration_head(next_text[i])
                        and not MATN_HINT.match(DIACRITICS.sub("", rest))):
                    # a باب whose line lost the word «باب» («6- تفسیر …»)
                    self.start_chapter(n, rest, volume, i, refs_by_i[i])
                    boundary = True
                    continue
                ok = (sep != TATWEEL and bool(rest)
                      and not TRANSLATION_HINT.match(rest)
                      and not rest.startswith("باب")
                      and self.book is not None)
                if not ok:
                    self.rejects.append((volume, i, n, "shape", text[:70]))
                elif not followed:
                    # Without a translation under it, only a matn-looking line
                    # — or one continuing the running sequence — advances; a
                    # numbered list item (next line another item) never does.
                    delta = n - self.last_printed
                    ok = (delta > 0 and
                          (bool(MATN_HINT.match(DIACRITICS.sub("", rest)))
                           or delta <= 5) and
                          not NUM_RE.match(next_text[i]))
                    if not ok:
                        self.rejects.append((volume, i, n, "no-translation",
                                             text[:70]))
                if ok:
                    if n != self.last_printed + 1:
                        self.anomalies.append((volume, i, n,
                                               self.last_printed + 1))
                    self.last_no += 1
                    self.start_entry(self.last_no, rest, refs_by_i[i],
                                     volume, i, printed=n)
                    self.last_printed = max(self.last_printed, n)
                    boundary = False
                    continue

            if self.book is None:
                # text that arrives before any book opens (a stray line of the
                # translator between two divisions): keep its notes, they are
                # printed in this volume all the same
                self._park_refs(refs_by_i[i], volume, i)
                boundary = False
                continue
            if self.chapter is None:
                self.pending_pre.append((text, refs_by_i[i], i))
                boundary = False
                continue
            if self.entry is None:
                self._add_preamble(text, refs_by_i[i], volume, i)
            else:
                self.entry["lines"].append((text, refs_by_i[i]))
            boundary = False

        self.close_chapter()

    # ── helpers ──────────────────────────────────────────────────────
    def close_book_tail(self):
        """«پایان کتاب …» closes the book but keeps its rows."""
        self.close_chapter()
        self.fasl = ""
        self.fasl_no = ""
        self.book = None
        self.pending_pre = []

    def _open_implicit_book(self, volume, para):
        """A chapter that arrives with no «کتاب» above it still needs a chain."""
        title = (self.fasl or self.group_title_only or "کتاب").strip()
        self.book = {
            "id": self.root_id, "title": title, "volume": volume,
            "no_word": "", "row": False, "implicit": True,
        }
        self.stats["books"] += 1
        self.stats["implicit_books"].append((volume, para, title[:40]))

    def _park_refs(self, refs, volume, para):
        """Keep the notes of a line we do not print.

        A «پایان.» or a repeated running head can still carry a footnote marker
        (the citation of the passage that just ended). Dropping the line used to
        drop its note with it; parking the note on the open chapter keeps every
        note of the volume inside the book.
        """
        if not refs:
            return
        if self.chapter is None:
            # nothing to hang them on yet: the next باب opens over them
            self.orphan_refs.append((refs, volume, para))
            return
        for nid, printed, note in refs:
            self.add_footnote(
                text=note, printed=printed, kind="chapter_heading",
                volume=volume,
                book_id=self.book["id"] if self.book else None,
                chapter_id=self.chapter["id"] if self.chapter else None,
                source_para=para, order=nid)

    def _next_is_book_head(self, next_text, i):
        t = next_text[i]
        return bool(re.match(r"^\s*[\(（]?\s*کتاب\b", t))

    @staticmethod
    def _is_numbered_line(t):
        """A line that starts with a printed number and a separator."""
        m = NUM_RE.match(t)
        return bool(m and m.group(3).strip())

    @staticmethod
    def _is_narration_head(t):
        m = NUM_RE.match(t)
        return bool(m and m.group(2) != TATWEEL and m.group(3).strip())

    def _is_structural(self, text, boundary):
        if BAB_RE.match(text) or BAB_NONUM_RE.match(text):
            return True
        if HEAD_RE.match(text) and self._is_heading(HEAD_RE.match(text)):
            return True
        return False

    def _is_running_head(self, text):
        if len(text) > 40:
            return False
        key = squash(text)
        candidates = {squash(self.group_title_only), squash(self.fasl)}
        if self.book:
            candidates.add(squash(self.book["title"]))
        return key in candidates - {""}

    @staticmethod
    def _is_heading(head):
        number_word = head.group(2).strip(" :：.")
        if number_word and number_word not in ORDINALS:
            # «کتاب مصابیح، شرح‌ها و …» opens a sentence, not a heading
            return False
        return True

    def _compose_group(self, number_word, title):
        """The مقصد label exactly as the page prints it.

        Nothing is inferred here: the edition never prints «مقصد اول», skips
        «مقصد چهارم» (احکام خانواده) entirely, and prints «مقصد هفتم» twice
        (once for امامت in the third volume, once for تاریخ in the fourth).
        Each heading is stored as it appears, so the reader sees the book's own
        face rather than a numbering this script invented.
        """
        title = (title or "").strip()
        label = f"مقصد {number_word}" if number_word else ""
        return f"{label}: {title}" if label and title else (label or title)

    def _part_label(self):
        """The مقصد · کتاب · فصل chain this باب sits under.

        The reader's فهرست has one level, so this string is the only thing that
        can open a group header: `maalim_screen` draws one every time it
        changes. It has to be written here because the database — not the UI —
        is what knows which باب was printed under which فصل.

        Titles are the book's own words and an ordinal is kept only where the
        page printed one («کتاب چهارم» with no title under it is still a titled
        division), the same rule as the مقصد label. A division whose title the
        parser already promoted to the book (a باب printed under a فصل with no
        «کتاب» line) is not repeated.
        """
        bits = []
        if self.group_title:
            bits.append(self.group_title)
        book = self.book or {}
        title = (book.get("title") or "").strip()
        if title and title != (self.fasl or "").strip():
            no = book.get("no_word") or ORDINAL_WORD.get(
                book.get("book_no") or 0, "")
            label = f"کتاب {no}" if no else "کتاب"
            bits.append(f"{label}: {title}")
        if self.fasl:
            label = f"فصل {self.fasl_no}" if self.fasl_no else "فصل"
            bits.append(f"{label}: {self.fasl}")
        return " · ".join(bits)


    def _set_book_title(self, title):
        if self.book is None:
            return
        self.book["title"] = title
        if self.book.get("row"):
            self.db.con.execute(
                "UPDATE books SET title_persian = ? WHERE id = ?",
                (title, self.book["id"]))

    def _fallback_book_title(self):
        """The title a «کتاب» heading carries on its own line.

        «کتاب چهارم» with no title under it is still a titled division — the
        heading *is* its name — so the line is used instead of a bare «کتاب».
        """
        return self.book["title"] or self.book.get("heading") or "کتاب"

    # ── rows ─────────────────────────────────────────────────────────
    def start_chapter(self, printed, title, volume, para, refs=()):
        self._start_chapter(title=strip_quotes(title),
                            printed=int(printed) if printed else None,
                            volume=volume, para=para)
        if self.chapter is None:
            return
        for nid, note_no, note in refs:
            self.add_footnote(
                text=note, printed=note_no, kind="chapter_heading",
                volume=volume, book_id=self.book["id"],
                chapter_id=self.chapter["id"], source_para=para, order=nid)

    def _start_chapter(self, *, title, printed, volume, para):
        self.close_chapter()
        if self.book is None:
            # Four مقاصد of this edition open their باب straight under the
            # مقصد title, without a «کتاب» line. Refusing the chapter dropped
            # every narration under it (مقصد دهم, «فتنه‌ها و آزمایشات», lost its
            # whole first باب). The مقصد title is the narrowest face we have,
            # so it becomes the book.
            self._open_implicit_book(volume, para)
        # The printed numbering restarts with every باب in this edition, so a
        # fresh chapter resets the running numeral. Without the reset the
        # sequence guard compared «196» against the previous باب's «2271» and
        # rejected the narration as an out-of-order list item — it then landed
        # in the preambles, leaving 63 باب that held text but no حدیث.
        self.last_printed = 0
        self.chapter_no += 1
        cid = self.db.chapter(
            self.book["id"], self.chapter_no, title or "باب",
            printed_number=printed, volume=volume, source_para=para,
            part=self._part_label())
        self.chapter = {"id": cid, "printed": printed, "preambles": 0}
        self.stats["chapters"] += 1
        for refs, v, p in self.orphan_refs:
            self._park_refs(refs, v, p)
        self.orphan_refs = []
        # text printed between the فصل heading and the first باب belongs to the
        # باب that follows it, never to a chapter of its own
        for text, refs, pi in self.pending_pre:
            self._add_preamble(text, refs, volume, pi)
        self.pending_pre = []

    def _add_preamble(self, text, refs, volume, para):
        self.chapter["preambles"] += 1
        pid = self.db.preamble(
            book_id=self.book["id"], chapter_id=self.chapter["id"],
            volume=volume, kind="chapter_preamble",
            para_order=self.chapter["preambles"], arabic=text,
            source_para=para)
        self.stats["preambles"] += 1
        for nid, printed, note in refs:
            self.add_footnote(
                text=note, printed=printed, kind="chapter_preamble",
                volume=volume, book_id=self.book["id"],
                chapter_id=self.chapter["id"], preamble_id=pid,
                source_para=para, order=nid)

    def start_entry(self, number, first_line, refs, volume, para,
                    printed=None):
        self.close_entry()
        if self.chapter is None:
            self._start_chapter(
                title=self.fasl or self.book["title"] or self.group_title_only,
                printed=None, volume=volume, para=para)
        self.entry = {"number": number, "printed": printed,
                      "lines": [(first_line, refs)],
                      "volume": volume, "source_para": para}


def front_matter_end(path):
    """Index of the first paragraph of the book proper.

    The introductions end where the first «N - باب» (or the first «کتاب»
    division) begins; the sentence the old break used ("شروع می کنیم به
    ترجمه") sits *inside* the author's مقدمه, so everything printed after it —
    «عقیده», «اسلام و ايمان» and their notes — fell through to the first باب.
    """
    doc = Document(path)
    texts = [clean(para_text_refs(p._p)[0]) for p in doc.paragraphs]
    # The فهرست مطالب repeats every باب heading; scanning from the top would
    # stop at the first table-of-contents row. Everything up to the last one is
    # the contents, so the book proper begins after it.
    toc = [i for i, t in enumerate(texts) if t and is_toc(t)]
    start = (toc[-1] + 1) if toc else 0
    for i in range(start, len(texts)):
        text = texts[i]
        if not text or is_toc(text):
            continue
        if BAB_RE.match(text):
            return i
        head = HEAD_RE.match(text)
        if head and head.group(1) == "کتاب" and Builder._is_heading(head):
            return i
    return start


def build(sources, out_dir, allow_rejects=False):
    os.makedirs(out_dir, exist_ok=True)
    db = BookDb(os.path.join(out_dir, "maalim.db"))
    root = db.book(
        "معالم السنه النبویه", book_no=1,
        title_arabic="معالم السنة النبوية",
        title_english="Ma'alim al-Sunan")
    b = Builder(db, root)
    b.open_matter("intro_translator", "مقدمه‌ی مترجم", 1)
    for idx, path in enumerate(sources, 1):
        skip_until = 0
        if idx == 1:
            skip_until = front_matter_end(path)
            _parse_front_matter(b, path, stop=skip_until)
        b.parse_volume(idx, path, skip_until=skip_until)
    b.close_chapter()
    db.finalize()

    con = db.con
    books = con.execute("SELECT COUNT(*) FROM books").fetchone()[0]
    chapters = con.execute("SELECT COUNT(*) FROM chapters").fetchone()[0]
    hadiths = con.execute("SELECT COUNT(*) FROM hadiths").fetchone()[0]
    lo, hi = con.execute(
        "SELECT MIN(hadith_number), MAX(hadith_number) FROM hadiths").fetchone()
    empty = con.execute(
        "SELECT COUNT(*) FROM chapters c WHERE NOT EXISTS (SELECT 1 FROM "
        "hadiths h WHERE h.chapter_id = c.id)").fetchone()[0]
    orphans = con.execute(
        "SELECT COUNT(*) FROM hadiths h LEFT JOIN chapters c ON c.id = "
        "h.chapter_id WHERE c.id IS NULL").fetchone()[0]
    bad_anchor = con.execute(
        "SELECT COUNT(*) FROM footnotes f JOIN hadiths h ON h.id = f.hadith_id "
        "WHERE f.anchor_line IS NOT NULL AND (f.anchor_line < 0 OR "
        "f.anchor_line >= length(h.arabic) - length(replace(h.arabic, char(10), "
        "'')) + 1)").fetchone()[0]
    assert orphans == 0, f"{orphans} orphans"
    assert bad_anchor == 0, f"{bad_anchor} footnotes anchored outside their text"
    gaps = con.execute(
        "SELECT COUNT(*) FROM (WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL "
        "SELECT x+1 FROM n WHERE x < %d) SELECT x FROM n WHERE x NOT IN "
        "(SELECT hadith_number FROM hadiths))" % PRINTED_TOTAL).fetchone()[0]
    twice = con.execute(
        "SELECT COUNT(*) FROM (SELECT hadith_number FROM hadiths GROUP BY "
        "hadith_number HAVING COUNT(*) > 1)").fetchone()[0]
    # The honest loss metric: a printed number the database does not carry AND
    # whose digits appear nowhere in any text was dropped on the floor, not
    # merged into a neighbour. The published four-volume build lost 212 this
    # way — the section could only report 3,823 of the edition's 3,921 numbers.
    text = "\n".join(r[0] for r in con.execute("SELECT arabic FROM hadiths"))
    missing = [n for n in range(1, PRINTED_TOTAL + 1)
               if n not in {r[0] for r in con.execute(
                   "SELECT DISTINCT hadith_number FROM hadiths")}]
    nowhere = [n for n in missing if str(n) not in text]
    con.commit()
    con.close()

    raw = os.path.join(out_dir, "maalim.db")
    gz = os.path.join(out_dir, "maalim.db.gz")

    print(f"books      : {books}")
    print(f"chapters   : {chapters} ({empty} without a narration)")
    print(f"hadiths    : {hadiths} numbered {lo}..{hi}")
    print(f"preambles  : {b.stats['preambles']}")
    print(f"footnotes  : {b.stats['footnotes']}  (anchors all inside their text)")
    print(f"matters    : {b.stats['matter_sections']} sections / "
          f"{b.stats['matter_paras']} paragraphs")
    print(f"dropped    : {len(b.stats['dropped'])} binding lines")
    for row in b.stats["dropped"][:8]:
        print("   ", row)
    print(f"printed    : numbered 1..{PRINTED_TOTAL} like the book "
          f"({lo}..{hi}), {gaps} numbers the book never printed, "
          f"{twice} printed twice")
    print(f"rejected   : {len(b.rejects)} numbered lines")
    for row in b.rejects[:25]:
        print("   vol%d p%d n=%d %s | %s" % (row[0], row[1], row[2], row[3],
                                             row[4]))
    print(f"missing    : {len(missing)} numbers, {len(nowhere)} of them with "
          f"no text anywhere (real losses)")
    if nowhere:
        print("   first lost numbers: %s" %
              ", ".join(str(n) for n in nowhere[:25]))
    if b.rejects and not allow_rejects:
        # A numbered line the parser could not place is a narration the book
        # prints and the database would be missing. Publishing it anyway is how
        # the count drifted from 3,921 to 3,823 without anyone noticing.
        if os.path.exists(raw):
            os.remove(raw)
        raise SystemExit(
            f"{len(b.rejects)} numbered lines were not placed. Fix the parse "
            "(see the rejects above) or pass --allow-rejects to write anyway.")
    with open(raw, "rb") as fin, gzip.GzipFile(gz, "wb", compresslevel=9) as f:
        shutil.copyfileobj(fin, f)
    os.remove(raw)
    print(f"written    : {gz} ({os.path.getsize(gz):,} bytes)")
    return b



def _parse_front_matter(b, path, stop=None):
    """Volume 1 opens with the translator's, author's and editor's intros."""
    doc = Document(path)
    notes = read_footnotes(path)
    texts = [clean(para_text_refs(p._p)[0]) for p in doc.paragraphs]
    start = max(i for i, t in enumerate(texts) if t and is_toc(t)) + 1
    for i in range(start, len(texts)):
        if stop is not None and i >= stop:
            # The book proper starts here; its lines and notes belong to the
            # first باب, not to the introductions.
            break
        t = texts[i]
        if not t:
            continue
        if t.startswith("مقدمه") and "مؤلف" in t:
            b.open_matter("intro_author", "مقدمه‌ی مؤلف", 1)
            continue
        if t.startswith("اهمیت و ویژگی"):
            b.open_matter("intro_about", "درآمدی بر کتاب", 1)
            continue
        if is_toc(t) or SEP_RE.match(t) or CHAPTER_END_RE.match(t) or \
                BOOK_END_RE.match(t) or VOLUME_END_RE.match(t):
            continue
        text, refs = para_text_refs(doc.paragraphs[i]._p)
        b.add_matter_line(t, [(nid, *notes[nid]) for _o, nid in refs
                              if nid in notes], 1, i)
    b.matter = None


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out-dir", default=DEFAULT_OUT)
    ap.add_argument("--allow-rejects", action="store_true",
                    help="write the database even when numbered lines were "
                         "not placed (only for a diagnosed, documented case)")
    args = ap.parse_args()
    for src in SOURCES:
        if not os.path.exists(src):
            raise SystemExit(f"source not found: {src}")
    build(SOURCES, args.out_dir, allow_rejects=args.allow_rejects)


if __name__ == "__main__":
    main()
