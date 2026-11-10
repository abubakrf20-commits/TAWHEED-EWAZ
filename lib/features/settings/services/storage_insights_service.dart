import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tawheeed/features/fatwa/services/fatwa_service.dart';
import 'package:tawheeed/features/hadeeth_enc/services/hadeeth_enc_db_service.dart';
import 'package:tawheeed/features/hadith/services/hadith_db_service.dart';
import 'package:tawheeed/features/quran/services/quran_storage.dart';
import 'package:tawheeed/features/riyad/services/riyad_service.dart';
import 'package:tawheeed/features/taraghib/services/taraghib_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// One measured row on the «مدیریت فضا» page.
class StorageItemUsage {
  const StorageItemUsage({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.bytes,
    required this.clearable,
  });

  final String id;
  final String title;
  final String subtitle;
  final int bytes;

  /// Whether the row can be cleared from this page. Only data the app can
  /// fetch again qualifies — the downloaded content databases included.
  /// Personal data and backups never are: they exist nowhere else, so they
  /// stay in their own sections.
  final bool clearable;
}

/// A titled group of [StorageItemUsage] rows.
class StorageGroupUsage {
  const StorageGroupUsage({required this.title, required this.items});

  final String title;
  final List<StorageItemUsage> items;

  int get bytes => items.fold(0, (sum, item) => sum + item.bytes);
}

/// The whole measured picture shown by the storage page.
class StorageReport {
  const StorageReport({required this.groups});

  final List<StorageGroupUsage> groups;

  int get totalBytes => groups.fold(0, (sum, group) => sum + group.bytes);
}

/// Every on-device root the page measures. Resolved once per refresh; the
/// measuring isolate only ever walks plain strings.
class StoragePaths {
  const StoragePaths({
    required this.documents,
    required this.support,
    required this.quranContent,
  });

  final String documents;
  final String support;
  final String quranContent;

  String get recitationAudio => p.join(quranContent, 'audio_mp3quran');
  String get translationAudio => p.join(quranContent, 'audio_translation');
  String get booksData => p.join(documents, 'books_data');
  String get hadithDatabase => p.join(documents, 'hadith.db');
  String get ryadDatabase => p.join(documents, 'ryadalsalihin.db');
  String get taraghibDatabase => p.join(documents, 'taraghib.db');
  String get fatwaDatabase => p.join(documents, 'fatwas.db');
  String get hadeethEncDatabase => p.join(documents, 'hadeeth_enc.db');
  String get audioLibrary => p.join(documents, 'audio_library');
  String get ruqyahAudio => p.join(documents, 'ruqyah_audio');
  String get attachments => p.join(documents, 'app_data');
  String get backups => p.join(documents, 'backups');
  String get customAzans => p.join(documents, 'custom_azans');
  String get logFile => p.join(documents, 'tawheed_log.txt');
  String get legacyLogFile => p.join(documents, 'trayheed_log.txt');
  String get diagnostics => p.join(documents, 'database_diagnostics');
  String get quranCache => p.join(support, 'quran_cache');
  String get dorarCache => p.join(support, 'dorar_cache.db');
}

class _StorageItemSpec {
  const _StorageItemSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.paths,
    this.excluded = const [],
    this.clearable = false,
    this.downloadPath,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> paths;
  final List<String> excluded;
  final bool clearable;

  /// The file the user actually downloaded, when it differs from what the row
  /// measures. A hadith database is stored gzipped beside its unpacked copy,
  /// and the unpacked copy is several times larger, so the row names both
  /// figures instead of leaving the download size implicit.
  ///
  /// It stays out of [paths] on purpose: [paths] is what the row owns and what
  /// `clear` verifies afterwards, and counting the archive there would report
  /// every download twice.
  final String? downloadPath;
}

class _StorageGroupSpec {
  const _StorageGroupSpec(this.title, this.items);

  final String title;
  final List<_StorageItemSpec> items;
}

