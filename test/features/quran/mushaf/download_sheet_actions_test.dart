import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the pre-download sheet's three promises: «حذف دانلودها» really
/// deletes, «فقط با وای‌فای دانلود شود» really gates every download start,
/// and the storage hero prints a real free-space number.
///
/// Widget tests cannot pump this sheet (it reads download managers and the
/// method channel), and the native half is invisible to `flutter test`, so
/// this scans the sources — the repo's idiom for platform/logic wiring (see
/// `test/android/tasbih_widget_tap_broadcast_test.dart`).
void main() {
  final sheet = File(
    'lib/features/quran/mushaf/quran_mushaf_pre_download_sheet.dart',
  ).readAsStringSync();
  final qcf4Sheet = File(
    'lib/features/quran/mushaf/quran_mushaf_qcf4_sheet.dart',
  ).readAsStringSync();
  final service = File('lib/shared/services/device_status_service.dart');
  final activity = File(
    'android/app/src/main/kotlin/com/islamic/tawheeed/MainActivity.kt',
  ).readAsStringSync();
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('«حذف دانلودها» really clears the stored mushaf', () {
    // The old button only showed a snackbar. The delete card's confirm path
    // must call the manager that cancels in-flight work and then clears the
    // pages + fonts.
    expect(sheet, contains('await Qcf4DownloadManager.instance.clearAllDownloaded();'),
        reason: 'the sheet delete must actually clear downloaded pages/fonts');
    final wipe = sheet.indexOf('_confirmStorageWipe');
    expect(wipe, greaterThan(-1));
    final body = sheet.substring(wipe, wipe + 2000);
    expect(body, contains('clearAllDownloaded'),
        reason: '_confirmStorageWipe no longer deletes anything');
    expect(body, contains('_refreshStorageCounts'),
        reason: 'the hero must re-read the cache counts after a delete');
  });

  test('the embedded QCF4 sheet reports a delete back to its host', () {
    expect(qcf4Sheet, contains('final VoidCallback? onDataDeleted;'),
        reason: 'the host storage hero goes stale without this callback');
    expect(sheet, contains('onDataDeleted: () => unawaited(_refreshStorageCounts())'),
        reason: 'the pre-download sheet must wire onDataDeleted to its refresh');
    expect(qcf4Sheet, contains('widget.onDataDeleted?.call();'),
        reason: 'the embedded sheet never reports its delete');
  });

  test('every download start passes the Wi-Fi gate', () {
    // Six confirm-dialog paths each start a download inside their own
    // `if (await _confirm… )` branch; each must also await the gate before
    // anything starts. The gate sits within the same branch, so a bounded
    // window is enough to prove the pairing without a fragile full match.
    final pattern = RegExp(
      r'if \(await _confirm(?:Translation)?Download\(',
    );
    final matches = pattern.allMatches(sheet).toList();
    expect(matches.length, 6,
        reason: 'expected the six download confirm paths (audio + translation '
            '× surah/all/juz); update this test if a new one is added');
    for (final m in matches) {
      final window = sheet.substring(m.start, m.end + 260);
      expect(window, contains('await _wifiAllowsDownload()'),
          reason: 'a download path starts without the Wi-Fi gate at '
              'offset ${m.start}');
    }

    // The reciter picker's shape is `final ok = …; if (ok && await …)`.
    expect(sheet, contains('if (ok && await _wifiAllowsDownload())'),
        reason: 'the reciter picker must gate its download too');

    // The QCF4 section starts through an async closure.
    final qcf4Start = sheet.indexOf('onStart: () async {');
    expect(qcf4Start, greaterThan(-1));
    final qcf4Window = sheet.substring(qcf4Start, qcf4Start + 200);
    expect(qcf4Window, contains('await _wifiAllowsDownload()'),
        reason: 'the QCF4 page download bypasses the Wi-Fi toggle');
  });

  test('the Wi-Fi toggle is persisted and fails open', () {
    expect(sheet, contains("_wifiOnlyPrefsKey = 'quran_download_wifi_only'"),
        reason: 'the toggle must survive a restart');
    expect(sheet, contains('if (onWifi != false) return true;'),
        reason: 'an unknown transport must never block a download');
    expect(sheet, contains('DeviceStatusService.isOnWifi()'));
  });

  test('the storage hero gets a real free-space reading', () {
    expect(service.existsSync(), isTrue,
        reason: 'device_status_service.dart is missing');
    final src = service.readAsStringSync();
    expect(src, contains("MethodChannel('com.tawheeed/storage')"));
    expect(src, contains("invokeMethod<int>('freeSpaceMb')"));
    expect(src, contains("invokeMethod<bool>('isOnWifi')"));

    // The hero must receive the measured value, never a hardcoded null —
    // that was the reported «فضای آزاد نمایش داده نمی‌شود».
    expect(sheet, contains('freeSpaceMb: _freeSpaceMb,'));
    expect(sheet, contains('_freeSpaceMb = freeSpaceMb;'));
    expect(sheet, isNot(contains('freeSpaceMb: null')),
        reason: 'the hero would keep its placeholder instead of the reading');
  });

  test('the native channel implements both reads', () {
    expect(activity, contains('"freeSpaceMb" ->'),
        reason: 'the Dart free-space call has no native branch');
    expect(activity, contains('StatFs('),
        reason: 'free space must be measured, not guessed');
    expect(activity, contains('"isOnWifi" ->'),
        reason: 'the Dart transport check has no native branch');
    expect(activity, contains('TRANSPORT_WIFI'));
    expect(activity, contains('TRANSPORT_CELLULAR'));
    expect(manifest, contains('android.permission.ACCESS_NETWORK_STATE'),
        reason: 'ConnectivityManager capabilities need this normal permission');
  });
}
