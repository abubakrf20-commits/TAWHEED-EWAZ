import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_nav_policy.dart';

/// The mushaf pager had several independent writers (recitation follow,
/// translation follow, global search, bookmark restore, retry) plus the user's
/// own drag. Whichever wrote last won, so a swipe could be cancelled or
/// redirected mid-gesture. These lock the arbitration rules down without
/// needing a live pager, real fonts, or a real gesture.
void main() {
  const pageCount = 604;

  MushafNavPolicy idle({required int currentPage, int pendingNavPage = 0}) =>
      MushafNavPolicy(
        currentPage: currentPage,
        userDragging: false,
        pendingNavPage: pendingNavPage,
      );

  group('user gesture is never overridden', () {
    test('a follow is dropped while the user is dragging', () {
      const policy = MushafNavPolicy(
        currentPage: 10,
        userDragging: true,
      );
      expect(policy.userInControl, isTrue);
      expect(policy.allows(MushafNavSource.audioFollow, 11), isFalse);
    });

    test('a follow is dropped during the post-drag grace period', () {
      // A flick has just ended; the follow fires on the very next word tick.
      // Without the grace the pager would snap away from where the user
      // deliberately left it.
      const policy = MushafNavPolicy(
        currentPage: 10,
        userDragging: false,
        dragGraceActive: true,
      );
      expect(policy.userInControl, isTrue);
      expect(policy.allows(MushafNavSource.audioFollow, 11), isFalse);
    });

    test('an explicit jump still works during a drag', () {
      // A jump is the user asking for a specific page from a sheet, so it is
      // not a competing writer — only the *follow* has to stand down.
      const policy = MushafNavPolicy(
        currentPage: 10,
        userDragging: true,
      );
      expect(policy.allows(MushafNavSource.explicitJump, 42), isTrue);
    });
  });

  group('explicit jumps are not hijacked', () {
    test('a follow cannot retarget a jump that is still animating', () {
      final policy = idle(currentPage: 10, pendingNavPage: 55);
      expect(policy.allows(MushafNavSource.audioFollow, 11), isFalse);
    });

    test('a second explicit jump is allowed while one is in flight', () {
      // The user tapping two search results in a row should land on the last
      // one; the follow must not interfere either way.
      final policy = idle(currentPage: 10, pendingNavPage: 55);
      expect(policy.allows(MushafNavSource.explicitJump, 70), isTrue);
    });

    test('the follow resumes once no jump is pending', () {
      final policy = idle(currentPage: 55);
      expect(policy.allows(MushafNavSource.audioFollow, 56), isTrue);
    });
  });

  group('no-op requests', () {
    test('a follow for the page already shown is dropped', () {
      // The follow re-evaluates on every word of the recitation. Allowing a
      // same-page request through would restart the snapping animation on
      // every tick, so the page would never settle.
      final policy = idle(currentPage: 10);
      expect(policy.allows(MushafNavSource.audioFollow, 10), isFalse);
    });

    test('a follow for a different page is allowed', () {
      final policy = idle(currentPage: 10);
      expect(policy.allows(MushafNavSource.audioFollow, 11), isTrue);
    });
  });

  group('resolve', () {
    test('converts a 1-based page to the pager zero-based index', () {
      expect(
        idle(currentPage: 1)
            .resolve(MushafNavSource.explicitJump, 1 + 1, pageCount: pageCount),
        1,
      );
    });

    test('resolves page 1 to index 0', () {
      expect(
        idle(currentPage: 604)
            .resolve(MushafNavSource.explicitJump, 1, pageCount: pageCount),
        0,
      );
    });

    test('returns null when the request must be ignored', () {
      const policy = MushafNavPolicy(currentPage: 10, userDragging: true);
      expect(
        policy.resolve(MushafNavSource.audioFollow, 11, pageCount: pageCount),
        isNull,
      );
    });

    test('clamps past the last page instead of throwing', () {
      // An out-of-range target handed to PageController would throw; the
      // policy has to keep it inside the mushaf.
      expect(
        idle(currentPage: 600)
            .resolve(MushafNavSource.explicitJump, 9999, pageCount: pageCount),
        pageCount - 1,
      );
    });

    test('clamps below page 1', () {
      expect(
        idle(currentPage: 5)
            .resolve(MushafNavSource.explicitJump, 0, pageCount: pageCount),
        0,
      );
      expect(
        idle(currentPage: 5)
            .resolve(MushafNavSource.explicitJump, -7, pageCount: pageCount),
        0,
      );
    });

    test('resolves every page of the mushaf without throwing', () {
      for (var page = 1; page <= pageCount; page++) {
        // The policy drops a request for the page already shown, so the
        // starting page has to differ from the target for the mapping to be
        // observable.
        final policy = idle(currentPage: page == 1 ? 2 : 1);
        expect(
          policy.resolve(MushafNavSource.explicitJump, page,
              pageCount: pageCount),
          page - 1,
          reason: 'page $page must map to index ${page - 1}',
        );
      }
    });
  });
}
