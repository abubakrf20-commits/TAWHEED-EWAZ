#!/usr/bin/env python3
"""
generate_qcf4_data.py

Regenerates the QCF4 (quran-qcf4) mushaf data used by the app:

1. Rewrites `qcf_quran_lite-0.0.5/lib/src/data/quran_data.dart`, replacing
   every ayah's `qcfData` with the authentic word-by-word glyph sequence from
   the quran-qcf4 dataset (MohamadHajjRabee/quran-qcf4, QCF v4 Madinah
   Mushaf 1441 AH). Every other field is preserved byte-for-byte.

2. Writes `quran_qcf4_font_map.dart`  — page number → font family
   (`QCF4_Hafs_01` .. `QCF4_Hafs_47`).

3. Writes `quran_qcf4_qbsml.dart` — surah number → QCF4_QBSML header glyph
   (style A codepoints from qbsml.json).

Usage:
  python tools/generate_qcf4_data.py \
      [--qcf4 <quran-qcf4 repo dir>] \
      [--quran-data <path to quran_data.dart>]

The default quran-qcf4 dir points at the local copy on this machine:
  C:/Users/abubakr/Desktop/quran-qcf4/quran-qcf4-main
"""

import argparse
import json
import os
import re
import sys


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--qcf4', default=r'C:/Users/abubakr/Desktop/quran-qcf4/quran-qcf4-main')
    p.add_argument('--quran-data',
                   default=r'qcf_quran_lite-0.0.5/lib/src/data/quran_data.dart')
    p.add_argument('--qbsml', default='')
    return p.parse_args()


def load_pages(qcf4_dir):
    """Return {page: {'font': str, 'words_by_line': [(line_no, [word,...])]}}."""
    pages = {}
    for n in range(1, 605):
        with open(os.path.join(qcf4_dir, 'pages', f'{n:03d}.json'), encoding='utf-8') as f:
            data = json.load(f)
        pages[n] = {
            'font': data['font'],
            'lines': [(ln['line'], ln['words']) for ln in data['lines']],
        }
    return pages


def build_verse_data(pages):
    """verse_key -> {line: [chars...], 'end': char} in reading order."""
    verses = {}
    for page, info in pages.items():
        for line_no, words in info['lines']:
            for w in words:
                vk = w.get('verse_key')
                wtype = w.get('type')
                if not vk:
                    continue
                entry = verses.setdefault(vk, {'page': page, 'lines': {}, 'end': None})
                if wtype == 'end':
                    entry['end'] = w['char']
                else:
                    entry['lines'].setdefault(line_no, []).append(w['char'])
    return verses


def parse_quran_data(text):
    """Return list of entries (dicts) from the quran_data.dart source."""
    entries = []
    for m in re.finditer(r'\{\s*"id": \d+.*?\n  \},', text, re.S):
        body = m.group(0)
        entry = {}
        for key in ('id', 'sora', 'aya_no', 'page'):
            km = re.search(rf'"{key}": (\d+)', body)
            if km:
                entry[key] = int(km.group(1))
        qm = re.search(r'"qcfData":\s*"([^"]*)"', body, re.S)
        if qm:
            entry['qcfData'] = qm.group(1)
        am = re.search(r'"aya_text":\s*"((?:[^"\\]|\\.)*)"', body, re.S)
        if am:
            # Unescape Dart string escapes so line counts work on real newlines.
            entry['aya_text'] = am.group(1).replace('\\n', '\n')
        entries.append(entry)
    return entries


def dart_escape_qcf(s):
    """Escape a qcfData string for a Dart double-quoted literal."""
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')


def build_new_qcf_data(vk, entry, verses, problems):
    """Build the new qcfData for verse vk from quran-qcf4 word data."""
    v = verses.get(vk)
    aya_text = entry.get('aya_text', '')
    # Convention: every line of aya_text ends with '\n' (including the last),
    # except single-line verses which may have none.
    expected_lines = aya_text.count('\n')
    if not aya_text.endswith('\n'):
        expected_lines += 1

    if v is None:
        problems.append(f'{vk}: no quran-qcf4 data')
        return entry.get('qcfData', '')

    line_nos = sorted(v['lines'].keys())
    if len(line_nos) != expected_lines:
        problems.append(
            f'{vk} (page {v["page"]}): quran-qcf4 lines={len(line_nos)} '
            f'({line_nos}) vs aya_text lines={expected_lines}')

    parts = []
    for i, line_no in enumerate(line_nos):
        chars = ''.join(v['lines'][line_no])
        if i == len(line_nos) - 1 and v['end']:
            chars += v['end']
        parts.append(chars)
    return '\n'.join(parts)


