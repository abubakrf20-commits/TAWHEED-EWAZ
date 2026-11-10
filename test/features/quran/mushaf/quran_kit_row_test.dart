import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/mushaf/quran_kit_row.dart';

/// The reader's one list row (report §6.6). These tests pin its states —
/// identity (icon / leading), badge, trailing, selected, onLongPress, the rich
/// subtitle used by search results — plus the two invariants the constructor
/// asserts and the single semantics node from §7.8.
void main() {
  const palette = MushafPalette.light;

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: child),
      );

  testWidgets('renders title, subtitle, badge and trailing', (tester) async {
    await tester.pumpWidget(host(const QuranKitRow(
      palette: palette,
      icon: Icons.person,
      title: 'حفص عن عاصم',
      subtitle: 'قاری',
      badge: Text('جدید'),
      trailing: Icon(Icons.check),
    )));

    expect(find.text('حفص عن عاصم'), findsOneWidget);
    expect(find.text('قاری'), findsOneWidget);
    expect(find.text('جدید'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('a number tile replaces the icon', (tester) async {
    await tester.pumpWidget(host(QuranKitRow(
      palette: palette,
      leading: QuranKitNumberTile(accent: palette.accent, label: '١٢٣'),
      title: 'الناس',
    )));

    expect(find.text('١٢٣'), findsOneWidget);
    expect(find.text('الناس'), findsOneWidget);
  });

  testWidgets('a selected row bolds its title', (tester) async {
    await tester.pumpWidget(host(const QuranKitRow(
      palette: palette,
      icon: Icons.speed,
      title: '2x',
      selected: true,
    )));

    final title = tester.widget<Text>(find.text('2x'));
    expect(title.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('onLongPress reaches the row', (tester) async {
    var longPressed = 0;
    await tester.pumpWidget(host(QuranKitRow(
      palette: palette,
      icon: Icons.speed,
      title: 'سرعت پخش',
      onTap: () {},
      onLongPress: () => longPressed++,
    )));

    await tester.longPress(find.byType(QuranKitRow));
    expect(longPressed, 1);
  });

  testWidgets('subtitleRich wins over subtitle and keeps its mark',
      (tester) async {
    await tester.pumpWidget(host(const QuranKitRow(
      palette: palette,
      icon: Icons.menu_book,
      title: 'بقره',
      subtitle: 'ignored',
      subtitleRich: TextSpan(
        children: [
          TextSpan(text: 'قل هو '),
          TextSpan(
            text: 'الله',
            style: TextStyle(backgroundColor: Color(0x291F7A63)),
          ),
        ],
      ),
    )));

    expect(find.text('ignored'), findsNothing);
    expect(find.textContaining('قل هو', findRichText: true), findsOneWidget);
  });

  testWidgets('one semantics node announces title — subtitle', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const QuranKitRow(
      palette: palette,
      icon: Icons.person,
      title: 'قاری',
      subtitle: 'حفص عن عاصم',
      onTap: _noop,
    )));

    expect(find.bySemanticsLabel('قاری — حفص عن عاصم'), findsOneWidget);
    handle.dispose();
  });

  test('exactly one identity is required', () {
    expect(
      () => QuranKitRow(palette: palette, title: 'x'),
      throwsAssertionError,
    );
    expect(
      () => QuranKitRow(
        palette: palette,
        title: 'x',
        icon: Icons.person,
        leading: const SizedBox.shrink(),
      ),
      throwsAssertionError,
    );
  });
}

void _noop() {}
