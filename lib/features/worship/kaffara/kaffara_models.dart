/// Data model and calculator for «کفاره و فدیه» (stage 3).
///
/// **Nothing in this file is a ruling.** Every number the screen shows comes
/// from `assets/data/kaffara_rules.json`, whose text is the app's own fiqh
/// content (`assets/content/sawm.json`) mapped verbatim — no component, amount
/// or condition is authored here. The engine multiplies what the rule says by
/// the counts and prices the user types in.
///
/// A rule is selectable only when `reviewed: true`; drafts exist for review and
/// are visible solely behind a debug-build toggle. When no reviewed rule covers
/// the selected category/madhhab the screen shows an EmptyState and no number.
library;

import 'dart:convert';

import 'package:tawheeed/shared/utils/app_logger.dart';

/// What kind of expiation the rule describes. `key` is the stored value.
enum KaffaraCategory {
  fidyaFast('fidya_fast', 'فدیهٔ روزه'),
  kaffaraFast('kaffara_fast', 'کفارهٔ روزه'),
  kaffaraOath('kaffara_oath', 'کفارهٔ سوگند'),
  kaffaraZihar('kaffara_zihar', 'کفارهٔ ظهار'),
  nadhr('nadhr', 'نذر'),
  fidyaDeceased('fidya_deceased', 'فدیهٔ میت'),
  kaffaraQatlKhata('kaffara_qatl_khata', 'کفارهٔ قتل خطا'),
  other('other', 'سایر');

  const KaffaraCategory(this.key, this.labelFa);

  final String key;
  final String labelFa;

  static KaffaraCategory fromKey(String value) =>
      KaffaraCategory.values.firstWhere(
        (c) => c.key == value,
        orElse: () => KaffaraCategory.other,
      );

  /// Categories the screen offers as chips, in this order.
  ///
  /// The order is the reader's, not the file's: the two Ramadan expiations sit
  /// together, a broken oath sits beside the vow it shares its expiation with,
  /// and the grave ones (ظهار، قتل خطا) come before the expiation paid on
  /// behalf of someone who has died.
  static const List<KaffaraCategory> chips = [
    KaffaraCategory.fidyaFast,
    KaffaraCategory.kaffaraFast,
    KaffaraCategory.kaffaraOath,
    KaffaraCategory.nadhr,
    KaffaraCategory.kaffaraZihar,
    KaffaraCategory.kaffaraQatlKhata,
    KaffaraCategory.fidyaDeceased,
  ];
}

/// Level of agreement among the four Sunni madhhabs on a rule.
///
/// Encoded per rule as `ijma` in the asset: `ittifaq` (full agreement / اجماع),
/// `jumhur` (majority view / رأی جمهور), `ikhtilaf` (disagreement / اختلاف).
///
/// It is NOT drawn as a pill any more: the same badge repeated «اتفاق نظر» on
/// every category and said nothing the summary and conditions do not. The
/// field is kept because it is authored content and the schema test pins it;
/// only the per-variant description is shown, and it spells out «نظر جمهور»
/// vs «نظر حنفی» where the measure actually diverges.
enum KaffaraIjma {
  ittifaq('ittifaq', 'اتفاق نظر', 'اتفاق چهار مذهب'),
  jumhur('jumhur', 'رأی جمهور', 'رأی جمهور (اکثریت)'),
  ikhtilaf('ikhtilaf', 'اختلاف مذاهب', 'اختلاف مذاهب');

  const KaffaraIjma(this.key, this.badgeFa, this.detailFa);

  final String key;
  final String badgeFa;
  final String detailFa;

  static KaffaraIjma fromKey(String value) => KaffaraIjma.values.firstWhere(
        (i) => i.key == value,
        orElse: () => KaffaraIjma.ikhtilaf,
      );
}

/// What one component of a rule is measured in.
enum KaffaraComponentType {
  meal('meal'),
  foodWeight('food_weight'),
  money('money'),
  fastingDays('fasting_days'),
  other('other');

  const KaffaraComponentType(this.key);

  final String key;

  static KaffaraComponentType? tryFrom(String value) {
    for (final type in KaffaraComponentType.values) {
      if (type.key == value) return type;
    }
    return null;
  }
}

/// An input the rule asks the user for. `days` feeds the per-day multiplier,
/// `price` is a money field (the app never supplies a price itself).
enum KaffaraInputType {
  days('days'),
  count('count'),
  price('price');

  const KaffaraInputType(this.key);

  final String key;

  static KaffaraInputType? tryFrom(String value) {
    for (final type in KaffaraInputType.values) {
      if (type.key == value) return type;
    }
    return null;
  }
}

class KaffaraInput {
  const KaffaraInput({
    required this.key,
    required this.labelFa,
    required this.type,
    this.unit = '',
    this.min = 0,
    this.max = 1000000,
    this.defaultValue = 0,
    this.required = true,
    this.placeholder = '',
  });

