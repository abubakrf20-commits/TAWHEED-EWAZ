import 'package:tawheeed/features/adhkar/domain/entities/prayer_period.dart';
export 'package:tawheeed/features/adhkar/domain/entities/prayer_period.dart';

class ZikrItem {
  final String id;
  final String title;
  final String arabicText;
  final String translation;
  final String virtue;
  final String source;
  final PrayerPeriod period;
  final int? count;
  final bool isCompleted;
  final String daleel;
  final int repeatCount;

  const ZikrItem({
    required this.id,
    required this.title,
    required this.arabicText,
    required this.translation,
    required this.source,
    required this.period,
    this.virtue = '',
    this.count,
    this.isCompleted = false,
    this.daleel = '',
    this.repeatCount = 1,
  });

  factory ZikrItem.fromJson(Map<String, dynamic> json) {
    return ZikrItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      arabicText: json['arabicText'] as String,
      translation: json['translation'] as String? ?? '',
      virtue: json['virtue'] as String? ?? '',
      source: json['source'] as String? ?? '',
      period: PrayerPeriod.values.asNameMap()[json['period']] ??
          PrayerPeriod.morningAzkar,
      count: json['count'] as int?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      daleel: json['daleel'] as String? ?? '',
      repeatCount: json['repeatCount'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'arabicText': arabicText,
        'translation': translation,
        'virtue': virtue,
        'source': source,
        'period': period.name,
        if (count != null) 'count': count,
        'daleel': daleel,
        'repeatCount': repeatCount,
      };

  ZikrItem copyWith({
    String? id,
    String? title,
    String? arabicText,
    String? translation,
    String? virtue,
    String? source,
    PrayerPeriod? period,
    int? count,
    bool? isCompleted,
    String? daleel,
    int? repeatCount,
  }) {
    return ZikrItem(
      id: id ?? this.id,
      title: title ?? this.title,
      arabicText: arabicText ?? this.arabicText,
      translation: translation ?? this.translation,
      virtue: virtue ?? this.virtue,
      source: source ?? this.source,
      period: period ?? this.period,
      count: count ?? this.count,
      isCompleted: isCompleted ?? this.isCompleted,
      daleel: daleel ?? this.daleel,
      repeatCount: repeatCount ?? this.repeatCount,
    );
  }
}
