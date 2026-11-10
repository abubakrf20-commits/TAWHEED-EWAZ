"""Offline tests for the manifest composer's lecture-section rules.

Run: python -m unittest discover -s tool/audio_library -p "test_*.py"

No bucket credentials needed: assemble() is pure over a {key: (size, etag)}
listing, so the new-speaker folders, the numeric ordering and the «متفرقه»
section inside lectures are all pinned here. carry_external() is pure over a
published manifest plus composed categories, so the rule that keeps a
third-party-hosted section through every bucket run is pinned here too. The
live bucket snapshot itself is covered by test/features/audio_library/
audio_library_merged_manifest_test.dart.
"""

import contextlib
import io
import json
import os
import unittest

import compose_manifest
from compose_manifest import assemble, build_group, carry_external

HERE = os.path.dirname(os.path.abspath(__file__))


def assemble_quiet(listing):
    """assemble() logs section titles (Persian) for the uploader's console;
    the Windows test console cannot encode them, so capture the log."""
    with contextlib.redirect_stdout(io.StringIO()):
        return assemble(listing)


def goudarzi_group():
    return next(
        g for g in compose_manifest.GROUPS
        if g.get("speaker") == ("goudarzi", "شیخ محمد رحیمی"))


class NumericGroupTest(unittest.TestCase):
    def test_orders_by_lesson_number_without_csv(self):
        group = dict(goudarzi_group())
        listing = {
            "sokhanrani/rahemi/10. دهم.opus": (1, "e1"),
            "sokhanrani/rahemi/2. دوم.opus": (1, "e2"),
            "sokhanrani/rahemi/1. اول.opus": (1, "e3"),
        }
        tracks, claimed, problems = build_group(group, listing)
        self.assertEqual(problems, [])
        self.assertEqual([t["title"] for t in tracks], ["اول", "دوم", "دهم"])
        self.assertEqual(
            [t["id"] for t in tracks], ["lec-gd-01", "lec-gd-02", "lec-gd-03"])
        self.assertEqual(claimed, set(listing))

    def test_unnumbered_file_is_reported_and_excluded(self):
        group = dict(goudarzi_group())
        listing = {
            "sokhanrani/rahemi/1. اول.opus": (1, "e1"),
            "sokhanrani/rahemi/بدون شماره.opus": (1, "e2"),
        }
        tracks, claimed, problems = build_group(group, listing)
        self.assertEqual(len(tracks), 1)
        self.assertTrue(
            any("carries no number" in p for p in problems), problems)
        # Claimed, so it cannot leak into «متفرقه» under a wrong identity.
        self.assertIn("sokhanrani/rahemi/بدون شماره.opus", claimed)


class AssembleLecturesTest(unittest.TestCase):
    def _listing(self):
        rows = compose_manifest.read_csv_order(
            os.path.join(HERE, "ziaei_mapping.csv"))
        listing = {
            "sokhanrani/ziaei/" + rows[0][0]: (1000, "z1"),
            "sokhanrani/ziaei/" + rows[1][0]: (1000, "z2"),
            "sokhanrani/rahemi/2. دوم.opus": (1000, "g2"),
            "sokhanrani/rahemi/1. اول.opus": (1000, "g1"),
            "sokhanrani/سخنرانی تنها.opus": (1000, "m1"),
            "index.json": (10, "ix"),
        }
        return listing

    def test_misc_is_a_section_inside_lectures(self):
        categories, _ = assemble_quiet(self._listing())
        self.assertEqual([c["id"] for c in categories],
                         ["yaqeen", "anasheed", "lectures"])
        lectures = next(c for c in categories if c["id"] == "lectures")
        self.assertEqual(
            [(s["id"], s["title"]) for s in lectures["speakers"]],
            [("ziaei", "شیخ ضیایی"),
             ("goudarzi", "شیخ محمد رحیمی"),
             ("misc", "متفرقه")])
        misc = lectures["speakers"][-1]
        self.assertEqual([t["id"] for t in misc["tracks"]], ["misc-01"])
        self.assertEqual(misc["tracks"][0]["file"], "sokhanrani/سخنرانی تنها.opus")

    def test_empty_speaker_folders_contribute_no_section(self):
        # bazmandegan/ and the Badri folders have no files yet: no empty tiles.
        categories, _ = assemble_quiet(self._listing())
        lectures = next(c for c in categories if c["id"] == "lectures")
        ids = [s["id"] for s in lectures["speakers"]]
        self.assertNotIn("bazmandegan", ids)
        self.assertNotIn("tafsir-badri", ids)

    def test_sections_tile_the_flat_list_with_unique_ids(self):
        categories, problems = assemble_quiet(self._listing())
        lectures = next(c for c in categories if c["id"] == "lectures")
        flat = [t["id"] for t in lectures["tracks"]]
        tiled = [t["id"] for s in lectures["speakers"] for t in s["tracks"]]
        self.assertEqual(tiled, flat)
        self.assertEqual(len(set(flat)), len(flat))
        files = [t["file"] for t in lectures["tracks"]]
        self.assertEqual(len(set(files)), len(files))
        self.assertNotIn("duplicate track ids", problems)
        self.assertNotIn("duplicate object keys", problems)


