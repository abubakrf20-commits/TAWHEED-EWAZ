import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/search/services/content_hit.dart';
import 'package:tawheeed/features/search/services/content_targets.dart';
import 'package:tawheeed/features/search/services/more_content_search.dart';
import 'package:tawheeed/features/settings/presentation/more/more_registry.dart'
    show moreItemById;
import 'package:tawheeed/shared/utils/arabic_search.dart'
    show normalizeSearchKey;

/// A source over injected text: the matching contract, without a database, a
/// provider or an asset behind it.
class _FakeSource extends MoreContentSource {
  _FakeSource(super.itemId, this.text);

  final List<ContentPiece> text;

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) async => text;
}

class _BrokenSource extends MoreContentSource {
  _BrokenSource() : super('broken');

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) async =>
      throw StateError('no content');
}

/// The کتابخانه source is deferred — expensive because it decompresses and
/// paginates whole books — so the page runs it in a second wave.
class _DeferredFakeSource extends MoreContentSource {
  _DeferredFakeSource(super.itemId, this.text);

  final List<ContentPiece> text;
  int calls = 0;

  @override
  bool get isDeferred => true;

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) async {
    calls++;
    return text;
  }
}

/// A standalone hadith database (ریاض الصالحین, صحیح الترغیب) over injected
/// chapter/hadith rows, so the target it builds can be judged without a
/// downloaded file behind it.
class _FakeHadithSource extends StandaloneHadithSource {
  _FakeHadithSource(
    super.itemId, {
    required this.chapterRows,
    required this.hadithRows,
    this.printedIndex,
  });

  final List<Map<String, dynamic>> chapterRows;
  final List<Map<String, dynamic>> hadithRows;

  /// The edition's own number rule, when the printed number is not the stored
  /// one — ریاض keeps it in a label table, so the fake can too.
  final Map<int, (num, int)>? printedIndex;

  @override
  Future<bool> get hasContent async => true;

  @override
  Future<List<Map<String, dynamic>>> chapters() async => chapterRows;

  @override
  Future<List<Map<String, dynamic>>> rows(String rawQuery, int limit) async =>
      hadithRows.take(limit).toList();

  @override
  Future<({int? bookId, num chapterIndex, int stored})?> locateNumber(
      int number) async {
    final pinned = printedIndex?[number];
    if (pinned != null) {
      return (bookId: null, chapterIndex: pinned.$1, stored: pinned.$2);
    }
    for (final r in hadithRows) {
      if ((r['hadith_number'] as num?)?.toInt() != number) continue;
      final chapterId = (r['chapter_id'] as num?)?.toInt();
      for (final c in chapterRows) {
        if ((c['id'] as num?)?.toInt() != chapterId) continue;
        final index = c['chapter_index'];
        if (index is num) {
          return (bookId: null, chapterIndex: index, stored: number);
        }
      }
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> entriesOfChapter(
    num chapterIndex, {
    int? bookId,
  }) async {
    final ids = {
      for (final c in chapterRows)
        if (c['chapter_index'] == chapterIndex) (c['id'] as num?)?.toInt(),
    };
    return [
      for (final r in hadithRows)
        if (ids.contains((r['chapter_id'] as num?)?.toInt())) r,
    ];
  }
}

/// True when every surrogate in [s] is part of a pair.
bool _hasNoLoneSurrogate(String s) {
  for (var i = 0; i < s.length; i++) {
    final u = s.codeUnitAt(i);
    if (u >= 0xD800 && u <= 0xDBFF) {
      if (i + 1 >= s.length) return false;
      final next = s.codeUnitAt(i + 1);
      if (next < 0xDC00 || next > 0xDFFF) return false;
      i++;
    } else if (u >= 0xDC00 && u <= 0xDFFF) {
      return false;
    }
  }
  return true;
}

String key(String input) => normalizeSearchKey(input);

void main() {
  // The bundled-guide group really reads `assets/content/*.json`, which the
  // test binding serves from `build/unit_test_assets`.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('snippetAround', () {
    test('centers the window on the match and marks both ends', () {
      final body = '${'الف ' * 40}نکتهٔ کلیدی ${'پایان ' * 40}';
      final s = snippetAround(body, 'نکتهٔ کلیدی', max: 90);
      expect(s, contains('نکتهٔ کلیدی'));
      expect(s, startsWith('…'));
      expect(s, endsWith('…'));
      expect(s.length, lessThanOrEqualTo(92));
    });

    test('falls back to the head when only the folded form matches', () {
      // The mushaf-style text carries harakat a typed query does not, so the
      // raw indexOf finds nothing and the excerpt opens at its head instead.
      final s = snippetAround(
          'أَعُوذُ بِاللهِ مِنَ الشَّيْطَانِ الرَّجِيمِ', 'اعوذ بالله',
          max: 30);
      expect(s, startsWith('أَعُوذُ'));
    });

    test('returns a short body untouched', () {
      expect(snippetAround('کوتاه است', 'کوتاه'), 'کوتاه است');
    });

    test('cuts a window off without splitting a surrogate pair', () {
      final body = '${'a' * 99}\u{1F600}${'b' * 60}';
      final s = snippetAround(body, '', max: 100);
      expect(_hasNoLoneSurrogate(s), isTrue);
      expect(s, endsWith('…'));
    });
  });

