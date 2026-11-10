"""
Convert quran.sql (MySQL dump) to quran_offline.json for the Flutter app.
Run: python tools/sql_to_json.py

Input:  quran.sql (in project root)
Output: assets/quran_offline.json
"""

import os
import re
import json
import sys

SQL_FILE = os.path.join(os.path.dirname(__file__), '..', 'quran.sql')
OUTPUT_FILE = os.path.join(os.path.dirname(__file__), '..', 'assets', 'quran_offline.json')

# Surah metadata (hardcoded since SQL may not have full metadata)
SURAH_META = {
    1: ("الفاتحة", "Al-Fatihah", "فاتحه", 7, True, 1, 1, True),
    2: ("البقرة", "Al-Baqarah", "بقره", 286, False, 2, 49, False),
    3: ("آل عمران", "Aal-E-Imran", "آل عمران", 200, False, 50, 76, False),
    4: ("النساء", "An-Nisa", "نساء", 176, False, 77, 105, False),
    5: ("المائدة", "Al-Ma'idah", "مائده", 120, False, 106, 127, False),
    6: ("الأنعام", "Al-An'am", "انعام", 165, True, 128, 150, False),
    7: ("الأعراف", "Al-A'raf", "اعراف", 206, True, 151, 176, False),
    8: ("الأنفال", "Al-Anfal", "انفال", 75, False, 177, 186, False),
    9: ("التوبة", "At-Tawbah", "توبه", 129, False, 187, 207, False),
    10: ("يونس", "Yunus", "یونس", 109, True, 208, 220, False),
    11: ("هود", "Hud", "هود", 123, True, 221, 234, False),
    12: ("يوسف", "Yusuf", "یوسف", 111, True, 235, 248, False),
    13: ("الرعد", "Ar-Ra'd", "رعد", 43, False, 249, 254, False),
    14: ("إبراهيم", "Ibrahim", "ابراهیم", 52, True, 255, 261, False),
    15: ("الحجر", "Al-Hijr", "حجر", 99, True, 262, 266, False),
    16: ("النحل", "An-Nahl", "نحل", 128, True, 267, 281, False),
    17: ("الإسراء", "Al-Isra", "اسراء", 111, True, 282, 292, False),
    18: ("الكهف", "Al-Kahf", "کهف", 110, True, 293, 304, False),
    19: ("مريم", "Maryam", "مریم", 98, True, 305, 311, False),
    20: ("طه", "Taha", "طه", 135, True, 312, 321, False),
    21: ("الأنبياء", "Al-Anbiya", "انبیاء", 112, True, 322, 331, False),
    22: ("الحج", "Al-Hajj", "حج", 78, False, 332, 341, False),
    23: ("المؤمنون", "Al-Mu'minun", "مؤمنون", 118, True, 342, 349, False),
    24: ("النور", "An-Nur", "نور", 64, False, 350, 358, False),
    25: ("الفرقان", "Al-Furqan", "فرقان", 77, True, 359, 366, False),
    26: ("الشعراء", "Ash-Shu'ara", "شعراء", 227, True, 367, 376, False),
    27: ("النمل", "An-Naml", "نمل", 93, True, 377, 384, False),
    28: ("القصص", "Al-Qasas", "قصص", 88, True, 385, 395, False),
    29: ("العنكبوت", "Al-Ankabut", "عنکبوت", 69, True, 396, 403, False),
    30: ("الروم", "Ar-Rum", "روم", 60, True, 404, 410, False),
    31: ("لقمان", "Luqman", "لقمان", 34, True, 411, 414, False),
    32: ("السجدة", "As-Sajdah", "سجده", 30, True, 415, 417, False),
    33: ("الأحزاب", "Al-Ahzab", "احزاب", 73, False, 418, 427, False),
    34: ("سبأ", "Saba", "سبأ", 54, True, 428, 433, False),
    35: ("فاطر", "Fatir", "فاطر", 45, True, 434, 439, False),
    36: ("يس", "Ya-Sin", "یس", 83, True, 440, 445, False),
    37: ("الصافات", "As-Saffat", "صافات", 182, True, 446, 452, False),
    38: ("ص", "Sad", "ص", 88, True, 453, 457, False),
    39: ("الزمر", "Az-Zumar", "زمر", 75, True, 458, 466, False),
    40: ("غافر", "Ghafir", "غافر", 85, True, 467, 476, False),
    41: ("فصلت", "Fussilat", "فصلت", 54, True, 477, 482, False),
    42: ("الشورى", "Ash-Shura", "شوری", 53, True, 483, 488, False),
    43: ("الزخرف", "Az-Zukhruf", "زخرف", 89, True, 489, 495, False),
    44: ("الدخان", "Ad-Dukhan", "دخان", 59, True, 496, 498, False),
    45: ("الجاثية", "Al-Jathiyah", "جاثیه", 37, True, 499, 501, False),
    46: ("الأحقاف", "Al-Ahqaf", "احقاف", 35, True, 502, 506, False),
    47: ("محمد", "Muhammad", "محمد", 38, False, 507, 510, False),
    48: ("الفتح", "Al-Fath", "فتح", 29, False, 511, 514, False),
    49: ("الحجرات", "Al-Hujurat", "حجرات", 18, False, 515, 517, False),
    50: ("ق", "Qaf", "ق", 45, True, 518, 520, False),
    51: ("الذاريات", "Adh-Dhariyat", "ذاریات", 60, True, 520, 522, False),
    52: ("الطور", "At-Tur", "طور", 49, True, 523, 525, False),
    53: ("النجم", "An-Najm", "نجم", 62, True, 526, 527, False),
    54: ("القمر", "Al-Qamar", "قمر", 55, True, 528, 530, False),
    55: ("الرحمن", "Ar-Rahman", "رحمن", 78, False, 531, 533, False),
    56: ("الواقعة", "Al-Waqi'ah", "واقعه", 96, True, 534, 536, False),
    57: ("الحديد", "Al-Hadid", "حديد", 29, False, 537, 541, False),
    58: ("المجادلة", "Al-Mujadilah", "مجادله", 22, False, 542, 544, False),
    59: ("الحشر", "Al-Hashr", "حشر", 24, False, 545, 548, False),
    60: ("الممتحنة", "Al-Mumtahanah", "ممتحنه", 13, False, 549, 550, False),
    61: ("الصف", "As-Saff", "صف", 14, False, 551, 551, False),
    62: ("الجمعة", "Al-Jumu'ah", "جمعه", 11, False, 552, 552, False),
    63: ("المنافقون", "Al-Munafiqun", "منافقون", 11, False, 553, 553, False),
    64: ("التغابن", "At-Taghabun", "تغابن", 18, True, 554, 555, False),
    65: ("الطلاق", "At-Talaq", "طلاق", 12, False, 556, 557, False),
    66: ("التحريم", "At-Tahrim", "تحریم", 12, False, 558, 559, False),
    67: ("الملك", "Al-Mulk", "ملک", 30, True, 560, 561, False),
    68: ("القلم", "Al-Qalam", "قلم", 52, True, 562, 564, False),
    69: ("الحاقة", "Al-Haqqah", "حاقة", 52, True, 564, 566, False),
    70: ("المعارج", "Al-Ma'arij", "معارج", 44, True, 566, 568, False),
    71: ("نوح", "Nuh", "نوح", 28, True, 568, 570, False),
    72: ("الجن", "Al-Jinn", "جن", 28, True, 570, 572, False),
    73: ("المزمل", "Al-Muzzammil", "مزمل", 20, True, 572, 573, False),
    74: ("المدثر", "Al-Muddaththir", "مدثر", 56, True, 574, 575, False),
    75: ("القيامة", "Al-Qiyamah", "قیامت", 40, True, 577, 577, False),
    76: ("الإنسان", "Al-Insan", "انسان", 31, False, 578, 579, False),
    77: ("المرسلات", "Al-Mursalat", "مرسلات", 50, True, 580, 581, False),
    78: ("النبأ", "An-Naba", "نبأ", 40, True, 582, 582, False),
    79: ("النازعات", "An-Nazi'at", "نازعات", 46, True, 583, 584, False),
    80: ("عبس", "Abasa", "عبس", 42, True, 585, 585, False),
    81: ("التكوير", "At-Takwir", "تکویر", 29, True, 586, 586, False),
    82: ("الانفطار", "Al-Infitar", "انفطار", 19, True, 587, 587, False),
    83: ("المطففين", "Al-Mutaffifin", "مطففین", 36, True, 587, 588, False),
    84: ("الانشقاق", "Al-Inshiqaq", "انشقاق", 25, True, 589, 589, False),
    85: ("البروج", "Al-Buruj", "بروج", 22, True, 590, 590, False),
    86: ("الطارق", "At-Tariq", "طارق", 17, True, 591, 591, False),
    87: ("الأعلى", "Al-A'la", "اعلی", 19, True, 591, 592, False),
    88: ("الغاشية", "Al-Ghashiyah", "غاشیه", 26, True, 592, 592, False),
    89: ("الفجر", "Al-Fajr", "فجر", 30, True, 593, 594, False),
    90: ("البلد", "Al-Balad", "بلد", 20, True, 595, 595, False),
    91: ("الشمس", "Ash-Shams", "شمس", 15, True, 596, 596, False),
    92: ("الليل", "Al-Layl", "لیل", 21, True, 596, 596, False),
    93: ("الضحى", "Ad-Duha", "ضحی", 11, True, 597, 597, False),
    94: ("الشرح", "Ash-Sharh", "شرح", 8, True, 597, 597, False),
    95: ("التين", "At-Tin", "تین", 8, True, 598, 598, False),
    96: ("العلق", "Al-Alaq", "علق", 19, True, 598, 598, False),
    97: ("القدر", "Al-Qadr", "قدر", 5, True, 599, 599, False),
    98: ("البينة", "Al-Bayyinah", "بینه", 8, False, 599, 600, False),
    99: ("الزلزلة", "Az-Zalzalah", "زلزله", 8, False, 600, 600, False),
    100: ("العاديات", "Al-Adiyat", "عادیات", 11, True, 601, 601, False),
    101: ("القارعة", "Al-Qari'ah", "قارعه", 11, True, 601, 601, False),
    102: ("التكاثر", "At-Takathur", "تکاثر", 8, True, 602, 602, False),
    103: ("العصر", "Al-Asr", "عصر", 3, True, 602, 602, False),
    104: ("الهمزة", "Al-Humazah", "همزه", 9, True, 602, 603, False),
    105: ("الفيل", "Al-Fil", "فیل", 5, True, 603, 603, False),
    106: ("قريش", "Quraysh", "قریش", 4, True, 603, 603, False),
    107: ("الماعون", "Al-Ma'un", "ماعون", 7, True, 604, 604, False),
    108: ("الكوثر", "Al-Kawthar", "کوثر", 3, True, 604, 604, False),
    109: ("الكافرون", "Al-Kafirun", "کافرون", 6, True, 604, 604, False),
    110: ("النصر", "An-Nasr", "نصر", 3, False, 604, 604, False),
    111: ("المسد", "Al-Masad", "مسد", 5, True, 604, 604, False),
    112: ("الإخلاص", "Al-Ikhlas", "اخلاص", 4, True, 604, 604, False),
    113: ("الفلق", "Al-Falaq", "فلق", 5, True, 604, 604, False),
    114: ("الناس", "An-Nas", "ناس", 6, True, 604, 604, False),
}


