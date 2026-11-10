import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/worship/kaffara/kaffara_models.dart';
import 'package:tawheeed/features/worship/kaffara/kaffara_providers.dart';
import 'package:tawheeed/features/worship/kaffara/kaffara_screen.dart';

import 'family_faith_test_kit.dart';

/// TEST-ONLY fixture: a reviewed rule so the calculator's filled state can be
/// exercised. The shipped asset now carries authoritative, four-madhhab,
/// reviewed content — the widget tests cover both the fixture and the asset.
const String _fixtureRules = '''
{"rules":[{
  "id":"test-fidya","titleFa":"فدیهٔ آزمون","category":"fidya_fast","ijma":"ittifaq","reviewed":true,
  "sources":["fixture, never shipped"],
  "madhhabVariants":{"shafi":{
    "description":"متن آزمون برای نمایش ساختار.",
    "inputs":[
      {"key":"daysCount","labelFa":"چند روز","type":"days","min":1,"max":100,"default":1},
      {"key":"pricePerKg","labelFa":"قیمت یک کیلوگرم","type":"price","min":0,"max":100000000,"placeholder":"وارد کنید"}
    ],
    "components":[
      {"type":"food_weight","labelFa":"غذای معمولی برای هر روز","quantityPerUnit":750,"perInput":"daysCount","unit":"g","priceInput":"pricePerKg","mealGrams":750}
    ]
  }}
}]}
''';

/// The real asset, parsed once. The widget tests never rely on the async
/// bundle load: a spinner that animates forever makes `pumpAndSettle` flaky,
/// and the asset's own integrity is covered by `kaffara_engine_test.dart`.
late final List<KaffaraRule> _shippedRules;

Future<void> _pump(
  WidgetTester tester, {
  List<KaffaraRule>? rules,
  Map<String, Object> prefs = const {},
  Size size = const Size(360, 1400),
  double scale = 1,
}) async {
  applyDayTheme();
  SharedPreferences.setMockInitialValues(prefs);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(familyTestApp(
    size: size,
    scale: scale,
    overrides: [
      kaffaraRulesProvider.overrideWith((ref) => rules ?? _shippedRules),
      kaffaraDebugProvider.overrideWith((ref) => false),
      kaffaraMadhhabProvider.overrideWithValue('shafi'),
    ],
    child: const KaffaraScreen(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    _shippedRules = parseKaffaraRules(
      File('assets/data/kaffara_rules.json').readAsStringSync(),
    );
  });

  testWidgets('the shipped data shows a result, never the EmptyState',
      (tester) async {
    await _pump(tester);
    // Default = فدیهٔ روزه / شافعی, which is reviewed and present.
    expect(find.text('این حکم هنوز در برنامه موجود نیست'), findsNothing);
    expect(find.text('مبلغ برآوردی'), findsOneWidget);
    // The explanation is written once: summary, conditions, cadence. The old
    // per-rule consensus pill is gone on purpose — it repeated the same words
    // on every category.
    expect(find.text('اتفاق نظر'), findsNothing);
    expect(find.text('شرایط و نکته‌ها'), findsOneWidget);
    expect(find.textContaining('فدیه بدلِ روزه'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all four madhhab chips are offered', (tester) async {
    await _pump(tester);
    expect(find.text('حنفی'), findsOneWidget);
    expect(find.text('مالکی'), findsOneWidget);
    expect(find.text('شافعی'), findsOneWidget);
    expect(find.text('حنبلی'), findsOneWidget);
  });

  testWidgets('opens on the school picked last time', (tester) async {
    // The Asr-madhhab default is Shafi (overridden below); a stored pick must
    // win, otherwise someone reading the Hanafi column re-picks it every visit.
    await _pump(tester, prefs: {'personal.kaffara.madhhab': 'hanafi'});
    expect(find.textContaining('نظر حنفی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting حنفی shows the Hanafi variant (with its measure)',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('حنفی'));
    await tester.pumpAndSettle();
    expect(find.text('این حکم هنوز در برنامه موجود نیست'), findsNothing);
    // The school note is only that school's difference.
    expect(find.textContaining('نظر حنفی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reviewed rule shows the breakdown and the total',
      (tester) async {
    await _pump(tester, rules: parseKaffaraRules(_fixtureRules));
    expect(find.text('فدیهٔ آزمون'), findsOneWidget);
    expect(find.text('مبلغ برآوردی'), findsOneWidget);
    // No price yet: the card shows a dash and the actions stay disabled.
    expect(find.text('—'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).first, '100000');
    await tester.pumpAndSettle();

    expect(find.text('75,000 تومان'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at 320 dp with text scale 1.3', (tester) async {
    await _pump(
      tester,
      rules: parseKaffaraRules(_fixtureRules),
      size: const Size(320, 1600),
      scale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shipped summaries and steps fit 320 dp at 1.3',
      (tester) async {
    // The real asset carries a summary plus numbered steps and conditions per
    // category — the long prose that the fixture does not have.
    await _pump(tester, size: const Size(320, 1600), scale: 1.3);
    await tester.tap(find.text('کفارهٔ سوگند'));
    await tester.pumpAndSettle();
    expect(find.text('گزینه‌ها'), findsOneWidget);
    expect(find.text('این مذهب مبلغی تعیین نمی‌کند'), findsNothing);
    await tester.tap(find.text('فدیهٔ میت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شافعی'));
    await tester.pumpAndSettle();
    expect(find.text('این مذهب مبلغی تعیین نمی‌کند'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
