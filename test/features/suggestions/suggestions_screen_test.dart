import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/services/admin_gate.dart';
import 'package:tawheeed/features/suggestions/data/suggestion_device_tag.dart';
import 'package:tawheeed/features/suggestions/domain/entities/suggestion.dart';
import 'package:tawheeed/features/suggestions/domain/repositories/suggestions_repository.dart';
import 'package:tawheeed/features/suggestions/presentation/providers/suggestions_providers.dart';
import 'package:tawheeed/features/suggestions/presentation/screens/suggestions_screen.dart';

/// دروازهٔ مدیر جعلی: نتیجهٔ ورود قابل پیکربندی (برای تست بدون Firebase).
class _FakeAdminGate implements AdminGate {
  _FakeAdminGate({
    this.result = true,
    this.throwOnSignIn = false,
    this.active = false,
    this.googleResult = true,
    this.throwOnGoogle = false,
  });

  bool result;
  bool throwOnSignIn;
  bool active;

  /// نتیجهٔ ورود گوگل؛ `null` یعنی کاربر انتخابگر را بست.
  bool? googleResult;
  bool throwOnGoogle;
  int signInCount = 0;
  int googleSignInCount = 0;
  int signOutCount = 0;

  @override
  Future<bool> signIn(String email, String password) async {
    signInCount++;
    if (throwOnSignIn) {
      throw Exception('email-already-in-use');
    }
    return result;
  }

  @override
  Future<bool?> signInWithGoogle() async {
    googleSignInCount++;
    if (throwOnGoogle) throw Exception('google-failed');
    return googleResult;
  }

  @override
  Future<bool> isAdminActive() async => active;

  @override
  Future<void> signOut() async {
    signOutCount++;
  }
}

/// مخزن جعلی درون‌حافظه‌ای برای تست بدون نیاز به Firebase.
class _FakeSuggestionsRepository implements SuggestionsRepository {
  _FakeSuggestionsRepository(
      {List<Suggestion>? seed, this.isAvailable = true}) {
    if (seed != null) _items.addAll(seed);
  }

  final List<Suggestion> _items = [];
  final _controller = StreamController<List<Suggestion>>.broadcast();
  int submitCount = 0;
  String? lastText;
  String? lastName;
  SuggestionCategory? lastCategory;
  final List<String> deletedIds = [];
  final Map<String, String> replies = {};
  final Map<String, bool> publicFlags = {};
  String myDeviceTag = 'aabbccdd';

  @override
  bool isAvailable;

  @override
  Stream<List<Suggestion>> watchAll() async* {
    yield List.of(_items);
    yield* _controller.stream;
  }