  group('walkContentNode', () {
    test('one piece per object, headings inherited by nested blocks', () {
      final out = <ContentPiece>[];
      walkContentNode({
        'title': 'غسل',
        'body': 'متن غسل',
        'subsections': [
          {'title': 'ارکان', 'body': 'متن ارکان'},
        ],
      }, '', out);
      expect(out.map((p) => p.title), ['غسل', 'ارکان']);
      expect(out[0].body, 'متن غسل');
      expect(out[1].body, 'متن ارکان');
    });

    test('ignores keys that name nothing readable', () {
      final out = <ContentPiece>[];
      walkContentNode({
        'id': 7,
        'icon': 'water_drop',
        'step': 3,
        'title': 'تیمم',
        'note': 'با خاک پاک',
      }, '', out);
      expect(out.length, 1);
      expect(out.single.title, 'تیمم');
      expect(out.single.body, 'با خاک پاک');
    });

    test('a list of bare strings becomes one piece per string', () {
      final out = <ContentPiece>[];
      walkContentNode({'title': 'سنن', 'items': ['اول', 'دوم']}, '', out);
      expect(out.map((p) => p.body), ['اول', 'دوم']);
      expect(out.every((p) => p.title == 'سنن'), isTrue);
    });

    test('empty and non-text nodes produce nothing', () {
      final out = <ContentPiece>[];
      walkContentNode({'a': '', 'b': 3, 'c': null, 'd': []}, 'عنوان', out);
      expect(out, isEmpty);
    });
  });

  group('content matching', () {
    test('uses the page\'s one normalization, so harakat and spacing vanish',
        () async {
      final source = _FakeSource('prayer', [
        const ContentPiece('تلبث', 'أَعُوذُ بِاللهِ مِنَ الشَّيْطَان'),
      ]);
      // A Persian keyboard, no diacritics, arbitrary spacing.
      final hits = await source.search(key('اعوذ  بالله'), 'اعوذ  بالله');
      expect(hits.single.itemId, 'prayer');
    });
  });