  final String key;
  final String labelFa;
  final KaffaraInputType type;
  final String unit;
  final double min;
  final double max;
  final double defaultValue;
  final bool required;
  final String placeholder;

  /// A price is the one input the app can never default: it changes with the
  /// market and the region, so the field starts empty.
  bool get isPrice => type == KaffaraInputType.price;
}

class KaffaraComponent {
  const KaffaraComponent({
    required this.type,
    required this.labelFa,
    required this.quantityPerUnit,
    this.perInput = 'daysCount',
    this.unit = '',
    this.priceInput = '',
    this.notes = '',
    this.mealGrams = 0,
  });

  final KaffaraComponentType type;
  final String labelFa;
  final double quantityPerUnit;

  /// Which input multiplies [quantityPerUnit].
  final String perInput;

  /// `g` for food weight, `meal` for meals, `''` for counts.
  final String unit;

  /// Key of the price input this component converts to money, when it does.
  final String priceInput;
  final String notes;

  /// Grams in one served meal of this item (one مُدّ for the majority, one
  /// نیم‌صاع for the Hanafi school). When set, the reader may price the food by
  /// the meal they actually buy instead of by the kilogram, and the meal count
  /// is reported honestly instead of being guessed by the screen.
  final double mealGrams;

  /// True when the component cannot be priced without a user-typed price.
  bool get needsPrice =>
      (type == KaffaraComponentType.meal ||
          type == KaffaraComponentType.foodWeight) &&
      priceInput.isNotEmpty;
}

class KaffaraVariant {
  const KaffaraVariant({
    required this.description,
    required this.components,
    required this.inputs,
  });

  final String description;
  final List<KaffaraComponent> components;
  final List<KaffaraInput> inputs;

  KaffaraInput? inputFor(String key) {
    for (final input in inputs) {
      if (input.key == key) return input;
    }
    return null;
  }
}

class KaffaraRule {
  const KaffaraRule({
    required this.id,
    required this.titleFa,
    required this.category,
    required this.ijma,
    required this.reviewed,
    required this.sources,
    required this.variants,
    this.summaryFa = '',
    this.steps = const [],
    this.stepsAreOptions = false,
    this.conditions = const [],
    this.draftNote = '',
  });

  final String id;
  final String titleFa;
  final KaffaraCategory category;

  /// Agreement level among the four Sunni madhhabs (ittifaq/jumhur/ikhtilaf).
  final KaffaraIjma ijma;

  /// Only `true` makes the rule selectable in a release build.
  final bool reviewed;
  final List<String> sources;
  final Map<String, KaffaraVariant> variants;

  /// The one explanation shown for every school: what the expiation is, who
  /// owes it and what settles it. Written once instead of being repeated in
  /// each variant's description.
  final String summaryFa;

  /// The agreed steps (or alternatives) the rule is carried out by.
  final List<String> steps;

  /// `true` when [steps] are alternatives to choose from rather than an order
  /// that must be followed.
  final bool stepsAreOptions;

  /// Conditions and cautions that change whether the expiation is due at all.
  final List<String> conditions;

  /// Free note saying what is still missing before this can be reviewed.
  final String draftNote;

  bool get isSelectableInRelease => reviewed;

  /// Rules are selectable in a debug build as drafts, so the owner can look at
  /// the structure before approving content.
  bool isSelectable({required bool debug}) => reviewed || debug;

  KaffaraVariant? variantFor(String madhhab) => variants[madhhab];
}

// ── Computation ────────────────────────────────────────────────────────────

class KaffaraLine {
  const KaffaraLine({
    required this.labelFa,
    required this.quantity,
    required this.unit,
    required this.money,
    this.notes = '',
    this.meals = 0,
    this.fastingDays = 0,
  });

  final String labelFa;
  final double quantity;
  final String unit;

  /// Null when the line has no monetary value (fasting days, textual items).
  final double? money;
  final String notes;

  /// How many people this line feeds, when the amount is food.
  final double meals;

  /// How many days of fasting this line stands for.
  final double fastingDays;
}

class KaffaraResult {
  const KaffaraResult({
    required this.lines,
    required this.total,
    required this.missingInputs,
    this.meals = 0,
    this.fastingDays = 0,
  });

  final List<KaffaraLine> lines;

  /// People fed across the whole expiation (all food lines added up).
  final double meals;

  /// Fasting days the expiation asks for, when it is paid by fasting.
  final double fastingDays;

  /// True when this school's answer carries no amount at all (the rule is a
  /// duty to make up, not a payment), so the card must not print «—» and
  /// pretend a price is missing.
  bool get hasNoMoney =>
      missingInputs.isEmpty && lines.every((line) => line.money == null);

