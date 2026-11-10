import 'package:tawheeed/shared/models/day_time.dart';

class PrayerInfo {
  final String name;
  final String arabicName;
  final DayTime time;
  final bool isCompleted;
  final int notificationMinutesBefore;

  const PrayerInfo({
    required this.name,
    required this.arabicName,
    required this.time,
    this.isCompleted = false,
    this.notificationMinutesBefore = 5,
  });

  PrayerInfo copyWith({
    String? name,
    String? arabicName,
    DayTime? time,
    bool? isCompleted,
    int? notificationMinutesBefore,
  }) {
    return PrayerInfo(
      name: name ?? this.name,
      arabicName: arabicName ?? this.arabicName,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
      notificationMinutesBefore:
          notificationMinutesBefore ?? this.notificationMinutesBefore,
    );
  }
}

class PrayerTimes {
  final DateTime date;
  final PrayerInfo fajr;
  final PrayerInfo shorouq;
  final PrayerInfo duhr;
  final PrayerInfo asr;
  final PrayerInfo maghrib;
  final PrayerInfo isha;
  final String? locationCity;
  final double? latitude;
  final double? longitude;

  const PrayerTimes({
    required this.date,
    required this.fajr,
    required this.shorouq,
    required this.duhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.locationCity,
    this.latitude,
    this.longitude,
  });

  PrayerTimes copyWith({
    DateTime? date,
    PrayerInfo? fajr,
    PrayerInfo? shorouq,
    PrayerInfo? duhr,
    PrayerInfo? asr,
    PrayerInfo? maghrib,
    PrayerInfo? isha,
    String? locationCity,
    double? latitude,
    double? longitude,
  }) {
    return PrayerTimes(
      date: date ?? this.date,
      fajr: fajr ?? this.fajr,
      shorouq: shorouq ?? this.shorouq,
      duhr: duhr ?? this.duhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
      locationCity: locationCity ?? this.locationCity,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