def parse_ayahs_from_sql(sql_content):
    """Extract ayah data from SQL INSERT statements."""
    ayahs = []

    # Match INSERT INTO `ayahs` VALUES (...) patterns
    pattern = r"INSERT INTO `ayahs`[^;]*VALUES\s*(.*?);"
    matches = re.findall(pattern, sql_content, re.DOTALL)

    for match in matches:
        # Parse individual value tuples
        # Format: (id, number, text, number_in_surah, page, surah_id, hizb_id, juz_id, sajda, created_at, updated_at)
        row_pattern = r"\((\d+),\s*(\d+),\s*'([^']*)',\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),"
        rows = re.findall(row_pattern, match)

        for row in rows:
            ayah_id, number, text, num_in_surah, page, surah_id, hizb_id, juz_id, sajda = row
            ayahs.append({
                'id': int(ayah_id),
                'surah': int(surah_id),
                'ayah': int(num_in_surah),
                'verse_number': int(num_in_surah),
                'verse_key': f"{surah_id}:{num_in_surah}",
                'text_uthmani': text.strip(),
                'text_imlaei': text.strip(),
                'page': int(page),
                'juz': int(juz_id),
                'hizb': int(hizb_id),
                'sajdah': int(sajda) if int(sajda) == 1 else None,
            })

    return ayahs


