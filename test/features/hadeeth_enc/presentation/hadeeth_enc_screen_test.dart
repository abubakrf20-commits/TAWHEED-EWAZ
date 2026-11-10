import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/screens/hadeeth_enc_screen.dart';
import 'package:tawheeed/features/hadeeth_enc/services/hadeeth_enc_db_service.dart';

/// Real dart:io futures only complete under [tester.runAsync]; this helper
/// alternates runAsync delays with pumps so async init can finish.
Future<void> _flushIo(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  Future<void> createFixture({required bool withCategory}) async {
    final file = File(p.join(tempDir.path, 'hadeeth_enc.db'));
    final db = sqlite3.open(file.path);
    try {
      db.execute('''
        CREATE TABLE hadiths (
          id INTEGER,
          title_ar TEXT,
          title TEXT,
          text_ar TEXT,
          text TEXT,
          explanation TEXT,
          benefits TEXT,
          grade TEXT,
          takhrij TEXT,
          link TEXT${withCategory ? ',\n          category TEXT,\n          cat_main INTEGER' : ''}
        );
        INSERT INTO hadiths VALUES
          (1, 'حديث أول', 'حديث اول فارسي', 'نص عربي أول',
           'متن فارسی اول', 'شرح اول', 'منافع اول', 'صحیح', 'منبع اول',
           ''${withCategory ? ", 'فقه عبادات', 4" : ''}),
          (2, 'حديث ثان', 'حديث دوم فارسي', 'نص عربي ثان',
           'متن فارسی دوم', 'شرح دوم', 'منافع دوم', 'حسن', 'منبع دوم',
           ''${withCategory ? ", 'فقه خانواده', 4" : ''});
      ''');
    } finally {
      db.close();
    }
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_enc_screen');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  tearDown(() async {
    HadeethEncDbService().close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('with a categorized db on disk shows the topic chips',
      (tester) async {
    await createFixture(withCategory: true);
    await tester.pumpWidget(const MaterialApp(home: HadeethEncScreen()));
    await _flushIo(tester);

    expect(find.text('موسوعه احادیث'), findsOneWidget);
    expect(find.text('همه موضوع‌ها'), findsOneWidget);
    expect(find.text('قرآن و علوم قرآنی'), findsOneWidget);
    expect(find.text('فقه و اصول'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('without a database shows the download gate', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HadeethEncScreen()));
    await _flushIo(tester);

    expect(find.text('موسوعه احادیث'), findsWidgets);
    expect(find.text('دانلود داده‌ها'), findsOneWidget);
    expect(find.textContaining('2٫1 مگابایت'), findsOneWidget);
    expect(find.textContaining('کاملاً آفلاین'), findsOneWidget);
    expect(find.text('همه موضوع‌ها'), findsNothing);
  });
}