/// Measures the storage the app itself owns and clears the parts that are
/// pure, re-downloadable caches.
///
/// The walk runs in an isolate: a phone with a full talaawah library holds
/// tens of thousands of tiny mp3 files, and doing that traversal on the UI
/// thread would drop frames the moment the page opens.
///
/// There is deliberately no free-device-space figure: the app has no
/// platform API for it (the Quran sheet's `freeSpaceMb` is always null), so
/// promising one here would mean a new dependency or a native channel.
class StorageInsightsService {
  StorageInsightsService({
    Future<StoragePaths> Function()? pathsResolver,
    Map<String, Future<void> Function()>? contentDeletes,
  })  : _pathsResolver = pathsResolver ?? _resolvePaths,
        _contentDeletes = contentDeletes;

  final Future<StoragePaths> Function() _pathsResolver;

  /// Test seam: replaces every content-database delete with fakes. The real
  /// map routes each row through its owning service.
  final Map<String, Future<void> Function()>? _contentDeletes;

  /// A content database is deleted through the service that owns it: it
  /// closes the open sqlite handle and clears the stored content revision, so
  /// the next visit offers a fresh download instead of reading a ghost file.
  static final Map<String, Future<void> Function()> _defaultContentDeletes = {
    'hadith.books': HadithDbService.deleteDownloaded,
    'hadith.riyad': () => RiyadService().deleteDownloaded(),
    'hadith.taraghib': () => TaraghibService().deleteDownloaded(),
    'hadith.fatwa': () => FatwaService().deleteDownloaded(),
    'hadith.encyclopedia': () => HadeethEncDbService().deleteDownloaded(),
  };

  static Future<StoragePaths> _resolvePaths() async {
    final documents = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    final quranContent = await QuranStorage.contentDir();
    return StoragePaths(
      documents: documents.path,
      support: support.path,
      quranContent: quranContent.path,
    );
  }

  Future<StorageReport> measure() async {
    final paths = await _pathsResolver();
    final specs = _specs(paths);
    final sizes = await Isolate.run(() {
      final result = <String, int>{};
      for (final group in specs) {
        for (final item in group.items) {
          var total = 0;
          for (final path in item.paths) {
            total += _measurePath(path, item.excluded);
          }
          result[item.id] = total;
          final archive = item.downloadPath;
          if (archive != null) {
            result['${item.id}.download'] = _measurePath(archive, const []);
          }
        }
      }
      return result;
    });
    return StorageReport(
      groups: [
        for (final group in specs)
          StorageGroupUsage(
            title: group.title,
            items: [
              for (final item in group.items)
                StorageItemUsage(
                  id: item.id,
                  title: item.title,
                  subtitle: _subtitleFor(item, sizes),
                  bytes: sizes[item.id] ?? 0,
                  clearable: item.clearable,
                ),
            ],
          ),
      ],
    );
  }

  /// A hadith row's figure counts the unpacked, indexed copy — several times
  /// the archive the user downloaded — so the row names both. With no archive
  /// on disk (a row that was never downloaded) the original wording stands.
  static String _subtitleFor(_StorageItemSpec item, Map<String, int> sizes) {
    if (item.downloadPath == null) return item.subtitle;
    final download = sizes['${item.id}.download'] ?? 0;
    if (download <= 0) return item.subtitle;
    final used = sizes[item.id] ?? 0;
    final archive = NumberFormat.formatBytes(download);
    final total = NumberFormat.formatBytes(used);
    return '${item.subtitle}\nحجم دانلود $archive · فضای اشغال‌شده $total';
  }

  /// Deletes the data behind [id]. Returns false for an unknown or
  /// non-clearable row, and logs (never rethrows) a filesystem failure.
  Future<bool> clear(String id) async {
    final paths = await _pathsResolver();
    final _StorageItemSpec? spec = _specOf(_specs(paths), id);
    if (spec == null || !spec.clearable) return false;
    final contentDelete = (_contentDeletes ?? _defaultContentDeletes)[id];
    final Future<void> Function()? action = contentDelete ??
        switch (id) {
          'quran.recitation' => () => _deleteDirectory(paths.recitationAudio),
          'quran.translation' => () => _deleteDirectory(paths.translationAudio),
          'books.data' => () => _deleteDirectory(paths.booksData),
          'media.audioLibrary' => () => _deleteDirectory(paths.audioLibrary),
          'media.ruqyah' => () => _deleteDirectory(paths.ruqyahAudio),
          'caches.quran' => () => _deleteDirectory(paths.quranCache),
          'caches.diagnostics' => () => _deleteDirectory(paths.diagnostics),
          'caches.logs' => () async {
              await _deleteFile(paths.logFile);
              await _deleteFile(paths.legacyLogFile);
            },
          _ => null,
        };
    if (action == null) return false;
    try {
      await action();
      // A content service logs and swallows its own delete failure, so success
      // is the absence of bytes — never the absence of an exception.
      final leftover = spec.paths
          .fold<int>(0, (sum, path) => sum + _measurePath(path, spec.excluded));
      return leftover == 0;
    } catch (e) {
      AppLogger.warning('storage_insights', 'clear $id failed: $e');
      return false;
    }
  }