  @override
  Stream<List<Suggestion>> watchMine() async* {
    final mine = _items.where((s) => s.deviceTag == myDeviceTag).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    yield mine;
    yield* _controller.stream.map((_) =>
        _items.where((s) => s.deviceTag == myDeviceTag).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Stream<List<Suggestion>> watchPublic() async* {
    List<Suggestion> pub() =>
        _items.where((s) => publicFlags[s.id] ?? s.isPublic).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    yield pub();
    yield* _controller.stream.map((_) => pub());
  }

  @override
  Future<void> submit({
    required String text,
    SuggestionCategory category = SuggestionCategory.suggestion,
    String? name,
  }) async {
    submitCount++;
    lastText = text;
    lastName = name;
    lastCategory = category;
    _items.insert(
      0,
      Suggestion(
        id: 's$submitCount',
        text: text,
        category: category,
        deviceTag: myDeviceTag,
        createdAt: DateTime.now(),
        name: name?.trim() ?? '',
      ),
    );
    _controller.add(List.of(_items));
  }

  @override
  Future<void> reply(String id, String text) async {
    replies[id] = text.trim();
    _replace(
      id,
      (s) => Suggestion(
        id: s.id,
        text: s.text,
        category: s.category,
        deviceTag: s.deviceTag,
        createdAt: s.createdAt,
        name: s.name,
        reply: text.trim(),
        repliedAt: DateTime.now(),
        isPublic: s.isPublic,
      ),
    );
  }

  @override
  Future<void> setPublic(String id, bool isPublic) async {
    publicFlags[id] = isPublic;
    _replace(
      id,
      (s) => Suggestion(
        id: s.id,
        text: s.text,
        category: s.category,
        deviceTag: s.deviceTag,
        createdAt: s.createdAt,
        name: s.name,
        reply: s.reply,
        repliedAt: s.repliedAt,
        isPublic: isPublic,
      ),
    );
  }

  void _replace(String id, Suggestion Function(Suggestion) build) {
    final i = _items.indexWhere((s) => s.id == id);
    if (i == -1) return;
    _items[i] = build(_items[i]);
    _controller.add(List.of(_items));
  }

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    _items.removeWhere((s) => s.id == id);
    _controller.add(List.of(_items));
  }
}

Future<void> _pumpScreen(WidgetTester tester,
    {required _FakeSuggestionsRepository repo, _FakeAdminGate? gate}) async {
  // صفحهٔ پیشنهاد با بخش‌های «پیشنهادهای من» و «پیشنهادهای عمومی» از ارتفاع
  // پیش‌فرض تست بلندتر شده است؛ سطح نمایش را بزرگ می‌کنیم تا ویجت‌های پایین
  // صفحه واقعاً ساخته شوند و تست قابل اتکا بماند.
  await tester.binding.setSurfaceSize(const Size(1000, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        suggestionsRepositoryProvider.overrideWithValue(repo),
        if (gate != null) adminGateProvider.overrideWithValue(gate),
      ],
      child: const MaterialApp(home: SuggestionsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// فیلدهای داخل دیالوگ ورود مدیر (ایمیل و رمز).
Finder _adminDialogFields() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

/// فیلد متن پیشنهاد (برچسبش همیشه رندر می‌شود، پس یاب پایدار است).
Finder _messageField() => find.widgetWithText(TextField, 'متن پیشنهاد');

/// فیلد نام اختیاری فرستنده.
Finder _nameField() => find.widgetWithText(TextField, 'نام شما (اختیاری)');

Future<void> _fillAdminLogin(WidgetTester tester,
    {String email = 'admin@tawhid.app', String password = 'secret'}) async {
  await tester.enterText(_adminDialogFields().at(0), email);
  await tester.enterText(_adminDialogFields().at(1), password);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SuggestionsScreen — ارسال پیشنهاد', () {
    testWidgets('رندر اولیه شامل فرم و بخش‌هاست', (tester) async {
      await _pumpScreen(tester, repo: _FakeSuggestionsRepository());
      expect(find.text('ارسال پیشنهاد'), findsWidgets);
      expect(find.text('موضوع پیام'), findsOneWidget);
      expect(find.text('نام شما (اختیاری)'), findsOneWidget);
      expect(find.text('پیشنهاد'), findsWidgets); // ChoiceChip برچسب
      expect(find.text('گزارش مشکل'), findsOneWidget);
      expect(find.text('ورود به پنل مدیریت'), findsOneWidget);
      expect(find.text('پیشنهادهای من'), findsOneWidget);
      expect(find.text('پیشنهادهای عمومی'), findsOneWidget);
    });

    testWidgets('متن خالی ارسال نمی‌شود و پیام هشدار می‌آید', (tester) async {
      final repo = _FakeSuggestionsRepository();
      await _pumpScreen(tester, repo: repo);
      await tester.tap(find.widgetWithText(FilledButton, 'ارسال پیشنهاد'));
      await tester.pump();
      expect(repo.submitCount, 0);
      expect(
          find.textContaining('لطفاً متن پیشنهاد را بنویسید'), findsOneWidget);
    });

    testWidgets('ارسال موفق: دسته + متن → مخزن صدا زده می‌شود', (tester) async {
      final repo = _FakeSuggestionsRepository();
      await _pumpScreen(tester, repo: repo);

      await tester.tap(find.text('گزارش مشکل'));
      await tester.pumpAndSettle();
      await tester.enterText(_messageField(), 'دکمهٔ اشتراک‌گذاری کار نمی‌کند');
      await tester.tap(find.widgetWithText(FilledButton, 'ارسال پیشنهاد'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 1);
      expect(repo.lastText, 'دکمهٔ اشتراک‌گذاری کار نمی‌کند');
      expect(repo.lastCategory, SuggestionCategory.bug);
      expect(find.textContaining('با موفقیت ارسال شد'), findsOneWidget);
    });

    testWidgets('نام اختیاری ارسال می‌شود و فرم پاک می‌شود', (tester) async {
      final repo = _FakeSuggestionsRepository();
      await _pumpScreen(tester, repo: repo);

      await tester.enterText(_nameField(), 'ابوبکر');
      await tester.enterText(_messageField(), 'افزودن ترجمهٔ ترجمه‌ها');
      await tester.tap(find.widgetWithText(FilledButton, 'ارسال پیشنهاد'));
      await tester.pumpAndSettle();

      expect(repo.lastName, 'ابوبکر');
      expect(find.textContaining('با موفقیت ارسال شد'), findsOneWidget);
      // فیلدها برای پیام بعدی خالی می‌شوند
      expect(tester.widget<TextField>(_messageField()).controller?.text, '');
      expect(tester.widget<TextField>(_nameField()).controller?.text, '');
    });

    testWidgets('بدون نام هم ارسال می‌شود (نام واقعاً اختیاری است)',
        (tester) async {
      final repo = _FakeSuggestionsRepository();
      await _pumpScreen(tester, repo: repo);

      await tester.enterText(_messageField(), 'پیشنهاد بی‌نام');
      await tester.tap(find.widgetWithText(FilledButton, 'ارسال پیشنهاد'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 1);
      expect(repo.lastName, '');
    });

    testWidgets('وقتی Firebase در دسترس نیست: ارسال و پنل غیرفعال می‌شوند',
        (tester) async {
      final repo = _FakeSuggestionsRepository(isAvailable: false);
      await _pumpScreen(tester, repo: repo);

      await tester.enterText(_messageField(), 'پیام تست');
      await tester.tap(find.widgetWithText(FilledButton, 'ارسال پیشنهاد'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 0);
      expect(find.textContaining('در دسترس نیست'), findsWidgets);
      expect(find.text('ورود به پنل مدیریت'), findsNothing);
      // بنر صریح «سرویس آنلاین در دسترس نیست» به‌جای سکوت کامل نمایش داده
      // می‌شود تا کاربر دلیل را همان ابتدا بداند.
      // دو بنر: یکی بالای فرم، یکی کنار بخش پنل مدیریت.
      expect(find.text('سرویس آنلاین در دسترس نیست'), findsNWidgets(2));
      expect(find.byIcon(Icons.cloud_off_outlined), findsNWidgets(2));
    });
  });

  group('SuggestionsScreen — پنل مدیریت', () {
    // دستگاهِ متفاوت از این دستگاه، تا در «پیشنهادهای من» ظاهر نشود.
    final seed = [
      Suggestion(
        id: 'a',
        text: 'بهترین برنامهٔ اسلامی تا الان',
        category: SuggestionCategory.suggestion,
        deviceTag: 'ffff1111',
        createdAt: DateTime.now(),
        name: 'سامان',
      ),
    ];

    testWidgets('اعتبارنامه‌ی نادرست پیام خطا می‌دهد و دسترسی باز نمی‌شود',
        (tester) async {
      final gate = _FakeAdminGate(throwOnSignIn: true);
      await _pumpScreen(tester,
          repo: _FakeSuggestionsRepository(seed: seed), gate: gate);

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await _fillAdminLogin(tester, password: '0000');
      await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
      await tester.pumpAndSettle();

      expect(gate.signInCount, 1);
      expect(find.text('ورود ناموفق بود؛ ایمیل یا رمز را بررسی کنید.'),
          findsOneWidget);
      expect(find.text('بهترین برنامهٔ اسلامی تا الان'), findsNothing);
    });

    testWidgets('حساب غیرمدیر: خطای دسترسی و بسته ماندن پنل', (tester) async {
      final gate = _FakeAdminGate(result: false);
      await _pumpScreen(tester,
          repo: _FakeSuggestionsRepository(seed: seed), gate: gate);

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await _fillAdminLogin(tester,
          email: 'user@example.com', password: 'anypass');
      await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
      await tester.pumpAndSettle();

      expect(find.text('این حساب دسترسی مدیر ندارد.'), findsOneWidget);
      expect(find.text('بهترین برنامهٔ اسلامی تا الان'), findsNothing);
    });

    testWidgets('ورود با حساب گوگل: پنل بدون رمز باز می‌شود', (tester) async {
      final gate = _FakeAdminGate();
      await _pumpScreen(tester,
          repo: _FakeSuggestionsRepository(seed: seed), gate: gate);

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ورود با حساب گوگل'));
      await tester.pumpAndSettle();

      expect(gate.googleSignInCount, 1);
      expect(gate.signInCount, 0);
      expect(find.text('پنل مدیریت'), findsOneWidget);
      expect(find.text('بهترین برنامهٔ اسلامی تا الان'), findsOneWidget);
    });

    testWidgets('حساب گوگل غیرمدیر: خطای دسترسی و بسته ماندن پنل',
        (tester) async {
      final gate = _FakeAdminGate(googleResult: false);
      await _pumpScreen(tester,
          repo: _FakeSuggestionsRepository(seed: seed), gate: gate);

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ورود با حساب گوگل'));
      await tester.pumpAndSettle();

      expect(find.text('این حساب دسترسی مدیر ندارد.'), findsOneWidget);
      expect(find.text('بهترین برنامهٔ اسلامی تا الان'), findsNothing);
    });

    testWidgets('خطای گوگل پیام می‌دهد و پنل بسته می‌ماند', (tester) async {
      final gate = _FakeAdminGate(throwOnGoogle: true);
      await _pumpScreen(tester,
          repo: _FakeSuggestionsRepository(seed: seed), gate: gate);

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ورود با حساب گوگل'));
      await tester.pumpAndSettle();

      expect(gate.googleSignInCount, 1);
      expect(find.text('ورود با گوگل ناموفق بود؛ دوباره تلاش کنید.'),
          findsOneWidget);
      expect(find.text('بهترین برنامهٔ اسلامی تا الان'), findsNothing);
    });

    testWidgets('بستن انتخاب‌گر گوگل بی‌صدا می‌گذرد', (tester) async {
      final gate = _FakeAdminGate(googleResult: null);
      await _pumpScreen(tester,
          repo: _FakeSuggestionsRepository(seed: seed), gate: gate);

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ورود با حساب گوگل'));
      await tester.pumpAndSettle();

      expect(gate.googleSignInCount, 1);
      expect(find.text('ورود با حساب گوگل'), findsOneWidget);
      expect(find.textContaining('ناموفق'), findsNothing);
      expect(find.text('بهترین برنامهٔ اسلامی تا الان'), findsNothing);
    });

    testWidgets('ورود مدیر: لیست پیشنهادها و حذف با تأیید کار می‌کند',
        (tester) async {
      final repo = _FakeSuggestionsRepository(seed: seed);
      final gate = _FakeAdminGate();
      await _pumpScreen(tester, repo: repo, gate: gate);

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await _fillAdminLogin(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
      await tester.pumpAndSettle();

      expect(find.text('پنل مدیریت'), findsOneWidget);
      expect(find.text('بهترین برنامهٔ اسلامی تا الان'), findsOneWidget);

      // حذف با تأیید
      await tester.ensureVisible(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.textContaining('برای همیشه حذف شود'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
      await tester.pumpAndSettle();

      expect(repo.deletedIds, ['a']);
      expect(find.text('هنوز پیشنهادی ارسال نشده است.'), findsOneWidget);
    });

    testWidgets('پنل با دکمهٔ قفل مجدداً بسته می‌شود', (tester) async {
      final repo = _FakeSuggestionsRepository(seed: seed);
      final gate = _FakeAdminGate();
      await _pumpScreen(tester, repo: repo, gate: gate);

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await _fillAdminLogin(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('قفل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('قفل'));
      await tester.pumpAndSettle();

      expect(gate.signOutCount, 1);
      expect(find.text('بهترین برنامهٔ اسلامی تا الان'), findsNothing);
      expect(find.text('ورود به پنل مدیریت'), findsOneWidget);
    });

    testWidgets('جلسهٔ فعال مدیر: پنل بدون تایپ ایمیل/رمز باز می‌شود',
        (tester) async {
      final repo = _FakeSuggestionsRepository(seed: seed);
      final gate = _FakeAdminGate(active: true);
      await _pumpScreen(tester, repo: repo, gate: gate);

      expect(find.text('پنل مدیریت'), findsOneWidget);
      expect(find.text('بهترین برنامهٔ اسلامی تا الان'), findsOneWidget);
      expect(find.text('ورود به پنل مدیریت'), findsNothing);
    });

    testWidgets('نام فرستنده در پنل نمایش داده می‌شود', (tester) async {
      await _pumpScreen(tester,
          repo: _FakeSuggestionsRepository(seed: seed),
          gate: _FakeAdminGate(active: true));
      expect(find.text('از سامان'), findsOneWidget);
    });

    testWidgets('مدیر می‌تواند پاسخ بدهد', (tester) async {
      final repo = _FakeSuggestionsRepository(seed: seed);
      await _pumpScreen(tester, repo: repo, gate: _FakeAdminGate(active: true));

      await tester.ensureVisible(find.byIcon(Icons.reply));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.reply));
      await tester.pumpAndSettle();

      expect(find.text('پاسخ به پیشنهاد'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, 'متن پاسخ'), 'ممنون از پیشنهادت');
      await tester.tap(find.widgetWithText(FilledButton, 'ثبت پاسخ'));
      // به‌جای pumpAndSettle: اسنک‌بار تا پایان مهلتش بسته می‌شود و از درخت
      // حذف می‌گردد، پس فقط ابتدای انیمیشنش را می‌سنجیم.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.replies['a'], 'ممنون از پیشنهادت');
      expect(find.text('پاسخ به پیشنهاد'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('پاسخ ثبت شد'), findsOneWidget);
    });

    testWidgets('کلید انتشار عمومی، پیشنهاد را عمومی می‌کند', (tester) async {
      final repo = _FakeSuggestionsRepository(seed: seed);
      await _pumpScreen(tester, repo: repo, gate: _FakeAdminGate(active: true));

      // برچسب «انتشار عمومی» هم‌نیا (sibling) کلید است، نه والد؛ پس خود کلید
      // را می‌گیریم (در پنل مدیریت فقط یک کلید وجود دارد).
      await tester.ensureVisible(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.publicFlags['a'], isTrue);
      expect(find.textContaining('منتشر شد'), findsOneWidget);
    });
  });

  group('SuggestionsScreen — پیشنهادهای من و عمومی', () {
    Suggestion mine(String id, String text,
            {String reply = '', bool isPublic = false}) =>
        Suggestion(
          id: id,
          text: text,
          category: SuggestionCategory.suggestion,
          deviceTag: 'aabbccdd',
          createdAt: DateTime.now(),
          name: 'ابوبکر',
          reply: reply,
          isPublic: isPublic,
        );

    testWidgets('پاسخ مدیر در «پیشنهادهای من» دیده می‌شود (مدیر وارد شده)', (
      tester,
    ) async {
      final repo = _FakeSuggestionsRepository(seed: [
        mine('m1', 'افزودن ترجمهٔ ترجمه‌ها', reply: 'حتماً انجام می‌دهیم')
      ]);
      await _pumpScreen(
        tester,
        repo: repo,
        gate: _FakeAdminGate(active: true),
      );

      expect(find.text('افزودن ترجمهٔ ترجمه‌ها'), findsWidgets);
      expect(find.text('پاسخ برنامه'), findsOneWidget);
      expect(find.text('حتماً انجام می‌دهیم'), findsWidgets);
    });

    testWidgets('بدون پاسخ: وضعیت «در انتظار پاسخ» نشان داده می‌شود', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repo: _FakeSuggestionsRepository(seed: [mine('m1', 'یک پیشنهاد')]),
        gate: _FakeAdminGate(active: true),
      );
      expect(find.text('در انتظار پاسخ برنامه…'), findsOneWidget);
    });

    testWidgets('پیشنهاد دیگران در «پیشنهادهای من» نیست', (tester) async {
      await _pumpScreen(tester,
          repo: _FakeSuggestionsRepository(seed: [
            Suggestion(
              id: 'other',
              text: 'پیشنهاد یک کاربر دیگر',
              category: SuggestionCategory.other,
              deviceTag: 'ffff1111',
              createdAt: DateTime.now(),
            ),
          ]));
      expect(find.text('هنوز پیشنهادی نفرستاده‌اید.'), findsOneWidget);
    });

    testWidgets('پس از ارسال، پیشنهاد بلافاصله در «پیشنهادهای من» دیده می‌شود',
        (
      tester,
    ) async {
      // کاربر عادی نمی‌تواند پیشنهادِ شخصی‌اش را از سرور بخواند؛ خودِ صفحه
      // آن را به‌صورت محلی نگه می‌دارد تا پیامش در «پیشنهادهای من» بماند.
      final repo = _FakeSuggestionsRepository();
      await _pumpScreen(tester, repo: repo);

      await tester.enterText(_messageField(), 'پیشنهاد لحظه‌ای من');
      await tester.tap(find.widgetWithText(FilledButton, 'ارسال پیشنهاد'));
      await tester.pumpAndSettle();

      expect(find.text('پیشنهاد لحظه‌ای من'), findsOneWidget);
      expect(find.text('در انتظار پاسخ برنامه…'), findsOneWidget);
    });

    testWidgets('فقط پیشنهادهای عمومی در بخش عمومی می‌آیند', (tester) async {
      // پیشنهاد عمومی از دستگاهی دیگر، فقط در بخش عمومی دیده می‌شود؛
      // پیشنهادِ شخصیِ این دستگاه (منتشرنشده) برای کاربر عادی در این نشست
      // دیده نمی‌شود تا به سرویس وابسته نباشد.
      await _pumpScreen(tester,
          repo: _FakeSuggestionsRepository(seed: [
            Suggestion(
              id: 'pub1',
              text: 'منتشرشده و عمومی',
              category: SuggestionCategory.suggestion,
              deviceTag: 'ffff1111',
              createdAt: DateTime.now(),
              name: 'سارا',
              isPublic: true,
            ),
            mine('m2', 'فقط برای خودم'),
          ]));
      expect(find.text('منتشرشده و عمومی'), findsOneWidget);
      expect(find.textContaining('سارا'), findsOneWidget);
      expect(find.text('فقط برای خودم'), findsNothing);
    });

    testWidgets('بخش عمومی خالی پیام راهنما نشان می‌دهد', (tester) async {
      await _pumpScreen(tester, repo: _FakeSuggestionsRepository());
      expect(find.text('هنوز پیشنهاد عمومی منتشر نشده است.'), findsOneWidget);
    });

    testWidgets('پیام بلند جمع می‌شود و با کلیک کامل باز و دوباره بسته می‌شود',
        (tester) async {
      const longText =
          'پیشنهاد می‌کنم بخشی برای یادآوری مطالعهٔ روزانه اضافه شود که هر روز مقدار مطالعهٔ قرآن و حدیث را ثبت کند و در پایان هفته خلاصه‌ای از پیشرفت هفتگی نشان دهد؛ این کار باعث می‌شود انگیزهٔ بیشتری برای ادامهٔ یادگیری داشته باشم و بتوانم عادت تلاوت روزانه را در برنامهٔ خود نگه دارم.';
      await _pumpScreen(tester,
          repo: _FakeSuggestionsRepository(seed: [
            Suggestion(
              id: 'pub1',
              text: longText,
              category: SuggestionCategory.suggestion,
              deviceTag: 'ffff1111',
              createdAt: DateTime.now(),
              isPublic: true,
            ),
          ]));

      // در حالت اولیه فقط دو خط دیده می‌شود و با یک لمس باز می‌شود.
      final collapsed = tester.widget<Text>(find.text(longText));
      expect(collapsed.maxLines, 2);
      expect(find.text('بیشتر'), findsOneWidget);

      // لمس → باز شدن کامل.
      await tester.tap(find.text('بیشتر'));
      await tester.pumpAndSettle();
      final expanded = tester.widget<Text>(find.text(longText));
      expect(expanded.maxLines, isNull);
      expect(find.text('بستن'), findsOneWidget);

      // لمس دوباره → بسته شدن.
      await tester.tap(find.text('بستن'));
      await tester.pumpAndSettle();
      final collapsedAgain = tester.widget<Text>(find.text(longText));
      expect(collapsedAgain.maxLines, 2);
      expect(find.text('بیشتر'), findsOneWidget);
    });

    testWidgets('پیام کوتاه بدون نشانهٔ «بیشتر» کامل رندر می‌شود',
        (tester) async {
      await _pumpScreen(tester,
          repo: _FakeSuggestionsRepository(seed: [
            Suggestion(
              id: 'pub2',
              text: 'پیام کوتاه',
              category: SuggestionCategory.suggestion,
              deviceTag: 'ffff1111',
              createdAt: DateTime.now(),
              isPublic: true,
            ),
          ]));
      expect(find.text('بیشتر'), findsNothing);
    });
  });

  group('SuggestionDeviceTag', () {
    test('شناسه تولید می‌شود و در جلسات بعد یکسان می‌ماند', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await SuggestionDeviceTag.get();
      expect(first.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(first), isTrue);

      // جلسهٔ بعدی — هم‌ارز «اجرای دوباره» با همان حافظه
      final second = await SuggestionDeviceTag.get();
      expect(second, first);
    });

    test('شناسهٔ موجود استفاده می‌شود', () async {
      SharedPreferences.setMockInitialValues(
          {'suggestion_device_tag': 'cafebabe'});
      expect(await SuggestionDeviceTag.get(), 'cafebabe');
    });
  });
}
