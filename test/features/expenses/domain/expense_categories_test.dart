import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/expenses/domain/expense_categories.dart';

void main() {
  group('normalizeExpenseCategory', () {
    test('trims and collapses inner whitespace', () {
      expect(normalizeExpenseCategory('  قهوه  '), 'قهوه');
      expect(normalizeExpenseCategory('قهوه    و   شیرینی'), 'قهوه و شیرینی');
      expect(normalizeExpenseCategory('قهوه\tو\nشیرینی'), 'قهوه و شیرینی');
    });

    test('strips bidi marks a right-to-left keyboard can emit', () {
      // LRM, RLM, ALM — invisible, and two names that differ only by one of
      // these must not be two categories.
      expect(normalizeExpenseCategory('\u200Fقهوه\u200F'), 'قهوه');
      expect(normalizeExpenseCategory('\u200Eقهوه\u200E'), 'قهوه');
      expect(normalizeExpenseCategory('\u061Cقهوه'), 'قهوه');
    });

    test('keeps ZWNJ, because Persian spelling needs it', () {
      // «دسته‌بندی» is one word: the ZWNJ is orthography, not noise. Removing it
      // would turn the name into «دستهبندی», a different string.
      expect(normalizeExpenseCategory('دسته‌بندی'), 'دسته‌بندی');
      expect(normalizeExpenseCategory('  دسته‌بندی  '), 'دسته‌بندی');
    });

    test('a non-breaking space counts as a space', () {
      expect(normalizeExpenseCategory('حمل\u00A0و\u00A0نقل'), 'حمل و نقل');
    });

    test('whitespace-only becomes empty', () {
      expect(normalizeExpenseCategory('   '), '');
      expect(normalizeExpenseCategory('\u200F \u200F'), '');
    });
  });

  group('canonicalExpenseCategory', () {
    test('the legacy sentinel becomes the picker default', () {
      expect(canonicalExpenseCategory(kLegacyExpenseCategorySentinel),
          kDefaultExpenseCategory);
    });

    test('empty becomes the default', () {
      expect(canonicalExpenseCategory(''), kDefaultExpenseCategory);
      expect(canonicalExpenseCategory('   '), kDefaultExpenseCategory);
    });

    test('anything else is returned trimmed and otherwise untouched', () {
      expect(canonicalExpenseCategory('  قهوه '), 'قهوه');
      // A user-typed name is never rewritten by being displayed — including one
      // that happens to be spelled like a built-in.
      expect(canonicalExpenseCategory('خوراک'), 'خوراک');
    });
  });

  group('validateNewExpenseCategory', () {
    List<String> choices() => [
          ...kBuiltInExpenseCategories,
          'قهوه',
        ];

    test('accepts a new name and normalises it', () {
      final draft = validateNewExpenseCategory('  قهوه  تلخ ',
          existing: kBuiltInExpenseCategories, customCount: 0);
      expect(draft.ok, isTrue);
      expect(draft.value, 'قهوه تلخ');
      expect(draft.rejection, isNull);
    });

    test('refuses an empty name', () {
      final draft = validateNewExpenseCategory('   ',
          existing: choices(), customCount: 0);
      expect(draft.rejection, ExpenseCategoryRejection.empty);
      expect(draft.ok, isFalse);
    });

    test('refuses a name past the length limit', () {
      final long = 'ا' * (kMaxExpenseCategoryLength + 1);
      final draft =
          validateNewExpenseCategory(long, existing: choices(), customCount: 0);
      expect(draft.rejection, ExpenseCategoryRejection.tooLong);
    });

    test('accepts a name exactly at the limit', () {
      final exact = 'ا' * kMaxExpenseCategoryLength;
      final draft =
          validateNewExpenseCategory(exact, existing: choices(), customCount: 0);
      expect(draft.ok, isTrue);
    });

    test('a duplicate names the entry it collided with', () {
      // Case-insensitive, and matched after normalisation — so a trailing space
      // cannot smuggle in a second «قهوه».
      final draft = validateNewExpenseCategory('قهوه ',
          existing: choices(), customCount: 1);
      expect(draft.rejection, ExpenseCategoryRejection.duplicate);
      expect(draft.match, 'قهوه');
    });

    test('a duplicate of a built-in is refused too', () {
      final draft = validateNewExpenseCategory('خوراک',
          existing: choices(), customCount: 0);
      expect(draft.rejection, ExpenseCategoryRejection.duplicate);
      expect(draft.match, 'خوراک');
    });

    test('the ceiling stops the fortieth-and-first addition', () {
      final full = validateNewExpenseCategory('تازه',
          existing: choices(), customCount: kMaxCustomExpenseCategories);
      expect(full.rejection, ExpenseCategoryRejection.full);
      final last = validateNewExpenseCategory('تازه',
          existing: choices(),
          customCount: kMaxCustomExpenseCategories - 1);
      expect(last.ok, isTrue);
    });
  });

  group('mergeExpenseCategories', () {
    test('built-ins come first, in their declared order', () {
      final merged = mergeExpenseCategories(custom: const []);
      expect(merged, kBuiltInExpenseCategories);
    });

    test('the user\'s own follow, in the order they were added', () {
      final merged = mergeExpenseCategories(custom: const ['قهوه', 'گل']);
      expect(merged.take(kBuiltInExpenseCategories.length),
          kBuiltInExpenseCategories);
      expect(merged.skip(kBuiltInExpenseCategories.length), ['قهوه', 'گل']);
    });

    test('a custom name that duplicates a built-in is not added twice', () {
      final merged = mergeExpenseCategories(custom: const ['خوراک', 'خوراک']);
      expect(merged.where((c) => c == 'خوراک').length, 1);
    });

    test('a category on a row is offered even when nobody added it', () {
      // A legacy import, or a custom name removed while its rows kept the label.
      final merged = mergeExpenseCategories(
        custom: const [],
        inUse: const ['قهوه'],
      );
      expect(merged, contains('قهوه'));
    });

    test('a hidden name stays out, even when rows and a budget mention it', () {
      final merged = mergeExpenseCategories(
        custom: const [],
        hidden: const {'قهوه'},
        inUse: const ['قهوه'],
        budgeted: const ['قهوه'],
      );
      expect(merged, isNot(contains('قهوه')));
    });

    test('a hidden name is matched after normalisation', () {
      final merged = mergeExpenseCategories(
        custom: const ['  قهوه  '],
        hidden: const {'قهوه'},
      );
      expect(merged, isNot(contains('قهوه')));
    });

    test('the legacy sentinel arrives as the default, once', () {
      final merged = mergeExpenseCategories(
        custom: const [],
        inUse: const [kLegacyExpenseCategorySentinel],
      );
      expect(merged.where((c) => c == kDefaultExpenseCategory).length, 1);
      expect(merged, isNot(contains(kLegacyExpenseCategorySentinel)));
    });

    test('a budgeted category with no spending is still offered', () {
      final merged = mergeExpenseCategories(
        custom: const [],
        budgeted: const ['سفر'],
      );
      expect(merged, contains('سفر'));
    });
  });

  group('isBuiltInExpenseCategory', () {
    test('recognises a built-in regardless of surrounding space', () {
      expect(isBuiltInExpenseCategory(' خوراک '), isTrue);
      expect(isBuiltInExpenseCategory('قهوه'), isFalse);
    });
  });
}
