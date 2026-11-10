import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The azkar/tasbih tab lives inside an IndexedStack, so it is built once and
/// never re-built at midnight; something has to invalidate the tasbih provider
/// when the day (or a custom reset deadline) rolls over.
///
/// That something used to be `Timer.periodic(Duration(minutes: 1))`, which read
/// SharedPreferences every sixty seconds — 1,440 reads a day — to catch one
/// event whose time the settings already know. It is now a single timer aimed
/// at the next boundary. The invariants below are the ones that made the old
/// tick safe, restated for the new shape, plus the one this change is about:
/// **the tab must not poll**.
///
/// Two of these cannot be reproduced from a widget test (the prefs read resolves
/// inside the same `pump`, so the teardown window cannot be held open), which is
/// why the repo idiom here is a source scan — cf.
/// `sciences_routing_guard_test.dart`.
const _path = 'lib/features/adhkar/presentation/screens/azkar_tasbih_tab.dart';

String _withoutComments(String source) => source.split('\n').map((line) {
      final comment = line.indexOf('//');
      return comment < 0 ? line : line.substring(0, comment);
    }).join('\n');

/// Index of the `}` matching the `{` at [open], ignoring braces in strings.
int _matchingBrace(String code, int open) {
  var depth = 0;
  var quote = '';
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (quote.isNotEmpty) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = '';
      }
      continue;
    }
    if (c == '"' || c == "'") {
      quote = c;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  throw StateError('unbalanced braces after index $open');
}

/// The body of the named member, from its signature to its closing brace.
String _body(String code, String signature) {
  final start = code.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature must still exist');
  final open = code.indexOf('{', start);
  expect(open, isNot(-1), reason: '$signature needs a block body');
  return code.substring(open + 1, _matchingBrace(code, open));
}

void main() {
  late String code;

  setUpAll(() {
    code = _withoutComments(File(_path).readAsStringSync());
  });

  test('the tab does not poll: no Timer.periodic anywhere', () {
    expect(code.contains('Timer.periodic'), isFalse,
        reason: 'a periodic timer reads prefs every tick to detect one nightly '
            'event. Aim one timer at the boundary instead '
            '(`tasbihNextResetBoundary`).');
  });

  test('the reset timer is aimed at the shared boundary helper', () {
    final schedule = _body(code, 'Future<void> _scheduleResetCheck()');
    expect(schedule, contains('await tasbihNextResetBoundary('),
        reason: 'the boundary arithmetic belongs next to the decision it '
            'predicts, not inline here where it can drift from it');
    expect(schedule, contains('_resetTimer?.cancel()'),
        reason: 're-aiming must cancel the previous timer or two timers race');
    expect(schedule, contains('boundary.difference(now)'),
        reason: 'the wait is the distance to the boundary, not a constant');
  });

  test('every ref use after an await is guarded', () {
    final body = _body(code, 'Future<void> _onResetBoundary()');
    final lines = body.split('\n');
    var seenAwait = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('await ')) seenAwait = true;
      if (!seenAwait || !RegExp(r'\bref\.').hasMatch(line)) continue;

      // A guard counts whether it is on the use itself (`if (overdue &&
      // mounted) ref.x(...)`) or on the line immediately above
      // (`if (!mounted) return;` then `ref.x(...)`). What must never happen is
      // a `ref.` after an await with no guard since the await.
      final guardedOnLine = line.contains('mounted');
      final previous = i > 0 ? lines[i - 1].trim() : '';
      final guardedAbove =
          previous.startsWith('if (!mounted)') || previous.contains('mounted)');
      expect(guardedOnLine || guardedAbove, isTrue,
          reason: 'the tick can be torn down during its prefs read; `ref` must '
              'be guarded since the await — offending line: ${line.trim()}');

      final mountedAt = line.indexOf('mounted');
      final awaitAt = line.lastIndexOf('await');
      if (mountedAt >= 0 && awaitAt >= 0) {
        expect(mountedAt, greaterThan(awaitAt),
            reason: 'a `mounted` check written before an `await` on the same '
                'line is stale by the time the await resumes — offending '
                'line: ${line.trim()}');
      }
    }
  });

  test('the overdue read is awaited before the provider is invalidated', () {
    final body = _body(code, 'Future<void> _onResetBoundary()');
    final awaitAt = body.indexOf('await isTasbihDailyResetOverdue(');
    expect(awaitAt, isNot(-1),
        reason: 'the custom reset deadline must be read through the shared '
            'decision helper');
    final guardedRefAt = body.indexOf('ref.invalidate', awaitAt);
    expect(guardedRefAt, greaterThan(awaitAt),
        reason: 'the provider is invalidated on the decision from the await');
  });

  test('rollover and overdue are exclusive branches', () {
    final body = _body(code, 'Future<void> _onResetBoundary()');
    final stampAt = body.indexOf('_lastSeenDate = today;');
    expect(stampAt, isNot(-1),
        reason: 'the tick must remember the new day or it re-fires forever');
    final elseIfAt = body.indexOf('else if');
    expect(elseIfAt, greaterThan(stampAt),
        reason: 'a rollover tick has already invalidated the provider; running '
            'the overdue read as well is a wasted prefs read');
  });

  test('the next boundary is scheduled whether or not this one acted', () {
    final body = _body(code, 'Future<void> _onResetBoundary()');
    final scheduleAt = body.lastIndexOf('_scheduleResetCheck()');
    expect(scheduleAt, isNot(-1),
        reason: 'a one-shot timer that is not re-armed stops after one night');
    expect(scheduleAt, greaterThan(body.indexOf('_lastSeenDate = today;')),
        reason: 're-arming must happen after the branch, so both paths reach it');
  });

  test('dispose cancels the reset timer before the controller', () {
    final body = _body(code, 'void dispose()');
    final cancelAt = body.indexOf('_resetTimer?.cancel();');
    expect(cancelAt, isNot(-1),
        reason: 'a leaked timer keeps invalidating a disposed ref');
    expect(body.indexOf('_tabController.dispose();'), greaterThan(cancelAt));
    expect(body.indexOf('super.dispose();'), greaterThan(cancelAt));
  });

  test('coming back to the foreground re-aims the timer', () {
    final body = _body(code, 'void didChangeAppLifecycleState(');
    expect(body, contains('AppLifecycleState.resumed'),
        reason: 'a one-shot timer trusts the clock; resume is the moment we '
            'know the clock may have moved');
    expect(body, contains('_scheduleResetCheck()'));
  });
}
