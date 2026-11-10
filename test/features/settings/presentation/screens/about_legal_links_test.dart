import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/constants/legal_links.dart';
import 'package:tawheeed/features/settings/presentation/screens/about_screen.dart';

/// Audit A-03: the privacy policy used to exist only as an in-app dialog and a
/// markdown file in the repo — no public URL for the Play listing or for a user
/// who already uninstalled. The pages are now hosted from the content repo's
/// `docs/` folder; these tests pin the addresses and the two doors in the
/// About dialog.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      // canLaunch + launch both need a truthy answer for launchUrl to run.
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> openPrivacyDialog(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pump();
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('حریم خصوصی و دسترسی‌ها'), 300,
        scrollable: list);
    await tester.tap(find.text('حریم خصوصی و دسترسی‌ها'));
    // Bounded pumps: the About page owns no settle contract, and this file
    // must not depend on one.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  List<String> launchedUrls() => calls
      .where((c) => c.method == 'launch')
      .map((c) => (c.arguments as Map)['url'] as String)
      .toList();

  test('the three legal addresses are distinct hosted HTTPS pages', () {
    final urls = {
      LegalLinks.privacy,
      LegalLinks.terms,
      LegalLinks.accountDeletion,
    };
    expect(urls, hasLength(3));
    for (final url in urls) {
      final uri = Uri.parse(url);
      expect(uri.scheme, 'https', reason: 'Play requires an https policy URL');
      expect(uri.host, 'abubakrf20-commits.github.io');
      expect(url, startsWith('${LegalLinks.base}/'));
      expect(url, endsWith('.html'));
    }
  });

  testWidgets('the privacy dialog carries the hosted policy and the terms',
      (tester) async {
    await openPrivacyDialog(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('نسخهٔ آنلاین'), findsOneWidget);
    expect(find.text('شرایط استفاده'), findsOneWidget);

    await tester.tap(find.text('نسخهٔ آنلاین'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(launchedUrls(), contains(LegalLinks.privacy));
  });

  testWidgets('the terms button opens the hosted terms page', (tester) async {
    await openPrivacyDialog(tester);

    await tester.tap(find.text('شرایط استفاده'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(launchedUrls(), contains(LegalLinks.terms));
    expect(launchedUrls(), isNot(contains(LegalLinks.privacy)));
  });
}
