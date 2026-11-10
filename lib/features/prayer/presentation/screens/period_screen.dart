import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_session.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/period_widgets.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

class PeriodScreen extends ConsumerStatefulWidget {
  const PeriodScreen({super.key});

  @override
  ConsumerState<PeriodScreen> createState() => _PeriodScreenState();
}

class _PeriodScreenState extends ConsumerState<PeriodScreen> {
  int _selectedMonth = Jalali.fromDateTime(DateTime.now()).month;
  int _selectedYear = Jalali.fromDateTime(DateTime.now()).year;

  /// Shared section header: transparent over the ambient backdrop; the pink
  /// icon keeps the page tied to the «دوره ماهانه» entry that opened it.
  AppBar _appBar({List<Widget>? actions}) {
    final t = TimeThemeKit.of(context).palette;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: t.primary,
      iconTheme: IconThemeData(color: t.primary),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.woman_outlined, color: TopicHues.period, size: 20),
          const SizedBox(width: 6),
          Text('دوره ماهانه',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                color: t.primary,
              )),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final asyncState = ref.watch(periodProvider);
    final notifier = ref.read(periodProvider.notifier);

    return asyncState.when(
      loading: () => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _appBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _appBar(),
        body: FailureView(
          id: 'period_load',
          title: 'بارگذاری دورهٔ ماهانه ناموفق بود',
          detail: 'ثبت‌های شما پاک نشده‌اند؛ فقط خواندنشان ناموفق بود. '
              'این بخش برای محافظت از حریم شما با کد قفل است و بدون آن باز نمی‌شود.',
          onRetry: () => ref.invalidate(periodProvider),
          layout: FailureLayout.page,
          error: e,
        ),
      ),
      data: (state) {
        // The proof that the PIN was entered lives in [periodSessionProvider],
        // not in this State: held locally it survived the app going to the
        // background, which left every record open on screen.
        if (state.isLocked && !ref.watch(periodSessionProvider)) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _appBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: t.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'این بخش قفل است',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 16),
                        color: t.textMuted),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _showUnlockDialog(context, notifier),
                    icon: const Icon(Icons.lock_open_outlined, size: 18),
                    label: Text('ورود رمز',
                        style: TextStyle(fontFamily: AppTheme.fontFamily)),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _appBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmClearAll(notifier),
                tooltip: 'پاک کردن همه',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.page, 4, DsSpacing.page, 24),
            children: [
              PeriodStatusCard(notifier: notifier),
              const SizedBox(height: 12),
              PeriodPregnancySection(notifier: notifier),
              const SizedBox(height: 12),
              PeriodStatsSection(notifier: notifier),
              const SizedBox(height: 12),
              PeriodCalendarSection(
                notifier: notifier,
                selectedMonth: _selectedMonth,
                selectedYear: _selectedYear,
                onMonthChanged: (m, y) => setState(() {
                  _selectedMonth = m;
                  _selectedYear = y;
                }),
              ),
              const SizedBox(height: 12),
              PeriodInputSection(notifier: notifier),
              const SizedBox(height: 12),
              const PeriodRulingsSection(),
              const SizedBox(height: 12),
              PeriodHistorySection(notifier: notifier),
              const SizedBox(height: 12),
              PeriodReportSection(notifier: notifier),
              const SizedBox(height: 12),
              // قضای روزه — the interactive make-up-fasts ledger. The static
              // «رمضان و قضای روزه» summary card was removed: it showed the
              // same Ramadan-derived number twice (here and in the ledger),
              // so everything lives in one place now.
              PeriodQadaFastingSection(notifier: notifier),
              const SizedBox(height: 12),
              PeriodNotificationsSection(notifier: notifier),
              const SizedBox(height: 12),
              PeriodLockSection(notifier: notifier),
              const SizedBox(height: 12),
              const PeriodPrivacyNote(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showUnlockDialog(BuildContext context, Period notifier) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ورود رمز'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          onSubmitted: (_) {
            if (_pinAccepted(notifier, ctrl.text)) {
              Navigator.pop(ctx, true);
            } else {
              _wrongPin(ctx);
            }
          },
          decoration: const InputDecoration(
            hintText: 'رمز خود را وارد کنید',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          if (notifier.hasRecovery)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
                _showRecoveryDialog(context, notifier);
              },
              child: const Text('فراموشی رمز'),
            ),
          FilledButton(
            onPressed: () {
              if (_pinAccepted(notifier, ctrl.text)) {
                Navigator.pop(ctx, true);
              } else {
                _wrongPin(ctx);
              }
            },
            child: const Text('ورود'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == true && mounted) {
      ref.read(periodSessionProvider.notifier).unlock();
    }
  }

  /// Accepts the digits the keyboard actually produced: a PIN stored as `1234`
  /// must not reject the Persian `۱۲۳۴` typed for it, and vice versa.
  bool _pinAccepted(Period notifier, String raw) =>
      notifier.verifyPin(NumberFormat.normalizeDigits(raw));

  void _wrongPin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('رمز اشتباه است'), duration: Duration(seconds: 2)),
    );
  }

  void _wrongAnswer(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('پاسخ اشتباه است'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _showRecoveryDialog(
      BuildContext context, Period notifier) async {
    final answerCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();

    // First step: answer recovery question
    final answered = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازیابی رمز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(notifier.recoveryQuestion,
                style:
                    TextStyle(fontFamily: AppTheme.fontFamily, fontSize: AppTheme.scaledFontSize(context, 14))),
            const SizedBox(height: 12),
            TextField(
              controller: answerCtrl,
              autofocus: true,
              onSubmitted: (_) {
                if (notifier.verifyRecoveryAnswer(answerCtrl.text)) {
                  Navigator.pop(ctx, true);
                } else {
                  _wrongAnswer(ctx);
                }
              },
              decoration: const InputDecoration(
                hintText: 'پاسخ خود را وارد کنید',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          FilledButton(
            onPressed: () {
              if (notifier.verifyRecoveryAnswer(answerCtrl.text)) {
                Navigator.pop(ctx, true);
              } else {
                _wrongAnswer(ctx);
              }
            },
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    answerCtrl.dispose();
    if (answered != true) return;

    // Second step: set new PIN
    if (!context.mounted) return;
    final newPin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رمز جدید'),
        content: TextField(
          controller: newPinCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          maxLength: 4,
          onSubmitted: (_) => _submitNewPin(ctx, newPinCtrl),
          decoration: const InputDecoration(
            hintText: 'رمز جدید (4 رقم)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(
            onPressed: () => _submitNewPin(ctx, newPinCtrl),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    newPinCtrl.dispose();
    if (newPin == null) return;
    await notifier.resetPin(newPin);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('رمز با موفقیت تغییر کرد'),
            duration: Duration(seconds: 2)),
      );
    }
  }

  /// Hands a validated replacement PIN back to the caller.
  ///
  /// Returned as ASCII digits: a code kept as `۱۲۳۴` would never match the
  /// `1234` the unlock path compares against.
  void _submitNewPin(BuildContext dialogContext, TextEditingController ctrl) {
    final pin = NumberFormat.normalizeDigits(ctrl.text);
    if (pin.length != 4) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(
            content: Text('رمز باید 4 رقم باشد'),
            duration: Duration(seconds: 2)),
      );
      return;
    }
    Navigator.pop(dialogContext, pin);
  }

  void _confirmClearAll(Period notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک کردن همه داده‌ها'),
        content: const Text('آیا از حذف تمام تاریخچه پریودی اطمینان دارید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.lightError),
            onPressed: () {
              notifier.clearAll();
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

/// قضای روزه — ledger of make-up fasts the user owes and has completed.
///
/// Independent of the period-derived Ramadan misses: the user can set any owed
/// total and record the fasts one by one. «افزودن روزه‌های رمضان» pulls the days
/// that fall inside recorded period days during Ramadan into the owed total, so
/// the automatic calculation and the manual ledger work together.
class PeriodQadaFastingSection extends ConsumerStatefulWidget {
  const PeriodQadaFastingSection({super.key, required this.notifier});

  final Period notifier;

  @override
  ConsumerState<PeriodQadaFastingSection> createState() =>
      _PeriodQadaFastingSectionState();
}

class _PeriodQadaFastingSectionState
    extends ConsumerState<PeriodQadaFastingSection> {
  Widget _metricRow(BuildContext context, String label, String value,
      {bool highlight = false}) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              color: t.textMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? periodAccentDeep : t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editOwed(int current) async {
    final ctrl = TextEditingController(text: '$current');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعداد روزه‌های قضای واجب'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'مثلاً 7',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(
            // A Persian keyboard types «۷»; tryParse would return null and the
            // dialog would close having done nothing.
            onPressed: () => Navigator.pop(
                ctx, int.tryParse(NumberFormat.normalizeDigits(ctrl.text))),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result >= 0) {
      await widget.notifier.setQadaFastsOwed(result);
    }
  }

  Future<void> _addFromRamadan() async {
    // getRamadanSummary takes the GREGORIAN year and finds the days whose Hijri
    // month is Ramadan (9) that fall inside recorded period days.
    final year = DateTime.now().year;
    final offset = ref.read(hijriOffsetProvider);
    final summary =
        widget.notifier.getRamadanSummary(year, hijriOffset: offset);
    final missed = (summary['missedDays'] as int?) ?? 0;
    if (!mounted) return;
    if (missed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('روزهٔ قضایی بر اساس روزهای ثبت‌شدهٔ امسال پیدا نشد.'),
        duration: Duration(seconds: 3),
      ));
      return;
    }
    // Idempotent: only the newly-recorded days are added on repeat taps.
    final added =
        await widget.notifier.addRamadanMissedToQada(year, hijriOffset: offset);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added > 0
          ? '$added روز جدید به قضای رمضان اضافه شد'
          : 'همهٔ روزهای قضا قبلاً اضافه شده‌اند'),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final state = ref.watch(periodProvider).value;
    final owed = state?.qadaFastsOwed ?? 0;
    final done = state?.qadaFastsDone ?? 0;
    final remaining = state?.qadaFastsRemaining ?? 0;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_repeat_outlined,
                  size: 20, color: periodAccentDeep),
              const SizedBox(width: 8),
              Text(
                'قضای روزه',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.bold,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _metricRow(context, 'واجب (کل)', '$owed روز'),
          _metricRow(context, 'ادا شده', '$done روز'),
          _metricRow(context, 'باقی‌مانده', '$remaining روز', highlight: true),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: owed <= 0 ? 0 : (done / owed).clamp(0.0, 1.0),
            minHeight: 6,
            color: periodAccent,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: remaining > 0
                    ? () => widget.notifier.addQadaFastDone()
                    : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('ثبت یک روز'),
              ),
              OutlinedButton.icon(
                onPressed: done > 0
                    ? () => widget.notifier.removeQadaFastDone()
                    : null,
                icon: const Icon(Icons.remove, size: 18),
                label: const Text('لغو یکی'),
              ),
              OutlinedButton.icon(
                onPressed: () => _editOwed(owed),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('ویرایش تعداد واجب'),
              ),
              TextButton.icon(
                onPressed: _addFromRamadan,
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('افزودن روزه‌های رمضان'),
              ),
              if (owed > 0 || done > 0)
                TextButton.icon(
                  onPressed: () => widget.notifier.resetQadaFasts(),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('صفر کردن'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
