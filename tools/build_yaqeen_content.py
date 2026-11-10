#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds assets/content/yaqeen.json from yaqeen.docx (نقشهٔ «یقین»).

Usage:
  python tools/build_yaqeen_content.py [--src yaqeen.docx] [--out assets/content/yaqeen.json]

The document contains the Yaqeen curriculum: 80% تثبیت یقین (core beliefs),
20% پاسخ به شبهات (answering doubts), plus critique and summary sections.
Top-level «فصل …» / «مقدمه: …» headings become lessons; «📌 گفتار …» lines
split each lesson into sections. Lesson → level/chapter mapping below
follows the 5-level plan stated in the document itself.
"""
import argparse
import html
import json
import math
import re
import zipfile
from pathlib import Path

# ── Curriculum mapping (curriculum order, NOT document order) ────────
# (level_id, chapter_id, heading_prefix, clean_title)
LESSONS = [
    # سطح ۲ — تثبیت یقین و باورها (هستهٔ اصلی)
    ("core", "methodology", "مقدمه: روش‌شناسی معرفت", "روش‌شناسی معرفت؛ سه منبع شناخت"),
    ("core", "methodology", "فصل اول: فطرت", "فطرت؛ نخستین منبع معرفت"),
    ("core", "methodology", "فصل دوم: عقل", "عقل؛ منبع استدلال و برهان"),
    ("core", "methodology", "فصل سوم: وحی", "وحی؛ منبع کامل‌کننده و هدایت‌گر"),
    ("core", "proofs", "فصل اول: برهان حدوث", "برهان حدوث"),
    ("core", "proofs", "فصل دوم: برهان نظم", "برهان نظم"),
    ("core", "proofs", "فصل سوم: برهان فطرت", "برهان فطرت"),
    ("core", "proofs", "فصل چهارم: برهان اخلاقی", "برهان اخلاقی"),
    ("core", "proofs", "فصل پنجم: پاسخ به مسئله شر", "پاسخ به مسئلهٔ شر"),
    ("core", "prophethood", "فصل دهم: نبوت و رسالت", "نبوت و رسالت"),
    ("core", "quran", "فصل یازدهم: قرآن و علوم قرآنی", "قرآن و علوم قرآنی"),
    ("core", "sunnah", "فصل دوازدهم: سنت نبوی", "سنت نبوی"),
    ("core", "faith", "فصل سیزدهم: ایمان و ارکان آن", "ایمان و ارکان آن"),
    ("core", "tawhid", "فصل چهاردهم: توحید و شرک", "توحید و شرک"),
    # سطح ۳ — نقد جریان‌های فکری انحرافی
    ("critique", "currents", "فصل ششم: پاسخ به تعارض علم و دین", "پاسخ به تعارض علم و دین"),
    ("critique", "currents", "فصل هفتم: نقد الحاد جدید", "نقد الحاد جدید"),
    # سطح ۴ — پاسخ به شبهات جامعه
    ("doubts", "scripture", "فصل هشتم: پاسخ به شبهات قرآنی و حدیثی", "پاسخ به شبهات قرآنی و حدیثی"),
    ("doubts", "scripture", "فصل شبهات مربوط به پیامبر", "شبهات مربوط به پیامبر اکرم ﷺ"),
    ("doubts", "scripture", "فصل شبهات مربوط به قرآن", "شبهات مربوط به قرآن کریم"),
    ("doubts", "social", "فصل پانزدهم: پاسخ به شبهات اجتماعی", "پاسخ به شبهات اجتماعی"),
    ("doubts", "social", "فصل شبهات مربوط به احکام", "شبهات مربوط به احکام اسلامی"),
    # سطح ۵ — تکمیل و جمع‌بندی
    ("summary", "final", "فصل نهم: جمع‌بندی نهایی", "جمع‌بندی نهایی و نتیجه‌گیری"),
]

LEVELS = {
    "core": {
        "title": "تثبیت یقین و باورها",
        "subtitle": "هستهٔ اصلی؛ ساختن ایمان ریشه‌دار بر فطرت، عقل و وحی",
        "chapters": {
            "methodology": "روش‌شناسی معرفت",
            "proofs": "خداشناسی و براهین اثبات خدا",
            "prophethood": "نبوت و رسالت",
            "quran": "قرآن و علوم قرآنی",
            "sunnah": "سنت نبوی",
            "faith": "ایمان و ارکان آن",
            "tawhid": "توحید و شرک",
        },
    },
    "critique": {
        "title": "نقد جریان‌های فکری انحرافی",
        "subtitle": "پاسخ منطقی به الحاد جدید و ساینتیسم",
        "chapters": {"currents": "الحاد، ساینتیسم و تعارض علم و دین"},
    },
    "doubts": {
        "title": "پاسخ به شبهات جامعه",
        "subtitle": "پاسخ‌های مستند به رایج‌ترین شبهات",
        "chapters": {
            "scripture": "شبهات اعتقادی و نقلی",
            "social": "شبهات اجتماعی و احکام",
        },
    },
    "summary": {
        "title": "تکمیل و کاربردی‌سازی",
        "subtitle": "جمع‌بندی مسیر و توصیه‌های عملی",
        "chapters": {"final": "جمع‌بندی نهایی"},
    },
}


def extract_lines(docx_path: Path):
    """One line per non-empty paragraph, same extraction as hand inspection."""
    with zipfile.ZipFile(docx_path) as z:
        xml = z.read("word/document.xml").decode("utf-8")
    xml = re.sub(r"<w:p [^>]*>|<w:p>", "\n", xml)
    text = re.sub(r"<[^>]+>", "", xml)
    text = html.unescape(text)
    return [ln.strip() for ln in text.split("\n") if ln.strip()]


def clean_title_line(s: str) -> str:
    s = s.strip()
    # The heading itself is the title; drop trailing colon variants.
    return s.rstrip(":：").strip()


NUM_HEADING = re.compile(r"^[۰-۹0-9]+\. [^:،]{3,60}[:：]$")
FALLBACK_PREFIXES = ("بخش ", "شبههٔ ", "شبهه' ", "شبهه ")


def split_sections(heading: str, body):
    """Body lines → sections list, splitting on 📌 گفتار markers.

    Lessons without 📌 markers fall back to their own internal heading
    style: «بخش …», «شبههٔ …» or numbered headings like «۱. تعریف فطرت:».
    """

    def _split(marker_pred, title_of):
        sections, cur_title, cur_paras = [], None, []

        def flush():
            nonlocal cur_title, cur_paras
            if cur_paras:
                sections.append({"title": cur_title,
                                 "paragraphs": cur_paras})
            cur_title, cur_paras = None, []

        for ln in body:
            if marker_pred(ln):
                flush()
                cur_title = title_of(ln)
                continue
            cur_paras.append(ln)
        flush()
        return sections

    sections = _split(
        lambda ln: ln.startswith("📌"),
        lambda ln: clean_title_line(ln.lstrip("📌").strip()),
    )
    if len(sections) > 1:
        return sections

    # Fallback A: بخش/شبهه prefixed headings.
    alt = _split(
        lambda ln: ln.startswith(FALLBACK_PREFIXES) and len(ln) < 100,
        lambda ln: clean_title_line(ln),
    )
    if len(alt) > 1:
        return alt

    # Fallback B: numbered headings like «۱. تعریف فطرت:».
    alt = _split(
        lambda ln: NUM_HEADING.match(ln) is not None,
        lambda ln: clean_title_line(ln),
    )
    return alt


def word_count(paragraphs) -> int:
    return sum(len(p.split()) for p in paragraphs)


def lesson_text(sections) -> str:
    out = []
    for s in sections:
        if s["title"]:
            out.append(s["title"])
        out.extend(s["paragraphs"])
    return " ".join(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="yaqeen.docx")
    ap.add_argument("--out", default="assets/content/yaqeen.json")
    args = ap.parse_args()

    lines = extract_lines(Path(args.src))

    # Locate each lesson heading (first line starting with its prefix).
    anchors = []  # (line_idx, level, chapter, title)
    for level_id, chapter_id, prefix, title in LESSONS:
        hit = next(
            (i for i, ln in enumerate(lines) if ln.startswith(prefix)), None
        )
        if hit is None:
            raise SystemExit(f"heading not found: {prefix!r}")
        anchors.append((hit, level_id, chapter_id, title))
    anchors.sort(key=lambda a: a[0])

    # Build lessons in curriculum order.
    lessons = []
    for order, (idx, level_id, chapter_id, title) in enumerate(anchors):
        end = anchors[order + 1][0] if order + 1 < len(anchors) else len(lines)
        sections = split_sections(title, lines[idx + 1 : end])
        if not sections:
            raise SystemExit(f"empty lesson: {title!r}")
        text = lesson_text(sections)
        words = word_count(text)
        lessons.append(
            {
                "id": f"l{order + 1:02d}",
                "level": level_id,
                "chapter": chapter_id,
                "title": title,
                "excerpt": text[:160].strip() + ("…" if len(text) > 160 else ""),
                "minutes": max(1, math.ceil(words / 170)),
                "sections": sections,
            }
        )

    # Assemble levels → chapters → lessons.
    out_levels = []
    for level_id, meta in LEVELS.items():
        level_lessons = [l for l in lessons if l["level"] == level_id]
        if not level_lessons:
            raise SystemExit(f"level {level_id} has no lessons")
        chapters = []
        for chapter_id, chapter_title in meta["chapters"].items():
            ch_lessons = [l for l in level_lessons if l["chapter"] == chapter_id]
            if not ch_lessons:
                raise SystemExit(
                    f"chapter {level_id}/{chapter_id} has no lessons"
                )
            chapters.append({"id": chapter_id, "title": chapter_title,
                             "lessons": ch_lessons})
        out_levels.append({
            "id": level_id,
            "title": meta["title"],
            "subtitle": meta["subtitle"],
            "chapters": chapters,
        })

    doc = {"version": 1, "levels": out_levels}
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(doc, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    n_sections = sum(len(l["sections"]) for lv in out_levels
                     for ch in lv["chapters"] for l in ch["lessons"])
    total_min = sum(l["minutes"] for lv in out_levels
                    for ch in lv["chapters"] for l in ch["lessons"])
    print(f"OK levels={len(out_levels)} lessons={len(lessons)} "
          f"sections={n_sections} minutes={total_min} "
          f"size={out_path.stat().st_size} bytes -> {out_path}")


if __name__ == "__main__":
    main()