  static _StorageItemSpec? _specOf(
      List<_StorageGroupSpec> groups, String id) {
    for (final group in groups) {
      for (final item in group.items) {
        if (item.id == id) return item;
      }
    }
    return null;
  }

  static List<_StorageGroupSpec> _specs(StoragePaths paths) => [
        _StorageGroupSpec('قرآن و تلاوت', [
          _StorageItemSpec(
            id: 'quran.recitation',
            title: 'تلاوت آفلاین',
            subtitle:
                'آیه‌های دانلودشدهٔ قاریان؛ با پخش دوباره از نو ذخیره می‌شود.',
            paths: [paths.recitationAudio],
            clearable: true,
          ),
          _StorageItemSpec(
            id: 'quran.translation',
            title: 'ترجمهٔ صوتی آفلاین',
            subtitle:
                'فایل‌های صوتی ترجمهٔ آیات؛ با پخش دوباره از نو ذخیره می‌شود.',
            paths: [paths.translationAudio],
            clearable: true,
          ),
          _StorageItemSpec(
            id: 'quran.content',
            title: 'متن، ترجمه و تفسیر',
            subtitle: 'فایل‌های محتوای مصحف؛ از بخش مصحف مدیریت می‌شود.',
            paths: [paths.quranContent],
            excluded: [paths.recitationAudio, paths.translationAudio],
          ),
        ]),
        _StorageGroupSpec('کتاب‌ها و حدیث', [
          _StorageItemSpec(
            id: 'books.data',
            title: 'کتاب‌های دانلودشده',
            subtitle:
                'نسخهٔ آفلاین کتاب‌ها؛ هنگام مطالعه دوباره دانلود می‌شود.',
            paths: [paths.booksData],
            clearable: true,
          ),
          _StorageItemSpec(
            id: 'hadith.books',
            title: 'کتب حدیث',
            subtitle:
                'دادهٔ ۱۷ کتاب حدیث؛ از بخش «کتب حدیث» یا همین‌جا دوباره دانلود می‌شود.',
            paths: [paths.hadithDatabase],
            clearable: true,
            downloadPath: '${paths.hadithDatabase}.gz',
          ),
          _StorageItemSpec(
            id: 'hadith.riyad',
            title: 'ریاض الصالحین',
            subtitle: 'شرح و ترجمهٔ ریاض الصالحین؛ از بخش خودش هم دانلود می‌شود.',
            paths: [paths.ryadDatabase],
            clearable: true,
            downloadPath: '${paths.ryadDatabase}.gz',
          ),
          _StorageItemSpec(
            id: 'hadith.taraghib',
            title: 'صحیح الترغیب',
            subtitle:
                'صحیح الترغیب و الترهیب؛ از بخش خودش هم دانلود می‌شود.',
            paths: [paths.taraghibDatabase],
            clearable: true,
            downloadPath: '${paths.taraghibDatabase}.gz',
          ),
          _StorageItemSpec(
            id: 'hadith.fatwa',
            title: 'فتاوای شرعی',
            subtitle: 'پرسش‌وپاسخ‌های فقهی؛ از بخش خودش هم دانلود می‌شود.',
            paths: [paths.fatwaDatabase],
            clearable: true,
            downloadPath: '${paths.fatwaDatabase}.gz',
          ),
          _StorageItemSpec(
            id: 'hadith.encyclopedia',
            title: 'موسوعه احادیث',
            subtitle:
                'احادیث با ترجمه و شرح؛ از بخش خودش هم دانلود می‌شود.',
            paths: [paths.hadeethEncDatabase],
            clearable: true,
            downloadPath: '${paths.hadeethEncDatabase}.gz',
          ),
        ]),
        _StorageGroupSpec('رسانه', [
          _StorageItemSpec(
            id: 'media.audioLibrary',
            title: 'کتابخانهٔ صوتی',
            subtitle: 'سخنرانی‌های دانلودشده؛ هنگام پخش دوباره دانلود می‌شود.',
            paths: [paths.audioLibrary],
            clearable: true,
          ),
          _StorageItemSpec(
            id: 'media.ruqyah',
            title: 'صدای رقیه',
            subtitle: 'فایل‌های صوتی رقیه؛ هنگام پخش دوباره دانلود می‌شود.',
            paths: [paths.ruqyahAudio],
            clearable: true,
          ),
        ]),
        _StorageGroupSpec('داده‌های شخصی', [
          _StorageItemSpec(
            id: 'personal.attachments',
            title: 'پیوست‌های اطلاعات من',
            subtitle: 'عکس‌ها و مدرک‌ها؛ فقط از داخل «اطلاعات من» حذف کنید.',
            paths: [paths.attachments],
          ),
          _StorageItemSpec(
            id: 'personal.backups',
            title: 'پشتیبان‌های محلی',
            subtitle: 'نسخه‌های پشتیبان این گوشی؛ بازیابی از «حساب و پشتیبان».',
            paths: [paths.backups],
          ),
          _StorageItemSpec(
            id: 'personal.azans',
            title: 'اذان‌های انتخابی',
            subtitle: 'فایل‌هایی که خودتان برای اذان انتخاب کرده‌اید.',
            paths: [paths.customAzans],
          ),
        ]),
        _StorageGroupSpec('کش و گزارش‌ها', [
          _StorageItemSpec(
            id: 'caches.quran',
            title: 'کش داده‌های قرآن',
            subtitle: 'پاسخ‌های ذخیره‌شدهٔ شبکه؛ خودکار بازسازی می‌شود.',
            paths: [paths.quranCache],
            clearable: true,
          ),
          _StorageItemSpec(
            id: 'caches.diagnostics',
            title: 'گزارش‌های تشخیصی',
            subtitle:
                'نسخه‌های پشتیبان پایگاه‌داده که پس از خطا ذخیره شده‌اند.',
            paths: [paths.diagnostics],
            clearable: true,
          ),
          _StorageItemSpec(
            id: 'caches.logs',
            title: 'فایل گزارش برنامه',
            subtitle: 'گزارش خطاهای اخیر؛ با پاک شدن، دوباره ساخته می‌شود.',
            paths: [paths.logFile, paths.legacyLogFile],
            clearable: true,
          ),
          _StorageItemSpec(
            id: 'caches.dorar',
            title: 'کش جست‌وجوی درر',
            subtitle: 'کش جست‌وجوی حدیث؛ خودکار مدیریت می‌شود.',
            paths: [paths.dorarCache],
          ),
        ]),
      ];

  static int _measurePath(String path, List<String> excluded) {
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.file) return File(path).lengthSync();
      if (type != FileSystemEntityType.directory) return 0;
      return _measureDir(Directory(path), excluded);
    } catch (_) {
      // Unreadable (permissions, removed SD card): report nothing rather
      // than failing the whole page.
      return 0;
    }
  }

  static int _measureDir(Directory dir, List<String> excluded) {
    var total = 0;
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      // A subdirectory removed mid-walk contributes nothing.
      return 0;
    }
    for (final entity in entries) {
      final path = entity.path;
      if (excluded.any(
          (root) => path == root || path.startsWith('$root${p.separator}'))) {
        continue;
      }
      if (entity is Directory) {
        total += _measureDir(entity, excluded);
      } else if (entity is File) {
        try {
          total += entity.lengthSync();
        } catch (_) {
          // File removed between listing and stat — skip it.
        }
      }
    }
    return total;
  }

  static Future<void> _deleteDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;
    await dir.delete(recursive: true);
  }

  static Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return;
    await file.delete();
  }
}
