part of 'period_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════
//  NOTIFICATIONS SECTION
// ══════════════════════════════════════════════════════════════════════════

class PeriodNotificationsSection extends ConsumerWidget {
  final Period notifier;
  const PeriodNotificationsSection({super.key, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final gold = periodAccent;
    final state = ref.watch(periodProvider).value ?? const PeriodState();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.outline),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.notifications_outlined, size: 20, color: gold),
            const SizedBox(width: 8),
            Expanded(
                child: Text('یادآوری‌ها',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary))),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('فعال‌سازی یادآوری',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: t.textPrimary)),
            subtitle: Text(
              'یادآوری نزدیک شدن پریود، پایان حیض، و غسل',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textMuted),
            ),
            value: state.notificationsEnabled,
            onChanged: notifier.setNotificationsEnabled,
            activeThumbColor: gold,
          ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('یادآوری پنجرهٔ باروری',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: t.textPrimary)),
            subtitle: Text(
              'یادآوری شروع پنجرهٔ باروری (حدود 6 روز)',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textMuted),
            ),
            value: notifier.fertileReminderEnabled,
            onChanged: notifier.setFertileReminder,
            activeThumbColor: gold,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  LOCK SECTION
// ══════════════════════════════════════════════════════════════════════════

class PeriodLockSection extends ConsumerWidget {
  final Period notifier;
  const PeriodLockSection({super.key, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final gold = periodAccent;
    final state = ref.watch(periodProvider).value ?? const PeriodState();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.outline),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lock_outline, size: 20, color: gold),
            const SizedBox(width: 8),
            Expanded(
                child: Text('حریم خصوصی',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary))),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('قفل بخش پریودی',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: t.textPrimary)),
            subtitle: Text(
              'برای دسترسی به این بخش نیاز به رمز باشد',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textMuted),
            ),
            value: state.isLocked,
            onChanged: (v) async {
              if (v) {
                final confirmed = await _showSetPinDialog(context, notifier);
                if (confirmed) {
                  // Chosen a code moments ago — do not make the user enter it
                  // again just to stay on the page they set it from.
                  ref.read(periodSessionProvider.notifier).unlock();
                } else {
                  notifier.setLocked(false);
                }
              } else {
                notifier.setLocked(false);
              }
            },
            activeThumbColor: gold,
          ),
        ],
      ),
    );
  }

  Future<bool> _showSetPinDialog(BuildContext context, Period notifier) async {
    final pinCtrl = TextEditingController();
    final questionCtrl = TextEditingController();
    final answerCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تنظیم رمز'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  hintText: 'رمز (4 رقم)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: questionCtrl,
                maxLength: 50,
                decoration: const InputDecoration(
                  hintText: 'سؤال بازیابی (مثلاً: نام مادر شما چیست؟)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: answerCtrl,
                maxLength: 50,
                decoration: const InputDecoration(
                  hintText: 'پاسخ سؤال بازیابی',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          FilledButton(
            onPressed: () {
              if (NumberFormat.normalizeDigits(pinCtrl.text).length != 4) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('رمز باید 4 رقم باشد'),
                      duration: Duration(seconds: 2)),
                );
              } else if (questionCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('لطفاً سؤال بازیابی را وارد کنید'),
                      duration: Duration(seconds: 2)),
                );
              } else if (answerCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('لطفاً پاسخ سؤال بازیابی را وارد کنید'),
                      duration: Duration(seconds: 2)),
                );
              } else {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (result == true) {
      // Stored as ASCII digits: verify() normalizes what is typed, so a code
      // kept as `۱۲۳۴` could never be matched again.
      await notifier.setPin(NumberFormat.normalizeDigits(pinCtrl.text));
      await notifier.setRecovery(
          questionCtrl.text.trim(), answerCtrl.text.trim());
      await notifier.setLocked(true);
    }
    pinCtrl.dispose();
    questionCtrl.dispose();
    answerCtrl.dispose();
    return result ?? false;
  }
}

class PeriodPrivacyNote extends StatelessWidget {
  const PeriodPrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: t.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تمام اطلاعات فقط روی دستگاه شما ذخیره می‌شود و به هیچ جایی ارسال نمی‌شود.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: t.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