  /// Sum of the monetary lines; null until every price the rule needs is
  /// present, so the card can show «—» instead of a wrong number.
  final double? total;

  /// Keys of the money inputs still empty.
  final List<String> missingInputs;

  bool get isComplete => missingInputs.isEmpty;
}

/// Computes a rule's components from user input.
///
/// `values` holds the raw numbers the user typed (days, counts, prices). The
/// engine never invents a price and never rounds a quantity it was not given.
KaffaraResult computeKaffara({
  required KaffaraVariant variant,
  required Map<String, double> values,
  bool pricePerMeal = false,
}) {
  final lines = <KaffaraLine>[];
  final missing = <String>[];
  var total = 0.0;
  var hasMoney = false;
  var allMoneyPresent = true;
  var meals = 0.0;
  var fastingDays = 0.0;

  for (final component in variant.components) {
    final multiplier = values[component.perInput] ?? 1;
    final quantity =
        component.quantityPerUnit * (multiplier <= 0 ? 0 : multiplier);

    double? money;
    var lineMeals = 0.0;
    var lineDays = 0.0;
    switch (component.type) {
      case KaffaraComponentType.meal:
        final price = values[component.priceInput];
        lineMeals = quantity;
        if (price == null || price <= 0) {
          allMoneyPresent = false;
          if (!missing.contains(component.priceInput) &&
              component.priceInput.isNotEmpty) {
            missing.add(component.priceInput);
          }
        } else {
          money = quantity * price;
        }
      case KaffaraComponentType.foodWeight:
        final price = values[component.priceInput];
        if (component.mealGrams > 0) {
          lineMeals = quantity / component.mealGrams;
        }
        if (price == null || price <= 0) {
          allMoneyPresent = false;
          if (!missing.contains(component.priceInput) &&
              component.priceInput.isNotEmpty) {
            missing.add(component.priceInput);
          }
        } else {
          // The price is either per kilogram or per served meal; both are
          // prices of the same food, so the quantity never changes.
          final byMeal = pricePerMeal && component.mealGrams > 0;
          money = byMeal
              ? quantity / component.mealGrams * price
              : quantity / 1000 * price;
          hasMoney = true;
        }
      case KaffaraComponentType.money:
        money = quantity;
      case KaffaraComponentType.fastingDays:
        money = null;
        lineDays = quantity;
      case KaffaraComponentType.other:
        money = null;
    }
    if (money != null) {
      total += money;
      hasMoney = true;
    }
    meals += lineMeals;
    fastingDays += lineDays;
    lines.add(KaffaraLine(
      labelFa: component.labelFa,
      quantity: quantity,
      unit: component.unit,
      money: money,
      notes: component.notes,
      meals: lineMeals,
      fastingDays: lineDays,
    ));
  }

  return KaffaraResult(
    lines: lines,
    total: hasMoney && allMoneyPresent ? total : null,
    missingInputs: missing,
    meals: meals,
    fastingDays: fastingDays,
  );
}

/// True when every required input has an acceptable value.
bool kaffaraInputsValid({
  required KaffaraVariant variant,
  required Map<String, double> values,
}) {
  for (final input in variant.inputs) {
    if (!input.required) continue;
    final value = values[input.key];
    if (value == null) return false;
    if (value < input.min || value > input.max) return false;
    if (input.type == KaffaraInputType.price && value <= 0) return false;
    if (input.type != KaffaraInputType.price && value <= 0) return false;
  }
  return true;
}

// ── Parsing ────────────────────────────────────────────────────────────────

/// Parses `assets/data/kaffara_rules.json`. A malformed rule is dropped with a
/// logged warning rather than taking the calculator down.
List<KaffaraRule> parseKaffaraRules(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['rules'] is! List) return const [];
    final rules = <KaffaraRule>[];
    for (final row in decoded['rules'] as List) {
      final rule = _parseRule(row);
      if (rule != null) rules.add(rule);
    }
    return rules;
  } catch (e) {
    AppLogger.warning('KaffaraRules', 'bundle read failed: $e');
    return const [];
  }
}

