import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_comparison_tab.dart';

/// Widget tests for the «تفاوت حجب میان مذاهب» card in the comparison tab.
///
/// The golden combination — grandfather + full brother — is proven at the
/// domain level (madhhab_comparison_test.dart): the brother inherits under
/// jumhur but is blocked under hanafi, so the engine reports a diff and the
/// card must surface it. Both tests drive the REAL tab: taps on the heir
/// rows and the compare button, then asserts on the rendered card.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await InheritanceContent.load();
  });

  Future<void> pumpTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: InheritanceComparisonTab()),
    ));
    await tester.pump();
  }

  /// Index of the heir row whose title is exactly [label]. The tab's rows
  /// are plain ListTiles and the tall viewport lays every one of them out,
  /// so the tile order matches the +/− button order used below.
  int rowIndex(WidgetTester tester, String label) {
    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    for (var i = 0; i < rows.length; i++) {
      final title = rows[i].title;
      if (title is Text && title.data == label) return i;
    }
    fail('heir row not found: $label');
  }

  Future<void> tapAdd(WidgetTester tester, String label,
      {int times = 1}) async {
    final index = rowIndex(tester, label);
    final buttons = find.byIcon(Icons.add_circle_outline);
    for (var i = 0; i < times; i++) {
      await tester.tap(buttons.at(index));
      await tester.pump();
    }
  }

  Future<void> tapRemove(WidgetTester tester, String label) async {
    final index = rowIndex(tester, label);
    await tester.tap(find.byIcon(Icons.remove_circle_outline).at(index));
    await tester.pump();
  }

  Future<void> compare(WidgetTester tester) async {
    // The header Text reads «مقایسه مذاهب» too — target the button itself.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'کارت حجب با وارث محجوب در حنفی رندر می‌شود و هر دو اردوگاه را نام می‌برد',
      (tester) async {
    await pumpTab(tester);

    // +1 پدربزرگ, +1 برادر شقیق (مادر و پدری) → brother blocked in hanafi.
    await tapAdd(tester, 'پدربزرگ پدری (پدرِ پدر)');
    await tapAdd(tester, 'برادر (پدری و مادری)');
    await compare(tester);

    // The card is rendered with its header.
    expect(find.text('تفاوت حجب میان مذاهب'), findsOneWidget);

    // Its line names BOTH camps: «ارث می‌برد در …» covers jumhur (and the
    // other non-hanafi fiqh madhhabs), «محجوب در …» names hanafi. Filtering
    // on the phrase avoids the heir row, whose title is the same label.
    final lines = find.textContaining('ارث می‌برد در');
    expect(lines, findsOneWidget);
    final text = tester.widget<Text>(lines).data!;
    expect(text, contains('برادر (پدری و مادری)'));
    expect(text, contains('جمهور'));
    expect(text, contains('محجوب در'));
    expect(text, contains('حنفی'));
  });

  testWidgets(
      'بدون اختلاف حجب کارتی رندر نمی‌شود و با تغییر وارثان دوباره ظاهر می‌شود',
      (tester) async {
    await pumpTab(tester);

    // همسر + پسر: both inherit everywhere → no blocking-diff card.
    await tapAdd(tester, 'همسر');
    await tapAdd(tester, 'پسر');
    await compare(tester);
    expect(find.text('تفاوت حجب میان مذاهب'), findsNothing);

    // Replace the son with a full brother — with the grandfather absent the
    // brother still inherits everywhere, so the card must STAY absent.
    await tapRemove(tester, 'پسر');
    await tapAdd(tester, 'برادر (پدری و مادری)');
    await compare(tester);
    expect(find.text('تفاوت حجب میان مذاهب'), findsNothing);

    // Add the grandfather: hanafi now blocks the brother → the card appears.
    await tapAdd(tester, 'پدربزرگ پدری (پدرِ پدر)');
    await compare(tester);
    expect(find.text('تفاوت حجب میان مذاهب'), findsOneWidget);
    expect(find.textContaining('ارث می‌برد در'), findsOneWidget);
  });
}
