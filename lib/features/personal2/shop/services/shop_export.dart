import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_tables.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_tables.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// «CSV کامل» — every shop table as one CSV, zipped.
///
/// The stage-2 export was a PDF summary: readable, and useless to a shopkeeper
/// who wants to hand their numbers to an accountant or open them in a
/// spreadsheet. This dumps the *rows*, one file per table, with the database's
/// own column names as headers, so nothing has to be retyped and nothing is
/// lost in a rounded summary.
///
/// Two deliberate format choices:
///  * **UTF-8 with BOM.** Excel on Windows still reads `.csv` as CP1256
///    (the same encoding that produced the app's mojibake incident), so a
///    BOM-less Persian CSV opens as gibberish. The BOM costs three bytes and
///    is the difference between a usable file and a broken one. It is not the
///    [ShopCsv] import dialect — import never reads these files.
///  * **Raw units, unchanged.** Money stays integer rial, quantities stay
///    `*_milli` (1/1000), dates stay epoch milliseconds. The README in the
///    archive states every one of those, because a spreadsheet column of
///    `1500000` that the reader assumes is «۱٬۵۰۰٬۰۰۰ ریال» is the honest
///    number, while a "prettified" `1,500,000` is a CSV nobody can re-read.
class ShopCsvArchive {
  ShopCsvArchive._();

  /// All shop tables, stage 2 then stage 3, in schema order.
  static List<String> get tables => [
        ...ShopTables.allTables,
        ...Shop3Tables.allTables,
      ];

  /// Builds the ZIP in memory. CPU-bound (a few MB of CSV), so callers should
  /// not run this inside a build; the tab awaits it from a button handler.
  static Future<Uint8List> build(AppDatabase db) async {
    final archive = Archive();
    for (final table in tables) {
      final csv = await _tableCsv(db, table);
      // BOM + body: see the class comment for why the BOM is here.
      final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
      archive.addFile(ArchiveFile('$table.csv', bytes.length, bytes));
    }
    final readme = Uint8List.fromList(utf8.encode(_readme));
    archive.addFile(ArchiveFile('README.txt', readme.length, readme));
    final zipped = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipped);
  }

  /// Writes [bytes] to a temp file and hands it to the share sheet.
  ///
  /// Returns false when sharing failed (no share target, cancelled, or an IO
  /// error) so the tab can say so instead of pretending it exported.
  static Future<bool> share(Uint8List bytes, {required String fileName}) async {
    File? file;
    try {
      final dir = await Directory.systemTemp.createTemp('shop_csv');
      file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip')],
        subject: 'پشتیبان CSV حساب مغازه',
      ));
      return true;
    } catch (e) {
      AppLogger.warning('ShopCsvArchive', 'zip share failed: $e');
      return false;
    } finally {
      try {
        if (file != null && await file.exists()) {
          await file.parent.delete(recursive: true);
        }
      } catch (e) {
        // Temp storage is the OS's to reclaim; the export itself succeeded.
        AppLogger.debug('ShopCsvArchive', 'temp cleanup skipped: $e');
      }
    }
  }

  static Future<String> _tableCsv(AppDatabase db, String table) async {
    final rows = await db.customSelect('SELECT * FROM $table ORDER BY 1').get();
    if (rows.isEmpty) {
      // A header-only file still tells the reader the table exists and which
      // columns it has — an empty file reads like a failed export.
      final columns = await _columns(db, table);
      return '${columns.map(_field).join(',')}\n';
    }
    final buffer = StringBuffer();
    buffer.writeln(rows.first.data.keys.map(_field).join(','));
    for (final row in rows) {
      buffer.writeln(row.data.values.map(_cell).join(','));
    }
    return buffer.toString();
  }

  /// `PRAGMA table_info` — the column names of an empty table. Drift keeps its
  /// generated `TableInfo` for typed tables only; these are raw-SQL ones.
  static Future<List<String>> _columns(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return [for (final r in rows) r.read<String>('name')];
  }

  static String _cell(Object? value) => switch (value) {
        null => '',
        final String s => _field(s),
        final Uint8List bytes => _field(base64Encode(bytes)),
        _ => '$value',
      };

  static String _field(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static const String _readme = '''
حساب مغازه — پشتیبان CSV
========================

هر جدول یک فایل CSV با نام خود جدول است. سرستون‌ها همان نام ستون‌های
پایگاه‌داده‌اند و ترتیبشان عوض نمی‌شود. فایل‌ها UTF-8 با BOM هستند تا
اکسل ویندوز فارسی را درست نشان دهد.

واحدها (هیچ ستونی «تزئین» نشده؛ عددها همان چیزی‌اند که ذخیره شده):
  • مبالغ: عدد صحیح ریال (بدون جداکنندهٔ هزارگان).
  • مقدار کالا: ستون‌های «*_milli» هزارم واحد هستند؛ 1500 = ۱٫۵ عدد.
  • تاریخ‌ها: میلی‌ثانیه از مبدأ یونیکس (epoch milliseconds).
  • مقادیر خالی: ستون خالی (نه صفر) — خالی یعنی «ثبت نشده».

این فایل‌ها برای بازخوانی در اکسل و تحویل به حسابدار هستند، نه برای
«ورود دوباره» در برنامه؛ قالب ورود برنامه در بخش کالاها/مشتریان است.
''';
}
