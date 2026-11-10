import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

import 'package:tawheeed/features/quran/mushaf/mushaf_backgrounds.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_page_turn.dart';

/// The reader's persisted colours, stored as ARGB **values**.
///
/// They used to be stored as *indices* into the palette, which forced the
/// palette to be append-only: `quran_bg_day = 12` meant "the thirteenth colour
/// in the list", so reordering or deleting an entry silently handed every
/// existing reader a different page. Removing the duplicate colours is exactly
/// the change that contract forbade, so it is retired here: a value survives
/// reordering, renaming and pruning, and a value that is no longer in the
/// palette snaps to its nearest neighbour instead of resetting to the default.
///
/// The legacy index keys are still read, once, and the migrated value is
/// written back, so an upgrading reader keeps the colour they chose.
class MushafReaderPrefs {
  const MushafReaderPrefs._();

  /// Page background, as an ARGB value.
  static const String backgroundKey = 'quran_bg_color';

  /// Recited-ayah colour, as an ARGB value.
  static const String recitationColorKey = 'quran_recitation_color_argb';

  /// Page background as an *index*, as persisted before the palette rewrite.
  /// Read-only.
  static const String legacyBackgroundIndexKey = 'quran_bg_day';

  /// Recited-ayah colour as an *index* (0…6), before the palette rewrite.
  /// Read-only.
  static const String legacyRecitationIndexKey = 'quran_recitation_color';

  /// The page background to paint, migrating and repairing as needed.
  ///
  /// [writeBack] is off in tests that only ask what would be shown.
  static Color backgroundFrom(SharedPreferences prefs,
      {bool writeBack = true}) {
    final stored = prefs.getInt(backgroundKey);
    if (stored != null) {
      final value = stored & 0xFFFFFFFF;
      final exact = mushafBackgroundIndexOf(Color(value));
      if (exact >= 0) return Color(value);
      // The colour is gone from the palette: keep the reader's look, snap it.
      final snapped =
          kMushafBackgrounds[mushafNearestBackgroundIndexOf(Color(value))]
              .color;
      if (writeBack) {
        unawaited(prefs.setInt(backgroundKey, snapped.toARGB32()));
      }
      return snapped;
    }
    final legacyIndex = prefs.getInt(legacyBackgroundIndexKey);
    final migrated = legacyIndex == null
        ? kMushafBackgrounds.first.color
        : kMushafBackgrounds[mushafNearestBackgroundIndexOf(
                mushafLegacyBackgroundColor(legacyIndex))]
            .color;
    if (writeBack) {
      unawaited(prefs.setInt(backgroundKey, migrated.toARGB32()));
    }
    return migrated;
  }

  /// The recited-ayah colour to paint, migrating and repairing as needed.
  static Color recitationColorFrom(SharedPreferences prefs,
      {bool writeBack = true}) {
    final stored = prefs.getInt(recitationColorKey);
    if (stored != null) {
      final value = stored & 0xFFFFFFFF;
      final exact = mushafRecitationIndexOf(Color(value));
      if (exact >= 0) return Color(value);
      final snapped =
          kMushafRecitationColors[mushafNearestRecitationIndexOf(Color(value))]
              .color;
      if (writeBack) {
        unawaited(prefs.setInt(recitationColorKey, snapped.toARGB32()));
      }
      return snapped;
    }
    final legacyIndex = prefs.getInt(legacyRecitationIndexKey);
    final migrated = legacyIndex == null
        ? kMushafRecitationColors.first.color
        : kMushafRecitationColors[mushafNearestRecitationIndexOf(
                mushafLegacyRecitationColor(legacyIndex))]
            .color;
    if (writeBack) {
      unawaited(prefs.setInt(recitationColorKey, migrated.toARGB32()));
    }
    return migrated;
  }

  /// Persists the reader's page background.
  static Future<void> saveBackground(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(backgroundKey, color.toARGB32());
  }

  /// Persists the reader's recited-ayah colour.
  /// Keep the screen awake while reading. Persisted as a plain bool; the
  /// reader holds the shared `AppWakelock` under a stable key so leaving
  /// قبله‌نما / the pomodoro timer never drops it.
  static const String keepAwakeKey = 'quran_keep_awake';

  /// Reads [keepAwakeKey] from an already-obtained [prefs] — the reader's
  /// init loads every other reader pref from one instance, so this keeps the
  /// keep-awake flag on the same pass instead of a second await.
  static bool loadKeepAwakeSync(SharedPreferences prefs) =>
      prefs.getBool(keepAwakeKey) ?? false;

  static Future<bool> loadKeepAwake() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keepAwakeKey) ?? false;
    } catch (e) {
      AppLogger.warning('mushaf_reader_prefs', 'keep-awake read failed: $e');
      return false;
    }
  }

  static Future<void> saveKeepAwake(bool on) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keepAwakeKey, on);
    } catch (e) {
      AppLogger.warning('mushaf_reader_prefs', 'keep-awake write failed: $e');
    }
  }

  /// «نوار بالای صفحه» — the header band's visibility.
  ///
  /// Missing means **off**: the reader opens on a bare page that shows the
  /// whole mushaf, and the band is a deliberate tick (or a double tap). Only
  /// an explicit `true` keeps it up, so an upgrading reader also lands on the
  /// bare page instead of inheriting a bar they never asked for.
  static const String headerVisibleKey = 'quran_header_visible';

  static bool loadHeaderVisibleSync(SharedPreferences prefs) =>
      prefs.getBool(headerVisibleKey) ?? false;

  static Future<void> saveHeaderVisible(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(headerVisibleKey, on);
  }

  /// How a page is turned. A missing or retired value is the plain slide.
  static const String pageTurnKey = 'quran_page_turn';

  static MushafPageTurn loadPageTurnSync(SharedPreferences prefs) =>
      MushafPageTurn.fromWire(prefs.getString(pageTurnKey));

  static Future<void> savePageTurn(MushafPageTurn turn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pageTurnKey, turn.wire);
  }

  /// «ظاهر صفحات راست و چپ مثل مصحف چاپی» — on unless the reader turns it off.
  ///
  /// A missing value is ON: the printed-book layout is what the reader gets on
  /// a fresh install, and an upgrading reader who never touched the option sees
  /// it too. Only an explicit `false` restores the pre-parity page.
  static const String pageChromeByParityKey = 'quran_page_chrome_parity';

  static bool loadPageChromeByParitySync(SharedPreferences prefs) =>
      prefs.getBool(pageChromeByParityKey) ?? true;

  static Future<void> savePageChromeByParity(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pageChromeByParityKey, on);
  }

  /// «سرعت» of a turn — the app's own turns use it; a finger's release keeps
  /// the pager's ballistics.
  static const String pageTurnSpeedKey = 'quran_page_turn_speed';

  static MushafTurnSpeed loadPageTurnSpeedSync(SharedPreferences prefs) =>
      MushafTurnSpeed.fromWire(prefs.getString(pageTurnSpeedKey));

  static Future<void> savePageTurnSpeed(MushafTurnSpeed speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pageTurnSpeedKey, speed.wire);
  }

  /// «لرزش ملایم هنگام ورق‌زدن» — one selection click when a turn commits.
  static const String pageTurnHapticKey = 'quran_page_turn_haptic';

  static bool loadPageTurnHapticSync(SharedPreferences prefs) =>
      prefs.getBool(pageTurnHapticKey) ?? true;

  static Future<void> savePageTurnHaptic(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pageTurnHapticKey, on);
  }

  static Future<void> saveRecitationColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(recitationColorKey, color.toARGB32());
  }
}
