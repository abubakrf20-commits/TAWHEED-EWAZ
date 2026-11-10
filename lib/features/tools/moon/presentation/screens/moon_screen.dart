import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/constants/moon_constants.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/eclipse_calculator.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/hilal_calendar.dart'
    as hc;
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/hilal_visibility.dart'
    as hv;
import 'package:tawheeed/features/tools/moon/domain/services/astronomical_hijri.dart';
import 'package:tawheeed/features/tools/moon/domain/services/hilal_notification_service.dart';
import 'package:tawheeed/features/tools/moon/presentation/widgets/hilal_sky_panel.dart';
import 'package:tawheeed/features/tools/moon/domain/services/lunar_calculator.dart';
import 'package:tawheeed/features/tools/moon/presentation/providers/moon_provider.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/shared/widgets/shamsi_date_picker.dart';

class MoonScreen extends ConsumerStatefulWidget {
  const MoonScreen({super.key});
  @override
  ConsumerState<MoonScreen> createState() => _MoonScreenState();
}

class _MoonScreenState extends ConsumerState<MoonScreen> {
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();
    HilalNotificationService.instance.init();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkHilalNotification());
  }

  Future<void> _checkHilalNotification() async {
    try {
      final settings = await ref.read(settingsProvider.future);
      if (!mounted) return;
      await HilalNotificationService.instance.checkAndNotify(
        DateTime.now(),
        settings.manualLat ?? 35.6892,
        settings.manualLng ?? 51.3890,
      );
    } catch (e) {
      // بی‌صدا — اعلان نباید تجربهٔ کاربر را مختل کند، اما ردپا برای عیب‌یابی
      AppLogger.debug('MoonScreen', 'hilal notification check failed: $e');
    }
  }

  static const List<String> _tabs = ['امروز', '30 روز', '28 منزل', 'هلال'];

  @override
  Widget build(BuildContext context) {
    final moon = ref.watch(moonForDateProvider(_selected));
    final settings = ref.watch(settingsProvider).value;
    final lat = settings?.manualLat ?? 35.6892;
    final lng = settings?.manualLng ?? 51.3890;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SectionPage(
      id: 'moon',
      title: 'ماه و منازل',
      tabs: _tabs,
      // The date band is shared by all four tabs, so it sits above the views
      // rather than inside each one.
      header: _DateSelector(
        selected: _selected,
        onChanged: (d) => setState(() => _selected = d),
        onToday: () => setState(() => _selected = DateTime.now()),
      ),
      children: [
        _TodayTab(moon: moon, isDark: isDark, lat: lat, lng: lng),
        _MonthAheadTab(
            start: _selected, hijriOffset: ref.watch(hijriOffsetProvider)),
        _ManazilTab(currentIndex: moon.manzil.index),
        _HilalTab(date: _selected, lat: lat, lng: lng),
      ],
    );
  }
}

