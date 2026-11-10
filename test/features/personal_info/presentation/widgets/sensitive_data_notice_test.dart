import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/presentation/widgets/sensitive_data_notice.dart';

void main() {
  Future<void> pumpNotice(
    WidgetTester tester, {
    required Brightness brightness,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          fontFamily: AppTheme.fontFamily,
          extensions: [
            TimeThemeKit(
              brightness == Brightness.dark
                  ? AppPalettes.goldDark
                  : AppPalettes.goldLight,
            ),
          ],
        ),
        home: const Scaffold(body: SensitiveDataNotice()),
      ),
    );
    // MaterialApp animates theme swaps through AnimatedTheme; the first frame
    // still reports the outgoing brightness. Settle before reading colours.
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('warns against banking codes in both themes', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpNotice(tester, brightness: brightness);
      expect(
        find.text('اطلاعات حساس را در این بخش ذخیره نکنید'),
        findsOneWidget,
      );
      expect(find.textContaining('رمز دوم پویا'), findsOneWidget);
      expect(find.textContaining('CVV2'), findsOneWidget);
      // The encryption promise stays honest: the vault IS encrypted, the
      // warning only narrows what belongs in it.
      expect(find.textContaining('رمزنگاری می‌شود'), findsOneWidget);
    }
  });

  testWidgets('paints flat — warning tint, hairline border, no shadow',
      (tester) async {
    await pumpNotice(tester, brightness: Brightness.light);
    final decoration = tester
        .widget<Container>(find.byType(Container))
        .decoration! as BoxDecoration;
    expect(decoration.color, AppTheme.lightWarning.withValues(alpha: 0.08));
    expect(decoration.boxShadow, isNull);
    final border = decoration.border! as Border;
    expect(border.top.color, AppTheme.lightWarning.withValues(alpha: 0.3));
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    await pumpNotice(tester, brightness: Brightness.dark);
    final darkDecoration = tester
        .widget<Container>(find.byType(Container))
        .decoration! as BoxDecoration;
    expect(darkDecoration.color, AppTheme.darkWarning.withValues(alpha: 0.08));
  });

  test('the dashboard renders it under the security banner', () {
    // A source-level placement lock: the notice is a safety promise on the
    // page, so it must stay above the sections a user can scroll into — not
    // buried under the expiry card or inside the credential screen.
    final source = File(
      'lib/features/personal_info/presentation/screens/personal_info_screen.dart',
    ).readAsStringSync();
    final banner = source.indexOf('_SecurityBanner(');
    final notice = source.indexOf('const SensitiveDataNotice()');
    final expiry = source.indexOf('// Expiry countdowns');
    expect(banner, isNonNegative);
    expect(notice, greaterThan(banner));
    expect(expiry, greaterThan(notice));
  });
}
