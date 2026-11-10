import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/account/data/repositories/account_repository.dart';
import 'package:tawheeed/features/account/domain/entities/cloud_backup_item.dart';
import 'package:tawheeed/features/account/presentation/providers/account_providers.dart';
import 'package:tawheeed/features/account/presentation/screens/account_screen.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/services/backup_service.dart';

import '../../../../core/database/mock_daos.dart';

/// In-memory [AccountRepository] so the screen can be driven without Firebase.
/// Every cloud call is recorded; failures are injected with the `fail*` fields.
class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({this.email});

  String? email;
  final List<CloudBackupItem> backups = [];
  Object? failUpload;
  String? downloadPath;
  File? lastUploadedFile;
  int uploadCalls = 0;
  int listCalls = 0;
  int deleteCalls = 0;
  String? resetEmail;
  int deleteAccountCalls = 0;

  @override
  Stream<String?> authStateChanges() => Stream<String?>.value(email);

  @override
  String? get currentAccountLabel => email;

  @override
  Future<String> signUpWithEmail(String email, String password) async {
    this.email = email;
    return 'uid-1';
  }

  @override
  Future<String> signInWithEmail(String email, String password) async {
    this.email = email;
    return 'uid-1';
  }

  String? lastGoogleIdToken;
  int googleSignInCalls = 0;

  @override
  Future<String?> signInWithGoogle({String? idToken}) async {
    googleSignInCalls++;
    lastGoogleIdToken = idToken;
    return 'uid-google';
  }

  @override
  Future<void> signOut() async {
    email = null;
  }

  @override
  Future<String> uploadBackup(File zip, {String? displayName}) async {
    if (failUpload != null) throw failUpload!;
    uploadCalls++;
    lastUploadedFile = zip;
    final name = displayName ?? p.basename(zip.path);
    backups.insert(
      0,
      CloudBackupItem(
        name: name,
        sizeBytes: zip.lengthSync(),
        updated: DateTime.now(),
      ),
    );
    return name;
  }

  @override
  Future<List<CloudBackupItem>> listBackups(Directory tempDir) async {
    listCalls++;
    return List<CloudBackupItem>.of(backups);
  }

  @override
  Future<String> downloadBackup(CloudBackupItem item, Directory tempDir) async {
    return downloadPath ?? '';
  }

  @override
  Future<void> deleteBackup(CloudBackupItem item) async {
    deleteCalls++;
    backups.removeWhere((b) => b.name == item.name);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls++;
    email = null;
    backups.clear();
  }
}

/// A real, valid backup ZIP carrying `restore_probe` with two rows.
Future<List<int>> _validBackupZip(Directory tempDir) async {
  final sourcePath = p.join(tempDir.path, 'account_backup_source.sqlite');
  final source = sqlite3.open(sourcePath);
  source.execute('CREATE TABLE restore_probe ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, v TEXT)');
  source.execute("INSERT INTO restore_probe (v) VALUES ('from-backup-1')");
  source.execute("INSERT INTO restore_probe (v) VALUES ('from-backup-2')");
  source.execute('VACUUM');
  source.close();
  final dbBytes = await File(sourcePath).readAsBytes();

  final archive = Archive();
  final meta = utf8.encode(jsonEncode({
    'format_version': 2,
    'version': '1.0.0',
    'buildNumber': '1',
    'date': '2026-01-01',
    'app': 'tawheeed',
    'schema_version': AppDatabase.currentSchemaVersion,
  }));
  archive.addFile(ArchiveFile('backup_meta.json', meta.length, meta));
  archive.addFile(ArchiveFile('app.sqlite', dbBytes.length, dbBytes));
  // A production backup always carries preferences.json beside the database;
  // without it the restore completeness check (< 2 sections) would reject an
  // otherwise valid backup, so the fixture mirrors the real shape.
  final prefsBytes = utf8.encode(jsonEncode({'probe_key': 'probe_value'}));
  archive
      .addFile(ArchiveFile('preferences.json', prefsBytes.length, prefsBytes));
  final manifest = utf8.encode(jsonEncode({
    'format_version': 2,
    'files': {
      'app.sqlite': sha256.convert(dbBytes).toString(),
      'preferences.json': sha256.convert(prefsBytes).toString(),
    },
  }));
  archive
      .addFile(ArchiveFile('backup_manifest.json', manifest.length, manifest));
  return ZipEncoder().encode(archive);
}