class _DateSelector extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback onToday;
  const _DateSelector(
      {required this.selected, required this.onChanged, required this.onToday});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: TopicHues.moon.withValues(alpha: 0.08),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'روز قبل',
              onPressed: () =>
                  onChanged(selected.subtract(const Duration(days: 1)))),
          Expanded(
            child: InkWell(
              onTap: () async {
                // تقویم شمسی — کاربر این ابزار ایرانی تاریخ را با شمسی
                // می‌خواند؛ دیالوگ میلادی GeoCalculator گمراه‌کننده بود.
                final picked = await showShamsiDatePicker(
                  context: context,
                  initialDate: selected,
                  accentColor: TopicHues.moon,
                );
                if (picked != null) onChanged(picked);
              },
              child: Column(
                children: [
                  Text(
                      '${selected.year}/${selected.month.toString().padLeft(2, '0')}/${selected.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppTheme.scaledFontSize(context, 13))),
                  Text(
                      '${LunarCalculator.formatAge(LunarCalculator.moonAge(selected))} از محاق',
                      style:
                          TextStyle(fontSize: AppTheme.scaledFontSize(context, 11), color: TimeThemeKit.of(context).palette.textMuted)),
                ],
              ),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'روز بعد',
              onPressed: () =>
                  onChanged(selected.add(const Duration(days: 1)))),
          TextButton(onPressed: onToday, child: const Text('امروز')),
        ],
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  final MoonState moon;
  final bool isDark;
  final double lat;
  final double lng;
  const _TodayTab(
      {required this.moon,
      required this.isDark,
      required this.lat,
      required this.lng});
  @override
  Widget build(BuildContext context) {
    // همه‌چیز بر پایهٔ تاریخ انتخابی — نه «اکنون»؛ وگرنه با فلش روز عوض
    // میشود ولی طلوع/غروب و شمارهٔ روز هجری همان دیروز می‌ماند.
    final date = moon.date;
    final rs = LunarCalculator.moonRiseSet(date, lat, lng);
    String fmt(DateTime? dt) => dt == null
        ? '—'
        : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final hijri = AstronomicalHijri.lunarMonthInfo(date);
    return ListView(
      padding: const EdgeInsets.all(DsSpacing.page),
      children: [
        _MoonPhaseCard(moon: moon),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'سن ماه',
          value: LunarCalculator.formatAge(moon.age),
          subtitle: '${moon.illumination.toStringAsFixed(1)}% روشنایی',
          icon: Icons.timelapse,
          color: TopicHues.moon,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _InfoCard(
                    title: 'طلوع ماه',
                    value: fmt(rs.rise),
                    icon: Icons.wb_twilight,
                    color: Colors.deepPurple)),
            const SizedBox(width: 8),
            Expanded(
                child: _InfoCard(
                    title: 'غروب ماه',
                    value: fmt(rs.set),
                    icon: Icons.brightness_4_outlined,
                    color: Colors.blueGrey)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: TopicHues.moon.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: TopicHues.moon.withValues(alpha: 0.15))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.event_repeat, size: 16, color: TopicHues.moon),
                const SizedBox(width: 6),
                Text('ماه هجری (نجومی)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: TopicHues.moon)),
              ]),
              const SizedBox(height: 6),
              Text(
                  'شروع ماه: ${hijri.monthStart.year}/${hijri.monthStart.month}/${hijri.monthStart.day}',
                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
              Text(
                  'روزِ ${hijri.dayInMonth} ماه است (طول ماه: ${hijri.monthLength} روز)',
                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11), color: TimeThemeKit.of(context).palette.textMuted)),
              // The calendar section reads the tabular date (with the user's
              // moon-sighting adjustment), not this astronomical one: near a
              // month boundary the two can differ by a day. Say so plainly so
              // the difference reads as defined behaviour, and name the
              // calendar as the reference for religious occasions.
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    'این تاریخ نجومی است و ممکن است با تاریخ بخش تقویم یک روز فرق داشته باشد؛ ملاک مناسبت‌ها همان تقویم است.',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: TimeThemeKit.of(context).palette.textMuted)),
              ),
              if (hijri.isConjunctionDay)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('🌙 امروز روز مقارنه است — امشب هلال جدید',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade800)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'منزل امشب',
          value:
              '${moon.manzil.index + 1}. ${moon.manzil.persian} (${moon.manzil.arabic})',
          subtitle: '${moon.manzil.star} — ${moon.manzil.description}',
          icon: Icons.star,
          color: Colors.amber.shade700,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _InfoCard(
                    title: 'نو بعدی',
                    value: '${moon.nextNewMoon.month}/${moon.nextNewMoon.day}',
                    icon: Icons.dark_mode,
                    color: Colors.indigo)),
            const SizedBox(width: 8),
            Expanded(
                child: _InfoCard(
                    title: 'بدر بعدی',
                    value:
                        '${moon.nextFullMoon.month}/${moon.nextFullMoon.day}',
                    icon: Icons.brightness_3,
                    color: Colors.orange)),
          ],
        ),
        if (moon.isAyamBeed) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('امشب از ایام البیض است — روزه مستحب 13-15',
                      style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12)),
          child: Text(
              'وَقَدَّرَهُ مَنَازِلَ لِتَعْلَمُوا عَدَدَ السِّنِينَ وَالْحِسَابَ — یونس 5\nماه میزان عبادات است: رمضان، حج، عده و زکات حول قمری.',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11), height: 1.6, color: Colors.blue.shade800)),
        ),
      ],
    );
  }
}