  group('MoreContentSource.search', () {
    test('caps at the limit and keeps the entity for deep links', () async {
      final marker = Object();
      final source = _FakeSource('zakat', [
        for (var i = 0; i < 10; i++)
          ContentPiece('عنوان $i', 'نصیب و سهم فقرا $i',
              entity: i == 4 ? marker : null),
      ]);
      final capped = await source.search(key('نصیب'), 'نصیب', limit: 2);
      expect(capped.length, 2);
      expect(capped.map((h) => h.title), ['عنوان 0', 'عنوان 1']);
      final withEntity = await source.search(key('فقرا 4'), 'فقرا 4', limit: 5);
      expect(withEntity.single.entity, same(marker));
    });

    test('a const source builds its text once, not per keystroke', () async {
      var builds = 0;
      final source = ConstSource('ruqyah', () {
        builds++;
        return const [ContentPiece('رقیه', 'آیهٔ الكرسي شفا است')];
      });
      await source.search(key('کرسي'), 'کرسي');
      await source.search(key('شفا'), 'شفا');
      expect(builds, 1);
    });

    test('a source with no text reports nothing', () async {
      expect(await _FakeSource('dua', const []).search(key('هرچیز'), 'هرچیز'),
          isEmpty);
    });
  });

  group('searchMoreContent', () {
    test('needs two characters before it searches anything', () async {
      var touched = 0;
      final source = ConstSource('purification', () {
        touched++;
        return const [ContentPiece('وضو', 'نیت')];
      });
      expect(
          await searchMoreContent(
              query: 'و', rawQuery: 'و', sources: [source]),
          isEmpty);
      expect(touched, 0);
    });

    test('one broken source cannot blank the other results', () async {
      final hits = await searchMoreContent(
        query: key('نصیب'),
        rawQuery: 'نصیب',
        sources: [
          _BrokenSource(),
          _FakeSource('zakat', [
            const ContentPiece('سهم', 'نصیب فقرا'),
          ]),
        ],
      );
      expect(hits.single.itemId, 'zakat');
    });

    test('respects the global limit', () async {
      final hits = await searchMoreContent(
        query: key('یکدو'),
        rawQuery: 'یکدو',
        perSource: 5,
        limit: 3,
        sources: [
          _FakeSource('hajj-umrah', [
            for (var i = 0; i < 8; i++) ContentPiece('ع', 'یکدو $i'),
          ]),
        ],
      );
      expect(hits.length, 3);
    });

    test('every shipped source names a section the page draws', () {
      for (final source in kMoreContentSources) {
        expect(moreItemById(source.itemId), isNotNull,
            reason: '${source.itemId} is not in the More registry');
      }
    });

    test('the locked و کاربردی sections are not indexed at all', () {
      final indexed = kMoreContentSources.map((s) => s.itemId).toSet();
      // A search result would leak text past the password screen guarding it.
      expect(indexed, isNot(contains('yaqeen')));
      // Private personal data stays out of a shared result list.
      expect(indexed, isNot(contains('personal-info')));
      expect(indexed, isNot(contains('period')));
      // Network-only sections cannot be searched offline.
      expect(indexed, isNot(contains('dorar-hadith')));
      expect(indexed, isNot(contains('audio-lectures')));
    });

    test('کتابخانه and صحیح الترغیب are reachable from the field', () {
      // The two sections a user reported as unsearchable: a downloaded book is
      // scanned off the isolate, and the standalone hadith DB answers through
      // its own engine.
      final ids = kMoreContentSources.map((s) => s.itemId).toSet();
      expect(ids, containsAll(<String>['ketabkhaneh', 'taraghib']));
    });

    test('the fast wave leaves the deferred کتابخانه scan for the second pass',
        () async {
      final fast = _FakeSource('zakat', [const ContentPiece('سهم', 'نصیب فقرا')]);
      final deferred = _DeferredFakeSource('ketabkhaneh', [
        const ContentPiece('کتاب', 'نصیب فقرا در کتاب'),
      ]);

      final first = await searchMoreContent(
        query: key('نصیب'),
        rawQuery: 'نصیب',
        sources: [fast, deferred],
        phase: MoreSearchPhase.fast,
      );
      expect(first.map((h) => h.itemId), ['zakat']);
      expect(deferred.calls, 0, reason: 'the expensive scan waits its turn');

      final second = await searchMoreContent(
        query: key('نصیب'),
        rawQuery: 'نصیب',
        sources: [fast, deferred],
        phase: MoreSearchPhase.deferred,
      );
      expect(second.map((h) => h.itemId), ['ketabkhaneh']);
      expect(deferred.calls, 1);
    });
  });

