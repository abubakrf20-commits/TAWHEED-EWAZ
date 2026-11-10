@Tags(<String>['network'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:dorar_hadith/dorar_hadith.dart';
import 'package:tawheeed/features/dorar_hadith/data/datasources/browser_user_agent_client.dart';
import 'package:tawheeed/features/dorar_hadith/data/datasources/dorar_remote_datasource.dart';
import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';

/// Talks to the real dorar.net through the production datasource.
///
/// «جستجوی احادیث هیچ نتیجه‌ای نمی‌آورد» is the kind of report that can be a
/// device/build problem or a site that changed its markup again — and the two
/// look identical from the outside. This test answers the code half: it drives
/// the exact object the repository builds, so a rewritten search page fails
/// here instead of silently emptying the list for every user.
///
/// Tagged `network` so an offline run can skip it with
/// `--exclude-tags network`.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

/// One test-level retry on a *transport* hiccup (timeout / network), with a
/// longer request timeout than the app's 15 s default: two full-suite runs in
/// one afternoon turned the release gate red on a transient dorar.net timeout
/// (F-15). A site that is genuinely down or rewritten still fails both
/// attempts, and `DorarParseException` is deliberately NOT caught — a changed
/// markup must fail here, that is this tripwire's whole point.
Future<T> _withOneRetry<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DorarTimeoutException {
    return await run();
  } on DorarNetworkException {
    return await run();
  }
}

void main() {
  // Deliberately NO TestWidgetsFlutterBinding.ensureInitialized(): the widget
  // binding installs HttpOverrides that answer every real request with 400, so
  // this test would never reach dorar.net. PathProviderPlatform is replaced
  // directly instead, which needs no binding.
  test('the live dorar search returns parsed hadiths with real text', () async {
    final supportDir =
        await Directory.systemTemp.createTemp('dorar_search_live');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(supportDir.path);
    addTearDown(() async {
      PathProviderPlatform.instance = original;
      try {
        if (await supportDir.exists()) await supportDir.delete(recursive: true);
      } on FileSystemException {
        // The drift cache keeps its file open for the process's lifetime, so
        // Windows refuses the delete. Not worth failing the test over.
      }
    });

    // Same wiring order the provider uses: the cache path must be fixed before
    // a DorarClient captures it.
    await configureDorarCache();
    final source = DorarRemoteDataSource(
      DorarClient(
        httpClient: DorarHttpClient(
          client: BrowserUserAgentClient(),
          // Live-tripwire only; production keeps the package's 15 s default.
          timeout: const Duration(seconds: 45),
        ),
      ),
    );

    final page = await _withOneRetry(() => source.search(
          query: 'الصلاة',
          page: 1,
          filter: DorarHadithFilter.all,
        ));

    expect(
      page.items,
      isNotEmpty,
      reason: 'dorar.net must yield rows for a common query — an empty list '
          'means the site markup changed and parseSiteResults no longer '
          'matches it',
    );
    expect(page.items.first.hadithText.trim(), isNotEmpty);
    expect(page.hasNextPage, isTrue,
        reason: 'a full 30-row page means another page exists');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