def main():
    args = parse_args()
    pages = load_pages(args.qcf4)
    verses = build_verse_data(pages)
    print(f'Loaded {len(pages)} pages, {len(verses)} verses from quran-qcf4.')

    with open(args.quran_data, encoding='utf-8') as f:
        src = f.read()
    entries = parse_quran_data(src)
    print(f'Parsed {len(entries)} entries from quran_data.dart.')

    problems = []
    new_qcf = {}
    for e in entries:
        vk = f'{e["sora"]}:{e["aya_no"]}'
        new_qcf[vk] = build_new_qcf_data(vk, e, verses, problems)

    # Verify every verse has a mapping.
    missing = [vk for vk, q in new_qcf.items() if not q and vk in verses]
    if missing:
        problems.append(f'{len(missing)} verses produced empty qcfData: {missing[:10]}')

    print(f'validation: {len(problems)} problems')
    for p_ in problems[:40]:
        print(' -', p_)
    if problems:
        print('ABORTING: fix data before writing files.')
        sys.exit(1)

    # Rebuild the file: replace each qcfData value in place, preserving everything else.
    def replace_qcf(match):
        body = match.group(0)
        qm = re.search(r'"qcfData":\s*"([^"]*)"', body, re.S)
        if not qm:
            return body
        idm = re.search(r'"id": (\d+)', body)
        e = next((x for x in entries if x['id'] == int(idm.group(1))), None)
        if e is None:
            return body
        vk = f'{e["sora"]}:{e["aya_no"]}'
        new_val = dart_escape_qcf(new_qcf.get(vk, e['qcfData']))
        return body[:qm.start(1)] + new_val + body[qm.end(1):]

    new_src, count = re.subn(r'\{\s*"id": \d+.*?\n  \},', replace_qcf, src, flags=re.S)
    with open(args.quran_data, 'w', encoding='utf-8', newline='') as f:
        f.write(new_src)
    print(f'Rewrote {count} qcfData values in quran_data.dart.')

    # ---- font map ----
    with open(os.path.join(args.qcf4, 'font-map.json'), encoding='utf-8') as f:
        font_map = json.load(f)
    fam = {}
    for pg in range(1, 605):
        fam[pg] = font_map.get(str(pg), pages[pg]['font'])
    with open('qcf_quran_lite-0.0.5/lib/src/data/quran_qcf4_font_map.dart',
              'w', encoding='utf-8') as f:
        f.write('/// Generated by tools/generate_qcf4_data.py — do not edit by hand.\n')
        f.write('/// Page number → QCF4 font family (quran-qcf4 dataset).\n')
        f.write('const Map<int, String> quranQcf4FontMap = {\n')
        for pg in range(1, 605):
            f.write(f'  {pg}: \'{fam[pg]}\',\n')
        f.write('};\n')
    print('Wrote quran_qcf4_font_map.dart (604 entries).')

    # ---- qbsml header glyphs (style A) ----
    qbsml_path = args.qbsml or os.path.join(args.qcf4, 'qbsml.json')
    if not os.path.exists(qbsml_path):
        raise SystemExit(
            f'qbsml.json not found at {qbsml_path}. Download it from\n'
            'https://raw.githubusercontent.com/MohamadHajjRabee/quran-qcf4/main/qbsml.json\n'
            'and pass --qbsml <path>.')
    with open(qbsml_path, encoding='utf-8') as f:
        qbsml = json.load(f)
    glyphs = {}
    for s in qbsml.get('sets', []):
        if s.get('name') != 'surah_headers_style_a':
            continue
        for e in s.get('entries', []):
            glyphs[e['sura']] = chr(e['codepoint'])
    with open('qcf_quran_lite-0.0.5/lib/src/data/quran_qcf4_qbsml.dart',
              'w', encoding='utf-8') as f:
        f.write('/// Generated by tools/generate_qcf4_data.py — do not edit by hand.\n')
        f.write('/// Surah number → QCF4_QBSML surah-header glyph (style A).\n')
        f.write("const String quranQcf4QbsmlFontFamily = 'QCF4_QBSML';\n")
        f.write('const Map<int, String> quranQcf4SurahHeaderGlyphs = {\n')
        for sura in sorted(glyphs):
            f.write(f'  {sura}: \'{glyphs[sura]}\',\n')
        f.write('};\n')
    print(f'Wrote quran_qcf4_qbsml.dart ({len(glyphs)} surah header glyphs).')


if __name__ == '__main__':
    main()
