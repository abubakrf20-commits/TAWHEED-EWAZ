import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/widgets/in_app_browser_screen.dart';

void main() {
  const root = 'https://qaf.ai/chat';

  group('InAppBrowserScreen.allowNavigation', () {
    test('keeps same-origin and subdomain navigations', () {
      expect(InAppBrowserScreen.allowNavigation(root, 'https://qaf.ai/'), isTrue);
      expect(
          InAppBrowserScreen.allowNavigation(root, 'https://www.qaf.ai/home'),
          isTrue);
      expect(
          InAppBrowserScreen.allowNavigation(root, 'https://qaf.ai/pricing?x=1'),
          isTrue);
    });

    test('blocks cross-origin and non-http schemes', () {
      expect(
          InAppBrowserScreen.allowNavigation(root, 'https://evil.example/x'),
          isFalse);
      // A suffix-lookalike must not pass the subdomain check.
      expect(
          InAppBrowserScreen.allowNavigation(root, 'https://qaf.ai.evil/x'),
          isFalse);
      expect(
          InAppBrowserScreen.allowNavigation(root, 'javascript:alert(1)'),
          isFalse);
      expect(
          InAppBrowserScreen.allowNavigation(root, 'file:///android_asset/x'),
          isFalse);
      expect(
          InAppBrowserScreen.allowNavigation(root, 'intent://scan/#Intent'),
          isFalse);
    });

    test('host comparison is case-insensitive', () {
      expect(
          InAppBrowserScreen.allowNavigation(root, 'https://QAF.AI/'), isTrue);
    });
  });
}
