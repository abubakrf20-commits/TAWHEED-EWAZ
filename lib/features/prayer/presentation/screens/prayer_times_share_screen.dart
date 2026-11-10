import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/utils/date_formatters.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/utils/share_wisdom.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_provider.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «اشتراک‌گذاری اوقات شرعی» — today's or tomorrow's prayer times
/// (fajr → isha) with city and a 4-column date strip (weekday + Shamsi +
/// Hijri + Gregorian) on the unified cream card, shareable as image (PNG),
/// formatted text, or copied — same experience as the other share screens.
class PrayerTimesShareScreen extends ConsumerStatefulWidget {
  const PrayerTimesShareScreen({super.key});

  @override
  ConsumerState<PrayerTimesShareScreen> createState() =>
      _PrayerTimesShareScreenState();
}

class _PrayerTimesShareScreenState
    extends ConsumerState<PrayerTimesShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  /// 0 = today, 1 = tomorrow (no other values are offered).
  int _dayOffset = 0;

  static const _wisdomKey = 'prayer_share_wisdom_index';

  /// Index of the rotating verse/hadith shown under the prayer times.
  /// Advances on every share (image/text/copy) and wraps to the first.
  int _wisdomIndex = 0;

  ShareWisdom get _wisdom => kShareWisdom[_wisdomIndex % kShareWisdom.length];

  @override
  void initState() {
    super.initState();
    _loadWisdomIndex();
  }

  Future<void> _loadWisdomIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_wisdomKey) ?? 0;
    if (mounted) setState(() => _wisdomIndex = idx);
  }

  /// Picks the next message for the next share and persists the position so
  /// each send shows a different verse/hadith in order.
  Future<void> _advanceWisdom() async {
    await _cycleWisdom(1);
  }

  /// Moves the verse/hadith by [delta] (+1 next, -1 previous) and persists the
  /// position, wrapping at both ends. The box cycles in BOTH directions: it
  /// used to only ever go forward — a tap always advanced — so a verse the
  /// reader had just left could not be brought back without sharing twice.
  Future<void> _cycleWisdom(int delta) async {
    final count = kShareWisdom.length;
    final next = (_wisdomIndex + delta) % count;
    final wrapped = next < 0 ? next + count : next;
    setState(() => _wisdomIndex = wrapped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wisdomKey, wrapped);
  }

  // Canonical prayer palette — AppTheme.prayerNameColor is the single
  // source of truth, so the share card can never drift from the app.
  static final _rows = [
    (
      'اذان صبح',
      'fajr',
      Icons.nightlight_round,
      AppTheme.prayerNameColor('fajr')
    ),
    (
      'طلوع آفتاب',
      'sunrise',
      Icons.wb_sunny_outlined,
      AppTheme.prayerNameColor('sunrise')
    ),
    ('اذان ظهر', 'dhuhr', Icons.light_mode, AppTheme.prayerNameColor('dhuhr')),
    ('اذان عصر', 'asr', Icons.cloud_outlined, AppTheme.prayerNameColor('asr')),
    (
      'اذان مغرب',
      'maghrib',
      Icons.wb_twilight,
      AppTheme.prayerNameColor('maghrib')
    ),
    ('اذان عشاء', 'isha', Icons.dark_mode, AppTheme.prayerNameColor('isha')),
  ];

  String _fa(String s) => NumberFormat.toLatin(s);

  String _fmtTime(DayTime? dt) {
    if (dt == null) return '--:--';
    return _fa(dt.toHHmm());
  }

  DateTime get _targetDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + _dayOffset);
  }

  String get _dayLabel => _dayOffset == 0 ? 'امروز' : 'فردا';

  Map<String, String> _timesFrom(pi.PrayerTimes? times) {
    if (times == null) return {};
    return {
      'fajr': _fmtTime(times.fajr.time),
      'sunrise': _fmtTime(times.shorouq.time),
      'dhuhr': _fmtTime(times.duhr.time),
      'asr': _fmtTime(times.asr.time),
      'maghrib': _fmtTime(times.maghrib.time),
      'isha': _fmtTime(times.isha.time),
    };
  }

  /// Times map for the currently selected day. Watch-based (build only).
  Map<String, String> _times() {
    if (_dayOffset == 0) {
      return _timesFrom(ref.watch(prayerTimesProvider).value);
    }
    return _timesFrom(ref.read(prayerTimeServiceProvider).prayerTimesForDate(
          _targetDate,
          settings: ref.read(settingsProvider).value,
        ));
  }

  /// Times map for the currently selected day. Listen/read-based (handlers).
  Map<String, String> _timesForText() {
    if (_dayOffset == 0) {
      return _timesFrom(ref.read(prayerTimesProvider).value);
    }
    return _timesFrom(ref.read(prayerTimeServiceProvider).prayerTimesForDate(
          _targetDate,
          settings: ref.read(settingsProvider).value,
        ));
  }

  // The PNG header and the formatted text read the city through these two
  // getters, so the two can never disagree about whether it is included.
  //
  // The city is always shared now (user decision, 2026-11-07): the «نمایش شهر
  // در تصویر و متن» switch and its persisted opt-out were removed, because a
  // timetable without the city leaves the reader unable to tell whose times
  // they are looking at. `prayer_share_show_city` stays written in older
  // installs and is ignored.
  String get _city {
    try {
      return ref.watch(prayerTimeServiceProvider).cityName;
    } catch (e) {
      AppLogger.warning('PrayerShare', 'date helper failed: $e');
      return '';
    }
  }

  String get _cityRead {
    try {
      return ref.read(prayerTimeServiceProvider).cityName;
    } catch (e) {
      AppLogger.warning('PrayerShare', 'date helper failed: $e');
      return '';
    }
  }

  /// Four-column date strip values for [now] (weekday + Shamsi + Hijri +
  /// Gregorian), normalized to [hijriOffset].
  ({String weekday, String shamsi, String hijri, String gregorian}) _calParts(
      int hijriOffset, DateTime now) {
    final weekday = DateFormatters.weekDays[(now.weekday + 1) % 7];
    final jalali = Jalali.fromDateTime(now);
    // Each digit run is LTR-isolated (audit P-01). Isolating the WHOLE date
    // would force an LTR reading and swap day/year inside the RTL card.
    final shamsi =
        '${NumberFormat.ltrIsolated(_fa('${jalali.day}'))} ${DateFormatters.persianMonths[jalali.month - 1]} ${NumberFormat.ltrIsolated(_fa('${jalali.year}'))}';
    var hijri = '';
    try {
      final h = HijriUtils.hijriFromGreg(now.year, now.month, now.day,
          offset: hijriOffset);
      hijri =
          '${NumberFormat.ltrIsolated(_fa('${h.day}'))} ${DateFormatters.hijriMonths[h.month - 1]} ${NumberFormat.ltrIsolated(_fa('${h.year}'))}';
    } catch (e) {
      AppLogger.warning('PrayerShare', 'gregorian date failed: $e');
    }
    final gregorian =
        '${NumberFormat.ltrIsolated(_fa('${now.day}'))} ${DateFormatters.gregorianMonths[now.month - 1]} ${NumberFormat.ltrIsolated(_fa('${now.year}'))}';
    return (
      weekday: weekday,
      shamsi: shamsi,
      hijri: hijri,
      gregorian: gregorian
    );
  }

  Future<void> _shareImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _pumpFrames();
      final bytes = await ShareService.captureCard(
        _cardKey,
      );
      await ShareService.sharePng(
        bytes,
        'prayer_times_${DateTime.now().millisecondsSinceEpoch}.png',
        text: ShareService.channelBlock,
      );
      await _advanceWisdom();
    } on ShareCaptureException catch (e) {
      AppLogger.warning('prayer_times_share_screen', 'error: $e');
      if (mounted) ShareService.showImageFailure(context, e.message);
    } catch (e) {
      AppLogger.warning('PrayerShare', 'screenshot failed: $e');
      if (mounted) ShareService.showImageFailure(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText() async {
    final text = _formattedText();
    if (text.isEmpty) return;
    await ShareService.shareText(text, subject: 'اوقات شرعی');
    await _advanceWisdom();
  }

  Future<void> _copyText() async {
    final text = _formattedText();
    if (text.isEmpty || !mounted) return;
    await ShareService.copyText(context, text);
    await _advanceWisdom();
  }

  String _formattedText() {
    final times = _timesForText();
    if (times.isEmpty) return '';
    final cal = _calParts(ref.read(hijriOffsetProvider), _targetDate);
    final b = StringBuffer()
      ..writeln('اوقات شرعی')
      ..writeln();
    if (_cityRead.trim().isNotEmpty) b.writeln('شهر: ${_cityRead.trim()}');
    b.writeln(
        '${cal.weekday} · ${cal.shamsi} · ${cal.hijri} · ${cal.gregorian}');
    b.writeln();
    for (final row in _rows) {
      b.writeln('${row.$1}: ${times[row.$2] ?? '--:--'}');
    }
    b.writeln();
    final w = _wisdom;
    if (w.arabic != null) b.writeln(w.arabic);
    b.writeln(w.persian);
    if (w.source != null && w.source!.isNotEmpty) {
      b.writeln('منبع: ${w.source}');
    }
    b
      ..writeln()
      ..writeln(ShareService.appLine('اوقات شرعی'))
      ..writeln(ShareService.channelLine);
    return b.toString().trim();
  }

  Future<void> _pumpFrames() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  @override
  Widget build(BuildContext context) {
    final times = _times();
    final t = TimeThemeKit.of(context).palette;
    final city = _city.trim();
    final cal = _calParts(ref.watch(hijriOffsetProvider), _targetDate);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'اشتراک‌گذاری اوقات شرعی'),
      // Audit P-06: the three actions used to sit *below* a tall card inside
      // the same ListView, so two were off the first viewport. The card now
      // scrolls while the actions stay pinned to a SafeArea footer.
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
          Text(
            'ساعت‌های $_dayLabel را به‌صورت تصویر یا متن ارسال کنید.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: t.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Center(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('امروز')),
                ButtonSegment(value: 1, label: Text('فردا')),
              ],
              selected: {_dayOffset},
              onSelectionChanged: _busy
                  ? null
                  : (selection) => setState(() => _dayOffset = selection.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          RepaintBoundary(
            key: _cardKey,
            child: ShareCardShell(
              children: [
                ShareCardHeader(
                  icon: Icons.mosque_outlined,
                  title: 'اوقات شرعی',
                  accent: TopicHues.prayer,
                  // No subtitle on purpose: «امروز · شنبه» repeated what the
                  // date strip already prints two lines below, and the card
                  // reads cleaner with the title alone.
                  // The city on the LEFT of the header with its own pin, as
                  // asked: the header lays right-to-left, so the trailing slot
                  // is the visual left edge of the card.
                  trailing: city.isEmpty ? null : _CityChip(city),
                ),
                const SizedBox(height: 12),
                PrayerShareDateStrip(
                  weekday: cal.weekday,
                  shamsi: cal.shamsi,
                  hijri: cal.hijri,
                  gregorian: cal.gregorian,
                ),
                const SizedBox(height: 12),
                // One table, not six boxes: a single hairline frame with a
                // rule between the rows is how a printed page sets a
                // timetable, and it stops the card reading as a form.
                _TimeTable(rows: _rows, times: times),
                const SizedBox(height: 12),
                _WisdomBox(
                  wisdom: _wisdom,
                  capture: _busy,
                  onPrevious: _busy ? null : () => unawaited(_cycleWisdom(-1)),
                  onNext: _busy ? null : () => unawaited(_cycleWisdom(1)),
                ),
                const SizedBox(height: 14),
                const ShareCardFooter(section: 'اوقات شرعی'),
              ],
            ),
          ),
              ],
            ),
          ),
          _actionsBar(context),
        ],
      ),
    );
  }

  /// Pinned footer (audit P-06): all three actions are reachable without a
  /// single scroll, even at 320dp and large text scales.
  Widget _actionsBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.94),
          border: Border(
            top: BorderSide(color: scheme.outline.withValues(alpha: 0.28)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _shareImage,
                icon: const Icon(Icons.image_outlined, size: 20),
                label: const Text('ارسال تصویر'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _shareText,
                      icon: const Icon(Icons.text_fields_outlined, size: 20),
                      label: const Text('ارسال متن'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _copyText,
                      icon: const Icon(Icons.copy_outlined, size: 20),
                      label: const Text('کپی متن'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card's 4-column date strip: weekday name, then the Shamsi, Hijri and
/// Gregorian dates.
///
/// All four boxes must read as one size. A cell's value is printed through a
/// [FittedBox] (`scaleDown`), and a scaled-down child reports a proportionally
/// SMALLER height — so in a plain [Row] the long Hijri date drew a visibly
/// shorter box than its neighbours (the reported «هجری کوتاه‌تر است»). The
/// intrinsic height plus `stretch` give every cell the tallest cell's height.
class PrayerShareDateStrip extends StatelessWidget {
  const PrayerShareDateStrip({
    super.key,
    required this.weekday,
    required this.shamsi,
    required this.hijri,
    required this.gregorian,
  });

  final String weekday;
  final String shamsi;
  final String hijri;
  final String gregorian;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _CalendarCell(value: weekday)),
          const SizedBox(width: 6),
          Expanded(child: _CalendarCell(value: shamsi)),
          const SizedBox(width: 6),
          Expanded(child: _CalendarCell(value: hijri)),
          const SizedBox(width: 6),
          Expanded(child: _CalendarCell(value: gregorian)),
        ],
      ),
    );
  }
}

