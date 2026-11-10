import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/worship/kaffara/kaffara_models.dart';

/// TEST-ONLY fixtures. These rule shapes are never shipped: the production
/// asset is `assets/data/kaffara_rules.json`, which is review-gated and maps
/// the app's own sawm content. Keeping the fixture here means the arithmetic
/// can be tested without pretending a real ruling exists.
const String _testOnlyRulesJson = '''
{
  "rules": [
    {
      "id": "test-fidya",
      "titleFa": "قاعدهٔ آزمون — فدیه",
      "category": "fidya_fast",
      "reviewed": true,
      "sources": ["fixture, never shipped"],
      "madhhabVariants": {
        "shafi": {
          "description": "توضیح آزمون",
          "inputs": [
            {"key": "daysCount", "labelFa": "چند روز", "type": "days", "min": 1, "max": 100, "default": 1},
            {"key": "pricePerKg", "labelFa": "قیمت کیلو", "type": "price", "min": 0, "max": 100000000}
          ],
          "components": [
            {"type": "food_weight", "labelFa": "غذا", "quantityPerUnit": 750, "perInput": "daysCount", "unit": "g", "priceInput": "pricePerKg", "mealGrams": 750}
          ]
        }
      }
    },
    {
      "id": "test-kaffara-draft",
      "titleFa": "قاعدهٔ آزمون — کفاره",
      "category": "kaffara_fast",
      "reviewed": false,
      "sources": ["fixture, never shipped"],
      "madhhabVariants": {
        "shafi": {
          "description": "توضیح آزمون",
          "inputs": [
            {"key": "daysCount", "labelFa": "چند بار", "type": "count", "min": 1, "max": 10, "default": 1},
            {"key": "mealPrice", "labelFa": "قیمت یک وعده", "type": "price", "min": 0, "max": 100000000}
          ],
          "components": [
            {"type": "fasting_days", "labelFa": "روزه", "quantityPerUnit": 60, "perInput": "daysCount", "unit": "روز"},
            {"type": "meal", "labelFa": "اطعام", "quantityPerUnit": 60, "perInput": "daysCount", "unit": "meal", "priceInput": "mealPrice"}
          ]
        }
      }
    },
    {
      "id": "test-no-variant",
      "titleFa": "بی‌مذهب",
      "category": "other",
      "reviewed": true,
      "sources": ["fixture"],
      "madhhabVariants": {}
    }
  ]
}
''';

