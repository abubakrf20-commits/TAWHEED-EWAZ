import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

/// How the home hero draws the prayer arc.
///
/// Stored by [wire] so a renamed constant can never quietly change a reader's
/// choice. [tags] is the look the app has always had, so an upgrade keeps it.
enum HomeArcStyle {
  tags('tags', 'برچسب‌دار'),
  sky('sky', 'آسمان'),
  segments('segments', 'قطعه‌ای');

  const HomeArcStyle(this.wire, this.label);

  final String wire;
  final String label;

  static HomeArcStyle fromWire(String? value) {
    for (final style in HomeArcStyle.values) {
      if (style.wire == value) return style;
    }
    return HomeArcStyle.tags;
  }
}

/// `home.arcStyle` + `home.arcSmallLabels`.
class HomeArcPrefs extends ChangeNotifier {
  HomeArcPrefs() {
    _load();
  }

  static const String styleKey = 'home.arcStyle';
  static const String smallLabelsKey = 'home.arcSmallLabels';

  HomeArcStyle _style = HomeArcStyle.tags;
  bool _smallLabels = true;

  HomeArcStyle get style => _style;

  /// «نمایش نام نشانگرهای کوچک» — the diamond milestones (طلوع، ضحی، نیمه‌شب،
  /// ثلث آخر). Off hides their names in the tagged and sky styles.
  bool get smallLabels => _smallLabels;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _style = HomeArcStyle.fromWire(prefs.getString(styleKey));
      _smallLabels = prefs.getBool(smallLabelsKey) ?? true;
      notifyListeners();
    } catch (e) {
      AppLogger.warning('arc_style_provider', 'load failed: $e');
    }
  }

  Future<void> setStyle(HomeArcStyle style) async {
    if (_style == style) return;
    _style = style;
    notifyListeners();
    await _write((p) => p.setString(styleKey, style.wire));
  }

  Future<void> setSmallLabels(bool value) async {
    if (_smallLabels == value) return;
    _smallLabels = value;
    notifyListeners();
    await _write((p) => p.setBool(smallLabelsKey, value));
  }

  Future<void> _write(Future<bool> Function(SharedPreferences p) op) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await op(prefs);
    } catch (e) {
      AppLogger.warning('arc_style_provider', 'write failed: $e');
    }
  }
}

/// One source for the arc's appearance; the hero and the settings preview both
/// watch it, which is why changing it applies without a restart.
final homeArcPrefsProvider = ChangeNotifierProvider<HomeArcPrefs>(
  (ref) => HomeArcPrefs(),
);
