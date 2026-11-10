import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `BookReaderScreen` cannot be pumped in a widget test: its content arrives
/// through the static, network-backed `BookContentService` and the screen also
/// reads Drift providers. The retry contract is therefore pinned at the source
/// level — the same idiom as this repo's other wiring guards.
void main() {
  String readSource() => File(
        'lib/features/books/presentation/screens/book_reader_screen.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');

  String loadContentBody() {
    final source = readSource();
    final start = source.indexOf('Future<void> _loadContent() async {');
    expect(start, greaterThan(0), reason: '_loadContent moved or was renamed');
    final end = source.indexOf('@override\n  void dispose()', start);
    expect(end, greaterThan(start));
    return source.substring(start, end);
  }

  test('a retry resets the error view before it starts loading again', () {
    final body = loadContentBody();
    final reset = body.indexOf('_errorMessage = null');
    final tryAt = body.indexOf('try {');
    expect(reset, greaterThan(0),
        reason: '«تلاش دوباره» re-enters _loadContent; the old message must go');
    expect(reset, lessThan(tryAt),
        reason: 'the message has to be cleared before the download, not after');
    final blockStart = body.lastIndexOf('setState(() {', reset);
    expect(blockStart, greaterThan(0));
    expect(body.substring(blockStart, tryAt).contains('_isLoading = true'),
        isTrue, reason: 'the spinner must replace the error view while retrying');
  });

  test('a successful load clears any stale error message', () {
    final body = loadContentBody();
    final success = body.indexOf('_pages = pages;');
    expect(success, greaterThan(0));
    final successSetState = body.substring(
      body.lastIndexOf('setState(() {', success),
      body.indexOf('});', success),
    );
    expect(successSetState.contains('_errorMessage = null'), isTrue,
        reason: 'without this the error view stays up after a good retry');
  });

  test('the error view retry button re-runs _loadContent', () {
    final source = readSource();
    final errorView = source.indexOf('Widget _buildErrorView()');
    expect(errorView, greaterThan(0));
    // The panel is the shared one, and its retry is wired to the same method the
    // old inline button called.
    expect(source.indexOf('FailureView(', errorView), greaterThan(errorView));
    final retry = source.indexOf('onRetry: _loadContent', errorView);
    expect(retry, greaterThan(errorView));
  });

  test('the exception is a debug channel, not the reader-facing message', () {
    final source = readSource();
    final errorView = source.indexOf('Widget _buildErrorView()');
    final end = source.indexOf('Widget _buildEmptyContent()', errorView);
    expect(end, greaterThan(errorView));
    final body = source.substring(errorView, end);
    // `_errorMessage` holds a sentence about the failure, never the thrown
    // object: the panel owns the copy, and the exception belongs to the log and
    // to the panel's debug-only `error` channel.
    expect(body.contains('error: _errorMessage'), isTrue);
    expect(body.contains('Text(_errorMessage'), isFalse);
  });

  test('a page turn settles in, and reduced motion turns the fade off', () {
    final source = readSource();
    final start = source.indexOf('Widget _buildContent()');
    final end = source.indexOf('Widget _turnTransition(');
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final body = source.substring(start, end);
    expect(body.contains('AnimatedSwitcher('), isTrue,
        reason: 'without it a turn is an instant swap, not a page');
    expect(body.contains("key: ValueKey('sheet-\$index')"), isTrue,
        reason: 'the switcher only animates when the sheet key changes');
    expect(body.contains('MediaQuery.disableAnimationsOf(context)'), isTrue,
        reason: 'a reader who asked the system for no motion must get none');
  });
}
