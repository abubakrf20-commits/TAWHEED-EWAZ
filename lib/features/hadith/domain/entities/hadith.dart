enum HadithGrade { sahih, hasan, daif, unknown }

/// Parses a raw `hadiths.grade` value into a [HadithGrade].
///
/// The DB column stores the enum names (`sahih` / `hasan` / `daif`), but the
/// shipped data is produced outside the app, so the common Arabic spellings
/// are accepted too. Anything else (or nothing at all) is
/// [HadithGrade.unknown] — never throws, so a malformed or future value
/// degrades to "no badge" instead of breaking the screen.
HadithGrade parseHadithGrade(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'sahih':
    case 'صحیح':
    case 'صحيح':
      return HadithGrade.sahih;
    case 'hasan':
    case 'حسن':
      return HadithGrade.hasan;
    case 'daif':
    case 'ضعیف':
    case 'ضعيف':
      return HadithGrade.daif;
    default:
      return HadithGrade.unknown;
  }
}

extension HadithGradeExtension on HadithGrade {
  /// Every spelling [parseHadithGrade] maps to this grade. The shipped data is
  /// produced outside the app, so the `grade` column can hold either the enum
  /// name or the Persian/Arabic word — a filter that only matched `name`
  /// silently returned nothing on real databases.
  List<String> get dbAliases {
    switch (this) {
      case HadithGrade.sahih:
        return const ['sahih', 'صحیح', 'صحيح'];
      case HadithGrade.hasan:
        return const ['hasan', 'حسن'];
      case HadithGrade.daif:
        return const ['daif', 'ضعیف', 'ضعيف'];
      case HadithGrade.unknown:
        return const [];
    }
  }

  String get label {
    switch (this) {
      case HadithGrade.sahih:
        return 'صحیح';
      case HadithGrade.hasan:
        return 'حسن';
      case HadithGrade.daif:
        return 'ضعیف';
      case HadithGrade.unknown:
        return 'نامشخص';
    }
  }

  int get colorValue {
    switch (this) {
      case HadithGrade.sahih:
        return 0xFF2E7D32;
      case HadithGrade.hasan:
        return 0xFFF9A825;
      case HadithGrade.daif:
        return 0xFFE53935;
      case HadithGrade.unknown:
        return 0xFF757575;
    }
  }
}

class HadithBook {
  final int id;
  final String titleArabic;
  final String? author;
  final int hadithCount;

  const HadithBook({
    required this.id,
    required this.titleArabic,
    this.author,
    required this.hadithCount,
  });
}

class HadithChapter {
  final int id;
  final int bookId;
  final String titleArabic;
  final int chapterIndex;

  const HadithChapter({
    required this.id,
    required this.bookId,
    required this.titleArabic,
    required this.chapterIndex,
  });
}

class Hadith {
  final int id;
  final int bookId;
  final int? chapterId;
  final int hadithNumber;
  final String arabic;
  final String? narratorArabic;
  final HadithGrade grade;

  const Hadith({
    required this.id,
    required this.bookId,
    this.chapterId,
    required this.hadithNumber,
    required this.arabic,
    this.narratorArabic,
    this.grade = HadithGrade.unknown,
  });
}
