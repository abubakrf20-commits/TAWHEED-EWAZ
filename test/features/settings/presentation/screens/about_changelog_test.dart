import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/presentation/screens/about_screen.dart';

/// The About «نسخه و تغییرات» section — a row that opens the owner's release
  /// notes (`assets/changelog.md`) in a dialog. The asset is read only on tap,
  /// so the page itself never touches the bundle while rendering. The notes are
  /// what the app owner writes there — NOT a copy of the developer changelog —
  /// so an unwritten file opens the dialog with a polite empty state.
  Widget _app(ThemeData theme) {
    return MaterialApp(
      theme: theme,
      home: const Directionality(
          textDirection: TextDirection.rtl, child: AboutScreen()),
    );
  }

  void main() {
    testWidgets('the changelog row opens the release notes dialog',
        (tester) async {
      AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
      await tester.pumpWidget(_app(AppTheme.light));
      await tester.pumpAndSettle();

      // The row sits under the description card, near the top of the page.
      expect(find.text('تغییرات نسخه‌ها'), findsOneWidget);

      await tester.tap(find.text('تغییرات نسخه‌ها'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      // The dialog carries the same title, and renders the owner's notes from
      // the asset. Anchor on the document's own first version heading so the
      // assertion does not freeze a wording the owner may edit.
      expect(
        find.descendant(of: dialog, matching: find.text('تغییرات نسخه‌ها')),
        findsOneWidget,
      );
      final notes = await rootBundle.loadString(kChangelogAsset);
      expect(notes.trim(), isNotEmpty);
      final firstHeading = notes
          .split('\n')
          .firstWhere((line) => line.startsWith('## '))
          .substring(3)
          .trim();
      expect(
        find.descendant(of: dialog, matching: find.text(firstHeading)),
        findsOneWidget,
      );
      expect(
          find.descendant(
              of: dialog, matching: find.text('هنوز متنی ثبت نشده است.')),
          findsNothing);

      // The owner appends releases at the end of the asset (oldest →
      // newest); the dialog must show them newest-first.
      final headings = notes
          .split('\n')
          .where((line) => line.startsWith('## '))
          .map((line) => line.substring(3).trim())
          .toList();
      expect(headings.length, greaterThan(1));
      final newest = headings.last;
      final oldest = headings.first;
      final newestDy = tester
          .getTopLeft(find.descendant(of: dialog, matching: find.text(newest)))
          .dy;
      final oldestDy = tester
          .getTopLeft(find.descendant(of: dialog, matching: find.text(oldest)))
          .dy;
      expect(newestDy, lessThan(oldestDy),
          reason: '«$newest» must sit above «$oldest»');

      await tester.tap(find.text('بستن'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }