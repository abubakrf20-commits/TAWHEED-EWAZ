import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/components/share_card_shell.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/screens/hadeeth_enc_share_screen.dart';
import 'package:tawheeed/shared/services/share_service.dart';

void main() {
  const hadith = HadeethEncHadith(
    id: 1751,
    titleAr: 'باب فضل الصدقة',
    textAr: 'متن عربی حدیث',
    text: 'ترجمهٔ فارسی حدیث',
    takhrij: 'متفق علیه',
    grade: 'صحیح',
    explanation: 'شرح کامل حدیث',
  );

  setUp(() {
    // Mock the clipboard platform channel so Clipboard.setData works in tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
  });

  Future<void> pumpShare(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: HadeethEncShareScreen(hadith: hadith),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'renders the card with Arabic, translation, منبع, صحت, شرح '
      'and the shared footer', (tester) async {
    await pumpShare(tester);

    expect(find.text('ارسال حدیث'), findsOneWidget);
    expect(find.text('حدیث شماره 1751'), findsOneWidget);
    expect(find.text('متن عربی حدیث'), findsOneWidget);
    expect(find.text('ترجمهٔ فارسی حدیث'), findsOneWidget);
    expect(find.text('متفق علیه'), findsOneWidget);
    expect(find.text('صحیح'), findsOneWidget);
    expect(find.text('شرح کامل حدیث'), findsOneWidget);
    // The mark over a dash-free signature — the text share keeps the dash.
    expect(find.text('موسوعه الأحادیث النبویة'), findsOneWidget);
    expect(
      find.text(ShareService.signatureLine('موسوعه الأحادیث النبویة')),
      findsOneWidget,
    );
    expect(
      find.text(ShareService.appLine('موسوعه الأحادیث النبویة')),
      findsNothing,
    );
    expect(find.text('برنامه توحید'), findsNothing);
    final logo = tester.widget<Image>(find.byType(Image));
    expect(logo.image, ShareCardLogo.providerFor(ShareCardLogo.defaultSize));
    expect(logo.height, ShareCardLogo.defaultSize);
  });

  testWidgets(
      'uses the hadith real number (sequence) instead of the route hint',
      (tester) async {
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const numbered = HadeethEncHadith(
      id: 1751,
      textAr: 'متن عربی حدیث',
      text: 'ترجمهٔ فارسی حدیث',
      sequence: 842,
    );
    // The route hint (e.g. the search-result position) says ۱ — the hadith's
    // real encyclopedia number must win so sharing never says «شماره ۱».
    await tester.pumpWidget(const MaterialApp(
      home: HadeethEncShareScreen(hadith: numbered, sequence: 1),
    ));
    await tester.pumpAndSettle();

    expect(find.text('حدیث شماره 842'), findsOneWidget);
  });

  testWidgets('shows the three action buttons', (tester) async {
    await pumpShare(tester);

    expect(find.text('ارسال تصویر'), findsOneWidget);
    expect(find.text('ارسال متن'), findsOneWidget);
    expect(find.text('کپی متن'), findsOneWidget);
  });

  testWidgets('copy button shows the copied confirmation snack bar',
      (tester) async {
    await pumpShare(tester);

    await tester.ensureVisible(find.byIcon(Icons.copy));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pumpAndSettle();
    expect(find.text('کپی شد'), findsOneWidget);
  });

  testWidgets('shows نکات حدیث section when benefits present', (tester) async {
    const withTips = HadeethEncHadith(
      id: 1751,
      titleAr: 'باب فضل الصدقة',
      textAr: 'متن عربی حدیث',
      text: 'ترجمهٔ فارسی حدیث',
      takhrij: 'متفق علیه',
      grade: 'صحیح',
      explanation: 'شرح کامل حدیث',
      benefits: 'اولین نکته.\nدومین نکته.',
    );
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: HadeethEncShareScreen(hadith: withTips),
    ));
    await tester.pumpAndSettle();

    expect(find.text('اولین نکته.'), findsOneWidget);
    expect(find.text('دومین نکته.'), findsOneWidget);
    expect(find.text('نکات حدیث'), findsNWidgets(3));
  });

  testWidgets('toggling off a block hides it from the image preview',
      (tester) async {
    await pumpShare(tester);

    expect(find.text('متن عربی حدیث'), findsOneWidget);
    await tester.ensureVisible(find.text('در تصویر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('متن عربی').last);
    await tester.pumpAndSettle();
    expect(find.text('متن عربی حدیث'), findsNothing);
  });
}