Future<String> _writeZip(
    Directory tempDir, String name, List<int> bytes) async {
  final file = File(p.join(tempDir.path, name));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const pkgChannel = MethodChannel('dev.fluttercommunity.plus/package_info');
  // the restore path reads the device backup key from the Keystore before it
  // touches a file; with no plugin behind the channel the safety copy fails
  // and the flow can end without ever showing its verdict.
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStore = <String, String>{};
  late Directory tempDir;
  late AppDatabase liveDb;
  late String corruptZipPath;
  late String encryptedZipPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_account');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory' ||
          call.method == 'getTemporaryDirectory') {
        return tempDir.path;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pkgChannel, (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'توحید',
          'packageName': 'com.tawheeed',
          'version': '1.2.3',
          'buildNumber': '45',
          'buildSignature': '',
        };
      }
      return null;
    });

    secureStore.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
      final args =
          (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return secureStore[key];
        case 'write':
          secureStore[key!] = args['value'] as String? ?? '';
          return null;
        case 'containsKey':
          return secureStore.containsKey(key);
        case 'delete':
          secureStore.remove(key);
          return null;
      }
      return null;
    });

    // All real dart:io work lives here (plain zone): inside `testWidgets`
    // only `tester.runAsync` ever lets those futures complete.
    await File(p.join(tempDir.path, 'app.sqlite')).writeAsString('db-bytes');
    final plainZip = await _validBackupZip(tempDir);
    await _writeZip(tempDir, 'valid.zip', plainZip);
    encryptedZipPath = await _writeZip(
      tempDir,
      'encrypted.zip',
      await BackupService.encryptBackupBytes(plainZip, '1234'),
    );
    corruptZipPath =
        await _writeZip(tempDir, 'corrupt.zip', utf8.encode('not a zip'));

    liveDb = AppDatabase.withConnection(NativeDatabase.memory());
    await liveDb.customStatement('CREATE TABLE restore_probe ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, v TEXT)');
    await liveDb
        .customStatement("INSERT INTO restore_probe (v) VALUES ('live-only')");
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pkgChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
    await liveDb.close();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } on FileSystemException {
        // A handle opened during the test may still be closing; give the OS a
        // moment, then report which entry is still locked so leaks are visible.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final locked = <String>[];
        for (final entity in tempDir.listSync(recursive: true)) {
          try {
            entity.deleteSync(recursive: true);
          } on FileSystemException catch (e) {
            locked.add('${entity.path}: ${e.message}');
          }
        }
        if (tempDir.existsSync()) {
          fail('temp dir not fully deleted; locked: ${locked.join(', ')}');
        }
      }
    }
  });

  Widget wrap(AccountRepository repo) {
    return ProviderScope(
      overrides: [
        accountRepositoryProvider.overrideWithValue(repo),
        appDatabaseProvider.overrideWithValue(liveDb),
      ],
      child: const MaterialApp(home: AccountScreen()),
    );
  }

  Future<List<String>?> probeValues(WidgetTester tester) {
    return tester.runAsync(() async => (await liveDb
            .customSelect('SELECT v FROM restore_probe ORDER BY id')
            .get())
        .map((row) => row.read<String>('v'))
        .toList());
  }

  /// Real dart:io futures only complete under [tester.runAsync]; alternate
  /// runAsync delays with pumps so the I/O started by the app can finish
  /// (same convention as hadeeth_enc_screen_test). The screen's busy spinner
  /// is the signal that async work is still outstanding: keep flushing until
  /// it has been gone for a few rounds (with a warm-up floor so a spinner
  /// that only appears after the first I/O is not mistaken for "done").
  ///
  /// When [until] is given it is the ONLY thing that may end the wait early:
  /// the widget it names (a dialog, a snackbar) appears after an await on a
  /// plugin reply, and the tree looks perfectly idle in between — under the
  /// load of a full-suite run that gap is longer than any idle heuristic, so
  /// returning on "idle" made the next tap miss the dialog.
  Future<void> flushIo(WidgetTester tester, {Finder? until}) async {
    var idle = 0;
    for (var i = 0; i < 160; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
      if (i >= 8 && until != null && until.evaluate().isNotEmpty) return;
      if (until != null) continue;
      final busy = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      idle = busy ? 0 : idle + 1;
      if (i >= 10 && idle >= 3) return;
    }
  }

  /// Settle the tree, but never hang on a spinner that is legitimately
  /// waiting for user input (e.g. the backup-password dialog).
  Future<void> settle(WidgetTester tester) async {
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 350));
    }
  }

  /// Let queued snackbars play out so no timer survives the test.
  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  /// End-to-end upload: export the zip, push it to the fake cloud, refresh.
  /// The upload first offers the optional backup password — these tests take
  /// the passwordless path.
  Future<void> uploadBackup(WidgetTester tester) async {
    await tester.ensureVisible(find.text('پشتیبان‌گیری ابری برنامه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پشتیبان‌گیری ابری برنامه'));
    await flushIo(tester, until: find.byType(AlertDialog));
    await settle(tester);
    await tester.tap(find.text('ادامه بدون رمز'));
    await flushIo(tester, until: find.byType(SnackBar));
    await settle(tester);
  }

  Future<void> confirmRestoreDialog(WidgetTester tester,
      {Finder? until}) async {
    await tester.tap(find.text('بازیابی'));
    // The confirmation body first awaits one Keystore read (the «اطلاعات من»
    // caveat), so let that plugin reply land before looking for the dialog.
    await flushIo(tester, until: find.byType(AlertDialog));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('بازیابی'),
      ),
    );
    await flushIo(tester, until: until); // download + restore do real I/O
    await settle(tester);
  }

  Future<void> enterBackupPassword(WidgetTester tester, String password) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      password,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('بازیابی'),
      ),
    );
    await flushIo(tester, until: find.byType(SnackBar));
    await settle(tester);
  }

  group('account cloud backup (audit H1)', () {
    testWidgets('signed-in user uploads a real zip and the list refreshes',
        (tester) async {
      final repo = _FakeAccountRepository(email: 'user@example.com');

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('پشتیبان‌گیری ابری برنامه'), findsOneWidget);
      expect(
        find.text('هنوز نسخه‌ای آپلود نشده است. «پشتیبان‌گیری ابری» را بزنید.'),
        findsOneWidget,
      );

      await uploadBackup(tester);

      expect(find.text('نسخهٔ پشتیبان در ابر ذخیره شد.'), findsOneWidget);
      expect(repo.uploadCalls, 1);
      expect(repo.lastUploadedFile, isNotNull);
      expect(repo.lastUploadedFile!.existsSync(), isTrue,
          reason: 'the uploaded zip must be a real file on disk');
      expect(repo.listCalls, greaterThanOrEqualTo(1),
          reason: 'the cloud list is refreshed after a successful upload');
      expect(repo.backups, hasLength(1));
      await drainSnackbars(tester);
    });

    testWidgets('upload with a password encrypts the zip', (tester) async {
      final repo = _FakeAccountRepository(email: 'user@example.com');

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('پشتیبان‌گیری ابری برنامه'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('پشتیبان‌گیری ابری برنامه'));
      await flushIo(tester, until: find.byType(AlertDialog));
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'secret123',
      );
      await tester.tap(find.text('ادامه با رمز'));
      await flushIo(tester, until: find.byType(SnackBar));
      await settle(tester);

      expect(repo.uploadCalls, 1);
      // Real dart:io needs runAsync under the fake-async test zone.
      final bytes =
          await tester.runAsync(() => repo.lastUploadedFile!.readAsBytes());
      expect(BackupService.isEncryptedBackup(bytes!), isTrue,
          reason: 'the cloud zip must carry the magic header when locked');
      await drainSnackbars(tester);
    });

    testWidgets('a failed upload shows a Persian error and survives',
        (tester) async {      final repo = _FakeAccountRepository(email: 'user@example.com')
        ..failUpload = Exception('storage down');

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      await uploadBackup(tester);

      expect(repo.uploadCalls, 0);
      expect(find.text('آپلود ناموفق بود؛ دوباره تلاش کنید.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await drainSnackbars(tester);
    });

    testWidgets('signed-out state shows the sign-in entry card',
        (tester) async {
      final repo = _FakeAccountRepository();

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('ورود با حساب گوگل'), findsOneWidget);
      expect(find.text('پشتیبان‌گیری ابری برنامه'), findsNothing);
      expect(find.text('نسخه‌های ابری'), findsNothing);
    });

    testWidgets('a corrupt cloud backup fails and leaves live rows untouched',
        (tester) async {
      final repo = _FakeAccountRepository(email: 'user@example.com')
        ..downloadPath = corruptZipPath;

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      // Upload first: the screen only lists cloud copies after a refresh.
      await uploadBackup(tester);
      await drainSnackbars(tester);

      await tester.ensureVisible(find.text('بازیابی'));
      await tester.pumpAndSettle();
      await confirmRestoreDialog(tester, until: find.byType(SnackBar));

      expect(find.text('بازیابی ناموفق بود.'), findsOneWidget);
      expect(await probeValues(tester), ['live-only'],
          reason: 'a rejected backup must not touch live rows');
      await drainSnackbars(tester);
    });

    testWidgets(
        'an encrypted backup prompts for the password: wrong rejected, right restores',
        (tester) async {
      final repo = _FakeAccountRepository(email: 'user@example.com')
        ..downloadPath = encryptedZipPath;

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      // Upload first so the cloud list has an entry to restore from.
      await uploadBackup(tester);
      await drainSnackbars(tester);

      await tester.ensureVisible(find.text('بازیابی'));
      await tester.pumpAndSettle();

      // First attempt: the screen must ask for the password.
      await confirmRestoreDialog(tester, until: find.byType(AlertDialog));
      expect(find.text('رمز پشتیبان'), findsOneWidget);

      await enterBackupPassword(tester, 'wrong-password');
      expect(find.text('بازیابی ناموفق بود.'), findsOneWidget);
      expect(await probeValues(tester), ['live-only'],
          reason: 'a wrong password must not modify any live row');
      await drainSnackbars(tester);

      // Second attempt with the right password restores the backup rows.
      await tester.ensureVisible(find.text('بازیابی'));
      await tester.pumpAndSettle();
      await confirmRestoreDialog(tester, until: find.byType(AlertDialog));
      expect(find.text('رمز پشتیبان'), findsOneWidget);
      await enterBackupPassword(tester, '1234');

      // The post-restore repair runs right after the success line, and in a
      // test binding its notification reschedule legitimately fails — it then
      // reports «بازیابی انجام شد، ولی …», which replaces the first snackbar.
      // Both carry the same verdict, so pin the verdict and the data, not the
      // second snackbar's wording.
      expect(find.textContaining('بازیابی انجام شد'), findsWidgets);
      expect(await probeValues(tester), ['from-backup-1', 'from-backup-2']);
      await drainSnackbars(tester);
    });
  });

  group('account deletion (Play Store requirement)', () {
    testWidgets('confirming the delete dialog deletes the account once',
        (tester) async {
      final repo = _FakeAccountRepository(email: 'user@example.com');

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      // The delete row lives at the bottom of the hub page; scroll the lazy
      // list until it materializes instead of assuming it is built.
      await tester.scrollUntilVisible(
          find.text('حذف حساب کاربری'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف حساب کاربری'));
      await flushIo(tester, until: find.byType(AlertDialog));
      expect(find.text('حذف قطعی'), findsOneWidget);

      await tester.tap(find.text('حذف قطعی'));
      await flushIo(tester, until: find.byType(SnackBar));

      expect(repo.deleteAccountCalls, 1);
      expect(find.text('حساب کاربری حذف شد.'), findsOneWidget);
      await drainSnackbars(tester);
    });

    testWidgets('cancelling the delete dialog keeps the account',
        (tester) async {
      final repo = _FakeAccountRepository(email: 'user@example.com');

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
          find.text('حذف حساب کاربری'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف حساب کاربری'));
      await flushIo(tester, until: find.byType(AlertDialog));

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('لغو'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.deleteAccountCalls, 0);
    });
  });

  group('unified hub: local backup, transfer and danger zone', () {
    Widget wrapHub(
      _FakeAccountRepository repo, [
      MockSettingsRepository? settings,
    ]) {
      return ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(repo),
          appDatabaseProvider.overrideWithValue(liveDb),
          settingsRepositoryProvider.overrideWith(
              (ref) async => settings ?? MockSettingsRepository()),
        ],
        child: const MaterialApp(home: AccountScreen()),
      );
    }

    /// Tall viewport lays the whole hub out in one pass (the repo idiom from
    /// the settings audit test), so rows below the fold need no scrolling.
    Future<void> pumpHub(WidgetTester tester, _FakeAccountRepository repo,
        [MockSettingsRepository? settings]) async {
      tester.view.physicalSize = const Size(412, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrapHub(repo, settings));
      await tester.pumpAndSettle();
    }

    /// Real async work (sqlite transaction, file deletes, plugin replies)
    /// only completes under runAsync; pump between slices like the cloud
    /// tests' flushIo, then settle once the busy spinner is gone.
    Future<void> flushWipe(WidgetTester tester) async {
      for (var i = 0; i < 120; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
        if (i >= 10 &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
    }

    testWidgets('signed-out hub shows local, transfer and danger rows',
        (tester) async {
      await pumpHub(tester, _FakeAccountRepository());

      for (final label in [
        'پشتیبان‌گیری در این گوشی',
        'پشتیبان‌گیری روزانه',
        'ایجاد پشتیبان کامل',
        'بازگردانی آخرین پشتیبان خودکار',
        'بازگردانی از فایل',
        'انتقال تنظیمات',
        'خروجی گرفتن از تنظیمات',
        'دریافت از فایل',
        'منطقه خطر',
        'بازنشانی تنظیمات به پیش‌فرض',
        'پاک‌سازی کامل دستگاه',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // No Firebase identity, so the cloud delete row stays hidden.
      expect(find.text('حذف حساب کاربری'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('{ایجاد پشتیبان کامل} opens the creation password dialog',
        (tester) async {
      await pumpHub(tester, _FakeAccountRepository());

      await tester.tap(find.text('ایجاد پشتیبان کامل'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('رمز اختیاری پشتیبان'), findsOneWidget);
      expect(find.text('ادامه'), findsOneWidget);

      // Dismiss without side effects.
      await tester.tap(find.text('لغو'));
      await tester.pumpAndSettle();
      expect(find.text('رمز اختیاری پشتیبان'), findsNothing);
    });

    testWidgets(
        'the reset row restores defaults after confirmation, keeping onboarding '
        'and premium', (tester) async {
      final settings = MockSettingsRepository()
        ..setMockSettings(const AppSettings(
          themeMode: ThemeModeOption.dark,
          accentPreset: 'gold',
          hijriOffset: 5,
          onboardingCompleted: true,
          isPremium: true,
        ));
      await pumpHub(tester, _FakeAccountRepository(), settings);

      // Cancelling the dialog changes nothing.
      await tester.tap(find.text('بازنشانی تنظیمات به پیش‌فرض'));
      await tester.pumpAndSettle();
      expect(find.text('بازنشانی تنظیمات'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'لغو'));
      await tester.pumpAndSettle();
      expect(settings.getMockSettings().themeMode, ThemeModeOption.dark);

      // Confirming returns every preference to its factory default.
      await tester.tap(find.text('بازنشانی تنظیمات به پیش‌فرض'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'بازنشانی'));
      await tester.pumpAndSettle();
      // resetPreferences now re-arms the native alarms: the 350 ms debounce,
      // then the scheduler's 1.2 s coalesce window — pump past both so no
      // timer outlives the test.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 2));

      final saved = settings.getMockSettings();
      expect(saved.themeMode, ThemeModeOption.light);
      expect(saved.accentPreset, 'night');
      expect(saved.hijriOffset, 2);
      // Not preferences: a reset must never drop onboarding or premium.
      expect(saved.onboardingCompleted, isTrue);
      expect(saved.isPremium, isTrue);
    });

    testWidgets('dismissing the first wipe dialog wipes nothing',
        (tester) async {
      SharedPreferences.setMockInitialValues({'wipe_probe': 'stay'});
      await pumpHub(tester, _FakeAccountRepository());

      await tester.tap(find.text('پاک‌سازی کامل دستگاه'));
      await tester.pumpAndSettle();
      expect(find.text('پاک‌سازی کامل دستگاه'), findsWidgets);

      await tester.tap(find.widgetWithText(TextButton, 'لغو'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wipe_probe'), 'stay');
      expect(await probeValues(tester), ['live-only']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirming both wipe dialogs empties prefs and tables',
        (tester) async {
      SharedPreferences.setMockInitialValues({'wipe_probe': 'gone'});
      FlutterSecureStorage.setMockInitialValues({'saved_lat': '35.7'});
      const notifChannel =
          MethodChannel('dexterous.com/flutter/local_notifications');
      const exactChannel = MethodChannel('com.tawheeed/exact_reminders');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notifChannel, (call) async => true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(exactChannel, (call) async => null);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(notifChannel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(exactChannel, null);
      });

      await pumpHub(tester, _FakeAccountRepository());

      await tester.tap(find.text('پاک‌سازی کامل دستگاه'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'ادامه'));
      await tester.pumpAndSettle();
      expect(find.text('آخرین هشدار'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'پاک‌سازی قطعی'));
      await flushWipe(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(await probeValues(tester), isEmpty);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'saved_lat'), isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