class _MoonPhaseCard extends StatelessWidget {
  final MoonState moon;
  const _MoonPhaseCard({required this.moon});
  @override
  Widget build(BuildContext context) {
    final phase = moon.phase;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TopicHues.moon,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(painter: _MoonPainter(phase: phase)),
          ),
          const SizedBox(height: 12),
          Text(moon.phaseName.persian,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTheme.scaledFontSize(context, 16))),
          Text('${(phase * 29.53).toStringAsFixed(1)} روز از محاق',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: AppTheme.scaledFontSize(context, 11))),
        ],
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  final double phase;
  _MoonPainter({required this.phase});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // قرص زمینهٔ تاریک
    canvas.drawCircle(
        center, r, Paint()..color = Colors.white.withValues(alpha: 0.12));

    // نسبت روشنایی: 0 محاق، 1 بدر (0.5 وسط)
    final k = (1 - math.cos(phase * 2 * math.pi)) / 2;
    if (k <= 0.005) return; // محاق — چیزی روشن نیست

    final waxing = phase < 0.5; // هلال افزاینده: سمت راست روشن
    final rxTerm = r * (2 * k - 1); // >0 بدر کاملتر، <0 هلال باریک
    final diskRect = Rect.fromCircle(center: center, radius: r);
    final termRect =
        Rect.fromCenter(center: center, width: rxTerm.abs() * 2, height: r * 2);

    final lit = Path()..moveTo(center.dx, center.dy - r);
    if (waxing) {
      // لبهٔ بیرونی: نیم‌دایرهٔ راست
      lit.arcTo(diskRect, -math.pi / 2, math.pi, false);
      // مرز روشنایی از پایین به بالا
      lit.arcTo(termRect, math.pi / 2, rxTerm >= 0 ? math.pi : -math.pi, false);
    } else {
      // لبهٔ بیرونی: نیم‌دایرهٔ چپ
      lit.arcTo(diskRect, math.pi / 2, math.pi, false);
      lit.arcTo(
          termRect, -math.pi / 2, rxTerm >= 0 ? math.pi : -math.pi, false);
    }
    lit.close();

    canvas.drawPath(lit, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MoonPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  const _InfoCard(
      {required this.title,
      required this.value,
      this.subtitle,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11), color: TimeThemeKit.of(context).palette.textMuted)),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 13), color: color)),
              if (subtitle != null)
                Text(subtitle!,
                    style:
                        TextStyle(fontSize: AppTheme.scaledFontSize(context, 10), color: TimeThemeKit.of(context).palette.textMuted)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MonthAheadTab extends StatelessWidget {
  final DateTime start;
  final int hijriOffset;
  const _MonthAheadTab({required this.start, required this.hijriOffset});
  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final today = DateTime(start.year, start.month, start.day);
    final realToday = DateTime.now();
    final days = List.generate(30, (i) => today.add(Duration(days: i)));
    return ListView.builder(
      padding: const EdgeInsets.all(DsSpacing.page),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final d = days[i];
        final age = LunarCalculator.moonAge(d);
        final illum = LunarCalculator.illumination(d);
        final phase = LunarCalculator.phase(d);
        final manzil = LunarCalculator.currentManzil(d);
        final isToday = d.year == realToday.year &&
            d.month == realToday.month &&
            d.day == realToday.day;
        final isBeed = HijriUtils.isAyamAlBidh(d, offset: hijriOffset);
        final isNew = phase < 0.02 || phase >= 0.98;
        final isFull = phase >= 0.485 && phase < 0.515;
        Color accent = Colors.grey.shade400;
        String badge = '';
        if (isNew) {
          accent = Colors.indigo;
          badge = 'محاق';
        } else if (isFull) {
          accent = Colors.amber.shade700;
          badge = 'بدر';
        } else if (isBeed) {
          accent = Colors.green;
          badge = 'ایام البیض';
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isToday
                ? TopicHues.moon.withValues(alpha: 0.12)
                : t.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isToday
                    ? TopicHues.moon
                    : t.outline,
                width: isToday ? 2 : 1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CustomPaint(painter: _MoonPainter(phase: phase)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                          '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: AppTheme.scaledFontSize(context, 12))),
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: TopicHues.moon,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('امروز',
                                style: TextStyle(
                                    color: Colors.white, fontSize: AppTheme.scaledFontSize(context, 9)))),
                      ],
                      if (badge.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(badge,
                                style: TextStyle(
                                    color: accent,
                                    fontSize: AppTheme.scaledFontSize(context, 9),
                                    fontWeight: FontWeight.w700))),
                      ],
                    ]),
                    Text(
                        'منزل ${manzil.index + 1}. ${manzil.persian} • ${illum.toStringAsFixed(0)}% روشن',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10), color: TimeThemeKit.of(context).palette.textMuted)),
                  ],
                ),
              ),
              Text(LunarCalculator.formatAge(age),
                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 10), color: TimeThemeKit.of(context).palette.textMuted)),
            ],
          ),
        );
      },
    );
  }
}

