import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/tools/calendar/domain/day_journal_entry.dart';
import 'package:tawheeed/features/tools/calendar/presentation/providers/day_journal_provider.dart';
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_widgets.dart';

/// The three parts that sit under the grid: the monthly occasions, the day
/// journal, and the quick-jump sheet.
///
/// Pinned here: the weekly-fasts collapse (the reason the list is readable at
/// all), the frozen clock that decides «امروز» / «بعدی» / past, the Shamsi
/// date reading as a date instead of a `1405/10/8` dump, a delete affordance
/// whose hit area is actually a touch target, and the year strip opening on the
/// selected year rather than two chips past it.

/// 30 October 2026 — a Friday, 8 مهر 1405, used as «today» throughout.
final _today = DateTime(2026, 10, 30);

CalendarMonthEvent _ev(DateTime day, String label, {int hijriDay = 1}) =>
    CalendarMonthEvent(hijriDay: hijriDay, gregorianDate: day, label: label);

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

class _FakeJournal extends DayJournalNotifier {
  _FakeJournal(this.initial);

  final Map<String, List<DayJournalEntry>> initial;
  final List<String> toggled = [];
  final List<String> removed = [];

  @override
  Future<Map<String, List<DayJournalEntry>>> build() async => initial;

  @override
  Future<void> toggleDone(String dateKey, String id) async =>
      toggled.add('$dateKey#$id');

  @override
  Future<void> remove(String dateKey, String id) async =>
      removed.add('$dateKey#$id');
}

/// A journal whose first read fails until [offline] is cleared. The flag lives
/// outside the notifier because a retry (`invalidate`) builds a new instance.
class _JournalFault {
  bool offline = true;
}

class _FlakyJournal extends DayJournalNotifier {
  _FlakyJournal(this.fault);

  final _JournalFault fault;

  @override
  Future<Map<String, List<DayJournalEntry>>> build() async {
    if (fault.offline) throw StateError('journal offline');
    return const {};
  }
}

DayJournalEntry _entry(String id, DayJournalKind kind, String text,
        {bool done = false}) =>
    DayJournalEntry(
        id: id, kind: kind, text: text, done: done, createdAt: _today);