class TafsirBadriAliasTest(unittest.TestCase):
    """One section, two folder spellings.

    The first real upload was staged under `tafseer-badri/` while the group
    table and the hosting doc said `tafsir-badri/`. An unclaimed spelling does
    not fail loudly — it drops into «متفرقه» under the wrong speaker — so both
    are pinned as one group with one numbering sequence.
    """

    def _group(self):
        return next(
            g for g in compose_manifest.GROUPS
            if g.get("speaker", (None,))[0] == "tafsir-badri")

    def test_title_is_the_users_exact_wording(self):
        self.assertEqual(
            self._group()["speaker"],
            ("tafsir-badri", "تفسیر قرآن مولانا عبدالغنی بدری"))

    def test_both_spellings_are_claimed_by_the_same_group(self):
        self.assertEqual(
            compose_manifest._prefixes(self._group()),
            ["sokhanrani/tafsir-badri/", "sokhanrani/tafseer-badri/"])

    def test_alias_folder_lands_in_the_section_not_in_misc(self):
        listing = {
            "sokhanrani/tafseer-badri/1 - مقدمه توحید بخش اول.opus":
                (20007701, "e1"),
        }
        # A synthetic listing holds none of the other folders' files, so the
        # CSV groups legitimately report missing rows here; what matters is
        # that nothing about the Badri group or «متفرقه» is reported.
        categories, problems = assemble_quiet(listing)
        self.assertFalse([p for p in problems if "badri" in p], problems)
        lectures = next(c for c in categories if c["id"] == "lectures")
        self.assertEqual(
            [(s["id"], s["title"]) for s in lectures["speakers"]],
            [("tafsir-badri", "تفسیر قرآن مولانا عبدالغنی بدری")])
        section = lectures["speakers"][0]
        self.assertEqual([t["id"] for t in section["tracks"]], ["lec-tb-01"])
        self.assertEqual([t["title"] for t in section["tracks"]],
                         ["مقدمه توحید بخش اول"])
        self.assertNotIn("misc", [s["id"] for s in lectures["speakers"]])
        # The single file is claimed, not left as an unclaimed lecture object.
        self.assertFalse(
            [p for p in problems if "unclaimed" in p], problems)

    def test_numbering_is_one_sequence_across_both_spellings(self):
        listing = {
            "sokhanrani/tafseer-badri/1 - اول.opus": (10, "e1"),
            "sokhanrani/tafsir-badri/2 - دوم.opus": (10, "e2"),
        }
        tracks, claimed, problems = build_group(self._group(), listing)
        self.assertEqual(problems, [])
        self.assertEqual([t["id"] for t in tracks], ["lec-tb-01", "lec-tb-02"])
        self.assertEqual([t["title"] for t in tracks], ["اول", "دوم"])
        self.assertEqual(claimed, set(listing))

    def test_one_name_under_both_spellings_is_reported_not_dropped_silently(self):
        listing = {
            "sokhanrani/tafsir-badri/1 - اول.opus": (10, "e1"),
            "sokhanrani/tafseer-badri/1 - اول.opus": (10, "e2"),
        }
        tracks, claimed, problems = build_group(self._group(), listing)
        self.assertEqual(len(tracks), 1)
        self.assertTrue(any("share the name" in p for p in problems), problems)
        # Both keys stay claimed, so the dropped twin cannot surface as متفرقه.
        self.assertEqual(claimed, set(listing))


