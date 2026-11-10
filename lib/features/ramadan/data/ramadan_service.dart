import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';

class RamadanDua {
  final String arabic;
  final String persian;
  final String source;
  const RamadanDua(
      {required this.arabic, required this.persian, this.source = ''});
}

/// Service to detect and manage Ramadan-specific features.
class RamadanService {
  const RamadanService._();

  static bool isRamadan({int hijriOffset = 0}) {
    final now = DateTime.now();
    final hijri = HijriUtils.hijriFromGreg(now.year, now.month, now.day,
        offset: hijriOffset);
    return hijri.month == 9;
  }

  static int ramadanDay({int hijriOffset = 0}) {
    if (!isRamadan(hijriOffset: hijriOffset)) return 0;
    final now = DateTime.now();
    final hijri = HijriUtils.hijriFromGreg(now.year, now.month, now.day,
        offset: hijriOffset);
    return hijri.day;
  }

  static int ramadanDaysRemaining({int hijriOffset = 0}) {
    if (!isRamadan(hijriOffset: hijriOffset)) return 0;
    final now = DateTime.now();
    final hijri = HijriUtils.hijriFromGreg(now.year, now.month, now.day,
        offset: hijriOffset);
    final length = HijriUtils.hijriMonthLength(9);
    return length - hijri.day + 1;
  }

  static int daysUntilRamadan({int hijriOffset = 0}) {
    if (isRamadan(hijriOffset: hijriOffset)) return 0;
    final now = DateTime.now();
    final currentJd =
        HijriUtils.gregToJd(now.year, now.month, now.day) + hijriOffset;
    final year = HijriUtils.findHijriYear(currentJd);
    final month = HijriUtils.hijriMonthFromJd(currentJd, year);
    final ramadanYear = month < 9 ? year : year + 1;
    final ramadanStartJd = HijriUtils.hijriToJd(ramadanYear, 9, 1);
    return ramadanStartJd - currentJd;
  }

  static DateTime? suhoorTime(PrayerTimeService prayerService) {
    final fajr = prayerService.fajr;
    if (fajr == null) return null;
    return fajr.subtract(const Duration(minutes: 10));
  }

  static DateTime? iftarTime(PrayerTimeService prayerService) =>
      prayerService.maghrib;

  static ({String label, Duration remaining, bool isSuhoor})? timeUntilNextMeal(
      PrayerTimeService prayerService) {
    final now = DateTime.now();
    final suhoor = suhoorTime(prayerService);
    final iftar = iftarTime(prayerService);
    if (suhoor == null || iftar == null) return null;
    if (now.isBefore(suhoor)) {
      return (label: 'سحر', remaining: suhoor.difference(now), isSuhoor: true);
    }
    if (now.isBefore(iftar)) {
      return (
        label: 'افطار',
        remaining: iftar.difference(now),
        isSuhoor: false
      );
    }
    return (
      label: 'سحر',
      remaining: suhoor.add(const Duration(days: 1)).difference(now),
      isSuhoor: true
    );
  }

  // ═══════════════════════════════════════════
  //  Fasting Tracker
  // ═══════════════════════════════════════════

  /// Hijri year of today — one Ramadan always lives in exactly one Hijri
  /// year, while Gregorian-year keys split/evaporate history every January.
  /// Deliberately offset-free: the display `hijriOffset` only shifts which
  /// Gregorian day maps to 1 Ramadan, whereas storage keys must stay stable so
  /// tweaking that offset never orphans already-saved tracker data.
  static int _hyear() {
    final now = DateTime.now();
    try {
      return HijriUtils.hijriFromGreg(now.year, now.month, now.day).year;
    } catch (_) {
      AppLogger.warning('ramadan_service', 'operation failed');
      return now.year;
    }
  }

  /// Returns the Hijri-year key for [prefix], adopting the legacy
  /// Gregorian-year list once (idempotent: only when the new key is empty
  /// and the old one has data).
  static Future<String> _listKey(SharedPreferences prefs, String prefix) async {
    final target = '$prefix${_hyear()}';
    if ((prefs.getStringList(target) ?? []).isNotEmpty) return target;
    final legacy = '$prefix${DateTime.now().year}';
    final old = prefs.getStringList(legacy);
    if (old != null && old.isNotEmpty) {
      await prefs.setStringList(target, old);
      await prefs.remove(legacy);
    }
    return target;
  }

  static int? _parseDay(String item) {
    final parts = item.split(':');
    if (parts.length != 2) return null;
    return int.tryParse(parts[0]);
  }

