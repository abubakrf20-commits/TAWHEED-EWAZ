import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/design_system/components/ring.dart';
import 'package:tawheeed/features/adhkar/data/azkar_data.dart';
import 'package:tawheeed/features/adhkar/data/repositories/azkar_repository_impl.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_provider.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/dhikr_view_prefs.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/home/presentation/widgets/adhkar_category_page.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';

import '../../../../core/database/mock_daos.dart';

class _MockSettings extends Settings {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

List<ZikrItem> _items({required int count}) => List.generate(count, (i) {
      final focused = i == 24;
      return ZikrItem(
        id: 'zikr_$i',
        title: focused ? 'فضل الصبر' : 'ذکر شماره $i',
        arabicText: focused ? 'الصبر مفتاح الفرج' : 'سُبْحَانَ اللَّهِ $i',
        translation: focused ? 'الصبر کلید گشایش است' : 'ترجمه شماره $i',
        source: 'quran',
        period: PrayerPeriod.morningAzkar,
      );
    });

Widget _host(Widget child, {required MockAzkarRepository repo}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(_MockSettings.new),
      azkarRepositoryProvider.overrideWith((ref) async => repo),
      tasbihDaoProvider.overrideWithValue(MockTasbihDao()),
    ],
    child: MaterialApp(
      theme: ThemeData(),
      // The page is pumped only once the provider has loaded: reading the
      // notifier on its first frame (still loading, `_loadedDay` empty) makes
      // it queue a day-change rebuild whose callback would land after disposal.
      home: Consumer(builder: (context, ref, _) {
        if (ref.watch(azkarProvider).isLoading) {
          return const SizedBox.shrink();
        }
        return child;
      }),
    ),
  );
}

/// True when any child span of [text] carries a painted highlight.
bool _hasHighlight(Text text) {
  final span = text.textSpan;
  if (span is! TextSpan) return false;
  return span.children
      ?.whereType<TextSpan>()
      .any((s) => s.style?.backgroundColor != null) ??
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAzkarRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final items = _items(count: 30);
    repo = MockAzkarRepository()..setItems(items);
    AzkarData.setTestData(items);
  });

  tearDown(() {
    AzkarData.setTestData([]);
    Azkar.nowOverride = DateTime.now;
  });

  testWidgets('search focus lands on the hit and paints the query',
      (tester) async {
    final items = _items(count: 30);
    await tester.pumpWidget(_host(
      AdhkarCategoryPage(
        title: 'اذکار صبح',
        period: PrayerPeriod.morningAzkar,
        items: items,
        focusId: 'zikr_24',
        highlightQuery: 'الصبر',
      ),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    // The focused card was built and sits at the top of the list — not 24
    // cards down, which is where it would be without the jump.
    final focused = find.byKey(const ValueKey('zikr_24_false'));
    expect(focused, findsOneWidget);
    final listRect = tester.getRect(find.byType(ScrollablePositionedList));
    final cardRect = tester.getRect(focused);
    expect(cardRect.top, lessThan(listRect.top + 80));
    expect(
      find.byKey(const ValueKey('zikr_0_false'), skipOffstage: false),
      findsNothing,
    );

    // The searched literal is shaded inside the destination text itself.
    final title = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((t) => t.textSpan?.toPlainText() == 'فضل الصبر');
    expect(_hasHighlight(title), isTrue);
    final flagged = (title.textSpan! as TextSpan)
        .children!
        .whereType<TextSpan>()
        .firstWhere((s) => s.style?.backgroundColor != null);
    expect(flagged.text, 'الصبر');
  });

  testWidgets('without a focus the list opens at its first card, unpainted',
      (tester) async {
    final items = _items(count: 3);
    repo = MockAzkarRepository()..setItems(items);
    AzkarData.setTestData(items);
    await tester.pumpWidget(_host(
      AdhkarCategoryPage(
        title: 'اذکار صبح',
        period: PrayerPeriod.morningAzkar,
        items: items,
      ),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    final first = find.byKey(const ValueKey('zikr_0_false'));
    expect(first, findsOneWidget);
    final listRect = tester.getRect(find.byType(ScrollablePositionedList));
    expect(tester.getRect(first).top, lessThan(listRect.top + 80));

    final texts = tester.widgetList<Text>(find.byType(Text));
    expect(texts.any(_hasHighlight), isFalse);
  });

  testWidgets('one tick in focus mode steps exactly one dhikr', (tester) async {
    SharedPreferences.setMockInitialValues({'dhikr.viewMode': 'focus'});
    final items = _items(count: 4);
    repo = MockAzkarRepository()..setItems(items);
    AzkarData.setTestData(items);
    await tester.pumpWidget(_host(
      AdhkarCategoryPage(
        title: 'اذکار صبح',
        period: PrayerPeriod.morningAzkar,
        items: items,
      ),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(RingView));
    // Discrete frames: the advance (350ms) and the session write (250ms) are
    // plain Timers, which schedule no frame, so `pumpAndSettle` can return with
    // both of them still pending.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The cursor is what the page stamps into the session, so this reads the
    // real place the modes will open on. The page moved it TWICE per completion
    // in the modes that report an advance — the listener stepping to the first
    // unfinished dhikr and the advance timer stepping again — which wrote
    // `current: 2` and left zikr_1 passed over although nobody tapped it.
    final prefs = await SharedPreferences.getInstance();
    final key = DhikrViewPrefs.sessionKey(PrayerPeriod.morningAzkar.name);
    final stamp = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
    expect(stamp['current'], 1,
        reason: 'a completion steps exactly one dhikr, never two');
  });

  testWidgets('one tick in the list steps exactly one dhikr', (tester) async {
    final items = _items(count: 4);
    repo = MockAzkarRepository()..setItems(items);
    AzkarData.setTestData(items);
    await tester.pumpWidget(_host(
      AdhkarCategoryPage(
        title: 'اذکار صبح',
        period: PrayerPeriod.morningAzkar,
        items: items,
      ),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('انجام شد').first);
    // Discrete frames again: the list has no advance button, so this tick
    // reaches the page through the card's own completion report only.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final prefs = await SharedPreferences.getInstance();
    final key = DhikrViewPrefs.sessionKey(PrayerPeriod.morningAzkar.name);
    final stamp = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
    expect(stamp['current'], 1, reason: 'the list steps once too, no jump');
  });
}
