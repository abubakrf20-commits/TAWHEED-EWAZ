import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_style.dart';

class DateConverterScreen extends ConsumerStatefulWidget {
  final int? initialHijriDay, initialHijriMonth, initialHijriYear;
  final int? initialShamsiDay, initialShamsiMonth, initialShamsiYear;
  final int? initialGregorianDay, initialGregorianMonth, initialGregorianYear;
  final int? hijriOffset;

  const DateConverterScreen({
    super.key,
    this.initialHijriDay,
    this.initialHijriMonth,
    this.initialHijriYear,
    this.initialShamsiDay,
    this.initialShamsiMonth,
    this.initialShamsiYear,
    this.initialGregorianDay,
    this.initialGregorianMonth,
    this.initialGregorianYear,
    this.hijriOffset,
  });

  @override
  ConsumerState<DateConverterScreen> createState() =>
      _DateConverterScreenState();
}

class _DateConverterScreenState extends ConsumerState<DateConverterScreen> {
  int _sourceType = 1; // 1=hijri, 2=shamsi, 3=gregorian
  int _hijriDay = 1, _hijriMonth = 1, _hijriYear = 1447;
  int _shamsiDay = 1, _shamsiMonth = 1, _shamsiYear = 1404;
  int _gregorianDay = 1, _gregorianMonth = 3, _gregorianYear = 2026;
  String _weekday = '';

  late int _hijriOffset;