  static Future<Map<int, bool>> loadFastingDays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getStringList(await _listKey(prefs, 'ramadan_fasting_')) ?? [];
    final map = <int, bool>{};
    for (final item in raw) {
      final day = _parseDay(item);
      if (day != null) map[day] = item.endsWith(':1');
    }
    return map;
  }

  static Future<void> toggleFastingDay(int day, bool fasted) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _listKey(prefs, 'ramadan_fasting_');
    final raw = prefs.getStringList(key) ?? [];
    raw.removeWhere((e) => e.startsWith('$day:'));
    raw.add('$day:${fasted ? '1' : '0'}');
    await prefs.setStringList(key, raw);
  }

  static Future<int> fastedDaysCount() async =>
      (await loadFastingDays()).values.where((v) => v).length;

  // ═══════════════════════════════════════════
  //  Qada (missed-fast) Counter
  // ═══════════════════════════════════════════

  /// Missed fasts the user still owes. Deliberately NOT Hijri-year scoped —
  /// a qada debt carries across years until it is made up, unlike the
  /// per-Ramadan trackers above.
  static const String _qadaKey = 'fasting_qada_owed';

  static Future<int> loadQadaOwed() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_qadaKey) ?? 0).clamp(0, 0x7fffffff);
  }

  /// Sets the outstanding qada count, clamped at zero; zero clears the key.
  static Future<void> setQadaOwed(int value) async {
    final prefs = await SharedPreferences.getInstance();
    final v = value < 0 ? 0 : value;
    if (v == 0) {
      await prefs.remove(_qadaKey);
    } else {
      await prefs.setInt(_qadaKey, v);
    }
  }

  // ═══════════════════════════════════════════
  //  Quran Tracker (Juz-based)
  // ═══════════════════════════════════════════

  static Future<Set<int>> loadQuranJuzCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getStringList(await _listKey(prefs, 'ramadan_quran_')) ?? [];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  static Future<void> toggleQuranJuz(int juz, bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _listKey(prefs, 'ramadan_quran_');
    final set = await loadQuranJuzCompleted();
    completed ? set.add(juz) : set.remove(juz);
    await prefs.setStringList(key, set.map((e) => e.toString()).toList());
  }

  static Future<String> _intKey(SharedPreferences prefs, String prefix) async {
    final target = '$prefix${_hyear()}';
    if (prefs.containsKey(target)) return target;
    final legacy = '$prefix${DateTime.now().year}';
    if (prefs.containsKey(legacy)) {
      final v = prefs.getInt(legacy) ?? 0;
      await prefs.setInt(target, v);
      await prefs.remove(legacy);
    }
    return target;
  }

  static Future<int> loadQuranCompletions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(await _intKey(prefs, 'ramadan_quran_completions_')) ??
        0;
  }

  static Future<int> completeQuranRound() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _intKey(prefs, 'ramadan_quran_completions_');
    final current = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, current);
    await prefs.setStringList(await _listKey(prefs, 'ramadan_quran_'), []);
    return current;
  }

  // ═══════════════════════════════════════════
  //  Taraweeh Tracker
  // ═══════════════════════════════════════════

  static Future<Map<int, bool>> loadTaraweehDays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getStringList(await _listKey(prefs, 'ramadan_taraweeh_')) ?? [];
    final map = <int, bool>{};
    for (final item in raw) {
      final day = _parseDay(item);
      if (day != null) map[day] = item.endsWith(':1');
    }
    return map;
  }

  static Future<void> toggleTaraweehDay(int day, bool prayed) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _listKey(prefs, 'ramadan_taraweeh_');
    final raw = prefs.getStringList(key) ?? [];
    raw.removeWhere((e) => e.startsWith('$day:'));
    raw.add('$day:${prayed ? '1' : '0'}');
    await prefs.setStringList(key, raw);
  }

  static Future<int> taraweehDaysCount() async =>
      (await loadTaraweehDays()).values.where((v) => v).length;

  // ═══════════════════════════════════════════
  //  Last 10 Days Checklist
  // ═══════════════════════════════════════════

  static Future<Map<String, bool>> loadLastTenDaysChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    final hy = _hyear();
    final keys = [
      'last10_itikaf',
      'last10_laylat',
      'last10_qiyam',
      'last10_sadaqa',
      'last10_dhikr'
    ];
    final map = <String, bool>{};
    for (final k in keys) {
      final target = 'ramadan_${k}_$hy';
      if (!prefs.containsKey(target)) {
        // One-time adoption from the legacy Gregorian-year key.
        final legacy = 'ramadan_${k}_${DateTime.now().year}';
        if (prefs.containsKey(legacy)) {
          await prefs.setBool(target, prefs.getBool(legacy) ?? false);
          await prefs.remove(legacy);
        }
      }
      map[k] = prefs.getBool(target) ?? false;
    }
    return map;
  }

  static Future<void> toggleLastTenDaysItem(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ramadan_${key}_${_hyear()}', value);
  }

  // ═══════════════════════════════════════════
  //  Night Prayers Tracker
  // ═══════════════════════════════════════════

  static Future<Map<int, bool>> loadNightPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getStringList(await _listKey(prefs, 'ramadan_night_')) ?? [];
    final map = <int, bool>{};
    for (final item in raw) {
      final day = _parseDay(item);
      if (day != null) map[day] = item.endsWith(':1');
    }
    return map;
  }

  static Future<void> toggleNightPrayer(int day, bool prayed) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _listKey(prefs, 'ramadan_night_');
    final raw = prefs.getStringList(key) ?? [];
    raw.removeWhere((e) => e.startsWith('$day:'));
    raw.add('$day:${prayed ? '1' : '0'}');
    await prefs.setStringList(key, raw);
  }

  static Future<int> nightPrayersCount() async =>
      (await loadNightPrayers()).values.where((v) => v).length;
}

