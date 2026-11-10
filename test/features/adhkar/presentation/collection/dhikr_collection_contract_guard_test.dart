import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The collection's cursor has ONE mover: the page's `_completeAdvance`, asked
/// for by the mode whose action finished a dhikr.
///
/// The reported defect was «احیاناً ترتیب به هم خورده … برخی ذکرها رد میکنه» —
/// the page both listened for the completion (`_onSessionChanged`, advancing
/// through `firstUnfinished`) AND advanced after the tap (`_completeAdvance`,
/// through `advance()`), so one tick moved the cursor twice and a dhikr in
/// between was passed over without anyone tapping it. A widget test cannot
/// watch the page's own listener and timer race each other, so the invariant is
/// pinned at the source — the repo's idiom for a lifecycle window a test binding
/// cannot hold open (cf. `azkar_tasbih_tab_midnight_guard_test.dart`).
///
/// The same file pins the section's two other one-source rules: the hold-to-
/// register wording lives once, in the kit, and both progress rings are the kit
/// `RingView` rather than a geometry each mode re-draws for itself.
const _page =
    'lib/features/home/presentation/widgets/adhkar_category_page.dart';
const _controller =
    'lib/features/adhkar/presentation/collection/dhikr_session_controller.dart';
const _list =
    'lib/features/adhkar/presentation/collection/dhikr_list_view.dart';
const _kit =
    'lib/features/adhkar/presentation/collection/dhikr_collection_kit.dart';
const _timeline =
    'lib/features/adhkar/presentation/collection/dhikr_timeline_view.dart';
const _focus =
    'lib/features/adhkar/presentation/collection/dhikr_focus_view.dart';

String _withoutComments(String source) => source
    .split('\n')
    .map((line) {
      final comment = line.indexOf('//');
      return comment < 0 ? line : line.substring(0, comment);
    })
    .join('\n');

int _count(String haystack, String needle) {
  var found = 0;
  var at = haystack.indexOf(needle);
  while (at >= 0) {
    found++;
    at = haystack.indexOf(needle, at + needle.length);
  }
  return found;
}

/// The repo's files check out CRLF on Windows, so a `\n` in any needle below
/// would simply never match (the `readSource` lesson).
String _read(String path) =>
    _withoutComments(File(path).readAsStringSync().replaceAll('\r\n', '\n'));

