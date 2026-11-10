class CalculationRecord {
  final int? id;
  final String expression;
  final String result;
  final DateTime timestamp;
  final bool isScientific;

  CalculationRecord({
    this.id,
    required this.expression,
    required this.result,
    required this.timestamp,
    this.isScientific = false,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'expression': expression,
        'result': result,
        'timestamp': timestamp.toIso8601String(),
        'isScientific': isScientific,
      };

  factory CalculationRecord.fromJson(Map<String, dynamic> json) =>
      CalculationRecord(
        id: json['id'] as int?,
        expression: json['expression'] as String,
        result: json['result'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isScientific: json['isScientific'] as bool? ?? false,
      );
}