class RamadanAzkar {
  const RamadanAzkar._();

  // ─── دعای افطار ───
  static const List<RamadanDua> iftarDuas = [
    RamadanDua(
        arabic:
            'ذَهَبَ الظَّمَأُ وَابْتَلَّتِ الْعُرُوقُ وَثَبَتَ الْأَجُرُ إِنْ شَاءَ اللّهُ',
        persian: 'تشنگی رفت و رگ‌ها تر شد و انشائلله پاداش ثابت شد.',
        source: 'احادیث نبوی'),
    RamadanDua(
        arabic: 'اللّهُمَّ لَكَ صُمْتُ وَعَلَى رِزْقِكَ أَفْطَرْتُ',
        persian: 'بارالها، برای تو روزه گرفتم و از روزی تو افطار کردم.',
        source: 'احادیث نبوی'),
  ];

  // ─── أدعية وفضائل ───
  static const List<String> laylatAlQadrVirtues = [
    'بهتر از هزار ماه است',
    'فرشته و روح در آن شب به اذن خدا نازل می‌شوند',
    'هر عمل نیکی در آن شب برابر با عمل هزار ماه است',
    'آمرزش گناهان گذشته',
  ];

  static const List<String> quranVersesForRamadan = [
    'شَهْرُ رَمَضَانَ الَّذِي أُنزِلَ فِيهِ الْقُرْآنُ هُدًى لِّلنَّاسِ وَبَيِّنَاتٍ مِّنَ الْهُدَىٰ وَالْفُرْقَانِ',
    'وَلَوْلَا أَن يَكُونَ النَّاسُ أُمَّةً وَاحِدَةً لَجَعَلْنَا لِمَن يَكْفُرُ بِالرَّحْمَٰنِ لِبُيُوتِهِمْ سُقُفًا مِّن فِضَّةٍ',
  ];
  // NOTE: 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ' was removed from this list —
  // it is a hadith (Bukhari/Muslim), not a Quran verse.

  static const List<Map<String, String>> ramadanVirtues = [
    {'title': 'نزول قرآن', 'text': 'ماه رمضان ماه نزول قرآن است'},
    {'title': 'درهای بهشت', 'text': 'درهای بهشت در ماه رمضان گشوده می‌شود'},
    {'title': 'درهای جهنم', 'text': 'درهای جهنم در ماه رمضان بسته می‌شود'},
    {'title': 'شیاطین', 'text': 'شیاطین در ماه رمضان در زنجیرند'},
    {'title': 'آمرزش', 'text': 'خداوند در ماه رمضان گناهان را می‌آمرزد'},
    {'title': 'رحمت', 'text': 'ماه رمضان ماه رحمت و آمرزش است'},
  ];

  static const List<Map<String, String>> lastTenDaysProgram = [
    {
      'title': 'اعتکاف',
      'text': 'گوشه‌نشینی در مسجد و عبادت در 10 روز آخر',
      'icon': '🕌'
    },
    {'title': 'شب قدر', 'text': 'شب 21، 23، 25، 27 و 29 رمضان', 'icon': '🌙'},
    {
      'title': 'قرائت قرآن',
      'text': 'تلاوت بیشتر قرآن و تدبر در معانی',
      'icon': '📖'
    },
    {
      'title': 'دعای فراوان',
      'text': 'درخواست از خداوند به ویژه دعای عفو',
      'icon': '🤲'
    },
    {'title': 'صدقه', 'text': 'افزایش صدقه و کمک به نیازمندان', 'icon': '💚'},
    {'title': 'نماز شب', 'text': 'نمازهای نفلی و قیام اللیل', 'icon': '🌃'},
  ];

  static const List<Map<String, String>> specialWorships = [
    {'title': 'نماز تراویح', 'text': '20 رکعت نماز پس از عشاء', 'icon': '🕌'},
    {'title': 'تلاوت قرآن', 'text': 'تلاوت روزانه قرآن', 'icon': '📖'},
    {
      'title': 'ادعیه مخصوص',
      'text': 'دعاهای افطار، سحر و شب‌های قدر',
      'icon': '🤲'
    },
    {'title': 'صدقه و احسان', 'text': 'افزایش صدقه و نیکی', 'icon': '💚'},
    {'title': 'نمازهای نفلی', 'text': 'نمازهای مستحبی', 'icon': '🕐'},
    {'title': 'ذکر و تسبیح', 'text': 'ذکر خداوند پس از نمازها', 'icon': '📿'},
  ];
}
