"""Offline tests for the Tafsir Badri merge.

Run: python -m unittest discover -s tool/audio_library -p "test_*.py"

Nothing here reaches the network or the bucket: build_tracks(), merge() and
validate() are pure over the TSV rows, a URL->bytes map and a hand-written
base. What they decide is what the «سخنرانی» page prints for 162 lectures that
belong to somebody else's server, so the rules worth pinning are the ones a
quiet edit would break: the URL is the file, the stem digit is the part label,
the live sections survive the merge, and a missing size is a refusal.

The source server flattened its files to the folder root and publishes the
ذاريات pair with inconsistent Latin spelling in the file names
(...zaryat-1 vs ...zariyat-2). Those facts are pinned below so a future
re-flatten or a spelling "fix" cannot quietly 404 a track or mislabel it.
"""

import copy
import json
import os
import unittest

import build_tafsir_badri_manifest as tb

HERE = os.path.dirname(os.path.abspath(__file__))
BASE_URL = "https://sunnatmedia.ir/download/Abdulghani-Badri/"


def track(folder, stem, title):
    return (BASE_URL + folder + "/" + stem + ".mp3", title)


def badri_row():
    return {"id": "lec-tb-01", "title": "الفاتحة",
            "file": BASE_URL + "001-Al-Fatihah.mp3",
            "sizeBytes": 47342193}


def live_base():
    """The shape the published v4 actually has: one speaker-less category,
    one with speakers whose flat list is their concatenation."""
    def one(tid, name):
        return {"id": tid, "title": name, "file": "k/" + tid, "sizeBytes": 100}

    return {
        "version": 4,
        "categories": [
            {"id": "yaqeen", "tracks": [one("yaqeen-01", "یک")], "speakers": []},
            {"id": "lectures",
             "tracks": [one("lec-01", "اول"), one("misc-01", "متفرقه")],
             "speakers": [
                 {"id": "ziaei", "title": "شیخ ضیایی",
                  "tracks": [one("lec-01", "اول")]},
                 {"id": "misc", "title": "متفرقه",
                  "tracks": [one("misc-01", "متفرقه")]}]},
        ],
    }


class UrlPartsTest(unittest.TestCase):
    def test_reads_both_part_digit_styles(self):
        # a bare suffix digit and a dash-separated one
        self.assertEqual(tb.part_of(BASE_URL + "002-Al-Baqarah/002-Al-Baqara8.mp3"), 8)
        self.assertEqual(tb.part_of(BASE_URL + "041-Fussilat/41-fosselat-1.mp3"), 1)

    def test_a_whole_surah_has_no_part_digit(self):
        self.assertIsNone(tb.part_of(BASE_URL + "013-Ar-Ra_d/013-Ar-Rad.mp3"))
        self.assertIsNone(tb.part_of(BASE_URL + "114-An-Nas/114-nas.mp3"))

    def test_folder_is_the_surah_segment(self):
        self.assertEqual(tb.folder_of(BASE_URL + "013-Ar-Ra_d/013-Ar-Rad.mp3"),
                         "013-Ar-Ra_d")


class GroupOrderTest(unittest.TestCase):
    def test_folders_follow_the_canonical_surah_number(self):
        rows = [track("114-An-Nas", "114-nas", "الناس"),
                track("002-Al-Baqarah", "002-Al-Baqara2", "البقرة 2"),
                track("002-Al-Baqarah", "002-Al-Baqara1", "البقرة 1"),
                track("001-Al-Fatihah", "001-Al-Fatihah", "الفاتحة")]
        ordered = tb.group_and_order(rows)
        # (url, raw title, part digit) — the digit decides the printed label
        self.assertEqual([t[1] for t in ordered],
                         ["الفاتحة", "البقرة 1", "البقرة 2", "الناس"])
        self.assertEqual([t[2] for t in ordered], [None, 1, 2, None])

    def test_parts_are_ordered_by_the_stem_digit_not_the_row_order(self):
        # The source publishes the الذاريات pair labelled the other way round.
        rows = [track("051-Adh-Dhariyat", "51-zariyat-2", "الذاريات 1"),
                track("051-Adh-Dhariyat", "51-zaryat-1", "الذاريات 2")]
        tracks = tb.build_tracks(rows, {r[0]: 10 for r in rows}, [])
        self.assertEqual([(t["title"], os.path.basename(t["file"]))
                          for t in tracks],
                         [("الذاريات 1", "51-zaryat-1.mp3"),
                          ("الذاريات 2", "51-zariyat-2.mp3")])

    def test_a_folder_without_part_digits_keeps_the_source_order(self):
        rows = [track("007-Al-A_raf", "007-Al-ArafX", "الأعراف"),
                track("007-Al-A_raf", "007-Al-ArafY", "الأعراف")]
        ordered = tb.group_and_order(rows)
        self.assertEqual([t[2] for t in ordered], [None, None])
        self.assertEqual([t[1] for t in ordered], ["الأعراف", "الأعراف"])

    def test_a_label_that_already_carries_a_number_is_replaced_not_doubled(self):
        self.assertEqual(tb.title_for("البقرة 7", 3, True), "البقرة 3")
        self.assertEqual(tb.title_for("البقرة", 3, True), "البقرة 3")
        # a whole surah keeps its own words
        self.assertEqual(tb.title_for("يس", None, True), "يس")


