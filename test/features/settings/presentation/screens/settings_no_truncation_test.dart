import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';

import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

/// The settings page must never cut a setting short with «…»: every row has to
/// show its full label and description on a phone.
///
/// The page is scanned for `RenderParagraph.didExceedMaxLines`, i.e. a `Text`
/// that opted into `maxLines` + ellipsis and then overflowed.
///
/// Three tracks:
/// * the app's own Persian face (the bundled Vazirmatn) at 320/360/412dp and at
///   text scale 1.0 and 1.3 — the user-facing promise;
/// * the test binding's fallback font at 360/412dp — a strict tripwire, because
///   that font draws every glyph one em wide while Vazirmatn measures ~1.7x
///   narrower («تاریخ هجری» is 140dp wide in the test font against 82dp in
///   Vazirmatn). Passing in that font means passing with margin.
///
/// 320dp is deliberately absent from the test-font track: at that width three
/// rows only exceed their cap under the inflated test metrics, and the
/// Vazirmatn track above proves they render in full with a real face.
Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  SharedPreferences.setMockInitialValues({});
  AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final repo = MockSettingsRepository()..setMockSettings(const AppSettings());
  final container = ProviderContainer(overrides: [
    settingsRepositoryProvider.overrideWith((ref) async => repo),
    dailyNotificationSchedulerProvider
        .overrideWithValue(FakeDailyNotificationScheduler()),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));

  // Grow the viewport to the page's own measured height: a lazily built list
  // would otherwise only lay out the rows that happened to be on screen.
  final pos =
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  final content = pos.maxScrollExtent + pos.viewportDimension;
  await tester.binding.setSurfaceSize(Size(width, content + kToolbarHeight));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

List<String> _ellipsised(WidgetTester tester) {
  final cut = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final ro = element.renderObject;
    if (ro is! RenderParagraph || !ro.didExceedMaxLines) continue;
    cut.add('«${ro.text.toPlainText()}» — '
        '${ro.constraints.maxWidth.toStringAsFixed(0)}dp available, '
        '${ro.getMaxIntrinsicWidth(double.infinity).toStringAsFixed(0)}dp '
        'needed');
  }
  return cut;
}

Future<void> _loadVazirmatn() async {
  final loader = FontLoader('Vazirmatn')
    ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
  await loader.load();
}

void main() {
  for (final width in <double>[320, 360, 412]) {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets(
          'no truncated setting — Vazirmatn ${width.toInt()}dp ×$scale',
          (tester) async {
        await _loadVazirmatn();
        AppTheme.fontFamily = 'Vazirmatn';
        addTearDown(() => AppTheme.fontFamily = AppTheme.defaultFontFamily);

        await _pump(tester, width: width, textScale: scale);

        final cut = _ellipsised(tester);
        expect(cut, isEmpty,
            reason: 'the settings page cut ${cut.length} text(s) short: '
                '${cut.join(' | ')}');
      });
    }
  }

  for (final width in <double>[360, 412]) {
    testWidgets('no truncated setting — conservative test font ${width.toInt()}dp',
        (tester) async {
      AppTheme.fontFamily = AppTheme.defaultFontFamily;
      await _pump(tester, width: width, textScale: 1.0);

      final cut = _ellipsised(tester);
      expect(cut, isEmpty,
          reason: 'the settings page cut ${cut.length} text(s) short: '
              '${cut.join(' | ')}');
    });
  }
}
