import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/mushaf/mushaf_backgrounds.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_color_sheets.dart';

void main() {
  testWidgets('a long sheet keeps its title under the status bar',
      (tester) async {
    // Mirrors the download page: a pinned header (handle + title) ABOVE the
    // scrolling body. The old sheet had them as the first children of the
    // scroll, so a long sheet scrolled its title up under the status bar.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              // Bounded like a modal route; a Scaffold body would hand the
              // column the whole screen.
              child: SizedBox(
                height: 400,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: .25),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'دانلود برای استفادهٔ آفلاین',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                        Expanded(
                          child: MushafSheetScroll(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < 40; i++)
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 12),
                                    child: Text('سطر'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final title = find.text('دانلود برای استفادهٔ آفلاین');
    expect(title, findsOneWidget);

    // Must start below the status-bar inset, never under it.
    final inset = tester.getTopLeft(find.byType(SafeArea)).dy;
    final titleTop = tester.getTopLeft(title).dy;
    expect(titleTop, greaterThanOrEqualTo(inset));

    // Scrolling the body must not drag the title up into the status bar.
    await tester.drag(find.byType(MushafSheetScroll), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dy, greaterThanOrEqualTo(inset));
  });

  test('mushaf palettes expose the tokens the reader chrome relies on', () {
    expect(kMushafBackgrounds, isNotEmpty);
    for (final p in kMushafBackgrounds) {
      expect(p.name, isNotEmpty);
      expect(p.color, isA<Color>());
    }
    // Day and night papers both exist, so the reader can offer «شب».
    expect(kMushafBackgrounds.any((p) => p.isNight), isTrue);
    expect(kMushafRecitationColors, isNotEmpty);
  });
}