class _ManazilTab extends StatelessWidget {
  final int currentIndex;
  const _ManazilTab({required this.currentIndex});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    return GridView.builder(
      padding: const EdgeInsets.all(DsSpacing.page),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8),
      itemCount: kMoonManazil.length,
      itemBuilder: (context, i) {
        final m = kMoonManazil[i];
        final isCurrent = i == currentIndex;
        final cardColor = isCurrent
            ? TopicHues.moon.withValues(alpha: isDark ? 0.28 : 0.15)
            : t.card;
        final borderColor = isCurrent
            ? TopicHues.moon
            : t.outline;
        final titleColor = isCurrent
            ? (isDark ? Colors.white : TopicHues.moon)
            : t.textPrimary;
        final numberBg = isCurrent
            ? TopicHues.moon
            : t.outline;
        final numberFg = isCurrent
            ? Colors.white
            : t.textMuted;
        final subColor = t.textMuted;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration:
                      BoxDecoration(color: numberBg, shape: BoxShape.circle),
                  child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 10),
                              fontWeight: FontWeight.bold,
                              color: numberFg))),
                ),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(m.persian,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            color: titleColor))),
                if (isCurrent)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: TopicHues.moon,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('امشب',
                          style: TextStyle(color: Colors.white, fontSize: AppTheme.scaledFontSize(context, 9)))),
              ]),
              const SizedBox(height: 4),
              Text(m.arabic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11), color: subColor)),
              Text(m.star,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 9), color: subColor)),
            ],
          ),
        );
      },
    );
  }
}

class _HilalTab extends StatefulWidget {
  final DateTime date;
  final double lat;
  final double lng;
  const _HilalTab({required this.date, required this.lat, required this.lng});
  @override
  State<_HilalTab> createState() => _HilalTabState();
}

class _HilalTabState extends State<_HilalTab> {
  bool _hilalEnabled = false;

  /// False until the stored value is read. An unread switch shows «off» for
  /// every user, so it stays inert instead of letting a tap write the
  /// inverse of a value nobody has seen yet.
  bool _hilalLoaded = false;

  /// True while a write is in flight — a second tap during the platform call
  /// would race the first and leave the switch showing the losing result.
  bool _hilalBusy = false;
  hc.HilalMonthBasis _basis = hc.HilalMonthBasis.nakedEye;

  // ── the forecast, kept ───────────────────────────────────────────────
  //
  // Measured on this machine: the six-month forecast costs ~350 ms and the
  // four-basis comparison another ~230 ms. Both are pure functions of
  // (date, place, basis), yet they used to run inline inside [build] — so
  // every tap on a date arrow froze the tab for six tenths of a second, and
  // tapping back re-ran the same work from scratch.
  //
  // The sunset panel (~23 ms) still runs inline so the verdict paints at
  // once; the two lists are computed after the frame and memoised by their
  // exact inputs. A revisit is instant, and a new date shows a quiet
  // placeholder for the length of the computation instead of a dead screen.
  String? _calcKey;
  hv.SunsetHilalData? _data;

  final Map<String, List<hc.HilalMonth>> _monthsCache = {};
  final Map<String, Map<hc.HilalMonthBasis, List<hc.HilalMonth>>> _basesCache =
      {};
  static const _cacheLimit = 8;

  /// The key whose lists are being computed right now, so a rebuild in the
  /// same frame cannot queue the same work twice.
  String? _forecastPending;

  List<EclipseInfo> _eclipses = const [];
  String? _eclipseDayKey;