  group('the standalone hadith sections carry a position', () {
    test('صحیح الترغیب: the hit names the chapter and the stored entry number',
        () async {
      final source = _FakeHadithSource(
        'taraghib',
        chapterRows: [
          {'id': 7, 'chapter_index': 3, 'name_arabic': 'باب الصلاة'},
        ],
        hadithRows: [
          {
            'chapter_id': 7,
            'hadith_number': 412,
            'arabic': 'مَنْ صَلَّى الصَّلَوَاتِ الْخَمْسَ',
          },
        ],
      );

      final hit = (await source.search(key('الصلوات'), 'الصلوات')).single;

      expect(hit.itemId, 'taraghib');
      expect(hit.title, 'باب الصلاة');
      // The paint target is the row's own literal — harakat and all — not the
      // bare query the database was searched with.
      expect(hit.highlightQuery, 'الصَّلَوَاتِ');
      final target = hit.target! as HadithChapterTarget;
      expect(target.itemId, 'taraghib');
      expect(target.chapterIndex, 3);
      expect(target.chapterTitle, 'باب الصلاة');
      expect(target.hadithNumber, 412);
    });

    test('a Persian-typed query still projects the Arabic literal', () async {
      // «کتاب» typed on a Persian keyboard matches the Arabic «كتاب» after the
      // search key folds ک→ك; the literal handed to the screen is the original.
      final source = _FakeHadithSource(
        'riyad',
        chapterRows: [
          {'id': 1, 'chapter_index': 1, 'name_arabic': 'باب العلم'},
        ],
        hadithRows: [
          {'chapter_id': 1, 'hadith_number': 9, 'arabic': 'كِتَابُ الصَّلَاةِ'},
        ],
      );

      final hit = (await source.search(key('کتاب'), 'کتاب')).single;
      expect(hit.highlightQuery, 'كِتَابُ');
    });

    test('a row outside any known chapter keeps no position', () async {
      final source = _FakeHadithSource(
        'riyad',
        chapterRows: const [],
        hadithRows: [
          {'chapter_id': 99, 'hadith_number': 1, 'arabic': 'نصیب فقرا'},
        ],
      );

      final hit = (await source.search(key('نصیب'), 'نصیب')).single;
      expect(hit.target, isNull);
      expect(hit.title, '');
    });
  });