KaffaraRule? _parseRule(Object? row) {
  if (row is! Map) return null;
  final id = (row['id'] as String?)?.trim() ?? '';
  final title = (row['titleFa'] as String?)?.trim() ?? '';
  if (id.isEmpty || title.isEmpty) return null;

  final variants = <String, KaffaraVariant>{};
  final rawVariants = row['madhhabVariants'];
  if (rawVariants is Map) {
    for (final entry in rawVariants.entries) {
      final variant = _parseVariant(entry.value);
      if (variant != null) variants[entry.key.toString()] = variant;
    }
  }
  if (variants.isEmpty) return null;

  final sources = <String>[];
  final rawSources = row['sources'];
  if (rawSources is List) {
    for (final source in rawSources) {
      if (source is String && source.trim().isNotEmpty)
        sources.add(source.trim());
    }
  }

  return KaffaraRule(
    id: id,
    titleFa: title,
    category: KaffaraCategory.fromKey((row['category'] as String?) ?? 'other'),
    ijma: KaffaraIjma.fromKey((row['ijma'] as String?) ?? 'ikhtilaf'),
    reviewed: row['reviewed'] == true,
    sources: sources,
    variants: variants,
    summaryFa: (row['summaryFa'] as String?)?.trim() ?? '',
    steps: _stringList(row['steps']),
    stepsAreOptions: (row['stepsMode'] as String?) == 'options',
    conditions: _stringList(row['conditions']),
    draftNote: (row['draftNote'] as String?)?.trim() ?? '',
  );
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
}

KaffaraVariant? _parseVariant(Object? raw) {
  if (raw is! Map) return null;
  final inputs = <KaffaraInput>[];
  final rawInputs = raw['inputs'];
  if (rawInputs is List) {
    for (final entry in rawInputs) {
      if (entry is! Map) continue;
      final key = (entry['key'] as String?)?.trim() ?? '';
      final type = KaffaraInputType.tryFrom((entry['type'] as String?) ?? '');
      if (key.isEmpty || type == null) continue;
      inputs.add(KaffaraInput(
        key: key,
        labelFa: (entry['labelFa'] as String?)?.trim() ?? key,
        type: type,
        unit: (entry['unit'] as String?) ?? '',
        min: _num(entry['min'])?.toDouble() ?? 0,
        max: _num(entry['max'])?.toDouble() ?? 1000000,
        defaultValue: _num(entry['default'])?.toDouble() ?? 0,
        required: entry['required'] != false,
        placeholder: (entry['placeholder'] as String?) ?? '',
      ));
    }
  }

  final components = <KaffaraComponent>[];
  final rawComponents = raw['components'];
  if (rawComponents is List) {
    for (final entry in rawComponents) {
      if (entry is! Map) continue;
      final type =
          KaffaraComponentType.tryFrom((entry['type'] as String?) ?? '');
      if (type == null) continue;
      components.add(KaffaraComponent(
        type: type,
        labelFa: (entry['labelFa'] as String?)?.trim() ?? '',
        quantityPerUnit: _num(entry['quantityPerUnit'])?.toDouble() ?? 0,
        perInput: (entry['perInput'] as String?) ?? 'daysCount',
        unit: (entry['unit'] as String?) ?? '',
        priceInput: (entry['priceInput'] as String?) ?? '',
        notes: (entry['notes'] as String?) ?? '',
        mealGrams: _num(entry['mealGrams'])?.toDouble() ?? 0,
      ));
    }
  }
  if (components.isEmpty) return null;

  return KaffaraVariant(
    description: (raw['description'] as String?)?.trim() ?? '',
    components: components,
    inputs: inputs,
  );
}

num? _num(Object? value) => value is num ? value : null;

/// Structural validation for the rules asset (used by the schema test).
///
/// Returns a human-readable list of problems; empty means the file is sound.
List<String> validateKaffaraRules(List<KaffaraRule> rules) {
  final problems = <String>[];
  if (rules.isEmpty) problems.add('no rules parsed');
  final seen = <String>{};
  for (final rule in rules) {
    if (!seen.add(rule.id)) problems.add('duplicate rule id: ${rule.id}');
    if (rule.sources.isEmpty) problems.add('${rule.id}: no source');
    if (rule.reviewed && rule.sources.isEmpty) {
      problems.add('${rule.id}: reviewed without a source');
    }
    for (final entry in rule.variants.entries) {
      final variant = entry.value;
      if (variant.inputs.isEmpty) {
        problems.add('${rule.id}/${entry.key}: no inputs');
      }
      final keys = variant.inputs.map((i) => i.key).toSet();
      for (final component in variant.components) {
        if (component.quantityPerUnit <= 0) {
          problems.add('${rule.id}/${entry.key}: non-positive quantity');
        }
        if (!keys.contains(component.perInput)) {
          problems.add(
              '${rule.id}/${entry.key}: component needs unknown input ${component.perInput}');
        }
        if (component.needsPrice &&
            (!keys.contains(component.priceInput) ||
                variant.inputFor(component.priceInput)?.type !=
                    KaffaraInputType.price)) {
          problems.add(
              '${rule.id}/${entry.key}: bad price input ${component.priceInput}');
        }
        if (component.type == KaffaraComponentType.foodWeight &&
            component.mealGrams <= 0) {
          // Without a meal weight the reader can never price a bought meal and
          // the meal count would have to be guessed.
          problems.add('${rule.id}/${entry.key}: food line without mealGrams');
        }
      }
    }
  }
  return problems;
}