  String get _placeKey => '${widget.lat}|${widget.lng}';

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}|$_placeKey';

  void _recomputeSunset() {
    final d = widget.date;
    _calcKey = '${_dateKey(d)}|${_basis.name}';
    _data = LunarCalculator.sunsetHilal(d, widget.lat, widget.lng);
  }

  /// Fills both caches after the current frame.
  ///
  /// The two halves are cached apart on purpose: the four-basis comparison
  /// does not depend on the selected basis, so switching the basis chip
  /// re-runs only the forecast it actually invalidates.
  void _scheduleForecast(DateTime d) {
    final dateKey = _dateKey(d);
    final monthsKey = '$dateKey|${_basis.name}';
    if (_forecastPending == monthsKey) return;
    _forecastPending = monthsKey;
    final basis = _basis;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final months = LunarCalculator.hilalMonths(
          after: d, lat: widget.lat, lng: widget.lng, count: 6, basis: basis);
      final bases = _basesCache[dateKey] ??
          LunarCalculator.hilalMonthsAllBases(
              after: d, lat: widget.lat, lng: widget.lng, count: 1);
      if (!mounted) return;
      setState(() {
        _trimCache(_monthsCache, monthsKey);
        _monthsCache[monthsKey] = months;
        _trimCache(_basesCache, dateKey);
        _basesCache[dateKey] = bases;
        _forecastPending = null;
      });
    });
  }

  /// Drops the oldest entry once the cache is over its limit — keys are
  /// inserted in visit order, so `keys.first` is the coldest.
  static void _trimCache(Map<String, Object> cache, String incoming) {
    if (cache.length < _cacheLimit || cache.containsKey(incoming)) return;
    cache.remove(cache.keys.first);
  }

  /// Eclipses come from a 10-year scan (~7 300 half-day steps, each with a
  /// sun AND a moon position). It used to run inline in [build], so the first
  /// frame of this tab blocked for the entire scan on a cold cache — the tab
  /// simply did not appear until it finished. Now it is scheduled after the
  /// frame: the tab paints at once and the eclipse rows fill in a beat later.
  bool _eclipseScheduled = false;

  void _scheduleEclipsesIfNeeded() {
    final now = DateTime.now();
    final dayKey = '${now.year}-${now.month}-${now.day}';
    if (_eclipseDayKey == dayKey || _eclipseScheduled) return;
    _eclipseScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _eclipseScheduled = false;
      if (!mounted) return;
      final fresh = LunarCalculator.upcomingEclipses(DateTime.now());
      if (!mounted) return;
      setState(() {
        _eclipseDayKey = dayKey;
        _eclipses = fresh;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    HilalNotificationService.instance.isEnabled().then((v) {
      if (!mounted) return;
      setState(() {
        _hilalEnabled = v;
        _hilalLoaded = true;
      });
    }).catchError((Object e) {
      // A failed read must not leave the switch inert forever: mark it loaded
      // with the default and leave a trace.
      AppLogger.warning('MoonScreen', 'hilal enabled read failed: $e');
      if (!mounted) return;
      setState(() => _hilalLoaded = true);
    });
  }

  /// Applies the toggle optimistically and rolls it back if the platform call
  /// fails. The previous version awaited the write before touching the
  /// switch, so the thumb visibly snapped back for the length of the call and
  /// a failure left the row showing a state that was never stored.
  Future<void> _setHilalEnabled(bool value) async {
    final previous = _hilalEnabled;
    setState(() {
      _hilalEnabled = value;
      _hilalBusy = true;
    });
    try {
      await HilalNotificationService.instance
          .setEnabled(value, lat: widget.lat, lng: widget.lng);
      if (!mounted) return;
      setState(() => _hilalBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                value ? 'اعلان هلال فعال شد' : 'اعلان هلال غیرفعال شد')),
      );
    } catch (e) {
      AppLogger.warning('MoonScreen', 'hilal toggle failed: $e');
      if (!mounted) return;
      setState(() {
        _hilalEnabled = previous;
        _hilalBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تغییر اعلان هلال انجام نشد؛ دوباره تلاش کنید.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.date;
    final key = '${_dateKey(d)}|${_basis.name}';
    if (key != _calcKey) _recomputeSunset();
    _scheduleEclipsesIfNeeded();
    final data = _data;
    final months = _monthsCache[key];
    final allBases = _basesCache[_dateKey(d)];
    if (months == null || allBases == null) _scheduleForecast(d);
    final eclipses = _eclipses;
    return ListView(
      padding: const EdgeInsets.all(DsSpacing.page),
      children: [
        if (data == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                const Icon(Icons.wb_shade, size: 40, color: Colors.blueGrey),
                const SizedBox(height: 8),
                Text('در این روز غروب خورشید رخ نمی‌دهد (مناطق قطبی)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
              ],
            ),
          )
        else ...[
          _VerdictBanner(data: data, date: widget.date),
          const SizedBox(height: 12),
          HilalSkyPanel(
              date: widget.date,
              lat: widget.lat,
              lng: widget.lng,
              bestTime: data.bestTime),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _InfoCard(
                    title: 'غروب خورشید',
                    value: _fmt(data.sunset),
                    icon: Icons.wb_twilight,
                    color: TopicHues.moon)),
            const SizedBox(width: 8),
            Expanded(
                child: _InfoCard(
                    title: 'غروب ماه',
                    value: _fmt(data.moonset),
                    icon: Icons.brightness_4_outlined,
                    color: Colors.blueGrey)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _InfoCard(
                    title: 'بهترین زمان رصد',
                    value: _fmt(data.bestTime),
                    icon: Icons.center_focus_strong,
                    color: Colors.teal)),
            const SizedBox(width: 8),
            Expanded(
                child: _InfoCard(
                    title: 'مکث (4/9 یالوپ)',
                    value: '${data.lagMinutes} دقیقه',
                    icon: Icons.timer_outlined,
                    color: Colors.purple)),
          ]),
          const SizedBox(height: 12),
          _sectionTitle(context, 'پارامترهای رصدی'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                  label: 'سن در غروب',
                  value: '${data.ageHoursAtSunset.toStringAsFixed(1)}h',
                  icon: Icons.schedule,
                  color: TopicHues.moon),
              _MetricChip(
                  label: 'ARCV (زمین‌مرکز)',
                  value: '${data.arcvGeocentric.toStringAsFixed(1)}°',
                  icon: Icons.straighten,
                  color: Colors.indigo),
              _MetricChip(
                  label: 'ARCV (توپو)',
                  value: '${data.arcvTopocentric.toStringAsFixed(1)}°',
                  icon: Icons.straighten,
                  color: Colors.cyan),
              _MetricChip(
                  label: 'فاصله زاویه‌ای ARCL',
                  value: '${data.arcl.toStringAsFixed(1)}°',
                  icon: Icons.rss_feed,
                  color: Colors.teal),
              _MetricChip(
                  label: 'عرض هلال',
                  value: "${data.crescentWidthArcMin.toStringAsFixed(2)}'",
                  icon: Icons.height,
                  color: Colors.amber.shade800),
              _MetricChip(
                  label: 'روشنایی',
                  value: '${data.illuminationPercent.toStringAsFixed(1)}%',
                  icon: Icons.brightness_low,
                  color: Colors.orange),
              _MetricChip(
                  label: 'ارتفاع ماه (توپو)',
                  value: '${data.moonAltitudeTopocentric.toStringAsFixed(1)}°',
                  icon: Icons.south,
                  color: Colors.lightBlue),
              _MetricChip(
                  label: 'اختلاف آزیموت',
                  value: '${data.daz.toStringAsFixed(1)}°',
                  icon: Icons.explore,
                  color: Colors.deepPurple),
            ],
          ),
          const SizedBox(height: 12),
          _sectionTitle(context, 'معیارهای علمی'),
          const SizedBox(height: 8),
          _YallopCard(data: data),
          const SizedBox(height: 8),
          _OdehCard(data: data),
          const SizedBox(height: 8),
          _BruinDanjonCard(data: data),
          const SizedBox(height: 16),
        ],
        _sectionTitle(context, 'پیش‌بینی ماه‌های قمری'),
        const SizedBox(height: 8),
        _BasisSelector(
            basis: _basis, onChanged: (b) => setState(() => _basis = b)),
        const SizedBox(height: 8),
        if (months == null)
          const _ForecastSkeleton()
        else
          ...months
              .asMap()
              .entries
              .map((e) => _ForecastRow(index: e.key, month: e.value)),
        const SizedBox(height: 12),
        _sectionTitle(context, 'مقایسهٔ مبناها — ماه آینده'),
        const SizedBox(height: 8),
        _BasisCompareCard(all: allBases ?? const {}),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: TopicHues.moon.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: TopicHues.moon.withValues(alpha: 0.15))),
          child: Row(
            children: [
              const Icon(Icons.notifications_active,
                  size: 18, color: TopicHues.moon),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('اعلان هلال فردا',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 12), fontWeight: FontWeight.w600))),
              Switch(
                value: _hilalEnabled,
                activeThumbColor: TopicHues.moon,
                // Inert until the stored value is known and while a write
                // is in flight — see [_hilalLoaded] / [_hilalBusy].
                onChanged:
                    _hilalLoaded && !_hilalBusy ? _setHilalEnabled : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12)),
          child: Text(
              'این معیارها (یالوپ، عوده، بروین، دانژون) تقریبی هستند و جایگزین رویت شرعی با چشم نیستند — برای رمضان و حج، رویت محلی معتبر است.',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11), height: 1.6, color: Colors.indigo.shade700)),
        ),
        const SizedBox(height: 16),
        Text('کسوف و خسوف پیش‌رو',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: TopicHues.moon)),
        const SizedBox(height: 8),
        ...eclipses.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.deepPurple.withValues(alpha: 0.15))),
              child: Row(
                children: [
                  Icon(
                      e.type.contains('خسوف')
                          ? Icons.brightness_2
                          : Icons.wb_sunny,
                      size: 18,
                      color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.type,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 12))),
                        Text(e.date,
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11), color: TimeThemeKit.of(context).palette.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: e.visibleInIran
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(e.visibleInIran ? 'قابل رویت' : 'غیرقابل رویت',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            color: e.visibleInIran
                                ? Colors.green.shade700
                                : TimeThemeKit.of(context).palette.textMuted)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppTheme.scaledFontSize(context, 13),
            color: TopicHues.moon));
  }

  String _fmt(DateTime? dt) => dt == null
      ? '—'
      : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _VerdictBanner extends StatelessWidget {
  final hv.SunsetHilalData data;
  final DateTime date;
  const _VerdictBanner({required this.data, required this.date});

  (Color, IconData) get _style {
    switch (data.verdict) {
      case hv.HilalSightingVerdict.easilyVisible:
        return (Colors.green, Icons.visibility);
      case hv.HilalSightingVerdict.nakedEyePossible:
        return (Colors.lightGreen, Icons.remove_red_eye);
      case hv.HilalSightingVerdict.opticalAid:
        return (Colors.orange, Icons.search);
      case hv.HilalSightingVerdict.notVisible:
        return (Colors.red, Icons.block);
      case hv.HilalSightingVerdict.preSunsetMoonset:
        return (Colors.blueGrey, Icons.wb_twilight);
      case hv.HilalSightingVerdict.belowDanjon:
        return (Colors.deepOrange, Icons.visibility_off);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 6),
          Text(data.verdict.persian,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 15), color: color)),
          Text(
            '$date.year/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} — '
            '${data.verdict.desc}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11), color: TimeThemeKit.of(context).palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricChip(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: AppTheme.scaledFontSize(context, 9), color: TimeThemeKit.of(context).palette.textMuted))),
          ]),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 11), color: color)),
        ],
      ),
    );
  }
}

