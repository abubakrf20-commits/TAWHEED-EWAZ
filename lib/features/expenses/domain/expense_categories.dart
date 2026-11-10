/// The ledger's category vocabulary: the built-ins, plus whatever the user adds.
///
/// WHY this is its own file. The list used to be a private field inside
/// `ExpenseDialogState`, which meant the budget dialog on the report screen had
/// to re-derive it from whatever rows happened to exist — so a category with no
/// spending yet could not be budgeted, and the two screens could disagree
/// without either one being wrong on its own terms. One vocabulary, one place.
library;

/// The word the ledger stores when a row carries no category of its own.
///
/// Kept apart from [kDefaultExpenseCategory] because it is not a category: it is
/// the sentinel that leaked into the column because the model's default and the
/// picker's first chip were spelled differently («عام» vs «عمومی»). Rows from
/// the pre-Drift JSON import can still hold it, and nothing in the UI ever
/// offered it — so a row carrying it opens with no chip selected, which reads as
/// "this transaction has no category" when it has one.
const String kLegacyExpenseCategorySentinel = 'عام';

/// The category the picker offers first, and what an empty value becomes.
const String kDefaultExpenseCategory = 'عمومی';

/// The categories every install starts with, in the order the picker shows them.
///
/// Not removable: they are the vocabulary the ledger has always written, and a
/// user who deletes one would still have rows carrying its name (see
/// [mergeExpenseCategories], which would put it straight back).
const List<String> kBuiltInExpenseCategories = [
  kDefaultExpenseCategory,
  'خوراک',
  'حمل و نقل',
  'درمان',
  'آموزش',
  'تفریح',
  'قبض',
  'حقوق',
  'سایر',
];

/// Longest accepted category name.
///
/// 24, not "as long as you like": the name is drawn as a badge inside a
/// single-line row in `expenses_tile.dart`, and at 320 dp with the text scale at
/// 1.3 a longer string has nowhere to go. The badge ellipsises now as well, so
/// this is a legibility limit rather than the only thing standing between a long
/// name and an overflow.
const int kMaxExpenseCategoryLength = 24;

/// Ceiling on how many categories a user may add.
///
/// Not a technical limit — prefs hold thousands — but the picker is a `Wrap`
/// inside a bottom sheet, and past this the sheet is mostly category chips. The
/// message when it is hit says so rather than failing silently.
const int kMaxCustomExpenseCategories = 40;

/// Whether [value] is one of [kBuiltInExpenseCategories] (case-insensitively).
bool isBuiltInExpenseCategory(String value) {
  final lower = normalizeExpenseCategory(value).toLowerCase();
  for (final c in kBuiltInExpenseCategories) {
    if (c.toLowerCase() == lower) return true;
  }
  return false;
}

/// The vocabulary's spelling of [raw].
///
/// Exactly two things are fixed here: the legacy sentinel and an empty string
/// both become [kDefaultExpenseCategory]. Everything else is returned trimmed,
/// untouched — this is a read, not a rewrite, so a category the user typed is
/// never silently renamed by being displayed.
///
/// Applied in the UI layer only, never at the DAO read boundary. The sentinel
/// lives on rows the pre-Drift import wrote; rewriting it in `_toModel` would
/// make the whole ledger agree on one word, but it would also rename a category a
/// user deliberately typed as «عام» — and since custom names are free text, that
/// is a name they can type. Fixing the word where the user chooses it (the
/// picker, which now opens such a row with «عمومی» selected instead of nothing)
/// gets the benefit without touching stored data.
String canonicalExpenseCategory(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == kLegacyExpenseCategorySentinel) {
    return kDefaultExpenseCategory;
  }
  return trimmed;
}

