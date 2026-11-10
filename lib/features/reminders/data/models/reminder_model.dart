import 'package:tawheeed/features/reminders/domain/entities/reminder_model.dart'
    as rm;

class ReminderModel {
  String id;
  String title;
  String note;
  int hour;
  int minute;
  List<int> daysOfWeek;
  bool isEnabled;
  DateTime createdAt;
  int advanceMinutes;
  bool useSound;
  DateTime? updatedAt;
  String soundName;
  DateTime? specificDate;
  String? prayerRef;
  int prayerOffsetMinutes;

  ReminderModel({
    required this.id,
    required this.title,
    this.note = '',
    required this.hour,
    required this.minute,
    this.daysOfWeek = const [],
    this.isEnabled = true,
    required this.createdAt,
    this.advanceMinutes = 0,
    this.useSound = false,
    this.updatedAt,
    this.soundName = 'default',
    this.specificDate,
    this.prayerRef,
    this.prayerOffsetMinutes = 0,
  });

  /// «وقت صبح»، «۱۵ دقیقه قبل از ظهر» یا «۰۶:۰۰» — one implementation shared
  /// with the domain helper (single source for the card and any consumer).
  String get timeString => rm.timeOfDayFa(
      hour: hour,
      minute: minute,
      prayerRef: prayerRef,
      prayerOffsetMinutes: prayerOffsetMinutes);

  /// Full weekday names — single source in the domain helper.
  String get daysString => rm.repeatSummaryFa(daysOfWeek);

  /// Compact chip summary — single source in the domain helper.
  String get repeatSummary => rm.repeatChipFa(daysOfWeek);

  bool matchesToday() => rm.matchesDay(DateTime.now(),
      specificDate: specificDate, daysOfWeek: daysOfWeek);

  int get totalMinutes {
    if (prayerRef != null) {
      return hour * 60 + minute + prayerOffsetMinutes;
    }
    return hour * 60 + minute;
  }

  ReminderModel copyWith({
    String? id,
    String? title,
    String? note,
    int? hour,
    int? minute,
    List<int>? daysOfWeek,
    bool? isEnabled,
    DateTime? createdAt,
    int? advanceMinutes,
    bool? useSound,
    DateTime? updatedAt,
    String? soundName,
    DateTime? specificDate,
    String? prayerRef,
    int? prayerOffsetMinutes,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      advanceMinutes: advanceMinutes ?? this.advanceMinutes,
      useSound: useSound ?? this.useSound,
      updatedAt: updatedAt ?? this.updatedAt,
      soundName: soundName ?? this.soundName,
      specificDate: specificDate ?? this.specificDate,
      prayerRef: prayerRef ?? this.prayerRef,
      prayerOffsetMinutes: prayerOffsetMinutes ?? this.prayerOffsetMinutes,
    );
  }
}