/// One box of the 4-column date strip — just the value (weekday name, then
/// the three calendar dates). Content is self-evident, so no labels.
class _CalendarCell extends StatelessWidget {
  final String value;

  const _CalendarCell({required this.value});

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      decoration: BoxDecoration(
        color: c.chipBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withValues(alpha: 0.8)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          maxLines: 1,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            fontWeight: FontWeight.w800,
            color: c.isDark ? Colors.white : ShareCardPalette.inkTitle,
          ),
        ),
      ),
    );
  }
}

/// The city, pinned to the header's LEFT edge with its own location glyph.
///
/// It used to be the header's subtitle, i.e. a line under the title on the
/// right — the user asked for it on the left instead, as the place the times
/// belong to. The chip is bounded and scales down rather than truncating: a
/// long «اهواز»-sized name must still read whole in an exported image, where
/// no one can tap it to see more.
class _CityChip extends StatelessWidget {
  const _CityChip(this.city);

  final String city;

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: c.chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border.withValues(alpha: 0.8)),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined,
                  size: 15, color: TopicHues.prayer),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    city,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w700,
                      color: c.chipText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The six times as ONE table: a single hairline frame with a rule between
/// the rows. Six separate bordered boxes made the card read as an input form;
/// a printed page sets a timetable like this instead.
class _TimeTable extends StatelessWidget {
  const _TimeTable({required this.rows, required this.times});

