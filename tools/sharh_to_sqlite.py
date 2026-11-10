# -*- coding: utf-8 -*-
"""Parse 6 Word volumes of Sharh Riyad al-Salihin -> one merged book
-> insert into hadith.db as book id 18 -> emit TAWHEED-EWAZ/hadith/hadith.db.gz

Block anatomy:
- Bab headings: style 'تیتر و ابواب' matching '^N- باب[:]' (numbering continues
  across volumes; small gaps exist -> we renumber sequentially).
- Hadith block starts, two schemes:
  1) vols 1-2(+parts of 3): style 'احادیث', per-bab numbering 'N- matn'
  2) vols 4-6(+parts of 3): mostly style 'Normal', GLOBAL riyad numbering,
     e.g. '1040- عن ابي هريرة...' -> accepted when number >= 200 and greater
     than last global number seen.
- Blocks end with '***'; segments without numbered hadiths (pure tafsir
  passages, e.g. bab 253) become unnumbered entries.
"""
import gzip
import os
import re
import shutil
import sqlite3
import sys

from docx import Document

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = [f"sharh-reyaz-al-salehin-{i}-Word.docx" for i in range(1, 7)]

BAB_RE = re.compile(r"^(\d+)\s*[-–]\s*باب\s*[:：]?\s*(.*)$", re.S)
NUM_RE = re.compile(r"^(\d{1,4})\s*[-–]\s*(.*)$", re.S)
REF_RE = re.compile(r"^\[[^\[\]]+\]$")
SHARH_MARK = "\x01"
_DIAC = re.compile(r"[\u064B-\u065F\u0670\u0640\u06D6-\u06ED]")
_MATN_OPEN = re.compile(
    r"^\s*(?:و?(?:ال)?\s*(?:عن|رواه)|(?:ال)?ثان[يىی]|(?:ال)?ثالث|"
    r"(?:ال)?رابع|(?:ال)?خامس|(?:ال)?سادس|(?:ال)?سابع|(?:ال)?ثامن|"
    r"(?:ال)?تاسع|(?:ال)?عاشر|(?:ال)?حادي\s*ع?شر)")


def looks_like_matn(rest):
    return bool(_MATN_OPEN.match(_DIAC.sub("", rest)))

HONORIFICS = {
    "$": "رضي الله عنه",
    "&": "رضي الله عنها",
    "#": "رضي الله عنهم",
}


def clean(text):
    t = text.replace("\u00a0", " ")
    t = re.sub(r"\(\s*\)", "", t)            # empty footnote parens
    t = re.sub(r"\(\s*\d{1,3}\s*\)", "", t)  # print footnote numbers
    for sym, rep in HONORIFICS.items():
        t = re.sub(rf"(?<=[\u0600-\u06FF])\s*{re.escape(sym)}", f" {rep}", t)
        t = t.replace(sym, "")
    t = re.sub(r"[ \t]+", " ", t)
    return t.strip()


def tidy(lines):
    out = []
    for ln in lines:
        ln = ln.strip()
        if not ln:
            continue
        if out and REF_RE.match(ln) and len(ln) < 45:
            out[-1] += " " + ln          # glue verse ref to its verse line
        else:
            out.append(ln)
    return out


def parse_volume(path):
    doc = Document(path)
    paras = [(p.style.name if p.style is not None else "", p.text)
             for p in doc.paragraphs]
    start = None
    for i, (s, t) in enumerate(paras):
        if s == "تیتر و ابواب" and BAB_RE.match(t.strip()):
            start = i
            break
    if start is None:
        raise RuntimeError(f"no bab marker in {path}")

    chapters = []
    state = {"ch": None, "h": None, "last_global": 0}

    def close_h():
        h = state["h"]
        if h is not None and state["ch"] is not None:
            state["ch"]["hadiths"].append(h)
        state["h"] = None

    def close_ch():
        close_h()
        state["ch"] = None

    def feed(style, text):
        if not text or text == "***":
            return

        # publisher footer lines (front matter + before each embedded volume)
        low = text.lower()
        if ("mowahedin" in low or "aqeedeh" in low
                or text.startswith("نظارت علمی")
                or "گروه علمی فرهنگی" in text
                or text.startswith("بازنشر این کتاب")
                or text.startswith("منبع:") or text.startswith("تماس با ما")):
            return

        if style == "تیتر و ابواب":
            m = BAB_RE.match(text)
            if m:
                close_ch()
                ch = {"title": clean(m.group(2)), "hadiths": []}
                chapters.append(ch)
                state["ch"] = ch
                return
            ch = state["ch"]
            if ch is not None and not ch["hadiths"] and state["h"] is None:
                ch["title"] = (ch["title"] + " " + text).strip()
                return

        m = NUM_RE.match(text)
        is_hadith_start = False
        matn = None
        no = None
        scheme = None
        if m:
            num = int(m.group(1))
            if len(m.group(1)) <= 3 and (
                    style == "احادیث" or looks_like_matn(m.group(2))):
                is_hadith_start = True           # per-bab scheme
                scheme = "bab"
            elif num >= 200 and looks_like_matn(m.group(2)):
                is_hadith_start = True           # global riyad scheme
                scheme = "global"
                state["last_global"] = max(num, state["last_global"])
            if is_hadith_start:
                matn = clean(m.group(2))
                no = num

        if is_hadith_start:
            close_h()
            state["h"] = {"matn": matn, "body": [], "no": no,
                          "scheme": scheme}
            return

        target = state["h"]["body"] if state["h"] is not None else None
        if target is None:
            # text between chapter start and first hadith -> chapter preamble
            # stored as an unnumbered entry so nothing is lost
            ch = state["ch"]
            if ch is None:
                return
            close_h()
            state["h"] = {"matn": "", "body": [], "no": None, "scheme": None}
            target = state["h"]["body"]

        if text == "شرح":
            target.append(SHARH_MARK)
        elif (target and REF_RE.match(text) and len(text) < 45
                and not target[-1].startswith(SHARH_MARK)):
            target[-1] += " " + text
        else:
            target.append(text)

    for style, raw in paras[start:]:
        # docx soft line-breaks (<w:br/>) surface as '\n' inside one paragraph
        # and can pack TWO hadiths into a single paragraph -> split them
        for sub in raw.split("\n"):
            feed(style, clean(sub))
    close_ch()
    return chapters


