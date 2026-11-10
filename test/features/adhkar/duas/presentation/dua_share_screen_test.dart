import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/components/share_card_shell.dart';
import 'package:tawheeed/features/adhkar/duas/domain/entities/dua_model.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/screens/dua_share_screen.dart';
import 'package:tawheeed/shared/services/share_service.dart';

void main() {
  const dua = DuaModel(
    id: 'dua-7',
    title: 'دعای ورود به خانه',
    arabicText: 'بِسْمِ اللَّهِ وَلَجْنَا...',
    translation: 'به نام خدا وارد شدیم و به نام خدا خارج شدیم...',
    transliteration: 'Bismillahi walajna...',
    source: 'مسلم',
    category: 'خانه',
  );

  setUp(() {
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
      home: DuaShareScreen(dua: dua),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'renders the card with Arabic, رونویسی, ترجمه, منبع '
      'and the shared footer', (tester) async {
    await pumpShare(tester);

    expect(find.text('ارسال دعا'), findsOneWidget);
    expect(find.textContaining('دعای ورود به خانه'), findsOneWidget);
    expect(find.text('بِسْمِ اللَّهِ وَلَجْنَا...'), findsOneWidget);
    expect(find.text('به نام خدا وارد شدیم و به نام خدا خارج شدیم...'),
        findsOneWidget);
    expect(find.text('مسلم'), findsOneWidget);
    // The mark beside a dash-free signature — the text share keeps the dash.
    expect(find.text(ShareService.signatureLine('حصن المسلم')), findsOneWidget);
    expect(find.text(ShareService.appLine('حصن المسلم')), findsNothing);
    expect(find.text('برنامه توحید'), findsNothing);
    final logo = tester.widget<Image>(find.byType(Image));
    expect(logo.image, ShareCardLogo.providerFor(ShareCardLogo.defaultSize));
    expect(logo.height, ShareCardLogo.defaultSize);
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

  testWidgets('toggling off a block hides it from the image preview',
      (tester) async {
    await pumpShare(tester);

    expect(find.text('بِسْمِ اللَّهِ وَلَجْنَا...'), findsOneWidget);
    await tester.ensureVisible(find.text('در تصویر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('متن عربی').last);
    await tester.pumpAndSettle();
    expect(find.text('بِسْمِ اللَّهِ وَلَجْنَا...'), findsNothing);
  });
}
