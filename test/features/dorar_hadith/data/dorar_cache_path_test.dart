import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// `CacheDatabase` از barrel عمومی پکیج export نشده؛ همین کلاس تنها نقطه‌ای
// است که مسیر کش را نگه می‌دارد، پس برای بستن رگرسیون باید مستقیم دیده شود.
// ignore: implementation_imports
import 'package:dorar_hadith/src/database/cache_database.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:tawheeed/features/dorar_hadith/data/datasources/dorar_remote_datasource.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String supportPath;
  _FakePathProvider(this.supportPath);

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('مسیر کش درر', () {
    late Directory supportDir;
    late File cwdCacheDb;
    late bool cwdCacheExistedBefore;

    setUpAll(() async {
      final original = PathProviderPlatform.instance;
      supportDir = await Directory.systemTemp.createTemp('dorar_cache_path');
      PathProviderPlatform.instance = _FakePathProvider(supportDir.path);
      addTearDown(() => PathProviderPlatform.instance = original);
      // Directory.current در تست همان ریشهٔ مخزن است؛ ممکن است به‌خاطر اجرای
      //های قبلی همین باگ فایلی از آن باقی مانده باشد، پس وضعیت اولیه‌اش را
      //ثبت می‌کنیم و فقط «تغییر نکردن» را می‌سنجیم.
      cwdCacheDb =
          File('${Directory.current.path}${Platform.pathSeparator}cache.db');
      cwdCacheExistedBefore = cwdCacheDb.existsSync();
      await configureDorarCache();
    });

    tearDownAll(() async {
      if (await supportDir.exists()) await supportDir.delete(recursive: true);
    });

    test('کش داخل پوشهٔ پشتیبان برنامه باز می‌شود، نه ریشهٔ کاری', () async {
      final db = CacheDatabase();
      addTearDown(db.close);
      // باز کردن واقعی کانکشن: LazyDatabase تا اولین query فایل نمی‌سازد.
      await db.customSelect('SELECT 1').get();

      final configured = File(
        '${supportDir.path}${Platform.pathSeparator}dorar_cache.db',
      );
      expect(
        configured.existsSync(),
        isTrue,
        reason: 'کش باید در getApplicationSupportDirectory ساخته شود؛ '
            'مسیر پیش‌فرض پکیج (Directory.current/cache.db) روی Android '
            'قابل نوشتن نیست و هر جست‌وجو را می‌شکند.',
      );
      expect(
        cwdCacheDb.existsSync(),
        cwdCacheExistedBefore,
        reason: 'هیچ کانکشنی نباید به cache.db ریشهٔ کاری باز شود.',
      );
    });

    test('فراخوانی همزمان configureDorarCache یک بار کار می‌کند', () async {
      // پرچم سادهٔ bool بین «شروع» و «اتمام» بازه داشت؛ این تست تضمین می‌کند
      // فراخوانی‌های موازی startup و provider به یک کار می‌رسند و خطا نمی‌دهند.
      await expectLater(
        Future.wait([configureDorarCache(), configureDorarCache()]),
        completes,
      );
      final db = CacheDatabase();
      addTearDown(db.close);
      await expectLater(db.customSelect('SELECT 1').get(), completes);
    });
  });
}
