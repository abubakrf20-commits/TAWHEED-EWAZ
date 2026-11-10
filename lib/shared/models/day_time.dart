class DayTime {
  final int hour;
  final int minute;

  const DayTime({required this.hour, required this.minute})
      : assert(hour >= 0 && hour <= 23, 'hour must be 0-23'),
        assert(minute >= 0 && minute <= 59, 'minute must be 0-59');

  factory DayTime.fromString(String value) {
    final parts = value.split(':');
    final h = int.parse(parts[0]).clamp(0, 23);
    final m = int.parse(parts[1]).clamp(0, 59);
    return DayTime(hour: h, minute: m);
  }

  String toHHmm() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  DayTime add({int hours = 0, int minutes = 0}) {
    final total = hour * 60 + minute + hours * 60 + minutes;
    return DayTime(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  @override
  String toString() => toHHmm();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayTime && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => hour * 60 + minute;
}