/// [raw] reduced to the form that is compared and stored.
///
/// Trims, collapses inner runs of whitespace to one space, and drops the bidi
/// control characters a right-to-left keyboard can emit at either end of a
/// pasted string — two names that look identical must not be two categories.
///
/// ZWNJ (U+200C) is deliberately kept: Persian spelling needs it («دسته‌بندی» is
/// one word, not two), so stripping it would corrupt the name instead of tidying
/// it. The marks removed are the ones that carry no letters: LRM, RLM, ALM.
String normalizeExpenseCategory(String raw) {
  final buffer = StringBuffer();
  // Starts true so leading whitespace is dropped without a second pass.
  var lastWasSpace = true;
  for (final rune in raw.runes) {
    if (rune == 0x200E || rune == 0x200F || rune == 0x061C) continue;
    final isSpace = rune == 0x20 ||
        rune == 0x09 ||
        rune == 0x0A ||
        rune == 0x0D ||
        rune == 0xA0;
    if (isSpace) {
      if (lastWasSpace) continue;
      lastWasSpace = true;
      buffer.write(' ');
    } else {
      lastWasSpace = false;
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().trimRight();
}

/// Why a proposed category was refused. Null means it was accepted.
enum ExpenseCategoryRejection {
  /// Nothing was left after normalisation.
  empty,

  /// Longer than [kMaxExpenseCategoryLength].
  tooLong,

  /// Already in the vocabulary; [ExpenseCategoryDraft.match] names the entry it
  /// collided with, so the UI can select it instead of just refusing.
  duplicate,

  /// [kMaxCustomExpenseCategories] already added.
  full,
}

/// The outcome of [validateNewExpenseCategory].
///
/// A record would do, but the widget needs to read `value`, `rejection` and
/// `match` by name in three different branches, and a class documents the
/// relationship between them (a rejection always explains the same value).
class ExpenseCategoryDraft {
  const ExpenseCategoryDraft._(this.value, this.rejection, this.match);

  /// The normalised name that would be stored.
  final String value;

  /// Null when [value] may be added.
  final ExpenseCategoryRejection? rejection;

  /// The existing entry a [ExpenseCategoryRejection.duplicate] collided with.
  final String? match;

  bool get ok => rejection == null;
}

/// Decides whether [raw] may become a new category.
///
/// Pure, so the rules can be tested without a widget: the picker calls this and
/// only then touches the store, which means a rejected name never reaches a
/// write.
ExpenseCategoryDraft validateNewExpenseCategory(
  String raw, {
  required List<String> existing,
  required int customCount,
}) {
  final value = normalizeExpenseCategory(raw);
  if (value.isEmpty) {
    return const ExpenseCategoryDraft._(
        '', ExpenseCategoryRejection.empty, null);
  }
  // `runes`, not `.length`: this counts code points, so a Persian name is
  // measured in letters rather than UTF-16 units. (No grapheme-cluster
  // handling — a category name with combining marks is not a case worth the
  // dependency.)
  if (value.runes.length > kMaxExpenseCategoryLength) {
    return ExpenseCategoryDraft._(
        value, ExpenseCategoryRejection.tooLong, null);
  }
  final lower = value.toLowerCase();
  for (final e in existing) {
    if (normalizeExpenseCategory(e).toLowerCase() == lower) {
      return ExpenseCategoryDraft._(
          value, ExpenseCategoryRejection.duplicate, e);
    }
  }
  if (customCount >= kMaxCustomExpenseCategories) {
    return ExpenseCategoryDraft._(value, ExpenseCategoryRejection.full, null);
  }
  return ExpenseCategoryDraft._(value, null, null);
}

/// Every category the UI may offer, in picker order.
///
/// Built-ins first, then the user's own in the order they added them, then
/// anything the ledger or a budget mentions that neither list has.
///
/// WHY the third pass exists: a category can be on a row without being in the
/// vocabulary — a legacy import, or one the user removed while its transactions
/// kept the label. Dropping it would leave those rows unfilterable and uneditable
/// from the picker, so it is appended instead.
///
/// WHY [hidden] is consulted before that pass: the pass would otherwise resurrect
/// every removed category on the next rebuild, and the remove button would look
/// broken. A hidden name is a name the user asked not to see offered — the rows
/// keep it, the picker does not. A name that is both custom and hidden resolves
/// as hidden, because removal is the later of the two decisions.
List<String> mergeExpenseCategories({
  required List<String> custom,
  Set<String> hidden = const {},
  Iterable<String> inUse = const [],
  Iterable<String> budgeted = const [],
}) {
  final out = <String>[];
  final seen = <String>{};

  void add(String raw) {
    final value = normalizeExpenseCategory(raw);
    if (value.isEmpty) return;
    if (!seen.add(value.toLowerCase())) return;
    out.add(value);
  }

  bool isHidden(String raw) =>
      hidden.contains(normalizeExpenseCategory(raw).toLowerCase());

  for (final c in kBuiltInExpenseCategories) {
    add(c);
  }
  for (final c in custom) {
    if (!isHidden(c)) add(c);
  }
  for (final c in inUse) {
    final value = canonicalExpenseCategory(c);
    if (!isHidden(value)) add(value);
  }
  for (final c in budgeted) {
    final value = canonicalExpenseCategory(c);
    if (!isHidden(value)) add(value);
  }
  return out;
}
