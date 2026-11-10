import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// A snapshot of everything a range reset is about to delete, written to disk
/// BEFORE the delete runs (user request, 2026-11-05: the reset dialog used to
/// say «برگشت‌پذیر نیست» and mean it — now the last few range resets can be
/// undone from the snackbar's «بازگردانی» action).
///
/// The rows are the exact shapes their tables store, so a restore is a plain
/// upsert back into `daily_status_table`, `prayer_tracker_table` and
/// `zikr_status_record_table`. Nothing here is parsed or repaired: the backup
/// only ever contains rows that were in the DB moments earlier.
class EvaluationResetBackup {
  static const int schemaVersion = 1;

  final String rangeStart;
  final String rangeEnd;
  final DateTime createdAt;
  final List<DailyStatusTableData> dailyRows;
  final List<PrayerTrackerTableData> prayerRows;
  final List<ZikrStatusRecordTableData> zikrRows;

  const EvaluationResetBackup({
    required this.rangeStart,
    required this.rangeEnd,
    required this.createdAt,
    required this.dailyRows,
    required this.prayerRows,
    required this.zikrRows,
  });

  bool get isEmpty =>
      dailyRows.isEmpty && prayerRows.isEmpty && zikrRows.isEmpty;

  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        'createdAt': createdAt.toIso8601String(),
        'rangeStart': rangeStart,
        'rangeEnd': rangeEnd,
        'dailyStatus': [
          for (final r in dailyRows)
            {
              'category': r.category,
              'date': r.date,
              'key': r.key,
              'value': r.value,
            },
        ],
        'prayerTracker': [
          for (final r in prayerRows)
            {
              'date': r.date,
              'prayerKey': r.prayerKey,
              'value': r.value,
            },
        ],
        'zikrStatus': [
          for (final r in zikrRows)
            {
              'id': r.id,
              'statusIndex': r.statusIndex,
              'date': r.date,
            },
        ],
      };

  static EvaluationResetBackup fromJson(Map<String, dynamic> json) {
    final schema = json['schema'];
    if (schema != schemaVersion) {
      throw FormatException('unknown evaluation backup schema: $schema');
    }
    return EvaluationResetBackup(
      rangeStart: json['rangeStart'] as String,
      rangeEnd: json['rangeEnd'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dailyRows: [
        for (final r in (json['dailyStatus'] as List? ?? const []))
          DailyStatusTableData(
            category: r['category'] as String,
            date: r['date'] as String,
            key: r['key'] as String,
            value: r['value'] as int,
          ),
      ],
      prayerRows: [
        for (final r in (json['prayerTracker'] as List? ?? const []))
          PrayerTrackerTableData(
            date: r['date'] as String,
            prayerKey: r['prayerKey'] as String,
            value: r['value'] as int?,
          ),
      ],
      zikrRows: [
        for (final r in (json['zikrStatus'] as List? ?? const []))
          ZikrStatusRecordTableData(
            id: r['id'] as String,
            statusIndex: r['statusIndex'] as int,
            date: r['date'] as String,
          ),
      ],
    );
  }
}

/// Where the backups live. Tests point this at a temp directory; production
/// resolves the documents directory on first use.
@visibleForTesting
Future<Directory> Function()? backupDirectoryResolver;

Future<Directory> _backupRoot() async {
  final resolver = backupDirectoryResolver;
  final base = resolver != null
      ? await resolver()
      : await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}${Platform.pathSeparator}evaluation_backups');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

/// Writes [backup] to disk and prunes older backups, keeping only the
/// [keep] newest. Returns the backup file's path for the snackbar's undo.
///
/// Deliberately synchronous IO: the snapshot is a few hundred rows of JSON at
/// most, and an async write inside the reset's await chain cannot complete
/// under the widget tests' fake-async zone — the snackbar would never appear.
/// Backup file names sort by timestamp, so pruning by name order and choosing
/// «the latest» for a restore are the same ordering.
Future<String> saveEvaluationBackup(EvaluationResetBackup backup,
    {int keep = 5}) async {
  final dir = await _backupRoot();
  final stamp = backup.createdAt.millisecondsSinceEpoch;
  final file = File(
      '${dir.path}${Platform.pathSeparator}eval_${backup.rangeStart}_${backup.rangeEnd}_$stamp.json');
  file.writeAsStringSync(jsonEncode(backup.toJson()), flush: true);

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  while (files.length > keep) {
    try {
      files.removeAt(0).deleteSync();
    } catch (e) {
      // A backup that refuses to be pruned is not a reason to fail the reset
      // it belongs to — the newest files are what a restore reads anyway.
      AppLogger.warning('evaluation_backup', 'prune failed: $e');
      break;
    }
  }
  return file.path;
}

/// Reads a backup written by [saveEvaluationBackup]. Synchronous for the same
/// fake-async reason as the write. Throws when the file is missing or carries
/// an unknown schema — the caller must treat that as «cannot undo», never as
/// an empty backup (which would look like a successful restore of nothing).
Future<EvaluationResetBackup> readEvaluationBackup(String path) async {
  final raw = File(path).readAsStringSync();
  return EvaluationResetBackup.fromJson(
      jsonDecode(raw) as Map<String, dynamic>);
}
