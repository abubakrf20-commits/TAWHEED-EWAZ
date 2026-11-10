import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tawheeed/features/dorar_hadith/data/datasources/browser_user_agent_client.dart';

/// Real dorar.net behaviour, 2026-10-06: the spoofed Chrome UA is answered by
/// Cloudflare's challenge page (`403`) while dart's own UA gets the results
/// page. These tests pin the retry that keeps both networks working, without
/// touching the network.
class _FakeInner extends http.BaseClient {
  _FakeInner(this.statusFor);

  final int Function(String? userAgent) statusFor;
  final List<String?> seenUserAgents = <String?>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final ua = request.headers['User-Agent'] ?? request.headers['user-agent'];
    seenUserAgents.add(ua);
    final status = statusFor(ua);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('body-$status')),
      status,
    );
  }
}

Future<http.StreamedResponse> _get(BrowserUserAgentClient client) =>
    client.send(http.Request('GET', Uri.parse('https://dorar.net/x')));

void main() {
  test('the disguise is sent first', () async {
    final inner = _FakeInner((_) => 200);
    final client = BrowserUserAgentClient(inner: inner);
    addTearDown(client.close);

    final res = await _get(client);

    expect(res.statusCode, 200);
    expect(inner.seenUserAgents, [BrowserUserAgentClient.userAgent]);
  });

  test('a challenge answer is retried once without the disguise', () async {
    final inner = _FakeInner(
      (ua) => ua == BrowserUserAgentClient.userAgent ? 403 : 200,
    );
    final client = BrowserUserAgentClient(inner: inner);
    addTearDown(client.close);

    final res = await _get(client);
    final body = await res.stream.bytesToString();

    expect(res.statusCode, 200);
    expect(body, 'body-200');
    expect(
      inner.seenUserAgents,
      [BrowserUserAgentClient.userAgent, isNull],
      reason: 'the retry must drop the UA, not reuse the rejected one',
    );
  });

  test('a 400 is treated as a challenge, a 404 is not', () async {
    final bad = _FakeInner((_) => 400);
    final client = BrowserUserAgentClient(inner: bad);
    addTearDown(client.close);
    expect((await _get(client)).statusCode, 400);
    expect(bad.seenUserAgents.length, 2);

    final missing = _FakeInner((_) => 404);
    final client2 = BrowserUserAgentClient(inner: missing);
    addTearDown(client2.close);
    expect((await _get(client2)).statusCode, 404);
    expect(missing.seenUserAgents, [BrowserUserAgentClient.userAgent]);
  });

  test('a healthy 500-style failure is not retried', () async {
    final inner = _FakeInner((_) => 500);
    final client = BrowserUserAgentClient(inner: inner);
    addTearDown(client.close);

    final res = await _get(client);

    expect(res.statusCode, 500);
    expect(inner.seenUserAgents, [BrowserUserAgentClient.userAgent]);
  });
}