class BuildTracksTest(unittest.TestCase):
    def test_the_file_is_the_published_url_verbatim(self):
        rows = [track("036-Ya-Sin", "036-Ya%20Seen", "يس"),
                track("005-Al-Ma_idah", "005-Al-Maeda1", "المائدة 1")]
        sizes = {BASE_URL + "036-Ya-Sin/036-Ya%20Seen.mp3": 50008115,
                 BASE_URL + "005-Al-Ma_idah/005-Al-Maeda1.mp3": 4000}
        tracks = tb.build_tracks(rows, sizes, [])
        files = [t["file"] for t in tracks]
        self.assertIn(BASE_URL + "036-Ya-Sin/036-Ya%20Seen.mp3", files)
        self.assertIn(BASE_URL + "005-Al-Ma_idah/005-Al-Maeda1.mp3", files)
        for f in files:
            self.assertNotIn("%25", f)          # no double-encoding
            self.assertTrue(f.startswith("https://"))

    def test_ids_are_the_reserved_prefix_and_contiguous(self):
        rows = [track("%03d-Folder" % i, "x%d" % i, "s%d" % i) for i in range(1, 3)]
        tracks = tb.build_tracks(rows, {r[0]: 10 for r in rows}, [])
        self.assertEqual([t["id"] for t in tracks], ["lec-tb-01", "lec-tb-02"])

    def test_an_unmeasured_url_is_a_problem_not_a_zero_size(self):
        rows = [track("001-Al-Fatihah", "001-Al-Fatihah", "الفاتحة")]
        problems = []
        tracks = tb.build_tracks(rows, {}, problems)
        self.assertTrue(any("no measured size" in p for p in problems), problems)
        self.assertEqual(tracks[0]["sizeBytes"], 0)

    def test_a_relative_url_is_refused(self):
        rows = [("sokhanrani/tafsir-badri/1.opus", "یک")]
        problems = []
        tb.build_tracks(rows, {"sokhanrani/tafsir-badri/1.opus": 10}, problems)
        self.assertTrue(any("not an https URL" in p for p in problems), problems)


class MergeTest(unittest.TestCase):
    def test_the_live_base_is_never_mutated(self):
        base = live_base()
        before = copy.deepcopy(base)
        problems = []
        tb.merge(base, [badri_row()], problems)
        self.assertEqual(base, before)
        self.assertEqual(problems, [])

    def test_the_speaker_joins_last_and_the_flat_list_follows(self):
        manifest = tb.merge(live_base(), [badri_row()], [])
        lectures = manifest["categories"][1]
        self.assertEqual([s["id"] for s in lectures["speakers"]],
                         ["ziaei", "misc", "tafsir-badri"])
        self.assertEqual([t["id"] for t in lectures["tracks"]],
                         ["lec-01", "misc-01", "lec-tb-01"])
        # untouched neighbours keep their bytes
        self.assertEqual(manifest["categories"][0], live_base()["categories"][0])

    def test_version_moves_one_up_from_the_base(self):
        self.assertEqual(tb.merge(live_base(), [badri_row()], [])["version"], 5)

    def test_a_re_run_replaces_the_section_it_published(self):
        once = tb.merge(live_base(), [badri_row()], [])
        twice = tb.merge(once, [badri_row()], [])
        lectures = twice["categories"][1]
        self.assertEqual(sum(1 for s in lectures["speakers"]
                             if s["id"] == "tafsir-badri"), 1)
        self.assertEqual(len(lectures["tracks"]), 3)

    def test_a_base_without_lectures_is_reported(self):
        problems = []
        tb.merge({"version": 4, "categories": [live_base()["categories"][0]]},
                 [badri_row()], problems)
        self.assertTrue(any("no 'lectures' category" in p for p in problems),
                        problems)


