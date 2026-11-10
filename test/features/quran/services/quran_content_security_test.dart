import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tawheeed/features/quran/services/quran_content_service.dart';

/// Routes the service's `http` calls through a [MockClient] by handing an
/// [IOClient] to the `http` package via [HttpOverrides].
class _MockedOverrides extends HttpOverrides {
  _MockedOverrides(this.mock);
  final MockClient mock;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _ForwardingHttpClient(mock);
}

class _ForwardingHttpClient implements HttpClient {
  _ForwardingHttpClient(this.mock);
  final MockClient mock;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Request(mock, url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.mock, this.url);
  final MockClient mock;
  final Uri url;

  final _NoopHeaders _headers = _NoopHeaders();

  @override
  bool followRedirects = true;
  bool maxRedirectsFollowed = false;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  int contentLength = -1;

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() async =>
      _Response(await mock.send(http.Request('GET', url)));

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  void write(Object? obj) {}

  @override
  void writeln([Object? msg = '']) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.inner);
  final http.StreamedResponse inner;

  @override
  int get statusCode => inner.statusCode;

  @override
  HttpHeaders get headers => _NoopHeaders();

  @override
  bool get isRedirect => false;

  @override
  String get reasonPhrase => '';

  @override
  int get contentLength => inner.contentLength ?? 0;

  @override
  bool get persistentConnection => false;

  Socket? get socket => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {void Function()? onDone, Function? onError, bool? cancelOnError}) =>
      inner.stream.listen(onData,
          onDone: onDone, onError: onError, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<T> withMock<T>(MockClient mock, Future<T> Function() body) =>
      HttpOverrides.runWithHttpOverrides(body, _MockedOverrides(mock));

  group('file name validation', () {
    test('accepts ordinary catalog names', () {
      for (final name in const [
        'tafsir-khamenei.db',
        'translation-sadegh.gz',
        'tafsir_2.db',
      ]) {
        expect(isSafeContentFileName(name), isTrue, reason: name);
      }
    });

    test('rejects traversal, absolute paths, and control characters', () {
      for (final name in const [
        '',
        '.',
        '..',
        '../../etc/passwd',
        '..%2f..%2fx',
        '/data/data/a.db',
        'C:\\Windows\\a.db',
        'sub/dir.db',
        'nul .db',
        'tab\t.db',
        'colon:name.db',
        'a.db?x=1',
        'a.db#frag',
        'a%2e%2edb',
      ]) {
        expect(isSafeContentFileName(name), isFalse, reason: name);
      }
    });

    test('remote names allow the .gz suffix but nothing else extra', () {
      expect(isSafeContentRemoteName('a.db.gz'), isTrue);
      expect(isSafeContentRemoteName('a.db'), isTrue);
      expect(isSafeContentRemoteName('../a.db.gz'), isFalse);
      expect(isSafeContentRemoteName('a.db?x=1.gz'), isFalse);
      expect(isSafeContentRemoteName('a.db.gz.gz'), isTrue);
      expect(isSafeContentRemoteName('a.db?x=1'), isFalse);
    });
  });

  group('catalog parsing', () {
    test('fromJson refuses an entry that would escape the content dir', () {
      expect(
        () => QuranContentFile.fromJson(const {
          'id': 'evil',
          'type': 'tafsir',
          'fileName': '../../../shared_prefs/app.xml',
        }),
        throwsFormatException,
      );
    });

    test('fromJson still accepts a normal entry', () {
      final file = QuranContentFile.fromJson(const {
        'id': 'khamenei',
        'type': 'tafsir',
        'fileName': 'tafsir-khamenei.db',
        'size': 10,
        'compressed': true,
      });
      expect(file.fileName, 'tafsir-khamenei.db');
      expect(file.remoteName, 'tafsir-khamenei.db.gz');
    });

    test('fetchCatalog keeps valid entries and drops hostile ones', () async {
      final manifest = jsonEncode({
        'contents': [
          {
            'id': 'ok',
            'type': 'translation',
            'fileName': 'translation-sadegh.db',
          },
          {
            'id': 'evil',
            'type': 'tafsir',
            'fileName': '../../../../databases/tawheeed.sqlite',
          },
          {'id': 'no-file', 'type': 'tafsir'},
          {
            'id': 'ok2',
            'type': 'tafsir',
            'fileName': 'tafsir-khamenei.db',
          },
        ]
      });
      final entries = await withMock(
          MockClient((_) async => http.Response(manifest, 200)),
          QuranContentService.fetchCatalog);
      expect(entries.map((e) => e.id), ['ok', 'ok2']);
    });
  });

  group('downloadPathFor containment', () {
    test('rejects an unsafe name before touching the filesystem', () async {
      await expectLater(
        QuranContentService.downloadPathFor('../../evil.db'),
        throwsFormatException,
      );
      await expectLater(
        QuranContentService.downloadPathFor('/abs/evil.db'),
        throwsFormatException,
      );
    });
  });

  group('bounded decompression', () {
    test('inflates a payload that fits', () {
      final payload = List<int>.filled(64 * 1024, 0x41);
      final packed = gzip.encode(payload);
      expect(packed.length, lessThan(payload.length ~/ 8),
          reason: 'repetitive data must actually compress');
      expect(gunzipBounded(packed, 1 << 20), payload);
    });

    test('aborts a gzip bomb instead of allocating the whole output', () {
      // ~8 MiB of zeroes compresses to a few KiB: the classic bomb shape.
      final bomb = gzip.encode(List<int>.filled(8 << 20, 0));
      expect(bomb.length, lessThan(64 << 10),
          reason: 'bomb must be small on the wire to be a real bomb');
      expect(() => gunzipBounded(bomb, 1 << 20),
          throwsA(isA<QuranContentLimitException>()));
    });
  });
}