  final _hijriYearCtrl = TextEditingController();
  final _shamsiYearCtrl = TextEditingController();
  final _gregYearCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hijriOffset = widget.hijriOffset ?? ref.read(hijriOffsetProvider);
    _initFromParams();
    _convert();
    _syncYearControllers();
    // An offset read in initState can still be the pre-settings fallback, and
    // a change made in Settings must move this page too: the calendar page
    // listens the same way, or the two would print different hijri days for
    // one date. An explicit [DateConverterScreen.hijriOffset] pins it instead.
    if (widget.hijriOffset == null) {
      ref.listenManual(hijriOffsetProvider, (prev, next) {
        if (prev != next && mounted) {
          setState(() {
            _hijriOffset = next;
            _convert();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _hijriYearCtrl.dispose();
    _shamsiYearCtrl.dispose();
    _gregYearCtrl.dispose();
    super.dispose();
  }

  void _syncYearControllers() {
    _hijriYearCtrl.text = _hijriYear.toString();
    _shamsiYearCtrl.text = _shamsiYear.toString();
    _gregYearCtrl.text = _gregorianYear.toString();
  }

  void _initFromParams() {
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);
    final hijri = HijriUtils.hijriFromGreg(now.year, now.month, now.day,
        offset: _hijriOffset);

    if (widget.initialHijriDay != null) {
      _sourceType = 1;
      _hijriDay = widget.initialHijriDay!;
      _hijriMonth = widget.initialHijriMonth!;
      _hijriYear = widget.initialHijriYear!;
    } else if (widget.initialShamsiDay != null) {
      _sourceType = 2;
      _shamsiDay = widget.initialShamsiDay!;
      _shamsiMonth = widget.initialShamsiMonth!;
      _shamsiYear = widget.initialShamsiYear!;
    } else if (widget.initialGregorianDay != null) {
      _sourceType = 3;
      _gregorianDay = widget.initialGregorianDay!;
      _gregorianMonth = widget.initialGregorianMonth!;
      _gregorianYear = widget.initialGregorianYear!;
    } else {
      _hijriDay = hijri.day;
      _hijriMonth = hijri.month;
      _hijriYear = hijri.year;
      _shamsiDay = jalali.day;
      _shamsiMonth = jalali.month;
      _shamsiYear = jalali.year;
      _gregorianDay = now.day;
      _gregorianMonth = now.month;
      _gregorianYear = now.year;
    }
  }

  int _maxDay(int type, int year, int month) {
    if (type == 1) {
      return HijriUtils.hijriMonthLength(month, year: year);
    } else if (type == 2) {
      // Shamsi — month 12 has 30 days in leap years.
      return Jalali(year, month).monthLength;
    } else {
      return DateTime(year, month + 1, 0).day;
    }
  }

  void _clampDay(int type) {
    final max = _maxDay(
        type,
        type == 1 ? _hijriYear : (type == 2 ? _shamsiYear : _gregorianYear),
        type == 1 ? _hijriMonth : (type == 2 ? _shamsiMonth : _gregorianMonth));
    if (type == 1) {
      _hijriDay = _hijriDay.clamp(1, max);
    } else if (type == 2) {
      _shamsiDay = _shamsiDay.clamp(1, max);
    } else {
      _gregorianDay = _gregorianDay.clamp(1, max);
    }
  }

  /// Convert the *source* date into the other two systems without overwriting
  /// the source's own fields (avoids round-trip drift from the hijri offset).
  void _convert() {
    try {
      DateTime greg;
      if (_sourceType == 1) {
        _clampDay(1);
        greg = HijriUtils.hijriToGreg(_hijriYear, _hijriMonth, _hijriDay,
            offset: _hijriOffset);
      } else if (_sourceType == 2) {
        _clampDay(2);
        greg = Jalali(_shamsiYear, _shamsiMonth, _shamsiDay).toDateTime();
      } else {
        _clampDay(3);
        greg = DateTime(_gregorianYear, _gregorianMonth, _gregorianDay);
      }

      _gregorianDay = greg.day;
      _gregorianMonth = greg.month;
      _gregorianYear = greg.year;

      final jalali = Jalali.fromDateTime(greg);
      _shamsiDay = jalali.day;
      _shamsiMonth = jalali.month;
      _shamsiYear = jalali.year;

      // Only recompute hijri when it is NOT the source (preserve user entry).
      if (_sourceType != 1) {
        final hijri = HijriUtils.hijriFromGreg(greg.year, greg.month, greg.day,
            offset: _hijriOffset);
        _hijriDay = hijri.day;
        _hijriMonth = hijri.month;
        _hijriYear = hijri.year;
      }

      _weekday = weekdayName(greg);
      _syncYearControllers();
    } catch (e) {
      AppLogger.warning('Date conversion failed', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'مبدل تاریخ',
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'امروز',
            onPressed: _goToToday,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'copy', child: Text('کپی همه')),
              const PopupMenuItem(value: 'share', child: Text('اشتراک‌گذاری')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DsSpacing.page),
        children: [
          SegmentedTabs(
            tabs: const [
              SegmentedTab(label: 'هجری'),
              SegmentedTab(label: 'شمسی'),
              SegmentedTab(label: 'میلادی'),
            ],
            index: _sourceType - 1,
            onChanged: (i) => setState(() {
              _sourceType = i + 1;
              _convert();
            }),
          ),
          const SizedBox(height: DsSpacing.gap),
          _buildInputSection(),
          const SizedBox(height: DsSpacing.gap),
          if (_weekday.isNotEmpty)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: isDark ? 0.16 : 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.primary.withValues(alpha: .3)),
                ),
                child: Text(_weekday,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 15),
                      fontWeight: FontWeight.w700,
                      color: t.primary,
                    )),
              ),
            ),
          const SizedBox(height: DsSpacing.gap),
          _buildResultCard('هجری قمری', _hijriDay, _hijriMonth, _hijriYear,
              DateConstants.hijriMonths, CalendarHues.hijri),
          const SizedBox(height: DsSpacing.gap),
          _buildResultCard('شمسی (جلالی)', _shamsiDay, _shamsiMonth,
              _shamsiYear, DateConstants.persianMonths, CalendarHues.shamsi),
          const SizedBox(height: DsSpacing.gap),
          _buildResultCard(
              'میلادی',
              _gregorianDay,
              _gregorianMonth,
              _gregorianYear,
              DateConstants.gregorianMonths,
              CalendarHues.gregorian),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    if (_sourceType == 1) {
      return _buildTripleInput(
        'سال هجری',
        _hijriYear,
        1300,
        1500,
        _hijriYearCtrl,
        'ماه',
        _hijriMonth,
        DateConstants.hijriMonths,
        'روز',
        _hijriDay,
        1,
        _maxDay(1, _hijriYear, _hijriMonth),
        (y, m, d) {
          setState(() {
            _hijriYear = y;
            _hijriMonth = m;
            _hijriDay = d;
            _convert();
          });
        },
      );
    } else if (_sourceType == 2) {
      return _buildTripleInput(
        'سال شمسی',
        _shamsiYear,
        1300,
        1450,
        _shamsiYearCtrl,
        'ماه',
        _shamsiMonth,
        DateConstants.persianMonths,
        'روز',
        _shamsiDay,
        1,
        _maxDay(2, _shamsiYear, _shamsiMonth),
        (y, m, d) {
          setState(() {
            _shamsiYear = y;
            _shamsiMonth = m;
            _shamsiDay = d;
            _convert();
          });
        },
      );
    } else {
      return _buildTripleInput(
        'سال میلادی',
        _gregorianYear,
        1900,
        2100,
        _gregYearCtrl,
        'ماه',
        _gregorianMonth,
        DateConstants.gregorianMonths,
        'روز',
        _gregorianDay,
        1,
        _maxDay(3, _gregorianYear, _gregorianMonth),
        (y, m, d) {
          setState(() {
            _gregorianYear = y;
            _gregorianMonth = m;
            _gregorianDay = d;
            _convert();
          });
        },
      );
    }
  }