class _YallopCard extends StatelessWidget {
  final hv.SunsetHilalData data;
  const _YallopCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cls = data.yallop.cls;
    final color = _zoneColor(cls.index);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(8)),
            child: Center(
                child: Text(cls.code,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.scaledFontSize(context, 15)))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('یالوپ — ناحیهٔ ${cls.code}: ${cls.persian}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 12))),
                Text('${cls.range} • q = ${data.yallop.q.toStringAsFixed(3)}',
                    style:
                        TextStyle(fontSize: AppTheme.scaledFontSize(context, 10), color: TimeThemeKit.of(context).palette.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OdehCard extends StatelessWidget {
  final hv.SunsetHilalData data;
  const _OdehCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cls = data.odeh.cls;
    final color = _zoneColor(cls.index);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(8)),
            child: Center(
                child: Text(cls.code,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.scaledFontSize(context, 15)))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('عوده (ICOP) — ناحیهٔ ${cls.code}: ${cls.persian}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 12))),
                Text('${cls.range} • V = ${data.odeh.v.toStringAsFixed(2)}',
                    style:
                        TextStyle(fontSize: AppTheme.scaledFontSize(context, 10), color: TimeThemeKit.of(context).palette.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BruinDanjonCard extends StatelessWidget {
  final hv.SunsetHilalData data;
  const _BruinDanjonCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final bruinVisible = data.bruin.visible;
    final dVisible = !data.danjon.belowLimit;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.brown.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.brown.withValues(alpha: 0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(bruinVisible ? Icons.check_circle : Icons.cancel,
                size: 16, color: bruinVisible ? Colors.green : Colors.red),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
                    'بروین: ${bruinVisible ? 'بالاتر از آستانه — قابل رؤیت' : 'پایین‌تر از آستانه — نامرئی'}  '
                    '(ARCV آستانه: ${data.bruin.arcvCritical.toStringAsFixed(1)}°)',
                    style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11)))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(dVisible ? Icons.check_circle : Icons.cancel,
                size: 16, color: dVisible ? Colors.green : Colors.red),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
                    'دانژون: elongation = ${data.arcl.toStringAsFixed(1)}°  '
                    '(حد ≈ ${data.danjon.limitDeg.toStringAsFixed(1)}°) — '
                    '${dVisible ? 'بالاتر از حد' : 'فروتر از حد'}',
                    style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11)))),
          ]),
        ],
      ),
    );
  }
}