def assemble(h):
    lines = [h["matn"]] if h["matn"] else []
    body = tidy(h["body"])
    pre, post = [], []
    cur = pre
    for ln in body:
        if ln == SHARH_MARK:
            cur = post
            continue
        cur.append(ln)
    if pre:
        first = pre[0]
        if first.startswith("ترجمه:") or first.startswith("ترجمه :"):
            lines += ["", first]
            rest = pre[1:]
            # extra نووی-style notes before sharh stay with translation block
            lines += rest if post else []
            if not post:
                return "\n".join(lines).strip()
        else:
            lines += ["", *pre]
    if post:
        lines += ["", "شرح و توضیح:"]
        lines += post
    elif "pre-only" and not post and pre and not (
            pre[0].startswith("ترجمه:") or pre[0].startswith("ترجمه :")):
        pass
    return "\n".join(x for x in lines if x != "").strip()


def main():
    book_id = 18
    all_chapters = []
    for f in FILES:
        chs = parse_volume(os.path.join(ROOT, f))
        n_h = sum(len(c["hadiths"]) for c in chs)
        print(f"{f}: {len(chs)} babs, {n_h} entries "
              f"(first: {chs[0]['title'][:40]!r})")
        all_chapters.extend(chs)

    total_h = sum(len(c["hadiths"]) for c in all_chapters)
    print(f"TOTAL: {len(all_chapters)} babs, {total_h} entries")

    print("\n--- sample bab1/entry1 ---")
    print(assemble(all_chapters[0]["hadiths"][0])[:700])
    print("\n--- sample bab186 area: global-numbered hadith ---")
    big = [h for c in all_chapters for h in c["hadiths"]
           if h["matn"].startswith("عن ابي هريرة أن")]
    if big:
        print(assemble(big[0])[:500])
    print("\n--- sample last bab / last entry (tail) ---")
    print(assemble(all_chapters[-1]["hadiths"][-1])[-500:])

    empty_babs = [i for i, c in enumerate(all_chapters, 1) if not c["hadiths"]]
    tiny = [(i, j) for i, c in enumerate(all_chapters, 1)
            for j, h in enumerate(c["hadiths"], 1) if len(assemble(h)) < 60]
    print(f"\nanomalies: empty-babs={empty_babs} tiny-entries={len(tiny)}")

    src = os.path.join(ROOT, "assets", "hadith.db")
    work = os.path.join(ROOT, "tools", "_sharh_work.db")
    shutil.copyfile(src, work)
    con = sqlite3.connect(work)
    cur = con.cursor()
    cur.execute("SELECT MAX(id), COUNT(*) FROM books")
    print("books max(id),count:", cur.fetchone())
    cur.execute("SELECT id FROM books WHERE id=?", (book_id,))
    assert cur.fetchone() is None, f"book id {book_id} already exists!"

    cur.execute(
        "INSERT INTO books (id, title_arabic, title_english, hadith_count) "
        "VALUES (?,?,?,?)",
        (book_id, "شرح ریاض الصالحین", "Sharh Riyad al-Salihin", total_h))

    hid = 0
    for ci, ch in enumerate(all_chapters, 1):
        cur.execute(
            "INSERT INTO chapters (book_id, chapter_index, name_arabic, "
            "name_english) VALUES (?,?,?,?)",
            (book_id, ci, ch["title"], ""))
        ch_row = cur.lastrowid
        for h in ch["hadiths"]:
            hid += 1
            cur.execute(
                "INSERT INTO hadiths (book_id, hadith_number, chapter_id, "
                "arabic) VALUES (?,?,?,?)",
                (book_id, hid, ch_row, assemble(h)))
    con.commit()

    cur.execute("SELECT COUNT(*) FROM chapters WHERE book_id=?", (book_id,))
    print("verify chapters:", cur.fetchone()[0])
    cur.execute("SELECT COUNT(*) FROM hadiths WHERE book_id=?", (book_id,))
    print("verify hadiths:", cur.fetchone()[0])
    cur.execute(
        "SELECT COUNT(*) FROM hadiths h LEFT JOIN chapters c "
        "ON h.chapter_id=c.id WHERE h.book_id=? AND c.id IS NULL", (book_id,))
    assert cur.fetchone()[0] == 0
    con.close()

    gz_path = os.path.join(ROOT, "TAWHEED-EWAZ", "hadith", "hadith.db.gz")
    with open(work, "rb") as fin, \
            gzip.GzipFile(gz_path, "wb", compresslevel=9) as fout:
        shutil.copyfileobj(fin, fout)
    print(f"gzip written: {gz_path} ({os.path.getsize(gz_path)} bytes)")
    os.remove(work)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