class CarryExternalTest(unittest.TestCase):
    """A section hosted off the bucket cannot come from a bucket listing.

    compose_manifest() writes index.json from `list_objects()` alone, so every
    track whose `file` is an absolute URL — the Badri tafsir's 160 lectures —
    would simply not be in the next published manifest. carry_external() reads
    the published copy and re-attaches them; each rule below is a way that a
    silent deletion or a double-hosted section could reach a phone.
    """

    def _bucket_categories(self):
        ziaei = {"id": "lec-01", "title": "توحید",
                 "file": "sokhanrani/ziaei/1. توحید.opus", "sizeBytes": 10}
        return [{"id": "lectures", "tracks": [ziaei],
                 "speakers": [{"id": "ziaei", "title": "شیخ ضیایی",
                               "tracks": [ziaei]}]}]

    def _previous(self, tracks=None):
        badri = {"id": "lec-tb-01", "title": "الفاتحة",
                 "file": "https://sunnatmedia.ir/download/Abdulghani-Badri/"
                         "001-Al-Fatihah/001-Al-Fatihah.mp3",
                 "sizeBytes": 47342193}
        return {"version": 5, "categories": [{
            "id": "lectures", "tracks": tracks if tracks is not None else [badri],
            "speakers": [{"id": "tafsir-badri",
                          "title": "تفسیر قرآن مولانا عبدالغنی بدری",
                          "tracks": tracks if tracks is not None else [badri]}]}]}

    def test_the_hosted_section_is_re_attached_and_the_flat_list_follows(self):
        categories = self._bucket_categories()
        problems = []
        self.assertEqual(carry_external(self._previous(), categories, problems), 1)
        self.assertEqual(problems, [])
        lectures = categories[0]
        self.assertEqual([s["id"] for s in lectures["speakers"]],
                         ["ziaei", "tafsir-badri"])
        self.assertEqual([t["id"] for t in lectures["tracks"]],
                         ["lec-01", "lec-tb-01"])
        self.assertEqual(lectures["tracks"],
                         [t for s in lectures["speakers"] for t in s["tracks"]])
        # the URL is untouched — re-encoding it would break the fetch
        self.assertTrue(lectures["tracks"][-1]["file"].startswith("https://"))

    def test_bucket_files_are_carried_verbatim_not_rewritten(self):
        categories = self._bucket_categories()
        before = json.dumps(self._previous(), sort_keys=True)
        carry_external(self._previous(), categories, [])
        self.assertEqual(json.dumps(self._previous(), sort_keys=True), before)

    def test_the_same_section_hosted_and_in_the_bucket_is_refused(self):
        # If the uploader ever mirrors the folder here, publishing both would
        # give one speaker two files; that is a question, not a decision here.
        categories = self._bucket_categories()
        hosted = self._previous()["categories"][0]["speakers"][0]["tracks"][0]
        twin = dict(hosted, file="sokhanrani/tafsir-badri/1 - اول.opus",
                    id="lec-tb-01")
        categories[0]["speakers"].append(
            {"id": "tafsir-badri", "title": "تفسیر", "tracks": [twin]})
        categories[0]["tracks"].append(twin)
        problems = []
        self.assertEqual(carry_external(self._previous(), categories, problems), 0)
        self.assertTrue(any("hosted AND in the bucket" in p for p in problems),
                        problems)
        self.assertEqual(len(categories[0]["speakers"]), 2)

    def test_a_hosted_track_with_no_section_of_its_own_is_reported(self):
        previous = {"version": 5, "categories": [{
            "id": "yaqeen",
            "tracks": [{"id": "yaqeen-01", "title": "x",
                        "file": "https://elsewhere.example/1.mp3",
                        "sizeBytes": 5}]}]}
        problems = []
        carry_external(previous, [{"id": "yaqeen", "tracks": [],
                                   "speakers": []}], problems)
        self.assertTrue(any("section-less category" in p for p in problems),
                        problems)

    def test_a_section_mixing_hosted_and_bucket_files_is_reported(self):
        mixed = self._previous(tracks=[
            {"id": "lec-tb-01", "title": "الفاتحة",
             "file": "https://sunnatmedia.ir/x/1.mp3", "sizeBytes": 5},
            {"id": "lec-tb-02", "title": "البقرة",
             "file": "sokhanrani/tafsir-badri/2.opus", "sizeBytes": 5}])
        problems = []
        carried = carry_external(mixed, self._bucket_categories(), problems)
        self.assertEqual(carried, 1)
        self.assertTrue(any("mixes hosted and bucket files" in p for p in problems),
                        problems)

    def test_a_category_that_this_run_dropped_is_reported(self):
        problems = []
        carry_external(self._previous(), [{"id": "anasheed", "tracks": [],
                                           "speakers": []}], problems)
        self.assertTrue(any("the category is gone" in p for p in problems),
                        problems)

    def test_carrying_twice_adds_nothing(self):
        # The published output of one carry is a valid --previous for the next
        # run: the section is already there, so it must not appear twice.
        categories = self._bucket_categories()
        carry_external(self._previous(), categories, [])
        problems = []
        self.assertEqual(carry_external(self._previous(), categories, problems), 0)
        self.assertEqual(sum(1 for s in categories[0]["speakers"]
                             if s["id"] == "tafsir-badri"), 1)
        self.assertTrue(any("hosted AND in the bucket" in p for p in problems),
                        problems)

    def test_a_manifest_with_no_hosted_tracks_changes_nothing(self):
        categories = self._bucket_categories()
        snapshot = json.dumps(categories, sort_keys=True)
        problems = []
        previous = {"version": 4, "categories": [{
            "id": "lectures", "tracks": categories[0]["tracks"],
            "speakers": categories[0]["speakers"]}]}
        self.assertEqual(carry_external(previous, categories, problems), 0)
        self.assertEqual(json.dumps(categories, sort_keys=True), snapshot)
        self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
