class ConvertedDate {
  final int year;
  final int month;
  final int day;
  final String monthName;
  final String weekday;
  final CalendarType type;

  const ConvertedDate({
    required this.year,
    required this.month,
    required this.day,
    required this.monthName,
    required this.weekday,
    required this.type,
  });

  String get formatted => '$day $monthName $year';
}

class ConversionResult {
  final ConvertedDate hijri;
  final ConvertedDate shamsi;
  final ConvertedDate gregorian;
  final String weekday;
  final int dayOfYear;
  final int daysInMonth;
  final int daysUntilMonthEnd;

  const ConversionResult({
    required this.hijri,
    required this.shamsi,
    required this.gregorian,
    required this.weekday,
    required this.dayOfYear,
    required this.daysInMonth,
    required this.daysUntilMonthEnd,
  });
}

enum CalendarType { hijri, shamsi, gregorian }
