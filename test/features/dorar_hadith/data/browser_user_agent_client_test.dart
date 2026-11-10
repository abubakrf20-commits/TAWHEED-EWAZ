import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tawheeed/features/dorar_hadith/data/datasources/browser_user_agent_client.dart';

void main() {
  test('هر درخواست هدر User-Agent مرورگر می‌گیرد', () async {
    http.Request? captured;
    final inner = MockClient((request) async {
      captured = request;
      return http.Response('{}', 200);
    });
    final client = BrowserUserAgentClient(inner: inner);

    await client.get(Uri.parse('https://www.dorar.net/hadith/search?q=x'));

    expect(captured!.headers['User-Agent'], BrowserUserAgentClient.userAgent);
    client.close();
  });
}