  final List<(String, String, IconData, Color)> rows;
  final Map<String, String> times;

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Container(height: 1, color: c.border.withValues(alpha: 0.7)),
            _TimeRow(
              name: rows[i].$1,
              time: times[rows[i].$2] ?? '--:--',
              icon: rows[i].$3,
              color: rows[i].$4,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String name;
  final String time;
  final IconData icon;
  final Color color;

  const _TimeRow({
    required this.name,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            DuotoneIconTile(accent: color, icon: icon, size: 34),
            const SizedBox(width: 10),
            Text(
              name,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: c.body,
              ),
            ),
            const Spacer(),
            Text(
              time,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 15),
                fontWeight: FontWeight.w800,
                color: c.head,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rotating verse/hadith — a compact green card under the prayer times:
/// first the Arabic (or Persian when no Arabic) in a golden tone, then the
/// Persian translation in green, then the source. The box is split into two
/// tap halves so it cycles BACKWARDS as well as forwards: «دست راست = ذکر
/// قبلی، دست چپ = ذکر بعدی» (user, 2026-11-07).
class _WisdomBox extends StatelessWidget {
  final ShareWisdom wisdom;

  /// Right half, in reading order — the earlier message.
  final VoidCallback? onPrevious;

  /// Left half — the later message.
  final VoidCallback? onNext;

  /// When true, the tap hints are hidden. Excluded while the share image is
  /// being captured so the hints never end up in the screenshot.
  final bool capture;

  const _WisdomBox({
    required this.wisdom,
    this.onPrevious,
    this.onNext,
    this.capture = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    final isDark = c.isDark;
    final arabicColor = isDark
        ? ShareCardPalette.wisdomArabicDark
        : ShareCardPalette.wisdomArabicLight;
    final persianColor = isDark
        ? ShareCardPalette.wisdomPersianDark
        : ShareCardPalette.wisdomPersianLight;
    final sourceColor = isDark
        ? ShareCardPalette.wisdomSourceDark
        : ShareCardPalette.wisdomSourceLight;
    final hintColor = isDark
        ? ShareCardPalette.wisdomHintDark
        : ShareCardPalette.wisdomHintLight;
    final arabic = wisdom.arabic;
    final hasArabic = arabic != null && arabic.isNotEmpty;

    return Stack(
      children: [
        AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Container(
          key: ValueKey(wisdom),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
          decoration: BoxDecoration(
            color: isDark
                ? ShareCardPalette.wisdomBgDark
                : ShareCardPalette.wisdomBgLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark
                    ? ShareCardPalette.wisdomBorderDark
                    : ShareCardPalette.wisdomBorderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hasArabic ? arabic : wisdom.persian,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: hasArabic ? 'Amiri' : AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w800,
                  color: arabicColor,
                  height: 1.6,
                ),
              ),
              if (wisdom.arabic != null && wisdom.arabic!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  wisdom.persian,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w500,
                    color: persianColor,
                    height: 1.45,
                  ),
                ),
              ],
              if (wisdom.source != null && wisdom.source!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  wisdom.source!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w600,
                    color: sourceColor,
                  ),
                ),
              ],
              if (!capture) ...[
                const SizedBox(height: 5),
                // Both directions are named on the box itself: a hint that only
                // says «بعدی» is why the backward half went unused.
                Row(
                  children: [
                    Icon(Icons.chevron_right,
                        size: 14, color: hintColor.withValues(alpha: 0.85)),
                    const SizedBox(width: 2),
                    Text(
                      'ذکر قبلی',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        fontWeight: FontWeight.w600,
                        color: hintColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'ذکر بعدی',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        fontWeight: FontWeight.w600,
                        color: hintColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_left,
                        size: 14, color: hintColor.withValues(alpha: 0.85)),
                  ],
                ),
              ],
            ],
          ),
        ),
        ),
        // The two halves sit OVER the card: right is the earlier message, left
        // the later one, in reading order. They are separate semantics nodes,
        // so a screen reader reaches «قبلی» and «بعدی» without having to guess
        // that the box itself is tappable.
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: _WisdomTapZone(label: 'ذکر قبلی', onTap: onPrevious),
              ),
              Expanded(
                child: _WisdomTapZone(label: 'ذکر بعدی', onTap: onNext),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One half of the wisdom box's tap surface. Transparent and full-height: the
/// text underneath stays a single flowing paragraph, and only the gesture is
/// split.
class _WisdomTapZone extends StatelessWidget {
  const _WisdomTapZone({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: const SizedBox.expand(),
        ),
      );
}
