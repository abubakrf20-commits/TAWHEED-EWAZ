"""Tests for the manifest generator's ordering and normalisation rules.

Run: python -m unittest discover -s tool/audio_library -p "test_*.py"

These are offline by design. The track order in index.json is a user-visible
promise -- an album that reshuffles when the generator is re-run is worse than
one that was never ordered -- so the collation is pinned here rather than only
exercised against a live bucket.
"""

import unittest

from build_manifest_from_bucket import collate_key, normalize, split_number


class NormalizeTest(unittest.TestCase):
    def test_folds_arabic_yeh_and_alef_maqsura_to_farsi_yeh(self):
        self.assertEqual(normalize("ي"), normalize("ی"))
        self.assertEqual(normalize("ى"), normalize("ی"))

    def test_folds_hamza_carriers_to_bare_alef(self):
        for variant in ("أ", "إ", "آ"):
            self.assertEqual(normalize(variant), normalize("ا"), variant)

    def test_alef_wasla_is_not_folded(self):
        # U+0671 keeps its own identity and its own slot right after the alef
        # family, matching lib/features/goals/domain/goal_query.dart. Folding it
        # would change a real letter into another one; ranking it separately is
        # what the app already does.
        self.assertNotEqual(normalize("ٱ"), normalize("ا"))
        self.assertEqual(normalize("ٱ"), "ٱ")

    def test_folds_teh_marbuta_and_arabic_kaf(self):
        self.assertEqual(normalize("ة"), normalize("ه"))
        self.assertEqual(normalize("ك"), normalize("ک"))

    def test_drops_diacritics_and_tatweel(self):
        # The whole point: a search and a sort must both find "مطالعه" when the
        # title is written "مُطالعه".
        self.assertEqual(normalize("مُطالعه"), normalize("مطالعه"))
        self.assertEqual(normalize("مـــطالعه"), normalize("مطالعه"))
        self.assertEqual(normalize("مَّ"), normalize("م"))

    def test_folds_persian_digits_to_ascii(self):
        self.assertEqual(normalize("۱۲۳"), "123")

    def test_arabic_indic_digits_do_not_crash(self):
        # Regression: the fold table once mixed code points (ints) with
        # character strings (the digit folds), so "".join() raised TypeError on
        # any title containing an Arabic-Indic digit. Those digits are U+0663
        # and are deliberately not folded -- they still sort correctly because
        # they ascend with their code points -- but they must not throw.
        self.assertEqual(normalize("٤٥"), normalize("٤٥"))

    def test_mixed_script_title_normalises_without_error(self):
        self.assertIsInstance(normalize("نشيد ١٢ album"), str)


class CollateKeyTest(unittest.TestCase):
    def test_madda_alef_does_not_sort_before_bare_alef(self):
        # By code point, ALEF WITH MADDA (U+0622) precedes ALEF (U+0627), so a
        # naive sort leads an Arabic album with "آخي..." instead of "ابوبكر".
        titles = ["آخي لا تشكو المذلة", "ابوبکر الصدیق"]
        self.assertEqual(sorted(titles, key=collate_key), [
            "ابوبکر الصدیق", "آخي لا تشكو المذلة",
        ])

    def test_arabic_yeh_and_farsi_yeh_sort_together_by_next_letter(self):
        # "يومًا" uses ARABIC YEH, "یمه" FARSI YEH. Same letter, so م (rank of
        # meem) must beat و (rank of waw) -- a code-point sort gets this
        # backwards because U+064A < U+06CC.
        titles = ["یمه یا نبع الحنان", "يوما سنفنى كلنا ما من مفر"]
        self.assertEqual(sorted(titles, key=collate_key), [
            "یمه یا نبع الحنان", "يوما سنفنى كلنا ما من مفر",
        ])

    def test_persian_unique_letters_rank_before_heh_and_yeh(self):
        # The reason a rank table is needed at all: GAF is U+06AF, far above
        # HEH (U+0647), yet گ comes long before ه in the alphabet.
        titles = ["هر چه", "گل سرخ", "پرواز"]
        self.assertEqual(sorted(titles, key=collate_key),
                         ["پرواز", "گل سرخ", "هر چه"])

    def test_persian_letters_sort_before_latin_and_digits(self):
        titles = ["Zebra", "001 alpha", "ابوبكر"]
        self.assertEqual(sorted(titles, key=collate_key),
                         ["ابوبكر", "001 alpha", "Zebra"])

    def test_diacritics_do_not_change_relative_order(self):
        self.assertEqual(sorted(["مدح", "مُدح"], key=collate_key),
                         ["مدح", "مُدح"])

    def test_sort_is_stable_and_total_on_repeated_runs(self):
        titles = ["مدح", "مُدح", "مَدح", "هدى", "هُدى"]
        first = sorted(titles, key=collate_key)
        second = sorted(reversed(titles), key=collate_key)
        self.assertEqual([collate_key(t) for t in first],
                         [collate_key(t) for t in second])

    def test_letters_rank_in_the_order_the_table_declares(self):
        # Consecutive entries must sort in that order, except where the two
        # fold together: أ إ آ all become ا, so they share rank 0 and tie-break
        # on the original codepoint. That is deliberate -- it is what the app's
        # own collator does -- so this asserts order only for entries that
        # survive normalisation as distinct letters.
        from build_manifest_from_bucket import PERSIAN_ALPHABET
        letters = [ch for ch in PERSIAN_ALPHABET if normalize(ch) == ch]
        for earlier, later in zip(letters, letters[1:]):
            self.assertLess(collate_key(earlier), collate_key(later),
                            f"{earlier!r} should rank before {later!r}")

    def test_alef_family_shares_one_rank(self):
        # Folding means these are not merely adjacent, they are the same key
        # apart from the raw tiebreak, so no alef spelling can lead the album.
        ranks = {collate_key(v)[1] for v in ("ا", "أ", "إ", "آ")}
        self.assertEqual(ranks, {0})


class SplitNumberTest(unittest.TestCase):
    def test_reads_dot_and_underscore_forms(self):
        self.assertEqual(split_number("4. اثبات الهی بودن قرآن.opus"),
                         (4, "اثبات الهی بودن قرآن"))
        self.assertEqual(split_number("4_اثبات الهی بودن قرآن.opus"),
                         (4, "اثبات الهی بودن قرآن"))

    def test_reads_dash_separated_lesson_numbers(self):
        # The Rahimi Ramadan uploads are numbered "01 - <title>": a dash
        # separator must order them instead of excluding them as unnumbered.
        self.assertEqual(split_number("01 - مقدمه.opus"), (1, "مقدمه"))
        self.assertEqual(split_number("12–عنوان.opus"), (12, "عنوان"))
        self.assertEqual(split_number("3 — عنوان.opus"), (3, "عنوان"))

    def test_unnumbered_name_keeps_whole_name_as_title(self):
        self.assertEqual(split_number("مدح.opus"), (None, "مدح"))

    def test_trailing_ordinal_is_stripped_from_title(self):
        self.assertEqual(split_number("23. چگونه قرآن بودنی خود را ثابت کنیم.opus"),
                         (23, "چگونه قرآن بودنی خود را ثابت کنیم"))


if __name__ == "__main__":
    unittest.main()