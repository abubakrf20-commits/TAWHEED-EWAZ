import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/period_hayz_banner.dart';
import 'package:tawheeed/features/prayer/data/daos/period_record_dao.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';

import '../../../../core/database/mock_daos.dart';

/// The home page's hayz note has two promises, both from the user's report
/// («اولا کامل نشان نمیده دوما … زیر دسترسی سریع»):
///
/// 1. it sits at the BOTTOM of the page, under «دسترسی سریع» (QuickActions),
///    and nowhere else — the prayer-times card renders no banner at all;
/// 2. its sentence always renders IN FULL, on every phone width and at text
///    scale 1.3, measured with the app's own bundled Persian face.
///
/// Promise 2 is the one that was broken: the note carried
/// `overflow: TextOverflow.ellipsis` inside a `Flexible`, and a paragraph with
/// an ellipsis overflow refuses to wrap — so it squeezed to one line and cut
/// itself with «…» at 320, 360 and 412dp alike.
const _trackerNote =
    'در ایام حیض نماز ساقط است؛ ثبت آن اختیاری است و ثبت‌نکردنش «فوت» شمرده نمی‌شود';
const _defaultNote =
    'در ایام حیض هستید — نماز و روزه ساقط است؛ طاعات دیگر را دستی ثبت کنید تا امتیاز بگیرید';

String _readSource(String relative) =>
    File(relative).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('placement: the note lives under «دسترسی سریع»', () {
    test('home_tab renders it after QuickActions and nowhere earlier', () {
      final source =
          _readSource('lib/features/home/presentation/screens/home_tab.dart');
      final quick = source.indexOf('const QuickActions()');
      final banner = source.indexOf('PeriodHayzBanner(');
      expect(quick, greaterThan(-1),
          reason: 'QuickActions must stay on the page');
      expect(banner, greaterThan(-1),
          reason: 'the page must render the hayz note itself');
      expect(banner, greaterThan(quick),
          reason: 'the note belongs BELOW quick access, not above it');
    });

    test('the prayer-times card renders no banner and imports none', () {
      final source = _readSource(
          'lib/features/home/presentation/widgets/prayer_times_card.dart');
      expect(source.contains('PeriodHayzBanner'), isFalse,
          reason: 'the note moved off the card — a second copy would disagree');
      expect(source.contains('period_hayz_banner.dart'), isFalse);
      // The card still needs the period itself: a closed unlogged window on a
      // period day must not wear the red missed dash. The watch is hoisted
      // above the QuantizedRebuild closures (watch cannot run inside a
      // listener callback), so the consult reads `periodLoaded &&`.
      expect(source.contains('exempt: periodLoaded &&'), isTrue);
      expect(source.contains('isDateInPeriod(now)'), isTrue);
    });
  });

  group('the sentence renders in full', () {
    for (final width in <double>[320, 360, 412]) {
      for (final scale in <double>[1.0, 1.3]) {
        for (final entry
            in {'tracker': _trackerNote, 'default': _defaultNote}.entries) {
          testWidgets('${entry.key} at ${width.toInt()}dp x$scale',
              (tester) async {
            await _pumpBanner(tester,
                width: width, scale: scale, note: entry.value);

            final render =
                tester.renderObject<RenderParagraph>(find.text(entry.value));
            final boxes = render.getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: entry.value.length));
            final lines = boxes.map((b) => b.top.round()).toSet().length;

            expect(render.didExceedMaxLines, isFalse,
                reason: 'a shar\'i note is never cut short with «…»');
            // The narrowest track must genuinely wrap: a component that merely
            // shrank the glyphs would report one line and pass the check above.
            if (width == 320) {
              expect(lines, greaterThanOrEqualTo(2),
                  reason:
                      'at 320dp the sentence has to take more than one line');
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}

Future<void> _pumpBanner(
  WidgetTester tester, {
  required double width,
  required double scale,
  required String note,
}) async {
  final loader = FontLoader('Vazirmatn')
    ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
  await loader.load();
  AppTheme.fontFamily = 'Vazirmatn';
  addTearDown(() => AppTheme.fontFamily = AppTheme.defaultFontFamily);

  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    periodRecordDaoProvider.overrideWithValue(MockPeriodRecordDao()),
  ]);
  addTearDown(container.dispose);

  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: PeriodHayzBanner(trackerNote: note),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ));

  // A record covering today is what makes the banner render at all.
  await container.read(periodProvider.notifier).startPeriod(DateTime.now());
  await tester.pump();
  await tester.pump();

  expect(find.text(note), findsOneWidget,
      reason:
          'the banner must be on screen for the measurement to mean anything');
}