def build_surahs_meta():
    """Build surah metadata list."""
    surahs = []
    for i in range(1, 115):
        if i in SURAH_META:
            name_arabic, name_simple, name_persian, ayah_count, is_makki, start_page, end_page, bismillah_pre = SURAH_META[i]
            surahs.append({
                'id': i,
                'name_arabic': name_arabic,
                'name_simple': name_simple,
                'name_persian': name_persian,
                'ayah_count': ayah_count,
                'revelation_place': 'makkah' if is_makki else 'madinah',
                'start_page': start_page,
                'end_page': end_page,
                'bismillah_pre': bismillah_pre,
            })
    return surahs


def main():
    print("=" * 50)
    print("  SQL to JSON Converter")
    print("=" * 50)

    if not os.path.exists(SQL_FILE):
        print(f"\nERROR: {SQL_FILE} not found!")
        print("Place quran.sql in the project root.")
        sys.exit(1)

    print(f"\nReading {SQL_FILE}...")
    with open(SQL_FILE, 'r', encoding='utf-8-sig') as f:
        sql_content = f.read()

    print("Parsing ayahs...")
    ayahs = parse_ayahs_from_sql(sql_content)
    print(f"  Found {len(ayahs)} ayahs")

    if len(ayahs) == 0:
        print("\nERROR: No ayahs found in SQL file!")
        print("The SQL format may be different than expected.")
        sys.exit(1)

    print("Building surah metadata...")
    surahs = build_surahs_meta()

    output = {
        'version': '1.0',
        'source': 'quran.sql',
        'surahs': surahs,
        'ayahs': ayahs,
        'translations': {},  # No translations in this SQL dump
    }

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    print(f"Writing {OUTPUT_FILE}...")
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False)

    size_kb = os.path.getsize(OUTPUT_FILE) // 1024
    print(f"\n{'=' * 50}")
    print(f"  DONE!")
    print(f"  Ayahs: {len(ayahs)}")
    print(f"  Surahs: {len(surahs)}")
    print(f"  Output: {OUTPUT_FILE}")
    print(f"  Size: {size_kb}KB")
    print(f"{'=' * 50}")


if __name__ == '__main__':
    main()
