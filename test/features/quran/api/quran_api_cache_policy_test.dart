import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/quran/api/quran_api_cache.dart';

/// The Quran API cache writes one JSON file per page, and one mushaf keys up to
/// 604 pages of a few hundred KB each — an unbounded cache grew by tens of
/// megabytes on a phone that only opens a handful of pages. [QuranApiCache]
/// therefore caps its JSON directory and evicts oldest-first on every write.
///
/// The selector is a pure function over plain records so the policy can be
/// proven without a real app-support directory; the wiring (the prune running
/// inside [QuranApiCache.setJson], the `.part` temporaries never becoming
/// candidates) is pinned by a source scan, the repo's idiom for an invariant no
/// unit test can observe.
String _withoutComments(String source) => source.split('\n').map((line) {
      final comment = line.indexOf('//');
      return comment < 0 ? line : line.substring(0, comment);
    }).join('\n');

({String path, int bytes, DateTime modified}) _entry(
  String path,
  int bytes,
  int day,
) =>
    (path: path, bytes: bytes, modified: DateTime(2026, 1, day));

void main() {
  group('eviction candidates', () {
    test('a directory under the cap loses nothing', () {
      final victims = QuranApiCache.evictionCandidatesFor(
        [_entry('a.json', 4, 1), _entry('b.json', 4, 2)],
        capBytes: 10,
      );

      expect(victims, isEmpty,
          reason: 'nothing may be deleted while the cache fits its cap');
    });

    test('a directory exactly at the cap loses nothing', () {
      final victims = QuranApiCache.evictionCandidatesFor(
        [_entry('a.json', 5, 1), _entry('b.json', 5, 2)],
        capBytes: 10,
      );

      expect(victims, isEmpty,
          reason: 'the cap is inclusive — only an overflow evicts');
    });

    test('the oldest entry goes first', () {
      final victims = QuranApiCache.evictionCandidatesFor(
        [
          // Deliberately out of order: the policy sorts, not the caller.
          _entry('newest.json', 4, 3),
          _entry('oldest.json', 4, 1),
          _entry('middle.json', 4, 2),
        ],
        capBytes: 10,
      );

      expect(victims, ['oldest.json'],
          reason: 'the oldest goes first — newest-first would evict the page '
              'the reader just opened and keep the one they left');
    });

    test('pruning stops the moment the total fits', () {
      final victims = QuranApiCache.evictionCandidatesFor(
        [
          _entry('a.json', 6, 1),
          _entry('b.json', 2, 2),
          _entry('c.json', 2, 3),
          _entry('d.json', 2, 4),
        ],
        capBytes: 10,
      );

      expect(victims, ['a.json'],
          reason: '12 B→10 B on the first victim: deleting more would throw '
              'away a page the reader could still reuse');
    });

    test('the entry just written is never a victim', () {
      final victims = QuranApiCache.evictionCandidatesFor(
        [
          _entry('a.json', 6, 1),
          _entry('just-written.json', 6, 2),
        ],
        capBytes: 10,
        keepPath: 'just-written.json',
      );

      expect(victims, ['a.json'],
          reason: 'the caller is about to read the entry it just wrote, so the '
              'older sibling pays for the overflow — the cap still makes '
              'progress instead of silently staying oversize');
      expect(victims, isNot(contains('just-written.json')),
          reason: 'never delete the entry the write that follows is about to '
              'read back');
    });

    test('the keep-path is skipped even when it is the oldest', () {
      final victims = QuranApiCache.evictionCandidatesFor(
        [
          _entry('just-written.json', 6, 1),
          _entry('newer.json', 6, 2),
        ],
        capBytes: 10,
        keepPath: 'just-written.json',
      );

      expect(victims, ['newer.json'],
          reason: 'keep-path wins over age — it is the one entry in the set '
              'that is guaranteed to be read back');
    });
  });

  group('the cache wiring', () {
    late String source;

    setUpAll(() {
      // flutter test runs from the repository root.
      source = _withoutComments(
        File('lib/features/quran/api/quran_api_cache.dart').readAsStringSync(),
      );
    });

    test('the cap is 16 MiB', () {
      expect(QuranApiCache.maxJsonBytes, 16 << 20,
          reason: 'the constant is the single source of the cap; a silent '
              'change here is a silent change in how much disk the reader '
              'spends on pages they may never reopen');
      expect(source, contains('maxJsonBytes'));
    });

    test('every JSON write prunes behind itself', () {
      final setJson = source.substring(
        source.indexOf('Future<void> setJson('),
        source.indexOf('static List<String> evictionCandidatesFor('),
      );
      expect(setJson, contains('_pruneIfOverCap(dir, keepPath: file.path)'),
          reason: 'the prune must run inside the write, keyed to the entry '
              'just written — a time-based prune never runs on a phone that '
              'only reads');
      expect(setJson, contains('AppLogger.warning'),
          reason: 'pruning is best-effort: a locked file or a full disk must '
              'never fail the network write that has already succeeded');
    });

    test('an in-flight .part temporary is never an eviction candidate', () {
      final prune = source.substring(
        source.indexOf('Future<void> _pruneIfOverCap('),
        source.indexOf('Future<void> _atomicWrite('),
      );
      expect(prune, contains("endsWith('.json')"),
          reason: '_atomicWrite stages <name>.part and renames it; deleting a '
              'sibling write\'s temporary would corrupt that write');
    });

    test('the prune evicts the oldest first', () {
      expect(source, contains('a.modified.compareTo(b.modified)'),
          reason: 'newest-first would evict the page the reader just opened '
              'and keep the one they left');
    });
  });
}