void main() {
  group('monthly occasions list', () {
    testWidgets('no occasions, no card', (tester) async {
      await tester.pumpWidget(
          _wrap(MonthlyEventsSection(events: const [], now: _today)));
      expect(find.byType(AppCard), findsNothing);
    });

    testWidgets('the weekly fasts collapse into one summary row',
        (tester) async {
      final events = [
        _ev(DateTime(2026, 10, 5), 'روزه دوشنبه (مستحب)'),
        _ev(DateTime(2026, 10, 8), 'روزه پنجشنبه (مستحب)'),
        _ev(DateTime(2026, 10, 12), 'روزه دوشنبه (مستحب)'),
        _ev(DateTime(2026, 10, 15), 'روزه دوشنبه (مستحب)'),
        _ev(DateTime(2026, 10, 22), 'روزه پنجشنبه (مستحب)'),
        _ev(DateTime(2026, 10, 17), 'عید فطر'),
      ];
      await tester
          .pumpWidget(_wrap(MonthlyEventsSection(events: events, now: _today)));
      await tester.pumpAndSettle();

      expect(find.text('روزه‌های هفتگی مستحب'), findsOneWidget);
      expect(
          find.text('این ماه 5 روز (دوشنبه‌ها و پنجشنبه‌ها)'), findsOneWidget);
      // The individual Mondays and Thursdays never reach the list.
      expect(find.text('روزه دوشنبه (مستحب)'), findsNothing);
      expect(find.text('روزه پنجشنبه (مستحب)'), findsNothing);
      // One occasion plus the summary row, counted in the header.
      expect(find.text('عید فطر'), findsOneWidget);
      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('an occasion today is marked, and it takes the «بعدی» place',
        (tester) async {
      final events = [
        _ev(DateTime(2026, 10, 15), 'عید فطر'),
        _ev(_today, 'شب یلدا'),
        _ev(DateTime(2026, 11, 5), 'روزه عرفه'),
      ];
      await tester
          .pumpWidget(_wrap(MonthlyEventsSection(events: events, now: _today)));
      await tester.pumpAndSettle();

      expect(find.text('امروز'), findsOneWidget);
      // «بعدی» is the first day that has not passed — here the today row
      // itself, which already wears «امروز».
      expect(find.text('بعدی'), findsNothing);
    });

    testWidgets('the next upcoming occasion is marked when nothing is today',
        (tester) async {
      final events = [
        _ev(DateTime(2026, 10, 15), 'عید فطر'),
        _ev(DateTime(2026, 10, 20), 'روزه عرفه'),
        _ev(DateTime(2026, 11, 5), 'عید غدیر'),
      ];
      await tester
          .pumpWidget(_wrap(MonthlyEventsSection(events: events, now: _today)));
      await tester.pumpAndSettle();

      expect(find.text('امروز'), findsNothing);
      expect(find.text('بعدی'), findsOneWidget);
      expect(find.text('عید غدیر'), findsOneWidget);
    });

    testWidgets('a month that has run out marks nothing', (tester) async {
      final events = [
        _ev(DateTime(2026, 10), 'عید فطر'),
        _ev(DateTime(2026, 10, 20), 'روزه عرفه'),
      ];
      await tester
          .pumpWidget(_wrap(MonthlyEventsSection(events: events, now: _today)));
      await tester.pumpAndSettle();

      expect(find.text('امروز'), findsNothing);
      expect(find.text('بعدی'), findsNothing);
    });

    testWidgets('the date under an occasion reads as a Shamsi date',
        (tester) async {
      final events = [_ev(_today, 'شب یلدا')];
      await tester
          .pumpWidget(_wrap(MonthlyEventsSection(events: events, now: _today)));
      await tester.pumpAndSettle();

      expect(find.text('جمعه · 8 آبان 1405'), findsOneWidget);
      expect(find.textContaining('1405/10/8'), findsNothing);
      // One shared occasion table gives the icon, not a second chain of rules.
      expect(find.byIcon(Icons.nights_stay), findsOneWidget);
    });
  });

  group('day journal', () {
    const dateKey = '2026-10-30';

    Future<_FakeJournal> pump(
        WidgetTester tester, List<DayJournalEntry> entries) async {
      final journal = _FakeJournal({dateKey: entries});
      await tester.pumpWidget(ProviderScope(
        overrides: [dayJournalProvider.overrideWith(() => journal)],
        child: _wrap(const DayJournalSection(
          dateKey: dateKey,
          dayLabel: '8 آبان 1405',
        )),
      ));
      await tester.pumpAndSettle();
      return journal;
    }

    testWidgets('the header counts what the day holds', (tester) async {
      await pump(tester, [
        _entry('1', DayJournalKind.task, 'ختم جزء ۳۰'),
        _entry('2', DayJournalKind.memory, 'یادآوری: تماس'),
      ]);
      expect(find.text('کارها و یادداشت‌های این روز'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('ختم جزء ۳۰'), findsOneWidget);
      expect(find.text('یادآوری: تماس'), findsOneWidget);
    });

    testWidgets('an empty day says so', (tester) async {
      await pump(tester, const []);
      expect(find.text('برای این روز چیزی ثبت نشده است.'), findsOneWidget);
    });

    testWidgets('a failed read offers a retry, then the honest empty day',
        (tester) async {
      final fault = _JournalFault();
      await tester.pumpWidget(ProviderScope(
        overrides: [dayJournalProvider.overrideWith(() => _FlakyJournal(fault))],
        child: _wrap(const DayJournalSection(
          dateKey: dateKey,
          dayLabel: '8 آبان 1405',
        )),
      ));
      await tester.pumpAndSettle();

      // A failed read must name itself; it may not pose as an empty day.
      expect(find.byKey(const ValueKey('failure_calendar_journal')),
          findsOneWidget);
      expect(find.text('ثبت یا بارگذاری یادداشت ممکن نشد'), findsOneWidget);
      expect(find.text('برای این روز چیزی ثبت نشده است.'), findsNothing);
      expect(find.text(FailureView.retryLabel), findsOneWidget);

      fault.offline = false;
      await tester.tap(find.text(FailureView.retryLabel));
      await tester.pumpAndSettle();

      // The retry reads again: the failure is gone and the real emptiness shows.
      expect(find.byKey(const ValueKey('failure_calendar_journal')),
          findsNothing);
      expect(find.text('برای این روز چیزی ثبت نشده است.'), findsOneWidget);
    });

    testWidgets('deleting has a real touch target', (tester) async {
      await pump(tester, [_entry('1', DayJournalKind.task, 'یک کار')]);
      final icon = find.byIcon(Icons.delete_outline_rounded);
      expect(icon, findsOneWidget);

      final tap = find.ancestor(
          of: icon,
          matching: find.byWidgetPredicate((w) => w is GestureDetector));
      final size = tester.getSize(tap);
      expect(size.width, greaterThanOrEqualTo(40));
      expect(size.height, greaterThanOrEqualTo(40));
    });

    testWidgets('the done circle reaches the journal', (tester) async {
      final journal = await pump(
          tester, [_entry('7', DayJournalKind.task, 'کار انجام‌شدنی')]);
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();
      expect(journal.toggled, ['$dateKey#7']);
    });

    testWidgets('a memory keeps no checkbox', (tester) async {
      await pump(tester, [_entry('9', DayJournalKind.memory, 'یادداشت روز')]);
      // The kind chips show a checklist and a story icon; only the task row
      // would add a check circle.
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    });
  });

  group('quick jump sheet', () {
    Future<void> open(
      WidgetTester tester, {
      required int year,
      required int month,
      required void Function(int, int) onSelected,
    }) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Builder(
                builder: (context) => Center(
                      child: ElevatedButton(
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => JalaliMonthPickerSheet(
                            initialYear: year,
                            initialMonth: month,
                            onSelected: onSelected,
                          ),
                        ),
                        child: const Text('باز کردن'),
                      ),
                    )),
          ),
        ),
      ));
      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();
    }

    testWidgets('the year strip opens on the selected year', (tester) async {
      int y = 0, m = 0;
      await open(tester, year: 1405, month: 7, onSelected: (a, b) {
        y = a;
        m = b;
      });
      expect(find.text('پرش سریع به تاریخ'), findsOneWidget);

      final rect = tester.getRect(find.text('1405'));
      // The old offset was computed against a 72px item in a 64px strip, which
      // parked the current year about two chips outside the viewport.
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(800));
      expect(y, 0);
      expect(m, 0);
    });

    testWidgets('choosing a month reports the pair and closes', (tester) async {
      int y = 0, m = 0;
      await open(tester, year: 1405, month: 7, onSelected: (a, b) {
        y = a;
        m = b;
      });
      await tester.tap(find.text('مهر'));
      await tester.pumpAndSettle();

      expect(y, 1405);
      expect(m, 7);
      expect(find.text('پرش سریع به تاریخ'), findsNothing);
    });

    testWidgets('the close button dismisses without choosing', (tester) async {
      int y = 0, m = 0;
      await open(tester, year: 1405, month: 7, onSelected: (a, b) {
        y = a;
        m = b;
      });
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('پرش سریع به تاریخ'), findsNothing);
      expect(y, 0);
      expect(m, 0);
    });
  });
}
