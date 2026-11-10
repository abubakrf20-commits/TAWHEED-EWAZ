import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/announcements/domain/entities/announcement.dart';
import 'package:tawheeed/features/announcements/domain/repositories/announcements_repository.dart';
import 'package:tawheeed/features/announcements/presentation/providers/announcements_providers.dart';
import 'package:tawheeed/features/announcements/presentation/screens/announcements_screen.dart';
import 'package:tawheeed/shared/services/admin_gate.dart';

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
    if (throwOnSignIn) throw Exception('invalid-credential');
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
  Future<void> signOut() async => signOutCount++;
}

class _FakeAnnouncementsRepository implements AnnouncementsRepository {
  _FakeAnnouncementsRepository({
    List<Announcement>? seed,
    this.isAvailable = true,
  }) {
    if (seed != null) _items.addAll(seed);
  }

  final List<Announcement> _items = [];
  final _controller = StreamController<List<Announcement>>.broadcast();
  final List<String> published = [];
  final List<String> deletedIds = [];
  final Map<String, bool> pins = {};
  int publishCount = 0;

  /// آیا هنگام انتشار، اعلان push هم صف شود؟
  bool pushQueues = true;

  /// خطایی که [publish] باید پرتاب کند.
  Object? publishError;

  @override
  bool isAvailable;

