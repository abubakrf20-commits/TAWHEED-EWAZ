# AUDIT_REPORT — religious-content integrity (Phase 1 redesign)

Rule in force (docs/PHASE1_SPEC.md): *never edit, "fix", re-word, re-order or
regenerate any Quran text, hadith/dua text, tafsir, fiqh rulings or their
sources; only REPORT suspected errors here. Mushaf rendering (QCF4 fonts, page
data, word timings) must keep working exactly as before — only the chrome
around it changes.*

## Compliance evidence

- Every restyle/migration commit on `phase1/redesign` was verified with a
  Unicode-run check before commit: the multiset of Arabic/Persian text runs
  (`[\u0600-\u06FF…]+`) in each touched file was compared against its
  `git show HEAD~:file` baseline — byte-identical in all cases. No religious
  string was re-worded, re-ordered or regenerated.
- The mushaf/quran bundle (QCF4 fonts, page data, word timings,
  `mushaf_backgrounds.dart`) was not edited in Phase 1; the three golden tests
  (QCF4 page color, QCF4 page uniformity, inheritance share card) pass
  unchanged at the final full-suite run (3255 passed / 9 skipped / 0 failed).
- Wave 5 deletions were evidence-backed (zero importers/references):
  `shared/widgets/gradient_button.dart`, `shared/widgets/section_header.dart`,
  `prayer/presentation/widgets/period_section.dart` + its test, three orphaned
  widget layouts and `splash_background.xml`. `period_section` was the approved
  deletion (spec §7.5 decision 5); the live period/menstruation logic and its
  data were untouched.
- No content asset, JSON, database schema or drift table was modified; no
  `build_runner` was run.

## Suspected errors found

None. No Quran/hadith/tafsir/fqh text error was encountered that needs
reporting during Phase 1.
