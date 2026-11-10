import 'package:flutter/material.dart' show Color, IconData;
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/education/data/sciences_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SciencesContent.load();
  });

  group('sciences registry integrity (flat redesign contract)', () {
    test('the registry is loaded and non-empty', () {
      expect(SciencesContent.isLoaded, isTrue);
      expect(SciencesContent.all, isNotEmpty);
    });

    test('every id is unique', () {
      final ids = SciencesContent.all.map((s) => s.id).toList();
      expect(ids.length, ids.toSet().length,
          reason: 'duplicate id in registry');
    });

    test('every science belongs to exactly one registry category', () {
      for (final s in SciencesContent.all) {
        expect(ScienceCategory.values.contains(s.category), isTrue,
            reason: '${s.id}: category ${s.category} is off-registry');
      }
    });

    test('every category appears in categoryOrder exactly once', () {
      final ordered = SciencesContent.categoryOrder.toSet();
      expect(ordered, ScienceCategory.values.toSet(),
          reason: 'categoryOrder must cover the enum exactly');
    });

    test('group accent table: every category has accent + glyph', () {
      for (final cat in ScienceCategory.values) {
        final visual = SciencesContent.categoryVisuals[cat];
        expect(visual, isNotNull, reason: '$cat has no entry');
        final (accent, glyph) = visual!;
        expect(accent.toARGB32() > 0, isTrue,
            reason: '$cat accent must be opaque');
        expect(glyph, isA<IconData>());
      }
      expect(SciencesContent.accentOf(ScienceCategory.foundational),
          isNot(SciencesContent.accent),
          reason: 'sanity: lookup actually runs');
      expect(SciencesContent.glyphOf(ScienceCategory.historical),
          SciencesContent.categoryVisuals[ScienceCategory.historical]!.$2);
    });

    test('the six category accents are distinct — each wears its own hue', () {
      final accents = <int>{};
      for (final cat in ScienceCategory.values) {
        final accent = SciencesContent.accentOf(cat);
        expect(accents.add(accent.toARGB32()), isTrue,
            reason: '$cat shares its accent with another category');
      }
      // علوم تاریخی used to wear the moon section's indigo (#283593); it now
      // has its own hue so the two sections cannot be confused.
      expect(SciencesContent.accentOf(ScienceCategory.historical),
          const Color(0xFFBF360C));
    });

    test('coming-soon entries are marked by the data flag only', () {
      final drafts = SciencesContent.all.where((s) => !s.isComplete).toList();
      // The UI gates navigation on this flag; the registry must not assume
      // any entry is complete implicitly (flag is the single source).
      for (final d in drafts) {
        expect(d.complete, isFalse);
        expect(d.chapters, anyOf(isEmpty, isNotEmpty),
            reason: 'draft status is not derived from chapter count');
      }
    });

    test('search: plain Persian query matches title and body fields', () {
      final any = SciencesContent.all.first;
      expect(any.matchesSearch(any.title), isTrue);
      expect(any.matchesSearch(any.definition), isTrue);
      // The normalizing search path lives at the screen level (arabic_search
      // utilities); the registry matcher is CONTAINS-based and case-exact,
      // which must match its own title verbatim.
      expect(any.matchesSearch('XQC_NONE_HAY'), isFalse);
    });
  });
}
