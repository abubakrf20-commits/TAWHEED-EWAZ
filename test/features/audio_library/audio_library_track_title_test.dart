import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';
import 'package:tawheeed/features/audio_library/presentation/screens/audio_library_screen.dart';

/// Track titles in the audio library must never be cut silently: a long
/// title shows one line with the shared «بیشتر» affordance and opens fully
/// on tap, while short titles render exactly as before (no toggle). The
/// cards keep their compact size — nothing is inflated to fit the text.
AudioLibraryManifest _manifest(String longTitle) => AudioLibraryManifest(
      version: 1,
      categories: [
        AudioCategory(
          id: 'misc',
          tracks: [
            const AudioTrack(
              id: 'short-01',
              title: 'درس کوتاه',
              file: 'short.opus',
              sizeBytes: 1000,
            ),
            AudioTrack(
              id: 'long-01',
              title: longTitle,
              file: 'long.opus',
              sizeBytes: 1000,
            ),
          ],
        ),
      ],
    );

void main() {
  // A real library title of the shape that used to vanish behind «…».
  const longTitle =
      'مسابقه در انجام عبادات، تربیت ایمانی، قرآن در ترتیب نزول سوره‌ها (شیخ ضیایی)';

  Future<void> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AudioLibraryScreen(loader: () async => _manifest(longTitle)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a long title collapses to one line with a «بیشتر» toggle',
      (tester) async {
    await pumpScreen(tester);

    final title = tester.widget<Text>(find.text(longTitle));
    expect(title.maxLines, 1,
        reason: 'the collapsed card keeps its one-line title');
    expect(find.text('بیشتر'), findsOneWidget,
        reason: 'only the overflowing title offers expansion');
  });

  testWidgets('tapping «بیشتر» opens the full title, «بستن» closes it',
      (tester) async {
    await pumpScreen(tester);

    await tester.ensureVisible(find.text('بیشتر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بیشتر'));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text(longTitle)).maxLines, isNull,
        reason: 'the expanded title is fully readable');
    expect(find.text('بستن'), findsOneWidget);

    await tester.tap(find.text('بستن'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(longTitle)).maxLines, 1);
    expect(find.text('بیشتر'), findsOneWidget);
  });

  testWidgets('a short title renders plainly with no toggle', (tester) async {
    await pumpScreen(tester);

    final title = tester.widget<Text>(find.text('درس کوتاه'));
    expect(title.maxLines, isNull,
        reason: 'short titles render as a plain Text, untouched');
  });
}
