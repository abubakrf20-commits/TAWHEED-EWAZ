import 'package:http/http.dart' as http;

/// Adds a browser User-Agent to every request — and drops it again when the
/// disguise is what gets rejected.
///
/// History, because the two halves look contradictory:
/// - 2026-10-04: a request with no UA (curl's default) was answered `403`, so
///   this layer started sending a mobile Chrome UA.
/// - 2026-10-06: that same UA is now answered `403` by Cloudflare's challenge
///   page, while dart's own `Dart/x.y (dart:io)` UA gets the real results page
///   (verified live: 60 rows / 30 parsed hadiths). Every spoofed variant tried
///   — mobile Chrome, desktop Chrome, curl, bare `Mozilla/5.0`, empty — got the
///   challenge, so the site is no longer pattern-matching on "has a UA" but on
///   the UA itself.
///
/// So the disguise stays (it is the fix some networks need) and a single
/// undisguised retry covers the case where it backfires. Only GET-style
/// requests go through here, and only one extra attempt is ever made.
class BrowserUserAgentClient extends http.BaseClient {
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  /// Statuses that mean "the request never reached the site": Cloudflare's
  /// challenge page answers `403` (and `503`/`400` during a block), and a
  /// retry against a real bad request simply fails again with the same code.
  static const Set<int> challengedStatuses = <int>{400, 403, 503};

  final http.Client _inner;

  BrowserUserAgentClient({http.Client? inner})
      : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['User-Agent'] = userAgent;
    final disguised = await _inner.send(request);
    if (!challengedStatuses.contains(disguised.statusCode)) return disguised;

    // Drain the challenge body first: an unread stream keeps the connection
    // pinned, and the retry opens its own.
    try {
      await disguised.stream.drain<void>();
    } catch (_) {
      // The body of a rejected response is worthless either way.
    }

    final plain = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    plain.headers.remove('User-Agent');
    plain.headers.remove('user-agent');
    return _inner.send(plain);
  }

  @override
  void close() => _inner.close();
}
