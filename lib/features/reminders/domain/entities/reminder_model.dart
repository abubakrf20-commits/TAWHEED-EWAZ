/// Pure helpers extracted from the reminders feature so the data-layer model
/// and the presentation layer share one implementation instead of duplicating
/// the Persian labels and the weekday-matching rules.
library;

/// Persian names of the schedulable prayers, keyed by the `prayerRef` codes
/// stored on a reminder row.
const Map<String, String> prayerFa = {
  'fajr': 'صبح',
  'dhuhr': 'ظهر',
  'asr': 'عصر',
  'maghrib': 'مغرب',
  'isha': 'عشاء',
};

/// `prayerRef` codes → their Persian names (unknown codes pass through).
String prayerNamesFa(String refs) =>
    refs.split(',').map((r) => prayerFa[r.trim()] ?? r.trim()).join('، ');

/// Human time label: «وقت اذان» → «وقت صبح»، offsets → «۵ دقیقه قبل از ظهر»،
/// otherwise the HH:mm clock time.
String timeOfDayFa({
  required int hour,
  required int minute,
  String? prayerRef,
  int prayerOffsetMinutes = 0,
}) {
  if (prayerRef != null) {
    final names = prayerNamesFa(prayerRef);
    if (prayerOffsetMinutes == 0) return 'وقت $names';
    if (prayerOffsetMinutes < 0) {
      return '${prayerOffsetMinutes.abs()} دقیقه قبل از $names';
    }
    return '$prayerOffsetMinutes دقیقه بعد از $names';
  }
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Full Persian weekday names, index 0 = شنبه … 6 = جمعه (the app-wide
/// convention; legacy rows may still carry the old 1..7 values).
const List<String> weekdayNamesFa = [
  'شنبه',
  'یکشنبه',
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه',
];

/// One-letter Persian weekday labels, index 0 = شنبه … 6 = جمعه.
const List<String> weekdayShortFa = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

String _nameFor(int day, List<String> names) =>
    (day >= 0 && day < names.length) ? names[day] : '$day';

/// «شنبه، دوشنبه، پنجشنبه» یا «هر روز» — out-of-range legacy values fall back
/// to the number instead of throwing RangeError.
String repeatSummaryFa(List<int> daysOfWeek) {
  if (daysOfWeek.isEmpty || daysOfWeek.length == 7) return 'هر روز';
  return daysOfWeek.map((d) => _nameFor(d, weekdayNamesFa)).join('، ');
}

/// Compact chip summary: «ش · د · پ» یا «هر روز».
String repeatChipFa(List<int> daysOfWeek) {
  if (daysOfWeek.isEmpty || daysOfWeek.length == 7) return 'هر روز';
  return daysOfWeek.map((d) => _nameFor(d, weekdayShortFa)).join(' · ');
}

/// Card kind label: «یک‌بار» for date-bound reminders, otherwise «تکرار».
String recurrenceKindFa({DateTime? specificDate}) =>
    specificDate != null ? 'یک‌بار' : 'تکرار';

/// Whether [date] is matched by the reminder's recurrence: an exact
/// [specificDate] wins, an empty day list means every day, and the stored
/// day indexes follow the 0=شنبه convention (legacy 7 → 0 normalised).
bool matchesDay(
  DateTime date, {
  DateTime? specificDate,
  List<int> daysOfWeek = const [],
}) {
  if (specificDate != null) {
    return specificDate.year == date.year &&
        specificDate.month == date.month &&
        specificDate.day == date.day;
  }
  if (daysOfWeek.isEmpty) return true;
  // Dart weekday: 1=Mon..7=Sun → Persian index: 0=Sat..6=Fri.
  // Tolerate legacy rows stored with the old 1..7 (Sunday..Saturday)
  // convention: 1..7 ∩ 0..6 overlap on 1..6, so normalize any 7 → 0 first
  // (Saturday) and keep 0..6 as-is.
  final raw = daysOfWeek.map((d) => d == 7 ? 0 : d).toList();
  return raw.contains((date.weekday + 1) % 7);
}
