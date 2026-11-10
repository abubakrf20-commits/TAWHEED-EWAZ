import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Which slice of the evaluation the reader is asking to clear.
///
/// The reset used to be one global action, and it read as broken: it deleted
/// the evaluation's own rows while the prayers, adhkar and tasbih records that
/// the score is built from stayed, so the score re-derived itself immediately.
/// Each tab now resets only its own range (user decision, 2026-11-05) — and the
/// range reset is a FULL wipe of that range's records, so the numbers actually
/// go to zero.
enum EvaluationResetScope { daily, weekly, monthly }

/// The dialog title and the noun used across the copy for [scope].
String evaluationResetTitle(EvaluationResetScope scope) => switch (scope) {
      EvaluationResetScope.daily => 'ریست ارزیابی روزانه؟',
      EvaluationResetScope.weekly => 'ریست ارزیابی هفتگی؟',
      EvaluationResetScope.monthly => 'ریست ارزیابی ماهانه؟',
    };

/// Asks before the evaluation of one range is cleared.
///
/// WHY a dialog, and why it is this long: the action deletes records that four
/// surfaces read — the daily checklist, the fasting marks in the calendar, the
/// step checklists inside نماز و وضو, and every score the week/month charts and
/// streaks are drawn from — and unlike the old global reset it also un-ticks
/// the prayers, adhkar and daily tasbih of the range, because that is what
/// makes the score actually reach zero. A one-line «آیا مطمئنید؟» asks the
/// reader to agree to something it never described. So the dialog names the
/// range, names what it deletes, names what it keeps, and says plainly that it
/// cannot be undone.
///
/// The numbers come from the provider's in-memory score cache scoped to the
/// same range, so the reader is deciding about their actual history rather
/// than an abstraction.
Future<bool> confirmEvaluationReset(
  BuildContext context, {
  required EvaluationResetScope scope,
  required String rangeLabel,
  required int days,
  required int points,
  required int bestStreak,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ResetDialog(
      scope: scope,
      rangeLabel: rangeLabel,
      days: days,
      points: points,
      bestStreak: bestStreak,
    ),
  );
  return confirmed == true;
}

class _ResetDialog extends StatelessWidget {
  const _ResetDialog({
    required this.scope,
    required this.rangeLabel,
    required this.days,
    required this.points,
    required this.bestStreak,
  });

  final EvaluationResetScope scope;
  final String rangeLabel;
  final int days;
  final int points;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    // The palette's own error colour, not a hand-picked red: this is the one
    // destructive action in the app that is not a restore, and it should read as
    // the same kind of red as every other failure the reader has seen.
    final danger = Theme.of(context).colorScheme.error;
    final bodyStyle = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: AppTheme.scaledFontSize(context, 13),
      height: 1.8,
      color: t.textSecondary,
    );
    final bulletStyle = bodyStyle.copyWith(color: t.textPrimary);

    return AlertDialog(
      backgroundColor: t.surface,
      icon: Icon(Icons.restart_alt, color: danger, size: 30),
      title: Text(
        evaluationResetTitle(scope),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 16),
          fontWeight: FontWeight.w800,
          color: t.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ارزیابی این بازه پاک می‌شود: $rangeLabel', style: bodyStyle),
            const SizedBox(height: 8),
            _Bullet(
              style: bulletStyle,
              text: days == 0
                  ? 'در این بازه هیچ روز امتیازداری ثبت نشده است.'
                  : '$days روز امتیاز ثبت‌شده ($points امتیاز در مجموع)',
            ),
            _Bullet(
              style: bulletStyle,
              text: bestStreak == 0
                  ? 'رشته‌ای برای پاک شدن در این بازه نیست.'
                  : 'بهترین رشتهٔ داخل بازه: $bestStreak روز',
            ),
            _Bullet(
              style: bulletStyle,
              text: 'تیک‌های نمازها، اذکار و شمارش تسبیح روزانهٔ همین بازه — '
                  'و تیک‌های چک‌لیست طاعات، همان تیک‌هایی که تقویم برای روزه '
                  'و مراحل نماز و وضو هم می‌خواند',
            ),
            const SizedBox(height: 12),
            // Neutral, not red and not green: this box is the answer to the
            // reader's real question ("what am I not losing?"), and dressing it
            // in either alarm colour would make them read it as a second
            // warning. The red in this dialog is spent on one line — the one
            // that says it cannot be undone.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'این‌ها دست‌نخورده می‌مانند:',
                    style: bodyStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مجموع کل تسبیح، ثبت‌های دورهٔ حیض، طاعات و اذکار '
                    'سفارشی‌شده و هر روز بیرون از این بازه پاک نمی‌شوند؛ '
                    'فقط ارزیابی همین بازه صفر می‌شود.',
                    style: bodyStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'اگر اشتباه بود، بلافاصله پس از پاک‌کردن با دکمهٔ «بازگردانی» '
              'در اعلان پایین صفحه می‌توانید برگردانید؛ این پشتیبان موقت است '
              'و برای چند پاک‌سازیِ آخر نگه داشته می‌شود.',
              style: bodyStyle.copyWith(
                fontWeight: FontWeight.w800,
                color: danger,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('evaluation_reset_cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'انصراف',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
            ),
          ),
        ),
        FilledButton(
          key: const ValueKey('evaluation_reset_confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: danger),
          child: Text(
            'ریست کن',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: style.copyWith(fontWeight: FontWeight.w800)),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
