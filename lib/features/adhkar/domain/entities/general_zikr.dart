class GeneralZikr {
  final String id;
  final String arabicText;
  final int targetCount;
  final bool isDefault;
  bool isEnabled;
  int currentCount;

  GeneralZikr({
    required this.id,
    required this.arabicText,
    this.targetCount = 100,
    this.isDefault = true,
    this.isEnabled = true,
    this.currentCount = 0,
  });

  GeneralZikr copyWith({
    String? id,
    String? arabicText,
    int? targetCount,
    bool? isDefault,
    bool? isEnabled,
    int? currentCount,
  }) {
    return GeneralZikr(
      id: id ?? this.id,
      arabicText: arabicText ?? this.arabicText,
      targetCount: targetCount ?? this.targetCount,
      isDefault: isDefault ?? this.isDefault,
      isEnabled: isEnabled ?? this.isEnabled,
      currentCount: currentCount ?? this.currentCount,
    );
  }
}
