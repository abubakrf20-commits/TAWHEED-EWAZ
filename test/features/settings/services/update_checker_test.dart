import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tawheeed/features/quran/api/quran_api_config.dart';
import 'package:tawheeed/features/settings/services/update_checker.dart';

/// Routes the service's `http.get` through a [MockClient] by wrapping it in
/// an [IOClient] that HttpOverrides hands back to the `http` package.
class _MockedOverrides extends HttpOverrides {
  _MockedOverrides(this.mock);
  final MockClient mock;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _ForwardingHttpClient(mock);
}

/// An [HttpClient] whose every request is answered by the [MockClient].
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

  final _headers = _NoopHeaders();

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
  Future<HttpClientResponse> close() async {
    final response = await mock.send(http.Request('GET', url));
    return _Response(response);
  }

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  void write(Object? obj) {}

  @override
  void writeln([Object? obj = '']) {}

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

  bool get compression => false;

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

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'tawheeed',
      packageName: 'com.islamic.tawheeed',
      version: '1.6.1',
      buildNumber: '4008',
      buildSignature: '',
    );
  });

  final sha256value = 'a' * 64;

  MockClient mockFor(Object? Function() body) => MockClient((request) async {
        final content = body();
        if (content == null) return http.Response('not found', 404);
        return http.Response(jsonEncode(content), 200,
            headers: {'content-type': 'application/json'});
      });

  Future<T> runWith<T>(MockClient mock, Future<T> Function() body) =>
      HttpOverrides.runWithHttpOverrides(body, _MockedOverrides(mock));

  test(
      'returns null when the remote versionCode equals the running build',
      () => runWith(mockFor(() => {'versionCode': 4008}), () async {
            expect(await UpdateChecker.instance.check(), isNull);
          }));

  test(
      'returns null when the manifest is missing (404)',
      () => runWith(mockFor(() => null), () async {
            expect(await UpdateChecker.instance.check(), isNull);
          }));

  test(
      'returns null when the manifest is malformed',
      () => runWith(
              MockClient(
                  (request) async => http.Response('<html>oops</html>', 200)),
              () async {
            expect(await UpdateChecker.instance.check(), isNull);
          }));

  test(
      'returns update info when a newer versionCode exists',
      () => runWith(
              mockFor(() => {
                    'versionCode': 4009,
                    'versionName': '1.6.2',
                    'notes': 'رفع اشکال',
                    'apkUrl':
                        'https://raw.githubusercontent.com/islamic-apps/tawheeed/main/app/tawheeed.apk',
                    'playUrl':
                        'https://play.google.com/store/apps/details?id=x',
                    'mandatory': false,
                    'apkSha256': sha256value,
                  }), () async {
            final update = await UpdateChecker.instance.check();
            expect(update, isNotNull);
            expect(update!.versionCode, 4009);
            expect(update.apkSha256, sha256value);
            expect(update.hasPinnedApk, isTrue);
            expect(update.versionName, '1.6.2');
            expect(update.bestUrl,
                'https://play.google.com/store/apps/details?id=x');
          }));

  test(
      'bestUrl falls back to the APK when no Play URL is provided',
      () => runWith(
              mockFor(() => {
                    'versionCode': 4010,
                    'versionName': '1.7.0',
                    'apkUrl':
                        'https://raw.githubusercontent.com/islamic-apps/tawheeed/main/app/tawheeed.apk',
                    'apkSha256': sha256value,
                  }), () async {
            final update = await UpdateChecker.instance.check();
            expect(update!.bestUrl,
                'https://raw.githubusercontent.com/islamic-apps/tawheeed/main/app/tawheeed.apk');
          }));

  test('probes the content catalog app/update.json path', () async {
    Uri? captured;
    final mock = MockClient((request) async {
      captured = request.url;
      return http.Response(jsonEncode({'versionCode': 4008}), 200);
    });
    await HttpOverrides.runWithHttpOverrides(() async {
      await UpdateChecker.instance.check();
      expect(captured.toString(),
          '${QuranApiConfig.contentBaseUrl}/app/update.json');
    }, _MockedOverrides(mock));
  });

  test(
      'prefers the revision field when the manifest provides one '
      '(direct builds use a constant versionCode)', () async {
    await runWith(
        mockFor(() => {
              'revision': 6001,
              'versionCode': 4009,
              'versionName': '1.7.1',
              'apkUrl':
                  'https://raw.githubusercontent.com/islamic-apps/tawheeed/main/app/direct.apk',
              'playUrl': 'https://play.google.com/store/apps/details?id=x',
              'apkSha256': sha256value,
            }), () async {
      final update = await UpdateChecker.instance.check();
      expect(update, isNotNull);
      expect(update!.revision, 6001);
      expect(update.versionCode, 4009);
    });
  });

  test('no update when the remote revision equals the running build', () async {
    await runWith(mockFor(() => {'revision': 4008}), () async {
      expect(await UpdateChecker.instance.check(), isNull);
    });
  });

  group('manifest integrity and URL allowlisting', () {
    Map<String, dynamic> manifest([Object? sha]) => {
          'revision': 7000,
          'versionName': '1.9.0',
          'apkUrl':
              'https://raw.githubusercontent.com/islamic-apps/tawheeed/main/app/a.apk',
          'apkSha256': sha ?? sha256value,
        };

    test('an update without an apkSha256 pin is never offered', () async {
      final unpinned = Map<String, dynamic>.from(manifest())
        ..remove('apkSha256');
      await runWith(mockFor(() => unpinned), () async {
        expect(await UpdateChecker.instance.check(), isNull);
      });
    });

    test('a non-hex or wrong-length pin is treated as unpinned', () async {
      await runWith(mockFor(() => manifest('zzz')), () async {
        expect(await UpdateChecker.instance.check(), isNull);
      });
    });

    test('a pinned hash is normalised to lowercase hex', () {
      final update = UpdateChecker.evaluate(
        runningCode: 4008,
        localRevision: 6000,
        manifest: manifest('A${'b' * 63}'),
      );
      expect(update!.apkSha256, 'a${'b' * 63}');
    });

    test('an apkUrl on a host we do not publish from is refused', () {
      for (final url in const [
        'https://evil.example.com/a.apk',
        'http://raw.githubusercontent.com/islamic-apps/tawheeed/a.apk',
        'file:///data/a.apk',
        'intent://scan/#Intent;scheme=zxing;end',
        'https://play.google.com.evil.com/a.apk',
        '',
      ]) {
        expect(UpdateChecker.isAllowedApkUrl(url), isFalse,
            reason: 'should refuse $url');
      }
    });

    test('only HTTPS play.google.com links are accepted', () {
      expect(
        UpdateChecker.isAllowedPlayUrl(
            'https://play.google.com/store/apps/details?id=com.islamic.tawheeed'),
        isTrue,
      );
      expect(
          UpdateChecker.isAllowedPlayUrl('http://play.google.com/x'), isFalse);
      expect(UpdateChecker.isAllowedPlayUrl('https://play.google.com.evil/x'),
          isFalse);
      expect(UpdateChecker.isAllowedPlayUrl('https://example.com/x'), isFalse);
    });

    test('a manifest whose only url is untrusted yields no update', () {
      final update = UpdateChecker.evaluate(
        runningCode: 4008,
        localRevision: 6000,
        manifest: {
          'revision': 7000,
          'apkUrl': 'https://evil.example.com/a.apk',
          'apkSha256': sha256value,
        },
      );
      expect(update, isNull);
    });

    test('an untrusted apkUrl is dropped while the play link survives', () {
      final update = UpdateChecker.evaluate(
        runningCode: 4008,
        localRevision: 6000,
        manifest: {
          'revision': 7000,
          'apkUrl': 'https://evil.example.com/a.apk',
          'playUrl': 'https://play.google.com/store/apps/details?id=x',
          'apkSha256': sha256value,
        },
      );
      expect(update!.apkUrl, '');
      expect(update.playUrl, 'https://play.google.com/store/apps/details?id=x');
      expect(update.bestUrl, 'https://play.google.com/store/apps/details?id=x');
    });
  });

  group('evaluate (direct / two-counter)', () {
    test('routes a direct build to the APK URL', () {
      final update = UpdateChecker.evaluate(
        runningCode: 2000000000,
        localRevision: 6010,
        manifest: {
          'revision': 7000,
          'apkUrl':
              'https://raw.githubusercontent.com/islamic-apps/tawheeed/main/app/direct.apk',
          'playUrl': 'https://play.google.com/store/apps/details?id=x',
        },
      );
      expect(update, isNotNull);
      expect(update!.isDirect, isTrue);
      expect(update.bestUrl,
          'https://raw.githubusercontent.com/islamic-apps/tawheeed/main/app/direct.apk');
    });

    test('a split ABI offset is still a direct build', () {
      final update = UpdateChecker.evaluate(
        runningCode: 2000002000,
        localRevision: 6010,
        manifest: {
          'revision': 7000,
          'apkUrl':
              'https://raw.githubusercontent.com/islamic-apps/tawheeed/main/app/direct.apk',
          'playUrl': 'https://play.google.com/store/apps/details?id=x',
        },
      );
      expect(update!.isDirect, isTrue);
      expect(update.bestUrl,
          'https://raw.githubusercontent.com/islamic-apps/tawheeed/main/app/direct.apk');
    });

    test('a direct build without a baked revision stays quiet', () {
      expect(
        UpdateChecker.evaluate(
          runningCode: 2000000000,
          localRevision: 0,
          manifest: {'revision': 7000},
        ),
        isNull,
      );
    });
  });

  group('per-ABI variants (frozen code + split offsets)', () {
    const universal = 'https://raw.githubusercontent.com/islamic-apps/'
        'tawheeed/main/app/tawheeed-1.9.0.apk';
    const arm64 = 'https://raw.githubusercontent.com/islamic-apps/'
        'tawheeed/main/app/tawheeed-1.9.0-arm64-v8a.apk';
    const armv7 = 'https://raw.githubusercontent.com/islamic-apps/'
        'tawheeed/main/app/tawheeed-1.9.0-armeabi-v7a.apk';
    final arm64Sha = 'b' * 64;
    final armv7Sha = 'c' * 64;

    Map<String, dynamic> manifestWithVariants() => {
          'revision': 7000,
          'versionName': '1.9.0',
          'apkUrl': universal,
          'apkSha256': sha256value,
          'apkVariants': [
            {
              'abi': 'arm64-v8a',
              'versionCode': 2000014020,
              'url': arm64,
              'sha256': arm64Sha,
            },
            {
              'abi': 'armeabi-v7a',
              'versionCode': 2000013020,
              'url': armv7,
              'sha256': armv7Sha,
            },
          ],
        };

    test('an arm64 split downloads the arm64 artifact, not the universal',
        () {
      final update = UpdateChecker.evaluate(
        runningCode: 2000014020,
        localRevision: 6000,
        manifest: manifestWithVariants(),
      );
      expect(update!.apkUrl, arm64);
      expect(update.apkSha256, arm64Sha);
      expect(update.hasPinnedApk, isTrue);
    });

    test('a 32-bit split downloads the armeabi-v7a artifact', () {
      final update = UpdateChecker.evaluate(
        runningCode: 2000013020,
        localRevision: 6000,
        manifest: manifestWithVariants(),
      );
      expect(update!.apkUrl, armv7);
      expect(update.apkSha256, armv7Sha);
    });

    test('a fat install (no matching split code) falls back to the universal',
        () {
      final update = UpdateChecker.evaluate(
        runningCode: 2000012020,
        localRevision: 6000,
        manifest: manifestWithVariants(),
      );
      expect(update!.apkUrl, universal);
      expect(update.apkSha256, sha256value);
    });

    test('a variant with an untrusted url or a bad pin is never selected', () {
      for (final broken in [
        {'url': 'https://evil.example.com/a.apk', 'sha256': arm64Sha},
        {'url': arm64, 'sha256': 'not-a-sha'},
        {'url': arm64},
      ]) {
        final manifest = manifestWithVariants();
        manifest['apkVariants'] = [
          {'versionCode': 2000014020, ...broken},
        ];
        final update = UpdateChecker.evaluate(
          runningCode: 2000014020,
          localRevision: 6000,
          manifest: manifest,
        );
        expect(update!.apkUrl, universal,
            reason: 'broken variant $broken must not be used');
        expect(update.apkSha256, sha256value);
      }
    });

    test('a variants-only manifest still resolves for a matching split', () {
      final manifest = manifestWithVariants()..remove('apkUrl');
      final update = UpdateChecker.evaluate(
        runningCode: 2000014020,
        localRevision: 6000,
        manifest: manifest,
      );
      expect(update!.apkUrl, arm64);
      expect(update.apkSha256, arm64Sha);
    });

    test('check() hands the split artifact to the installer', () async {
      // The mocked PackageInfo reports code 4008, so the manifest declares a
      // variant for it — proving the running code, not the device model,
      // selects the artifact.
      final manifest = manifestWithVariants();
      manifest['apkVariants'] = [
        {
          'abi': 'arm64-v8a',
          'versionCode': 4008,
          'url': arm64,
          'sha256': arm64Sha,
        },
      ];
      await runWith(mockFor(() => manifest), () async {
        final update = await UpdateChecker.instance.check();
        expect(update, isNotNull);
        expect(update!.apkUrl, arm64);
        expect(update.apkSha256, arm64Sha);
      });
    });

    test('an unrelated malformed variants field is ignored', () {
      final manifest = manifestWithVariants()
        ..['apkVariants'] = 'arm64-v8a';
      final update = UpdateChecker.evaluate(
        runningCode: 2000014020,
        localRevision: 6000,
        manifest: manifest,
      );
      expect(update!.apkUrl, universal);
      expect(update.apkSha256, sha256value);
    });
  });
}