  Widget _buildTripleInput(
    String yearLabel,
    int yearValue,
    int yearMin,
    int yearMax,
    TextEditingController yearCtrl,
    String monthLabel,
    int monthValue,
    List<String> monthNames,
    String dayLabel,
    int dayValue,
    int dayMin,
    int dayMax,
    Function(int, int, int) onChanged,
  ) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.all(12),
      borderColor: t.primary.withValues(alpha: 0.3),
      child: Column(
        children: [
          _buildYearRow(yearLabel, yearValue, yearMin, yearMax, yearCtrl, (v) {
            onChanged(v, monthValue, dayValue);
          }),
          const SizedBox(height: DsSpacing.gap),
          _buildMonthRow(monthLabel, monthValue, monthNames, (v) {
            onChanged(yearValue, v, dayValue);
          }),
          const SizedBox(height: DsSpacing.gap),
          _buildNumberRow(dayLabel, dayValue, dayMin, dayMax, (v) {
            onChanged(yearValue, monthValue, v);
          }),
        ],
      ),
    );
  }

  Widget _buildYearRow(String label, int value, int min, int max,
      TextEditingController ctrl, Function(int) onChanged) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        _rowLabel(label),
        // Fast -10. These two used to set padding: EdgeInsets.zero and a
        // zero BoxConstraints, which shrank the tap target to the 18px glyph.
        IconButton(
          icon: const Icon(Icons.fast_rewind),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          tooltip: '10 سال عقب',
          onPressed: value - 10 >= min
              ? () => onChanged((value - 10).clamp(min, max))
              : null,
          color: value - 10 >= min ? t.primary : t.textMuted,
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          iconSize: 28,
          visualDensity: VisualDensity.compact,
          tooltip: 'یک سال عقب',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          color: value > min ? t.primary : t.textMuted,
        ),
        Expanded(
          // The visible row label is a sibling, so the field itself must
          // carry the name for TalkBack.
          child: Semantics(
            label: label,
            child: TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 18),
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()]),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (text) {
                // Apply only a complete, in-range year. Clamping every keystroke
                // (and then rewriting the field from _syncYearControllers) made
                // typing «1447» impossible: the first digit became 1300.
                final v = int.tryParse(text);
                if (v != null && v >= min && v <= max) onChanged(v);
              },
              onSubmitted: (text) {
                final v = int.tryParse(text);
                if (v == null) return;
                onChanged(v.clamp(min, max));
              },
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          iconSize: 28,
          visualDensity: VisualDensity.compact,
          tooltip: 'یک سال جلو',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          color: value < max ? t.primary : t.textMuted,
        ),
        // Fast +10
        IconButton(
          icon: const Icon(Icons.fast_forward),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          tooltip: '10 سال جلو',
          onPressed: value + 10 <= max
              ? () => onChanged((value + 10).clamp(min, max))
              : null,
          color: value + 10 <= max ? t.primary : t.textMuted,
        ),
      ],
    );
  }

  Widget _buildNumberRow(
      String label, int value, int min, int max, Function(int) onChanged) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        _rowLabel(label),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 28,
                visualDensity: VisualDensity.compact,
                tooltip: 'کاهش یک واحد',
                onPressed: value > min ? () => onChanged(value - 1) : null,
                color: value > min ? t.primary : t.textMuted,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$value',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 18),
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 28,
                visualDensity: VisualDensity.compact,
                tooltip: 'افزایش یک واحد',
                onPressed: value < max ? () => onChanged(value + 1) : null,
                color: value < max ? t.primary : t.textMuted,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The right-hand name of an input row. 60px keeps the three rows' controls
  /// on one left edge.
  Widget _rowLabel(String label) {
    final t = TimeThemeKit.of(context).palette;
    return SizedBox(
        width: 60,
        child: Text(label,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: t.textMuted)));
  }

  Widget _buildMonthRow(
      String label, int value, List<String> names, Function(int) onChanged) {
    return Row(
      children: [
        _rowLabel(label),
        Expanded(
          child: SizedBox(
            height: 40,
            child:
                _MonthStrip(names: names, value: value, onChanged: onChanged),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(String title, int day, int month, int year,
      List<String> monthNames, Color hue) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = dsContentColor(context, hue);
    return AppCard(
      padding: const EdgeInsets.all(12),
      color: hue.withValues(alpha: isDark ? 0.14 : 0.05),
      borderColor: hue.withValues(alpha: isDark ? 0.34 : 0.22),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
                color: hue, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: ink,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('$day ${monthNames[month - 1]} $year',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 18),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy_rounded, size: 18, color: ink),
            tooltip: 'کپی',
            visualDensity: VisualDensity.compact,
            onPressed: () => _copyOne(title, day, month, year, monthNames),
          ),
        ],
      ),
    );
  }

  void _goToToday() {
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);
    final hijri = HijriUtils.hijriFromGreg(now.year, now.month, now.day,
        offset: _hijriOffset);
    setState(() {
      _hijriDay = hijri.day;
      _hijriMonth = hijri.month;
      _hijriYear = hijri.year;
      _shamsiDay = jalali.day;
      _shamsiMonth = jalali.month;
      _shamsiYear = jalali.year;
      _gregorianDay = now.day;
      _gregorianMonth = now.month;
      _gregorianYear = now.year;
      _convert();
    });
  }

  void _copyOne(
      String title, int day, int month, int year, List<String> months) {
    final text = '$title: $day ${months[month - 1]} $year';
    Clipboard.setData(ClipboardData(text: text));
    AppSnackBar.success(context, 'کپی شد');
  }

  void _handleMenuAction(String action) {
    const hijriMonths = DateConstants.hijriMonths;
    final shamsiMonths = DateConstants.persianMonths;
    const gregMonths = DateConstants.gregorianMonths;

    final text =
        'هجری: $_hijriDay ${hijriMonths[_hijriMonth - 1]} $_hijriYear\n'
        'شمسی: $_shamsiDay ${shamsiMonths[_shamsiMonth - 1]} $_shamsiYear\n'
        'میلادی: $_gregorianDay ${gregMonths[_gregorianMonth - 1]} $_gregorianYear\n'
        '$_weekday';

    if (action == 'copy') {
      Clipboard.setData(ClipboardData(text: text));
      AppSnackBar.success(context, 'کپی شد');
    } else if (action == 'share') {
      SharePlus.instance.share(ShareParams(text: text));
    }
  }
}