  List<Announcement> _sorted() {
    final copy = List.of(_items);
    copy.sort((a, b) {
      final ap = pins[a.id] ?? a.isPinned;
      final bp = pins[b.id] ?? b.isPinned;
      if (ap != bp) return ap ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }

  void _emit() => _controller.add(_sorted());

  @override
  Stream<List<Announcement>> watchAll() async* {
    yield _sorted();
    yield* _controller.stream;
  }

  @override
  Future<AnnounceResult> publish({
    required String title,
    required String body,
  }) async {
    if (publishError != null) throw publishError!;
    publishCount++;
    published.add('$title|$body');
    _items.add(
      Announcement(
        id: 'n$publishCount',
        title: title.trim(),
        body: body.trim(),
        createdAt: DateTime.now(),
      ),
    );
    _emit();
    return AnnounceResult(id: 'n$publishCount', pushQueued: pushQueues);
  }

  @override
  Future<void> setPinned(String id, bool isPinned) async {
    pins[id] = isPinned;
    _emit();
  }

  final List<String> updated = [];
  Object? updateError;

  @override
  Future<void> update({
    required String id,
    required String title,
    required String body,
  }) async {
    if (updateError != null) throw updateError!;
    updated.add('$id|$title|$body');
    final index = _items.indexWhere((a) => a.id == id);
    if (index != -1) {
      _items[index] = Announcement(
        id: id,
        title: title.trim(),
        body: body.trim(),
        createdAt: _items[index].createdAt,
        isPinned: _items[index].isPinned,
      );
    }
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    _items.removeWhere((a) => a.id == id);
    _emit();
  }
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeAnnouncementsRepository repo,
  _FakeAdminGate? gate,
}) async {
  // پنل مدیریت پایین صفحه است؛ سطح نمایش بزرگ می‌شود تا ویجت‌های پایین
  // صفحه واقعاً ساخته شوند.
  await tester.binding.setSurfaceSize(const Size(1000, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        announcementsRepositoryProvider.overrideWithValue(repo),
        announcementsAdminGateProvider.overrideWithValue(
          gate ?? _FakeAdminGate(),
        ),
      ],
      child: const MaterialApp(home: AnnouncementsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// فیلدهای دیالوگ ورود مدیر (ایمیل و رمز).
Finder _adminDialogFields() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

Future<void> _fillAdminLogin(
  WidgetTester tester, {
  String email = 'admin@tawhid.app',
  String password = 'secret',
}) async {
  await tester.enterText(_adminDialogFields().at(0), email);
  await tester.enterText(_adminDialogFields().at(1), password);
}

Announcement _a(
  String id,
  String title, {
  String body = 'متن پیام',
  bool pinned = false,
  int minutesAgo = 0,
}) =>
    Announcement(
      id: id,
      title: title,
      body: body,
      createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
      isPinned: pinned,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AnnouncementsScreen — نمایش به کاربر', () {
    testWidgets('رندر اولیه شامل عنوان و پیام‌هاست', (tester) async {
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(seed: [_a('1', 'اولین پیام')]),
      );
      expect(find.text('پیام‌های مدیریت'), findsOneWidget);
      expect(find.text('اولین پیام'), findsOneWidget);
      expect(find.text('متن پیام'), findsOneWidget);
      expect(find.text('ورود به پنل مدیریت'), findsOneWidget);
    });

    testWidgets('پیام سنجاق‌شده نشان سنجاق می‌گیرد', (tester) async {
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(
          seed: [_a('1', 'پیام مهم', pinned: true)],
        ),
      );
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });

    testWidgets('متن بلند جمع می‌شود و با لمس «بیشتر» باز می‌شود',
        (tester) async {
      final longBody = 'متن طولانی برنامه ' * 50;
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(
          seed: [_a('1', 'پیام طولانی', body: longBody)],
        ),
      );
      expect(find.text('بیشتر'), findsOneWidget);
      expect(tester.widget<Text>(find.text(longBody)).maxLines, 3);

      await tester.tap(find.text('بیشتر'));
      await tester.pumpAndSettle();
      expect(find.text('بستن'), findsOneWidget);
      expect(tester.widget<Text>(find.text(longBody)).maxLines, isNull);

      await tester.tap(find.text('بستن'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text(longBody)).maxLines, 3);
    });

    testWidgets('فهرست خالی پیام راهنما نشان می‌دهد', (tester) async {
      await _pumpScreen(tester, repo: _FakeAnnouncementsRepository());
      expect(find.text('هنوز پیامی منتشر نشده است.'), findsWidgets);
    });

    testWidgets('وقتی Firebase در دسترس نیست: پیام و پنل غیرفعال می‌شوند', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(isAvailable: false),
      );
      expect(find.textContaining('در دسترس نیست'), findsWidgets);
      expect(find.text('ورود به پنل مدیریت'), findsNothing);
      // بنر صریح جای کارت بی‌رمق قبلی.
      expect(find.text('سرویس آنلاین در دسترس نیست'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });
  });

  group('AnnouncementsScreen — پنل مدیریت', () {
    testWidgets('اعتبارنامهٔ نادرست خطا می‌دهد و دسترسی باز نمی‌شود', (
      tester,
    ) async {
      final gate = _FakeAdminGate(throwOnSignIn: true);
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(seed: [_a('1', 'پیام محرمانه')]),
        gate: gate,
      );

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await _fillAdminLogin(tester, password: '0000');
      await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
      await tester.pumpAndSettle();

      expect(gate.signInCount, 1);
      expect(find.textContaining('ورود ناموفق بود'), findsOneWidget);
      expect(find.text('پیام جدید'), findsNothing);
    });

    testWidgets('حساب غیرمدیر: خطای دسترسی و بسته ماندن پنل', (tester) async {
      final gate = _FakeAdminGate(result: false);
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(),
        gate: gate,
      );

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await _fillAdminLogin(tester, email: 'user@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
      await tester.pumpAndSettle();

      expect(find.text('این حساب دسترسی مدیر ندارد.'), findsOneWidget);
      expect(find.text('پیام جدید'), findsNothing);
    });

    testWidgets('ورود مدیر: دکمهٔ پیام جدید باز می‌شود', (tester) async {
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(),
        gate: _FakeAdminGate(),
      );

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await _fillAdminLogin(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
      await tester.pumpAndSettle();

      expect(find.text('پیام جدید'), findsOneWidget);
    });

    testWidgets('ورود با حساب گوگل: مدیر وارد می‌شود', (tester) async {
      final gate = _FakeAdminGate();
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(),
        gate: gate,
      );

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ورود با حساب گوگل'));
      await tester.pumpAndSettle();

      expect(gate.googleSignInCount, 1);
      // رمز اصلاً پرسیده نشد — همان مسیر گوگلِ حساب و پشتیبان.
      expect(gate.signInCount, 0);
      expect(find.text('پیام جدید'), findsOneWidget);
    });

    testWidgets('حساب گوگل غیرمدیر: پیام خطا و بسته ماندن پنل', (tester) async {
      final gate = _FakeAdminGate(googleResult: false);
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(),
        gate: gate,
      );

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ورود با حساب گوگل'));
      await tester.pumpAndSettle();

      expect(gate.googleSignInCount, 1);
      expect(find.text('این حساب دسترسی مدیر ندارد.'), findsOneWidget);
      expect(find.text('پیام جدید'), findsNothing);
    });

    testWidgets('خطای گوگل پیام قابل‌فهم می‌دهد و پنل را باز نمی‌کند',
        (tester) async {
      final gate = _FakeAdminGate(throwOnGoogle: true);
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(),
        gate: gate,
      );

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ورود با حساب گوگل'));
      await tester.pumpAndSettle();

      expect(gate.googleSignInCount, 1);
      expect(find.text('ورود با گوگل ناموفق بود؛ دوباره تلاش کنید.'),
          findsOneWidget);
      expect(find.text('پیام جدید'), findsNothing);
    });

    testWidgets('بستن انتخاب‌گر گوگل خطایی نشان نمی‌دهد', (tester) async {
      final gate = _FakeAdminGate(googleResult: null);
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(),
        gate: gate,
      );

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ورود با حساب گوگل'));
      await tester.pumpAndSettle();

      expect(gate.googleSignInCount, 1);
      // دیالوگ باز می‌ماند و هیچ پیام خطایی ندارد.
      expect(find.text('ورود با حساب گوگل'), findsOneWidget);
      expect(find.textContaining('ناموفق'), findsNothing);
      expect(find.text('این حساب دسترسی مدیر ندارد.'), findsNothing);
      expect(find.text('پیام جدید'), findsNothing);
    });

    testWidgets('انتشار پیام جدید', (tester) async {
      final repo = _FakeAnnouncementsRepository();
      await _pumpScreen(tester, repo: repo, gate: _FakeAdminGate());

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await _fillAdminLogin(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('پیام جدید'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'عنوان'),
        'تعمیرات برنامه',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'متن پیام'),
        'امشب ساعت ۲ بامداد',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'انتشار'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.publishCount, 1);
      expect(repo.published.single, 'تعمیرات برنامه|امشب ساعت ۲ بامداد');
      expect(find.text('تعمیرات برنامه'), findsWidgets);
      // انتشار مستقیم از اپ: فقط پیامِ داخل برنامه نوشته می‌شود.
      expect(find.text('پیام منتشر شد.'), findsWidgets);
    });

    testWidgets(
      'خطای دسترسی Firestore به کاربر گفته می‌شود، نه «دوباره تلاش کنید»',
      (tester) async {
        // ریشهٔ گزارش «پیام‌ها ارسال نمی‌شه»: قوانین امنیتی نوشتن را رد می‌کردند
        // اما رابط کاربری فقط یک پیام عمومی نشان می‌داد، پس نه کاربر می‌فهمید
        // چه شده و نه توسعه‌دهنده. حالا دلیل واقعی نمایش داده می‌شود.
        final repo = _FakeAnnouncementsRepository()
          ..publishError = const AnnouncementsWriteError(
            AnnouncementsFailure.permissionDenied,
          );
        await _pumpScreen(tester, repo: repo, gate: _FakeAdminGate());

        await tester.tap(find.text('ورود به پنل مدیریت'));
        await tester.pumpAndSettle();
        await _fillAdminLogin(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('پیام جدید'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'عنوان'),
          'تعمیرات برنامه',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'متن پیام'),
          'متن آزمایشی',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'انتشار'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // نه پیام مبهم قبلی...
        expect(find.text('انتشار ناموفق بود؛ دوباره تلاش کنید.'), findsNothing);
        // ...بلکه راهنمای عملیِ قوانین/دسترسی.
        expect(
          find.textContaining('firebase deploy --only firestore:rules'),
          findsOneWidget,
        );
      },
    );

    testWidgets('انتشار مستقیم موفق اعلام می‌شود حتی اگر push در دسترس نباشد', (
      tester,
    ) async {
      // انتشار «مستقیم از اپ» به Cloud Function وابسته نیست؛ پیام فقط در
      // `announcements` نوشته می‌شود و اعلان push دیگر تعیین‌کنندهٔ نتیجه نیست.
      final repo = _FakeAnnouncementsRepository()..pushQueues = false;
      await _pumpScreen(tester, repo: repo, gate: _FakeAdminGate());

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await _fillAdminLogin(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('پیام جدید'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'عنوان'),
        'تعمیرات برنامه',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'متن پیام'),
        'متن آزمایشی',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'انتشار'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.publishCount, 1);
      expect(find.text('پیام منتشر شد.'), findsWidgets);
      // پیام واقعاً در فهرست هست.
      expect(find.text('تعمیرات برنامه'), findsWidgets);
    });

    testWidgets('ویرایش پیام با دیالوگ پیش‌پر شده', (tester) async {
      final repo = _FakeAnnouncementsRepository(
        seed: [_a('1', 'عنوان اول', body: 'متن اول')],
      );
      await _pumpScreen(tester, repo: repo, gate: _FakeAdminGate(active: true));

      await tester.ensureVisible(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('ویرایش پیام'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'عنوان').last,
        'عنوان جدید',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'متن پیام').last,
        'متن جدید',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.updated, ['1|عنوان جدید|متن جدید']);
      expect(find.text('عنوان جدید'), findsWidgets);
      expect(find.text('متن جدید'), findsWidgets);
      expect(find.text('پیام ویرایش شد.'), findsWidgets);
    });

    testWidgets('دیالوگ ویرایش خالی ذخیره نمی‌کند و پیام می‌دهد',
        (tester) async {
      final repo = _FakeAnnouncementsRepository(seed: [_a('1', 'عنوان اول')]);
      await _pumpScreen(tester, repo: repo, gate: _FakeAdminGate(active: true));

      await tester.ensureVisible(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'عنوان').last, '');
      await tester.enterText(
          find.widgetWithText(TextField, 'متن پیام').last, '');
      await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
      await tester.pumpAndSettle();

      expect(repo.updated, isEmpty);
      expect(find.text('هم عنوان و هم متن پیام لازم است.'), findsOneWidget);
    });

    testWidgets('خطای دسترسی Firestore هنگام ویرایش به کاربر گفته می‌شود', (
      tester,
    ) async {
      final repo = _FakeAnnouncementsRepository(
        seed: [_a('1', 'عنوان اول')],
      )..updateError = const AnnouncementsWriteError(
          AnnouncementsFailure.permissionDenied,
        );
      await _pumpScreen(tester, repo: repo, gate: _FakeAdminGate(active: true));

      await tester.ensureVisible(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.updated, isEmpty);
      expect(
        find.textContaining('firebase deploy --only firestore:rules'),
        findsOneWidget,
      );
    });

    testWidgets('دیالوگ خالی منتشر نمی‌کند و پیام می‌دهد', (tester) async {
      final repo = _FakeAnnouncementsRepository();
      await _pumpScreen(tester, repo: repo, gate: _FakeAdminGate());

      await tester.tap(find.text('ورود به پنل مدیریت'));
      await tester.pumpAndSettle();
      await _fillAdminLogin(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('پیام جدید'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'انتشار'));
      await tester.pumpAndSettle();

      expect(repo.publishCount, 0);
      expect(find.text('هم عنوان و هم متن پیام لازم است.'), findsOneWidget);
    });

    testWidgets('کلید سنجاق، پیام را بالای فهرست می‌برد', (tester) async {
      final repo = _FakeAnnouncementsRepository(
        seed: [
          _a('1', 'پیام قدیمی', minutesAgo: 30),
          _a('2', 'پیام جدید', minutesAgo: 1),
        ],
      );
      await _pumpScreen(tester, repo: repo, gate: _FakeAdminGate(active: true));

      final toggle = find.byType(Switch).first;
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.pins['2'], isTrue);
      // پیام تازه حالا سنجاق شده و باید بالاتر از پیام قدیمی باشد.
      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(
        titles.indexOf('پیام جدید'),
        lessThan(titles.indexOf('پیام قدیمی')),
      );
    });

    testWidgets('حذف پیام با تأیید', (tester) async {
      final repo = _FakeAnnouncementsRepository(seed: [_a('1', 'پیام موقتی')]);
      await _pumpScreen(tester, repo: repo, gate: _FakeAdminGate(active: true));

      await tester.ensureVisible(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('برای همیشه حذف شود'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
      await tester.pumpAndSettle();

      expect(repo.deletedIds, ['1']);
      expect(find.text('پیام موقتی'), findsNothing);
    });

    testWidgets('دکمهٔ قفل پنل را می‌بندد', (tester) async {
      final gate = _FakeAdminGate(active: true);
      await _pumpScreen(
        tester,
        repo: _FakeAnnouncementsRepository(),
        gate: gate,
      );

      expect(find.text('پیام جدید'), findsOneWidget);

      await tester.ensureVisible(find.text('قفل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('قفل'));
      await tester.pumpAndSettle();

      expect(gate.signOutCount, 1);
      expect(find.text('پیام جدید'), findsNothing);
      expect(find.text('ورود به پنل مدیریت'), findsOneWidget);
    });
  });
}