class ValidateTest(unittest.TestCase):
    def test_a_speaker_less_category_is_still_checked(self):
        # The 23 يقین rows live only in the flat list: nothing may skip them.
        base = live_base()
        base["categories"][0]["tracks"][0]["sizeBytes"] = 0
        problems = []
        count = tb.validate(base, problems)
        self.assertEqual(count, 3)
        self.assertTrue(any(p.startswith("yaqeen-01") for p in problems), problems)

    def test_flat_and_sections_must_agree(self):
        base = live_base()
        base["categories"][1]["tracks"] = base["categories"][1]["tracks"][:1]
        problems = []
        tb.validate(base, problems)
        self.assertTrue(any("flat tracks and sections disagree" in p
                            for p in problems), problems)

    def test_an_empty_speaker_is_a_problem(self):
        base = live_base()
        base["categories"][1]["speakers"].append(
            {"id": "nobody", "title": "خالی", "tracks": []})
        problems = []
        tb.validate(base, problems)
        self.assertTrue(any("a speaker with no tracks" in p
                            for p in problems), problems)

    def test_a_duplicate_id_across_categories_is_a_problem(self):
        base = live_base()
        base["categories"][1]["tracks"][1]["id"] = "yaqeen-01"
        base["categories"][1]["speakers"][1]["tracks"][0]["id"] = "yaqeen-01"
        problems = []
        tb.validate(base, problems)
        self.assertTrue(any("duplicate track id" in p for p in problems), problems)

    def test_the_published_merge_is_valid(self):
        problems = []
        manifest = tb.merge(live_base(), [badri_row()], [])
        self.assertEqual(tb.validate(manifest, problems), 4)
        self.assertEqual(problems, [])


class RealInputsTest(unittest.TestCase):
    """The shipped 162-row pair: the TSV and the probed sizes must still agree."""

    @classmethod
    def setUpClass(cls):
        cls.rows = tb.read_tracks(os.path.join(HERE, "tafsir_badri_tracks.tsv"))
        cls.sizes = tb.read_sizes(os.path.join(HERE, "tafsir_badri_sizes.json"))

    def test_every_row_has_a_measured_size(self):
        missing = [url for url, _ in self.rows if not self.sizes.get(url)]
        self.assertEqual(missing, [])

    def test_the_section_is_canonical_contiguous_and_absolute(self):
        problems = []
        tracks = tb.build_tracks(self.rows, self.sizes, problems)
        self.assertEqual(problems, [])
        self.assertEqual(len(tracks), 162)
        self.assertEqual([t["id"] for t in tracks],
                         ["lec-tb-%02d" % i for i in range(1, 163)])
        self.assertEqual(tracks[0]["title"], "مقدمه ۱")
        self.assertEqual(tracks[-1]["title"], "الناس")
        for t in tracks:
            self.assertTrue(t["file"].startswith("https://sunnatmedia.ir/"))
            self.assertGreater(t["sizeBytes"], 0)
            # Regression pin: the live host serves these flat at the folder
            # root. A subdirectory URL (the previous layout) now 404s and would
            # make every track unplayable; it must never sneak back in.
            self.assertEqual(t["file"], BASE_URL + os.path.basename(t["file"]))

    def test_the_hazard_rows_survive_verbatim(self):
        tracks = tb.build_tracks(self.rows, self.sizes, [])
        by_title = {t["title"]: t for t in tracks}
        # the live host flattened every file to the folder root (no subdir, no
        # %20), so each track's file is exactly BASE + its basename, verbatim.
        self.assertEqual(by_title["الفاتحة"]["file"], BASE_URL + "001-Al-Fatihah.mp3")
        self.assertEqual(by_title["يس"]["file"], BASE_URL + "036-YaSeen.mp3")
        # The source publishes the الذاريات pair with inconsistent Latin
        # spelling in the file names (...zaryat-1 vs ...zariyat-2). What must
        # hold is that each label follows its STEM digit and the file is the
        # flat, verbatim URL — not a particular Latin spelling.
        self.assertIn("الذاريات 1", by_title)
        self.assertIn("الذاريات 2", by_title)
        for title, digit in (("الذاريات 1", "1"), ("الذاريات 2", "2")):
            t = by_title[title]
            bn = os.path.basename(t["file"])
            self.assertEqual(t["file"], BASE_URL + bn)  # flat, verbatim
            self.assertTrue(bn.endswith(digit + ".mp3"), bn)


if __name__ == "__main__":
    unittest.main()