Color _zoneColor(int index) {
  const colors = [
    Colors.green,
    Colors.lightGreen,
    Colors.orange,
    Colors.deepOrange,
    Colors.red,
    Colors.brown,
  ];
  return colors[index.clamp(0, colors.length - 1)];
}

class _BasisSelector extends StatelessWidget {
  final hc.HilalMonthBasis basis;
  final ValueChanged<hc.HilalMonthBasis> onChanged;
  const _BasisSelector({required this.basis, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final b in hc.HilalMonthBasis.values)
          ChoiceChip(
            label: Text(b.persian, style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11))),
            selected: b == basis,
            selectedColor: TopicHues.moon.withValues(alpha: 0.2),
            onSelected: (_) => onChanged(b),
          ),
      ],
    );
  }
}

class _ForecastRow extends StatelessWidget {
  final int index;
  final hc.HilalMonth month;
  const _ForecastRow({required this.index, required this.month});

  @override
  Widget build(BuildContext context) {
    final s = month.sightingEvening;
    final verdict = s?.verdict;
    final color = verdict == null
        ? Colors.grey
        : switch (verdict) {
            hv.HilalSightingVerdict.easilyVisible ||
            hv.HilalSightingVerdict.nakedEyePossible =>
              Colors.green,
            hv.HilalSightingVerdict.opticalAid => Colors.orange,
            hv.HilalSightingVerdict.notVisible ||
            hv.HilalSightingVerdict.belowDanjon =>
              Colors.red,
            hv.HilalSightingVerdict.preSunsetMoonset => Colors.blueGrey,
          };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: TimeThemeKit.of(context).palette.card,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: TimeThemeKit.of(context).palette.outline)),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: TopicHues.moon.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Center(
                child: Text('${index + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: TopicHues.moon))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${month.startDate.year}/${month.startDate.month.toString().padLeft(2, '0')}/${month.startDate.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: AppTheme.scaledFontSize(context, 12))),
                Text('طول ماه: ${month.days} روز',
                    style:
                        TextStyle(fontSize: AppTheme.scaledFontSize(context, 10), color: TimeThemeKit.of(context).palette.textMuted)),
              ],
            ),
          ),
          if (verdict != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(verdict.persian,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 9), fontWeight: FontWeight.w700, color: color)),
            ),
        ],
      ),
    );
  }
}

/// Six quiet bars standing in for the month rows while the forecast runs.
///
/// No animation on purpose: the work is short enough that a shimmer would be
/// gone before the eye found it, and a still shape reads as "loading" without
/// pulling attention away from the verdict above.
class _ForecastSkeleton extends StatelessWidget {
  const _ForecastSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 46,
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.outline),
            ),
          ),
      ],
    );
  }
}

class _BasisCompareCard extends StatelessWidget {
  final Map<hc.HilalMonthBasis, List<hc.HilalMonth>> all;
  const _BasisCompareCard({required this.all});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: TopicHues.moon.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: TopicHues.moon.withValues(alpha: 0.15))),
      child: Column(
        children: [
          for (final b in hc.HilalMonthBasis.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(b.persian,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10), fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Builder(builder: (context) {
                      final list = all[b];
                      final m =
                          (list == null || list.isEmpty) ? null : list.first;
                      if (m == null) return const Text('—');
                      final s = m.startDate;
                      return Text(
                          '${s.year}/${s.month.toString().padLeft(2, '0')}/${s.day.toString().padLeft(2, '0')}  '
                          '(${m.days} روز)',
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 11), color: TimeThemeKit.of(context).palette.textMuted));
                    }),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