void main() {
  group('parsing', () {
    final rules = parseKaffaraRules(_testOnlyRulesJson);

    test('drops a rule with no madhhab variant', () {
      expect(rules.map((r) => r.id), ['test-fidya', 'test-kaffara-draft']);
    });

    test('the fixture passes structural validation', () {
      expect(validateKaffaraRules(rules), isEmpty);
    });

    test('malformed JSON degrades to an empty list', () {
      expect(parseKaffaraRules('nope'), isEmpty);
      expect(parseKaffaraRules('{"rules": [{"id": ""}]}'), isEmpty);
    });

    test('an unknown category falls back to «other»', () {
      final parsed = parseKaffaraRules('''
      {"rules":[{"id":"x","titleFa":"x","category":"invented","reviewed":false,
      "sources":["s"],"madhhabVariants":{"shafi":{"inputs":[{"key":"daysCount","type":"days"}],
      "components":[{"type":"other","labelFa":"x","quantityPerUnit":1}]}}}]}
      ''');
      expect(parsed.single.category, KaffaraCategory.other);
    });
  });

  group('reviewed gating', () {
    final rules = parseKaffaraRules(_testOnlyRulesJson);

    test('a reviewed rule is selectable in release', () {
      expect(rules.first.isSelectable(debug: false), isTrue);
    });

    test('an unreviewed rule is hidden in release and visible in debug', () {
      final draft = rules.last;
      expect(draft.reviewed, isFalse);
      expect(draft.isSelectable(debug: false), isFalse);
      expect(draft.isSelectable(debug: true), isTrue);
    });

    test('a rule without the selected madhhab is not selectable', () {
      final rule = rules.first;
      expect(rule.variantFor('hanafi'), isNull);
      expect(rule.variantFor('shafi'), isNotNull);
    });
  });

  group('computation', () {
    final rule = parseKaffaraRules(_testOnlyRulesJson).first;
    final variant = rule.variants['shafi']!;

    test('food weight is grams ÷ 1000 × the user price', () {
      final result = computeKaffara(
        variant: variant,
        values: {'daysCount': 10, 'pricePerKg': 100000},
      );
      expect(result.lines.single.quantity, 7500);
      expect(result.lines.single.money, 750000);
      expect(result.total, 750000);
      expect(result.isComplete, isTrue);
    });

    test('without a price there is no total, only the quantity', () {
      final result = computeKaffara(variant: variant, values: {'daysCount': 3});
      expect(result.total, isNull);
      expect(result.missingInputs, ['pricePerKg']);
      expect(result.lines.single.quantity, 2250);
    });

    test('a zero price counts as missing', () {
      final result = computeKaffara(
        variant: variant,
        values: {'daysCount': 3, 'pricePerKg': 0},
      );
      expect(result.total, isNull);
      expect(result.isComplete, isFalse);
    });

    test('a fasting-day component has no money value', () {
      final draft = parseKaffaraRules(_testOnlyRulesJson).last;
      final result = computeKaffara(
        variant: draft.variants['shafi']!,
        values: {'daysCount': 2},
      );
      final fasting = result.lines.first;
      expect(fasting.quantity, 120);
      expect(fasting.money, isNull);
      // The meal line needs a price the rule asks for, so no total yet.
      expect(result.total, isNull);
      expect(result.missingInputs, ['mealPrice']);
    });

    test('meal quantity × price is money', () {
      final draft = parseKaffaraRules(_testOnlyRulesJson).last;
      final result = computeKaffara(
        variant: draft.variants['shafi']!,
        values: {'daysCount': 2, 'mealPrice': 30000},
      );
      expect(result.lines.last.money, 3600000);
    });

    test('pricing by the served meal divides by that meal weight', () {
      final result = computeKaffara(
        variant: variant,
        values: {'daysCount': 10, 'pricePerKg': 100000},
        pricePerMeal: true,
      );
      // 10 days x 750 g is exactly ten meals, so the meal price is ten times
      // the typed price — not the kilogram figure.
      expect(result.lines.single.meals, 10);
      expect(result.lines.single.money, 1000000);
      expect(result.meals, 10);
    });

    test('a food line reports its meals from the rule, not from a guess', () {
      final result = computeKaffara(
        variant: variant,
        values: {'daysCount': 3, 'pricePerKg': 1000},
      );
      expect(result.meals, 3);
      expect(result.lines.single.meals, 3);
    });

    test('a rule whose answer is qada has no money and says so', () {
      const json = '''
      {"rules":[{"id":"x","titleFa":"x","category":"fidya_deceased","reviewed":true,
      "sources":["s"],"madhhabVariants":{"shafi":{"inputs":[{"key":"daysCount","type":"days","default":1,"min":1}],
      "components":[{"type":"other","labelFa":"قضا","quantityPerUnit":1,"perInput":"daysCount"}]}}}]}
      ''';
      final parsed = parseKaffaraRules(json).single;
      final result = computeKaffara(
        variant: parsed.variants['shafi']!,
        values: {'daysCount': 4},
      );
      expect(result.total, isNull);
      expect(result.hasNoMoney, isTrue);
    });

    test('a food line without a meal weight is a validation problem', () {
      const json = '''
      {"rules":[{"id":"x","titleFa":"x","category":"fidya_fast","reviewed":true,
      "sources":["s"],"madhhabVariants":{"shafi":{"inputs":[{"key":"daysCount","type":"days","default":1,"min":1},
      {"key":"pricePerKg","type":"price"}],
      "components":[{"type":"food_weight","labelFa":"غذا","quantityPerUnit":750,"perInput":"daysCount","unit":"g","priceInput":"pricePerKg"}]}}}]}
      ''';
      final parsed = parseKaffaraRules(json);
      expect(
        validateKaffaraRules(parsed).join(' '),
        contains('mealGrams'),
      );
    });

    test('the multiplier can never be negative', () {
      final result = computeKaffara(
        variant: variant,
        values: {'daysCount': -5, 'pricePerKg': 1000},
      );
      expect(result.lines.single.quantity, 0);
      expect(result.total, 0);
    });
  });

  group('input validation', () {
    final variant =
        parseKaffaraRules(_testOnlyRulesJson).first.variants['shafi']!;

    test('valid values pass', () {
      expect(
        kaffaraInputsValid(
          variant: variant,
          values: {'daysCount': 5, 'pricePerKg': 1000},
        ),
        isTrue,
      );
    });

    test('a missing price fails', () {
      expect(
        kaffaraInputsValid(variant: variant, values: {'daysCount': 5}),
        isFalse,
      );
    });

    test('a value below the rule minimum fails', () {
      expect(
        kaffaraInputsValid(
          variant: variant,
          values: {'daysCount': 0, 'pricePerKg': 1000},
        ),
        isFalse,
      );
      expect(
        kaffaraInputsValid(
          variant: variant,
          values: {'daysCount': 500, 'pricePerKg': 1000},
        ),
        isFalse,
      );
    });
  });

  group('the shipped rule file', () {
    late List<KaffaraRule> shipped;

    setUpAll(() {
      shipped = parseKaffaraRules(
        File('assets/data/kaffara_rules.json').readAsStringSync(),
      );
    });

    test('parses and validates', () {
      expect(shipped, isNotEmpty);
      expect(validateKaffaraRules(shipped), isEmpty);
    });

    test('ships as reviewed, four-madhhab content (selectable in release)', () {
      for (final rule in shipped) {
        expect(rule.reviewed, isTrue, reason: rule.id);
        expect(rule.isSelectable(debug: false), isTrue, reason: rule.id);
      }
    });

    test('every shipped rule names a fiqh source', () {
      for (final rule in shipped) {
        expect(rule.sources, isNotEmpty, reason: rule.id);
        // Recognised fiqh references: the Quran or a hadith collection.
        expect(
          rule.sources.join(' '),
          anyOf(
            contains('القرآن'),
            contains('بخاری'),
            contains('مسلم'),
            contains('أبی داود'),
            contains('الموسوعة'),
          ),
          reason: rule.id,
        );
      }
    });

    test('every category explains itself once: summary, conditions, steps', () {
      for (final rule in shipped) {
        expect(rule.summaryFa, isNotEmpty, reason: rule.id);
        expect(rule.conditions, isNotEmpty, reason: rule.id);
        // The school note is now only that school's difference, never the
        // repeated explanation of the whole category.
        for (final variant in rule.variants.values) {
          expect(variant.description.length, lessThan(140), reason: rule.id);
        }
      }
      final ordered = shipped.where((r) => r.steps.isNotEmpty);
      expect(ordered, isNotEmpty);
      expect(
        shipped.where((r) => r.stepsAreOptions).map((r) => r.id),
        containsAll(<String>['kaffara-oath', 'nadhr']),
      );
    });

    test('every shipped food line knows its meal weight', () {
      for (final rule in shipped) {
        for (final variant in rule.variants.values) {
          for (final component in variant.components) {
            if (component.type != KaffaraComponentType.foodWeight) continue;
            expect(component.mealGrams, greaterThan(0), reason: rule.id);
          }
        }
      }
    });

    test('covers all seven kaffara categories', () {
      final categories = shipped.map((r) => r.category).toSet();
      expect(
        categories,
        containsAll(<KaffaraCategory>{
          KaffaraCategory.fidyaFast,
          KaffaraCategory.kaffaraFast,
          KaffaraCategory.kaffaraOath,
          KaffaraCategory.kaffaraZihar,
          KaffaraCategory.nadhr,
          KaffaraCategory.fidyaDeceased,
          KaffaraCategory.kaffaraQatlKhata,
        }),
      );
    });

    test('the chip order groups the reader’s topics, not the file order', () {
      expect(
        KaffaraCategory.chips,
        [
          KaffaraCategory.fidyaFast,
          KaffaraCategory.kaffaraFast,
          KaffaraCategory.kaffaraOath,
          KaffaraCategory.nadhr,
          KaffaraCategory.kaffaraZihar,
          KaffaraCategory.kaffaraQatlKhata,
          KaffaraCategory.fidyaDeceased,
        ],
      );
    });

    test('قتل خطا is two consecutive months of fasting, never a price', () {
      final rule = shipped.firstWhere((r) => r.id == 'kaffara-qatl-khata');
      expect(rule.reviewed, isTrue);
      expect(rule.category, KaffaraCategory.kaffaraQatlKhata);
      // The verse's own fallback: شهرين متتابعين.
      final result = computeKaffara(
        variant: rule.variants['shafi']!,
        values: {'timesCount': 1},
      );
      expect(result.fastingDays, 60);
      expect(result.total, isNull);
      expect(result.hasNoMoney, isTrue);
      // Three schools require freeing a slave first; the Hanafi one is a choice.
      expect(
        rule.variants['hanafi']!.components.first.labelFa,
        'آزاد کردن بندهٔ مؤمن',
      );
      expect(rule.variants['hanafi']!.description, contains('مخیر'));
    });

    test('every rule carries all four Sunni madhhabs', () {
      const four = {'hanafi', 'maliki', 'shafi', 'hanbali'};
      for (final rule in shipped) {
        expect(rule.variants.keys.toSet(), four, reason: rule.id);
      }
    });

    test('consensus markers match the authored content', () {
      final byId = {for (final r in shipped) r.id: r.ijma};
      expect(byId['fidya-deceased'], KaffaraIjma.ikhtilaf);
      // Three schools require the order (slave, then fasting); the Hanafi
      // school makes it a choice, so this is a majority view, not unanimity.
      expect(byId['kaffara-qatl-khata'], KaffaraIjma.jumhur);
      for (final id in [
        'fidya-fast',
        'kaffara-fast',
        'kaffara-oath',
        'kaffara-zihar',
        'nadhr',
      ]) {
        expect(byId[id], KaffaraIjma.ittifaq, reason: id);
      }
    });
  });
}