void main() {
  late String page;
  late String controller;
  late String list;
  late String kit;
  late String timeline;
  late String focus;

  setUpAll(() {
    page = _read(_page);
    controller = _read(_controller);
    list = _read(_list);
    kit = _read(_kit);
    timeline = _read(_timeline);
    focus = _read(_focus);
  });

  group('the page advances once', () {
    test('no session listener is left to move the cursor', () {
      expect(
        page,
        isNot(contains('_onSessionChanged')),
        reason: 'a second mover is the double-advance defect itself',
      );
      expect(
        page,
        isNot(contains('addListener')),
        reason: 'the session must have one cursor mover, not two',
      );
      expect(
        page,
        isNot(contains('_lastDone')),
        reason:
            'the completion-growth bookkeeping only existed for the '
            'listener',
      );
    });

    test('every mode hands its completion to the same mover', () {
      expect(
        _count(page, 'onCompleteCurrent: _completeAdvance'),
        2,
        reason: 'the list and the timeline both report through it',
      );
      expect(
        page,
        contains('onCompleteAll: _completeAll'),
        reason: 'the one tick goes through the same advance',
      );
      expect(
        page,
        isNot(contains('firstUnfinished')),
        reason:
            'the page must not keep a second «what is next» rule of its '
            'own',
      );
      expect(
        page,
        isNot(contains('nextUnfinishedAfter')),
        reason:
            'stepping is the controller\'s `advance()`, not a hand-rolled '
            'search plus goTo',
      );
    });

    test('_completeAdvance is the mover the doc promises', () {
      final start = page.indexOf('void _completeAdvance() {');
      expect(start, isNonNegative, reason: '«$start» moved — re-point this');
      final body = page.substring(start, start + 420);
      expect(
        body,
        contains('if (!prefs.autoAdvance)'),
        reason: 'with auto-advance off the finished dhikr waits for «بعدی»',
      );
      expect(body, contains('_session.advance();'));
      expect(body, contains('_scrollToCurrent();'));
    });
  });

  group('the controller owns the rules', () {
    test('one restoration rule, used by both entry points', () {
      expect(
        _count(controller, '_restoreCursor('),
        3,
        reason: 'definition + constructor + seed',
      );
      expect(
        controller,
        isNot(contains('_current = _clamp(current')),
        reason: 'seed() must not re-implement the clamping the helper does',
      );
      expect(
        controller,
        isNot(contains('if (_entryAt(_current).done)')),
        reason: 'the stored-cursor correction lives in one place',
      );
    });

    test('the dead neighbour step stays deleted', () {
      expect(
        controller,
        isNot(contains('neighbour(')),
        reason: 'it ignored both done and skipped, and had no caller',
      );
    });

    test('the one-tick primitives report whether they finished anything', () {
      expect(
        controller,
        contains('bool complete(int index) {'),
        reason: 'the views ask for it before reporting a completion',
      );
      expect(controller, contains('bool setDone(int index, bool value) {'));
      expect(
        controller,
        contains('if (value) return complete(index);'),
        reason: 'un-ticking is undo — one definition of «one step back»',
      );
    });

    test('a completion never moves the cursor by itself', () {
      const openers = ['bool tap(int index) {', 'bool complete(int index) {'];
      for (final opener in openers) {
        final start = controller.indexOf(opener);
        expect(start, isNonNegative, reason: '«$opener» moved — re-point this');
        final body = controller.substring(start, start + 460);
        expect(
          body,
          isNot(contains('goTo(')),
          reason:
              'a self-advancing completion plus the page\'s advance is '
              'the double step that skips a dhikr',
        );
        expect(body, isNot(contains('_current =')), reason: 'same reason');
      }
    });
  });

  group('the views report instead of deciding', () {
    test('the list reports only real completions', () {
      expect(list, contains('required this.onCompleteCurrent'));
      expect(
        list,
        contains('if (controller.complete(index)) onCompleteCurrent();'),
      );
      expect(
        list,
        contains('if (controller.setDone(index, !controller.isDone(index))) {'),
      );
      expect(
        list,
        contains('if (!finished) return;'),
        reason: 'a «+» that did not reach the target reports nothing',
      );
    });

    test('the timeline holds to register and reports once', () {
      expect(timeline, contains('onLongPress: counted ? onComplete : null'));
      expect(
        timeline,
        contains('if (controller.complete(i)) onCompleteCurrent();'),
        reason: 'a re-tap on a finished row is not a completion',
      );
      expect(
        timeline,
        contains('kDhikrHoldToRegister'),
        reason: 'the hold is named on the card, not left invisible',
      );
    });

    test('the focus view keeps its swipe on the shared doors', () {
      expect(focus, contains('onCompleteAll'));
      expect(focus, contains('onLongPress: target > 1 ? onCompleteAll : null'));
      expect(
        focus,
        isNot(contains('controller.goTo(')),
        reason:
            'the swipe is onNext/onPrevious — a gesture must not own a '
            'cursor rule of its own',
      );
      expect(focus, isNot(contains('nextUnfinishedAfter')));
    });
    test('the hold hint is worded once, in the kit', () {
      expect(
        kit,
        contains('const String kDhikrHoldToRegister ='),
        reason: 'the sentence has one home',
      );
      expect(timeline, contains('kDhikrHoldToRegister'));
      expect(focus, contains('kDhikrHoldToRegister'));
      for (final source in [list, timeline, focus]) {
        expect(
          source,
          isNot(contains('نگه دارید')),
          reason:
              'a view must not re-type the kit\'s wording — three copies '
              'is how the modes drift apart',
        );
      }
    });
  });

  group('the rings are the kit ring', () {
    test('both progress rings go through RingView', () {
      expect(kit, contains('RingView('));
      expect(focus, contains('RingView('));
      expect(
        kit,
        contains(
          'import '
          '\'package:tawheeed/core/design_system/components/ring.dart\'',
        ),
      );
      expect(
        focus,
        contains(
          'import '
          '\'package:tawheeed/core/design_system/components/ring.dart\'',
        ),
      );
    });

    test('no mode draws its own ring geometry again', () {
      // The section used to hand-build the same ring twice (a Stack over a
      // CircularProgressIndicator in the progress card, another in the focus
      // counter). Two local copies is how one ring ends up opening one way and
      // the other the opposite way — the app's rule is the kit `RingView`,
      // from 12 o'clock, round caps.
      for (final source in {
        'kit': kit,
        'focus': focus,
        'timeline': timeline,
        'list': list,
        'page': page,
      }.entries) {
        expect(
          source.value,
          isNot(contains('CircularProgressIndicator')),
          reason: '${source.key} must not re-fork the ring',
        );
        expect(
          source.value,
          isNot(contains('drawArc')),
          reason: '${source.key} must not paint a ring of its own',
        );
      }
    });
  });
}
