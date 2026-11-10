import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/books/presentation/book_page_notes.dart';
import 'package:tawheeed/features/books/presentation/book_palette.dart';
import 'package:tawheeed/features/books/presentation/widgets/book_reader_page.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';

/// One baseline per paper the reader can pick.
///
/// The page is where the books feature lives or dies, and every one of its
/// parts (running head, hairline, paragraph rhythm, folio) is invisible to a
/// normal assertion once it drifts by a few pixels. These four record the
/// frame on each surface, so a change in the head or the bottom margin shows
/// up as a diff instead of shipping quietly.
///
/// The test binding loads no font, so glyphs render as boxes — these guard
/// palette and layout, not shaping. A device pass is still the only proof of
/// how the page reads.
void main() {
  const text =
      'الحمد لله رب العالمين، والصلاة والسلام على أشرف الأنبياء والمرسلين، '
      'أما بعد: فهذه صفحاتٌ من كتابٍ جمع أصول السنة النبوية.\n'
      'قال المؤلف رحمه الله: اعلم أن الله سبحانه وتعالى أوجب على العباد طاعته '
      'وطاعة رسوله، وجعل ذلك سبيل النجاة في الدنيا والآخرة.\n'
      'باب فضل العلم\n'
      'من سلك طريقاً يلتمس فيه علماً سهّل الله له به طريقاً إلى الجنة.';

  for (final paper in BookPalette.papers) {
    testWidgets('page on ${paper.key}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
            key: const ValueKey('golden-page'),
            child: Container(
              color: paper.surface,
              child: BookReaderPage(
                page: const BookPage(
                  index: 1,
                  text: text,
                  heading: 'باب فضل العلم',
                  printNo: 59,
                  printTotal: 458,
                ),
                bookTitle: 'معالم السنه النبویه',
                style: BookReaderPageStyle(
                  fontSize: 17,
                  lineHeight: 1.9,
                  fontFamily: 'Vazirmatn',
                  ink: paper.ink,
                  sideMargin: 26,
                ),
                highlights: const [],
                footnotes: const <BookPageNote>[],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('golden-page')),
        matchesGoldenFile('goldens/book_page_${paper.key}.png'),
      );
    });
  }
}