  group('searching by hadith number', () {
    test('only a whole positive number is a number query', () {
      expect(moreContentNumberQuery('412'), 412);
      expect(moreContentNumberQuery('5'), 5);
      // No edition prints entry 0, and a sign is not a digit run.
      expect(moreContentNumberQuery('0'), isNull);
      expect(moreContentNumberQuery('-3'), isNull);
      expect(moreContentNumberQuery('ab'), isNull);
      expect(moreContentNumberQuery(''), isNull);

      // The page's spinner and this engine share one gate: a single digit is
      // live while a single letter is not.
      expect(moreContentQueryIsSearchable('5'), isTrue);
      expect(moreContentQueryIsSearchable('0'), isFalse);
      expect(moreContentQueryIsSearchable('a'), isFalse);
      expect(moreContentQueryIsSearchable('ab'), isTrue);
    });

    test('the title names the number in Latin digits beside its chapter', () {
      final withChapter = hadithNumberTitle(412, 'باب الصلاة');
      expect(withChapter.contains('412'), isTrue);
      expect(withChapter.contains('۴۱۲'), isFalse);
      // The digits are LTR-isolated, or bidi reorders them inside the Persian.
      expect(withChapter.contains('\u2066'), isTrue);
      expect(withChapter, endsWith(' · باب الصلاة'));
      expect(hadithNumberTitle(7, ''), isNot(contains('·')));
    });

    test('a Persian keypad number jump to the entry that carries it', () async {
      final source = _FakeHadithSource(
        'taraghib',
        chapterRows: [
          {'id': 7, 'chapter_index': 3, 'name_arabic': 'باب الصلاة'},
        ],
        hadithRows: [
          {
            'chapter_id': 7,
            'hadith_number': 412,
            'arabic': 'مَنْ صَلَّى الصَّلَوَاتِ الْخَمْسَ',
          },
        ],
      );

      // The page folds ۴۱۲ to 412 before any source sees it.
      final hits = await searchMoreContent(
        query: key('۴۱۲'),
        rawQuery: '۴۱۲',
        sources: [source],
      );

      final hit = hits.single;
      expect(hit.itemId, 'taraghib');
      expect(hit.title, hadithNumberTitle(412, 'باب الصلاة'));
      // The query's digits are not a literal inside the Arabic text, so the
      // destination paints nothing and shows its own «حدیث N» badge instead.
      expect(hit.highlightQuery, '');
      expect(hit.snippet, 'مَنْ صَلَّى الصَّلَوَاتِ الْخَمْسَ');
      final target = hit.target! as HadithChapterTarget;
      expect(target.chapterIndex, 3);
      expect(target.chapterTitle, 'باب الصلاة');
      expect(target.hadithNumber, 412);
    });

    test('ریاض answers a printed number with the stored row number', () async {
      // ریاض keeps its intros in `hadith_number`, so the printed 12 lives in a
      // label table and points at stored row 40 — the destination's own badge.
      final source = _FakeHadithSource(
        'riyad',
        chapterRows: [
          {'id': 1, 'chapter_index': 2, 'name_arabic': 'باب الإخلاص'},
        ],
        hadithRows: [
          {'chapter_id': 1, 'hadith_number': 40, 'arabic': 'نصیب التوحيد'},
        ],
        printedIndex: {12: (2, 40)},
      );

      final hit = (await source.searchByNumber(12)).single;
      expect(hit.title, hadithNumberTitle(12, 'باب الإخلاص'));
      expect((hit.target! as HadithChapterTarget).hadithNumber, 40);
    });

    test('a single digit asks numbers and never text', () async {
      var touched = 0;
      final textOnly = ConstSource('purification', () {
        touched++;
        return const [ContentPiece('وضو', '۵ بار')];
      });
      final hadith = _FakeHadithSource(
        'taraghib',
        chapterRows: [
          {'id': 1, 'chapter_index': 1, 'name_arabic': 'باب العلم'},
        ],
        hadithRows: [
          {'chapter_id': 1, 'hadith_number': 5, 'arabic': 'خمس'},
        ],
      );

      final hits = await searchMoreContent(
        query: key('5'),
        rawQuery: '5',
        sources: [textOnly, hadith],
      );
      expect(hits.single.itemId, 'taraghib');
      expect(touched, 0, reason: 'one character is not a text question');

      // With no number index answering, a single digit stays empty rather than
      // turning into a one-letter text scan.
      expect(
        await searchMoreContent(
            query: key('5'), rawQuery: '5', sources: [textOnly]),
        isEmpty,
      );
      expect(touched, 0);
    });

    test('a numeric query still reaches text-only sections', () async {
      final hits = await searchMoreContent(
        query: key('12'),
        rawQuery: '12',
        sources: [
          _FakeSource('zakat', [
            const ContentPiece('سهم', 'سهم 12 از نصاب'),
          ]),
        ],
      );
      expect(hits.single.itemId, 'zakat');
      expect(hits.single.highlightQuery, '12');
    });

    test('a number the edition does not carry falls through to text', () async {
      final source = _FakeHadithSource(
        'taraghib',
        chapterRows: [
          {'id': 1, 'chapter_index': 1, 'name_arabic': 'باب العلم'},
        ],
        hadithRows: [
          {'chapter_id': 1, 'hadith_number': 7, 'arabic': 'باب 999 من العلم'},
        ],
      );

      final hit = (await searchMoreContent(
        query: key('999'),
        rawQuery: '999',
        sources: [source],
      ))
          .single;
      // The row it found by TEXT is entry 7, not 999 — the target must say so
      // or the destination would jump to a passage that does not exist.
      expect((hit.target! as HadithChapterTarget).hadithNumber, 7);
      expect(hit.highlightQuery, '999');
    });

    test('the entry carrying the number wins over one that mentions it',
        () async {
      final source = _FakeHadithSource(
        'taraghib',
        chapterRows: [
          {'id': 1, 'chapter_index': 1, 'name_arabic': 'باب العلم'},
        ],
        hadithRows: [
          {'chapter_id': 1, 'hadith_number': 12, 'arabic': 'حديث اثنا عشر'},
          {'chapter_id': 1, 'hadith_number': 3, 'arabic': 'ذكر الرقم 12'},
        ],
      );

      final hits = await searchMoreContent(
        query: key('12'),
        rawQuery: '12',
        sources: [source],
      );
      expect(hits, hasLength(1));
      expect((hits.single.target! as HadithChapterTarget).hadithNumber, 12);
    });
  });

