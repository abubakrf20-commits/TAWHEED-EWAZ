import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/widgets/session_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSection(
    WidgetTester tester, {
    List<PomodoroSessionTableData> history = const [],
    Object? error,
    bool loading = false,
    int todayMinutes = 0,
    VoidCallback? onRetry,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SessionHistorySection(
              todayMinutes: todayMinutes,
              history: history,
              weekTotals: List<int>.filled(7, 0),
              loading: loading,
              error: error,
              onRetry: onRetry,
              onClearHistory: () {},
            ),
          ),
        ),
      ),
    );
    // An indeterminate spinner never settles, and the retrying case renders one.
    if (loading) {
      await tester.pump(const Duration(milliseconds: 50));
    } else {
      await tester.pumpAndSettle();
    }
  }

  PomodoroSessionTableData session({int minutes = 30}) {
    return PomodoroSessionTableData(
      id: 1,
      startedAt: DateTime.now(),
      durationMinutes: minutes,
      mode: 'classic',
      focusType: 'قرآن',
    );
  }

  testWidgets('a failed first read names the failure and claims no empty history',
      (tester) async {
    await pumpSection(
      tester,
      error: StateError('history offline'),
      onRetry: () {},
    );

    expect(find.byKey(const ValueKey('failure_pomodoro_history')),
        findsOneWidget);
    expect(find.text('بارگذاری تاریخچهٔ جلسات ممکن نشد'), findsOneWidget);
    expect(find.text(FailureView.retryLabel), findsOneWidget);
    // The exact dishonest state this guards: a failed read rendered as
    // «no sessions yet» plus a zero today.
    expect(find.textContaining('هنوز جلسه‌ای ثبت نشده'), findsNothing);
    expect(find.text('0 دقیقه'), findsNothing);
    expect(find.text('تاریخچهٔ جلسات'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the rows of the last good read',
      (tester) async {
    await pumpSection(
      tester,
      history: [session()],
      todayMinutes: 30,
      error: StateError('history offline'),
      onRetry: () {},
    );

    // Title and the stale-data disclosure are now separate lines of the same
    // panel, so the reader gets the claim and its caveat at different weights.
    expect(find.text('به‌روزرسانی تاریخچه ممکن نشد'), findsOneWidget);
    expect(
      find.text('جلسه‌های نمایش‌داده‌شده از آخرین بارگذاری‌اند.'),
      findsOneWidget,
    );
    expect(find.textContaining('30 دقیقه'), findsOneWidget);
    // The summary cards stay suppressed: they would print a zero the read
    // never proved. (Exact match: «30 دقیقه» in the row above contains it.)
    expect(find.text('0 دقیقه'), findsNothing);
    // The rows are still real, so the clear action stays available.
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('while a retry runs the button becomes a spinner',
      (tester) async {
    await pumpSection(
      tester,
      error: StateError('history offline'),
      loading: true,
      onRetry: () {},
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(FailureView.retryLabel), findsNothing);
    expect(find.text('بارگذاری تاریخچهٔ جلسات ممکن نشد'), findsOneWidget);
  });

  testWidgets('a healthy empty history states its zero and offers no retry',
      (tester) async {
    await pumpSection(tester);

    expect(find.text('0 دقیقه'), findsOneWidget);
    expect(
      find.text('هنوز جلسه‌ای ثبت نشده — اولین جلسهٔ تمرکز شما اینجا می‌آید.'),
      findsOneWidget,
    );
    expect(find.text(FailureView.retryLabel), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('the retry button reports the tap', (tester) async {
    var taps = 0;
    await pumpSection(
      tester,
      error: StateError('history offline'),
      onRetry: () => taps++,
    );

    await tester.tap(find.text(FailureView.retryLabel));
    expect(taps, 1);
  });
}
