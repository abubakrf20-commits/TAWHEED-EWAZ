import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The five top-level tabs wear a slim [PageHeader] instead of a 56dp [AppBar]
/// (user request, 2026-10-14: «بالای تب‌ها زیادی جا گرفتند»). This is a source
/// scan, the repo's idiom for a "must not come back" invariant: the tabs are
/// expensive to pump (each needs its own provider graph), and the thing being
/// guarded is structural — an `appBar:` on any of these five.
///
/// The quran tab is not listed: it never had a bar.
String _stripComments(String source) => source.split('\n').map((line) {
      final i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    }).join('\n');

/// Each tab: its file, the nav pill's label (which the header must keep, so the
/// page still names itself to a screen reader), and the tooltip of the action
/// the old bar carried (which must survive the move).
const _tabs = <(String, String, String?)>[
  (
    'lib/features/home/presentation/screens/home_tab.dart',
    'خانه',
    'جستجو در همه بخش‌ها',
  ),
  (
    'lib/features/adhkar/presentation/screens/azkar_tasbih_tab.dart',
    'اذکار و تسبیح',
    'تنظیمات اذکار و تسبیح',
  ),
  (
    'lib/features/tools/calendar/presentation/screens/calendar_screen.dart',
    'تقویم',
    'مبدل تاریخ',
  ),
  (
    'lib/features/worship/presentation/screens/evaluation_tab.dart',
    'ارزیابی و گزارش',
    null,
  ),
  (
    'lib/features/settings/presentation/screens/more_screen.dart',
    'بیشتر',
    null,
  ),
];

void main() {
  for (final (path, title, actionTooltip) in _tabs) {
    final file = File(path);

    group(path.split('/').last, () {
      test('carries a PageHeader and no AppBar', () {
        expect(file.existsSync(), isTrue, reason: 'missing $path');
        final src = _stripComments(file.readAsStringSync());
        expect(src, isNot(contains('appBar:')));
        expect(src, isNot(contains('AppBar(')));
        // A page may render the header itself or delegate to the shared
        // SectionShell, which renders a PageHeader for it (Home adopted the
        // shell in the 2026-10-25 extraction). Either way the page must still
        // supply its own title and actions — the two tests below pin those.
        expect(
          src.contains('PageHeader(') || src.contains('SectionShell.'),
          isTrue,
          reason: 'the page must wear a PageHeader, directly or through the '
              'shared SectionShell',
        );
      });

      test('the header still names the page «$title»', () {
        final src = _stripComments(file.readAsStringSync());
        // The exact constructor call, so the title cannot be quietly dropped
        // (the pill names the tab, but the page itself must too).
        expect(src, contains("title: '$title'"));
      });

      if (actionTooltip != null) {
        test('the action «$actionTooltip» survived the move', () {
          final src = _stripComments(file.readAsStringSync());
          expect(src, contains('PageAction('));
          expect(src, contains("tooltip: '$actionTooltip'"));
        });
      }
    });
  }

  test('the adhkar sub-tabs use the kit control, not a TabBar', () {
    final src = _stripComments(File(
            'lib/features/adhkar/presentation/screens/azkar_tasbih_tab.dart')
        .readAsStringSync());
    expect(RegExp(r'\bTabBar\(').hasMatch(src), isFalse);
    // `\b` keeps `SegmentedTab(` and `TabBarView(` out of the match.
    expect(RegExp(r'\bTab\(').hasMatch(src), isFalse);
    expect(src, contains('SegmentedTabs('));
    expect(src, contains('SegmentedTab(label:'));
  });
}