  group('scanBookPages (کتابخانه)', () {
    Future<String> bookOnDisk(Map<String, Object?> json) async {
      final dir = await Directory.systemTemp.createTemp('more_book_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/book_b1.json.gz');
      await file.writeAsBytes(gzip.encode(utf8.encode(jsonEncode(json))));
      return file.path;
    }

    test('a page hit names the book, the page and its printed number',
        () async {
      final path = await bookOnDisk({
        'content': [
          'عنوان مقدمه',
          '(1/3)صفحهٔ نخست بدون واژهٔ جستجو',
          '(2/3)در این صفحه واژهٔ چرت آمده است',
          '(3/3)پایان کتاب',
        ],
      });

      final hits = scanBookPages([
        {'id': 'b1', 'title': 'کتاب آزمون', 'path': path},
      ], 'چرت', 5);

      expect(hits, hasLength(1));
      expect(hits.single['bookId'], 'b1');
      expect(hits.single['bookTitle'], 'کتاب آزمون');
      // The page the reader must open is the one the paginator produced from
      // the same `(N/M)` markers — the search and the reader share it.
      expect(hits.single['pageIndex'], 2);
      expect(hits.single['printNo'], 2);
      expect(hits.single['matched'], 'چرت');
    });

    test('a missing file yields nothing instead of throwing', () async {
      expect(
        scanBookPages([
          {'id': 'gone', 'title': '', 'path': '/nowhere/book.json.gz'},
        ], 'چرت', 5),
        isEmpty,
      );
    });
  });

  group('the bundled guides really are searchable', () {
    test('طهارت: a phrase only found inside a paragraph', () async {
      final source =
          JsonGuideSource('purification', 'assets/content/taharah.json');
      final hits = await source.search(key('چرت زدن'), 'چرت زدن');
      expect(hits, isNotEmpty);
      expect(hits.first.title, contains('خواب عمیق'));
      expect(hits.first.snippet, contains('چرت'));
    });

    test('علوم اسلامی: a heading match survives the biggest asset', () async {
      final source = JsonGuideSource('sciences', 'assets/content/sciences.json');
      final hits = await source.search(key('اسماء و صفات'), 'اسماء و صفات');
      expect(hits, isNotEmpty);
      expect(hits.first.itemId, 'sciences');
    });

    test('a guide that is not on disk yields nothing instead of throwing',
        () async {
      final source =
          JsonGuideSource('purification', 'assets/content/does_not_exist.json');
      expect(await source.search(key('هرچه'), 'هرچه'), isEmpty);
    });
  });
}
