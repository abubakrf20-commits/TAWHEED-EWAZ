/// A local unit («من»، «خروار»، هر واحد دیگری که کاربر خودش مبنا می‌دهد).
///
/// Two sources feed this list: the shipped defaults in `units.json`, which are
/// marked `verified: false` because their base differs from region to region,
/// and the user's own rows in `unit_local_override`. A row from the table
/// always wins over the shipped default with the same id.
library;

import 'package:tawheeed/shared/utils/app_logger.dart';

class LocalUnit {
  const LocalUnit({
    required this.id,
    required this.name,
    required this.factor,
    required this.baseUnit,
    this.isUserEdited = false,
  });

  final String id;
  final String name;

  /// How many base units (grams, for the shipped set) one of this unit is.
  final double factor;
  final String baseUnit;

  /// True when the value came from the user (edited default or new row).
  final bool isUserEdited;

  bool get isVerified => isUserEdited;

  LocalUnit copyWith({
    String? name,
    double? factor,
    String? baseUnit,
    bool? isUserEdited,
  }) =>
      LocalUnit(
        id: id,
        name: name ?? this.name,
        factor: factor ?? this.factor,
        baseUnit: baseUnit ?? this.baseUnit,
        isUserEdited: isUserEdited ?? this.isUserEdited,
      );

  /// Parses `{"id","name","factor"}` — unknown shapes are rejected, never
  /// guessed.
  static LocalUnit? tryParse(Object? raw, {required String baseUnit}) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || name is! String) return null;
    if (id.isEmpty || name.isEmpty) return null;
    final factor = raw['factor'];
    if (factor is! num || factor <= 0) {
      AppLogger.warning('LocalUnit', 'ignored "$id": bad factor $factor');
      return null;
    }
    return LocalUnit(
      id: id,
      name: name,
      factor: factor.toDouble(),
      baseUnit: baseUnit,
      isUserEdited: true,
    );
  }
}