/// The twelve month names as a horizontal strip that always opens with the
/// selected month in view. The strip used to start at month 1, so a converted
/// date in, say, مهر sat off-screen with nothing hinting that it was there.
class _MonthStrip extends StatefulWidget {
  const _MonthStrip({
    required this.names,
    required this.value,
    required this.onChanged,
  });

  final List<String> names;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_MonthStrip> createState() => _MonthStripState();
}

class _MonthStripState extends State<_MonthStrip> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(covariant _MonthStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The same State is reused when the source system changes, so the names
    // changing is a reveal trigger too — the chips resize.
    if (oldWidget.value != widget.value ||
        !identical(oldWidget.names, widget.names)) {
      _revealSelected();
    }
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _selectedKey.currentContext;
      if (!mounted || context == null) return;
      Scrollable.ensureVisible(context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < widget.names.length; i++)
            Builder(
              key: i + 1 == widget.value ? _selectedKey : null,
              builder: (ctx) {
                final selected = i + 1 == widget.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onChanged(i + 1),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        // The day cell's own selection language: a flat tint of
                        // the primary, the primary hairline, no reversed ink.
                        color: selected
                            ? t.primary.withValues(alpha: isDark ? 0.16 : 0.06)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? t.primary : t.outline,
                          width: selected ? 1.2 : .5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.names[i],
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? t.primary : t.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
