/// A person tracked for Quran memorization (حافظ).
class HafizModel {
  final String id;
  final String name;
  final String colorHex;
  final int sabaqWindowDays;
  final DateTime createdAt;

  const HafizModel({
    required this.id,
    required this.name,
    this.colorHex = '#1976D2',
    this.sabaqWindowDays = 7,
    required this.createdAt,
  });

  HafizModel copyWith({
    String? id,
    String? name,
    String? colorHex,
    int? sabaqWindowDays,
    DateTime? createdAt,
  }) {
    return HafizModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      sabaqWindowDays: sabaqWindowDays ?? this.sabaqWindowDays,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
