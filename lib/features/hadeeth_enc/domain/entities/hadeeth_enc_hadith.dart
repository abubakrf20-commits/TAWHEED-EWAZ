/// A single hadith from the موسوعه احادیث (HadeethEnc.com) dataset.
///
/// Display order in the app mirrors the source: Arabic text first, then the
/// Persian translation, the takhrij (منبع), the grade (صحت) and finally the
/// explanation (شرح) and benefits (نکات حدیث).
class HadeethEncHadith {
  final int id;
  final String titleAr;
  final String title;
  final String textAr;
  final String text;
  final String explanation;
  final String benefits;
  final String grade;
  final String takhrij;
  final String link;

  /// Thematic category (موضوع) from HadeethEnc.com, e.g. «فقه عبادات».
  final String category;

  /// Global 1-based number of the hadith in the encyclopedia (source order
  /// by id) — computed by the database queries as `sequence`. This is the
  /// number shown in the list badge, the detail title and shared content;
  /// null only for hand-built rows (tests) that carry no such column.
  final int? sequence;

  const HadeethEncHadith({
    required this.id,
    this.titleAr = '',
    this.title = '',
    required this.textAr,
    required this.text,
    this.explanation = '',
    this.benefits = '',
    this.grade = '',
    this.takhrij = '',
    this.link = '',
    this.category = '',
    this.sequence,
  });

  /// Row of the list screen: id + Arabic title + Persian title.
  bool get hasTitle => title.isNotEmpty;

  factory HadeethEncHadith.fromRow(Map<String, dynamic> row) {
    String s(Object? v) => (v ?? '').toString();
    return HadeethEncHadith(
      id: (row['id'] as num).toInt(),
      titleAr: s(row['title_ar']).trim(),
      title: s(row['title']).trim(),
      textAr: s(row['text_ar']).trim(),
      text: s(row['text']).trim(),
      explanation: s(row['explanation']).trim(),
      benefits: s(row['benefits']).trim(),
      grade: s(row['grade']).trim(),
      takhrij: s(row['takhrij']).trim(),
      link: s(row['link']).trim(),
      category: s(row['category']).trim(),
      sequence: (row['sequence'] as num?)?.toInt(),
    );
  }
}

/// Decodes the `extra` of the detail route: a bare hadith or the positional
/// record `(hadith, sequence)` pushed by the list and random/jump actions.
HadeethEncHadith? hadithFromRouteExtra(Object? extra) {
  if (extra is HadeethEncHadith) return extra;
  if (extra is (HadeethEncHadith, int?)) return extra.$1;
  return null;
}

/// Decodes the optional 1-based list position from the detail route `extra`.
int? sequenceFromRouteExtra(Object? extra) {
  if (extra is (HadeethEncHadith, int?)) return extra.$2;
  return null;
}
