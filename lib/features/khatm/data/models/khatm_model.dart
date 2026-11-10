import 'package:tawheeed/core/utils/calendar_days.dart';
import 'package:tawheeed/shared/utils/date_key.dart' as shared;

class KhatmParticipant {
  final String name;
  final List<int> assignedJuzs;

  const KhatmParticipant({required this.name, required this.assignedJuzs});
}

class KhatmModel {
  final String id;
  final String title;
  final DateTime startDate;
  DateTime? endDate;
  final int targetDays;
  List<bool> pagesRead;
  bool isCompleted;
  List<String> participantNames;
  List<int> participantAssignedJuzs;

  /// Pages read per local calendar day: 'YYYY-MM-DD' → count.
  Map<String, int> dailyRead;

  /// Local date key for [date] (e.g. `2026-08-10`).
  static String dateKeyOf(DateTime date) => shared.dateKeyOf(date.toLocal());

  /// Pages read today.
  int get pagesToday => dailyRead[dateKeyOf(DateTime.now())] ?? 0;

  /// Pages read on the given local date key.
  int pagesOn(String dateKey) => dailyRead[dateKey] ?? 0;

  KhatmModel({
    required this.id,
    required this.title,
    required this.startDate,
    this.endDate,
    required this.targetDays,
    List<bool>? pagesRead,
    Map<String, int>? dailyRead,
    this.isCompleted = false,
    List<String>? participantNames,
    List<int>? participantAssignedJuzs,
  })  : pagesRead = pagesRead ?? List.filled(604, false),
        dailyRead = dailyRead ?? {},
        participantNames = participantNames ?? [],
        participantAssignedJuzs = participantAssignedJuzs ?? [];

  List<KhatmParticipant> get participants {
    final result = <KhatmParticipant>[];
    int juzIndex = 0;
    for (int i = 0; i < participantNames.length; i++) {
      final count =
          participantAssignedJuzs.length > i ? participantAssignedJuzs[i] : 0;
      final juzs = <int>[];
      for (int j = 0; j < count && juzIndex < 30; j++) {
        juzs.add(juzIndex + 1);
        juzIndex++;
      }
      result
          .add(KhatmParticipant(name: participantNames[i], assignedJuzs: juzs));
    }
    return result;
  }

  int get totalPages => 604;
  int get readPages => pagesRead.where((p) => p).length;
  double get progress => readPages / totalPages;
  int get remainingPages => totalPages - readPages;

  int get dailyTarget {
    final deadline = addCalendarDaysFromMidnight(startDate, targetDays);
    final remaining = calendarDaysBetween(DateTime.now(), deadline);
    final days = remaining > 0 ? remaining : 1;
    return (remainingPages / days).ceil();
  }

  bool get isGroup => participantNames.length > 1;

  KhatmModel copyWith({
    String? id,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    int? targetDays,
    List<bool>? pagesRead,
    Map<String, int>? dailyRead,
    bool? isCompleted,
    List<String>? participantNames,
    List<int>? participantAssignedJuzs,
  }) {
    return KhatmModel(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      targetDays: targetDays ?? this.targetDays,
      pagesRead: pagesRead ?? this.pagesRead,
      dailyRead: dailyRead ?? this.dailyRead,
      isCompleted: isCompleted ?? this.isCompleted,
      participantNames: participantNames ?? this.participantNames,
      participantAssignedJuzs:
          participantAssignedJuzs ?? this.participantAssignedJuzs,
    );
  }
}
