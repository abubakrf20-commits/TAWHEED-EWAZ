/// Model of `assets/data/units.json` — the single source of unit factors.
///
/// Pure Dart: the calculator screen, the engine and the local-unit sheet all
/// read these values, and no widget hard-codes a factor.
library;

import 'dart:convert';

import 'package:tawheeed/shared/utils/app_logger.dart';

/// One unit inside a category.
class UnitDef {
  const UnitDef({
    required this.id,
    required this.label,
    this.factor = 1,
    this.verified = true,
  });

  final String id;
  final String label;

  /// Multiplier to the category's base unit. Temperature units carry no
  /// factor: they are converted by explicit formulas.
  final double factor;

  /// `false` for the shipped local units: the base is a SUGGESTION the user is
  /// expected to check against their own region.
  final bool verified;

  UnitDef copyWith({double? factor, bool? verified, String? label}) => UnitDef(
        id: id,
        label: label ?? this.label,
        factor: factor ?? this.factor,
        verified: verified ?? this.verified,
      );
}

/// A group of units sharing one base (length, mass, temperature, …).
class UnitCategory {
  const UnitCategory({
    required this.id,
    required this.label,
    required this.baseLabel,
    required this.units,
    this.isTemperature = false,
    this.isLocal = false,
  });

  final String id;
  final String label;
  final String baseLabel;
  final List<UnitDef> units;
  final bool isTemperature;

  /// The «محلی ★» category: its units come from the defaults plus whatever the
  /// user edited or added.
  final bool isLocal;

  UnitDef? unitById(String id) {
    for (final u in units) {
      if (u.id == id) return u;
    }
    return null;
  }
}

/// The whole parsed file.
class UnitsCatalog {
  const UnitsCatalog({
    required this.categories,
    this.note = '',
    this.localNote = '',
  });

  final List<UnitCategory> categories;
  final String note;
  final String localNote;

  UnitCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Never throws: a malformed file yields the categories it could read.
  static UnitsCatalog parse(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return const UnitsCatalog(categories: []);
      final rawCategories = decoded['categories'];
      final categories = <UnitCategory>[];
      if (rawCategories is List) {
        for (final raw in rawCategories) {
          final parsed = _parseCategory(raw);
          if (parsed != null) categories.add(parsed);
        }
      }
      return UnitsCatalog(
        categories: categories,
        note: _string(decoded['note']),
        localNote: _string(decoded['localNote']),
      );
    } catch (e) {
      AppLogger.warning('UnitsCatalog', 'unreadable units file: $e');
      return const UnitsCatalog(categories: []);
    }
  }

  static UnitCategory? _parseCategory(Object? raw) {
    if (raw is! Map) return null;
    final id = _string(raw['id']);
    final label = _string(raw['label']);
    if (id.isEmpty || label.isEmpty) return null;
    final units = <UnitDef>[];
    final rawUnits = raw['units'];
    if (rawUnits is List) {
      for (final u in rawUnits) {
        final parsed = _parseUnit(u);
        if (parsed != null) units.add(parsed);
      }
    }
    if (units.isEmpty) return null;
    return UnitCategory(
      id: id,
      label: label,
      baseLabel: _string(raw['base']),
      units: units,
      isTemperature: raw['temperature'] == true,
      isLocal: raw['local'] == true,
    );
  }

  static UnitDef? _parseUnit(Object? raw) {
    if (raw is! Map) return null;
    final id = _string(raw['id']);
    final label = _string(raw['label']);
    if (id.isEmpty || label.isEmpty) return null;
    final factor = raw['factor'];
    return UnitDef(
      id: id,
      label: label,
      factor: factor is num ? factor.toDouble() : 1,
      verified: raw['verified'] != false,
    );
  }

  static String _string(Object? value) => value is String ? value : '';
}

