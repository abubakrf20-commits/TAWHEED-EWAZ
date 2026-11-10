part of 'period_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════
//  RULINGS SECTION
// ══════════════════════════════════════════════════════════════════════════
class PeriodRulingsSection extends StatelessWidget {
  const PeriodRulingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _rulingCard(context, 'احکام شرعی حیض', [
          const _Ruling(
              'مدت حیض',
              'کمترین: 1 شبانه‌روز — بیشترین: 15 روز — غالب: 6 یا 7 روز',
              Icons.schedule,
              _periodDeepPink),
          const _Ruling('مدت طهر', 'کمترین: 15 روز', Icons.check_circle_outline,
              AppTheme.lightSuccess),
          const _Ruling('نماز', 'در ایام حیض ساقط است و قضا ندارد',
              Icons.mosque, Color(0xFF1565C0)),
          const _Ruling(
              'روزه',
              'در حیض ساقط است و فقط قضای روزهٔ واجب (رمضان) دارد؛ روزهٔ مستحبی قضا ندارد',
              Icons.nightlight,
              Color(0xFF7B1FA2)),
          const _Ruling(
              'طواف',
              'طوافِ واجب (حج یا عمره) در ایام حیض صحیح نیست؛ پس از پاکی و غسل انجام میشود و تا آن زمان به تأخیر میافتد',
              Icons.explore,
              AppTheme.warning),
          const _Ruling('غسل', 'پس از پاکی غسل واجب است', Icons.water_drop,
              Color(0xFF00897B)),
          const _Ruling(
              'عبادت ثبت می‌شود',
              'تمام عباداتی که زن در حیض نتوانسته انجام دهد، نزد خداوند ثبت می‌شود',
              Icons.favorite_outline,
              AppTheme.lightSuccess),
        ]),
        const SizedBox(height: 12),
        _rulingCard(context, 'احکام شرعی نفاس', [
          const _Ruling(
              'مدت نفاس',
              'خونریزی پس از زایمان؛ بیشترین: 60 روز (قول مشهور شافعی)',
              Icons.child_care,
              Color(0xFF6A1B9A)),
          const _Ruling('نماز', 'در نفاس ساقط است و قضا ندارد', Icons.mosque,
              Color(0xFF1565C0)),
          const _Ruling(
              'روزه',
              'ساقط است و فقط قضای روزهٔ واجب (رمضان) دارد؛ روزهٔ مستحبی قضا ندارد',
              Icons.nightlight,
              Color(0xFF7B1FA2)),
          const _Ruling('غسل', 'پس از پاکی غسل واجب است', Icons.water_drop,
              Color(0xFF00897B)),
        ]),
        const SizedBox(height: 12),
        _rulingCard(context, 'احکام شرعی استحاضه', [
          const _Ruling(
              'تعریف',
              'خونریزی خارج از عادت حیض است؛ نه حیض است و نه نفاس',
              Icons.water_drop_outlined,
              AppTheme.success),
          const _Ruling(
              'نماز و روزه',
              'در استحاضه نماز و روزه واجب است و صحیح است (برخلاف حیض که نماز ساقط است)',
              Icons.favorite_outline,
              AppTheme.lightSuccess),
          const _Ruling(
              'وضو',
              'پیش از هر نماز وضو بگیرید و ناحیه را پاک نگه دارید (مانند هر حکم دیگر طهارت)',
              Icons.water_drop,
              Color(0xFF00897B)),
          const _Ruling(
              'منابع',
              'بنابر مذهب امام شافعی (رضی الله عنه)؛ برای موارد استثنا با عالم محل مشورت کنید',
              Icons.menu_book_outlined,
              Color(0xFF757575)),
        ]),
      ],
    );
  }

  Widget _rulingCard(BuildContext context, String title, List<_Ruling> items) {
    final t = TimeThemeKit.of(context).palette;
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
            Icon(Icons.book_outlined, size: 20, color: periodAccent),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary))),
          ]),
          const SizedBox(height: 12),
          ...items.map(
              (r) => _rulingItem(context, r.title, r.body, r.icon, r.color)),
        ],
      ),
    );
  }

  Widget _rulingItem(BuildContext context, String title, String body,
      IconData icon, Color color) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary)),
                const SizedBox(height: 2),
                Text(body,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textMuted,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ruling {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  const _Ruling(this.title, this.body, this.icon, this.color);
}

// ══════════════════════════════════════════════════════════════════════════
//  HISTORY SECTION
// ══════════════════════════════════════════════════════════════════════════

class PeriodHistorySection extends StatelessWidget {
  final Period notifier;
  const PeriodHistorySection({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final history = notifier.getHistorySummary();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final gold = periodAccent;

    if (history.isEmpty) {
      return AppEmptyState(
        icon: Icons.history,
        message: 'هنوز دوره‌ای ثبت نشده',
        subtitle:
            'با ثبت اولین دوره، تاریخچه و پیش‌بینی چرخه اینجا پدیدار می‌شود.',
        accent: gold,
      );
    }

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
            Icon(Icons.history, size: 20, color: gold),
            const SizedBox(width: 8),
            Expanded(
                child: Text('تاریخچه دوره‌ها',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary))),
            const SizedBox(width: 8),
            Text(
                history.length > 6
                    ? 'آخرین 6 از ${_num(history.length)} دوره'
                    : '${_num(history.length)} دوره',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: t.textMuted)),
          ]),
          const SizedBox(height: 12),
          ...history.take(6).map((h) {
            final start = h['startDate'] as DateTime;
            final end = h['endDate'] as DateTime?;
            final days = h['periodDays'] as int;
            final cycle = h['cycleDays'] as int?;
            final isActive = h['isActive'] as bool;
            final symptoms = h['symptoms'] as String? ?? '';
            final notes = h['notes'] as String? ?? '';
            final typeLabel = h['typeLabel'] as String? ?? 'حیض';
            final flowLabel = h['flowLabel'] as String?;
            final recordId = h['id'] as int;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? periodAccentDeep.withValues(alpha: 0.06)
                    : t.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: isActive
                    ? Border.all(color: periodAccentDeep.withValues(alpha: 0.2))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isActive
                              ? periodAccentDeep.withValues(alpha: 0.1)
                              : gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${start.day}',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 16),
                                fontWeight: FontWeight.w700,
                                color: isActive ? periodAccentDeep : gold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isActive
                                  ? '${_faJalaliDay(start)} — فعال (روز ${_num(days > 0 ? days : 1)})'
                                  : '${_faJalaliDay(start)} — ${_faJalaliDay(end!)}',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 13),
                                  fontWeight: FontWeight.w600,
                                  color: t.textPrimary),
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  isActive
                                      ? 'در حال اجرا · روز ${_num(DateTime.now().difference(DateTime(start.year, start.month, start.day)).inDays + 1)}'
                                      : '${_num(days)} روز${cycle != null ? ' · سیکل: ${_num(cycle)} روز' : ''}',
                                  style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize:
                                          AppTheme.scaledFontSize(context, 12),
                                      color: t.textMuted),
                                ),
                                if (typeLabel != 'حیض')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _periodDeepPink.withValues(
                                          alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      typeLabel,
                                      style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: AppTheme.scaledFontSize(
                                              context, 10),
                                          fontWeight: FontWeight.w700,
                                          color: _periodDeepPink),
                                    ),
                                  ),
                                if (flowLabel != null)
                                  Text(flowLabel,
                                      style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: AppTheme.scaledFontSize(
                                              context, 11),
                                          color: t.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (symptoms.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: symptoms
                          .split(',')
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: gold.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 11),
                                        color: isDark
                                            ? gold
                                            : (Color.lerp(
                                                    gold, Colors.black, 0.3) ??
                                                gold))),
                              ))
                          .toList(),
                    ),
                  ],
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(notes,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: t.textMuted)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            showPeriodDayActions(context, notifier, start),
                        icon: Icon(Icons.edit_outlined, size: 16, color: gold),
                        label: Text('ویرایش',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                color: gold)),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('حذف دوره'),
                              content: const Text(
                                  'این رکورد حذف شود؟ این عمل قابل بازگشت نیست.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('لغو')),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(ctx).brightness ==
                                                  Brightness.dark
                                              ? AppTheme.darkError
                                              : AppTheme.lightError),
                                  child: const Text('حذف'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await notifier.deleteRecord(recordId);
                          }
                        },
                        icon: Icon(Icons.delete_outline,
                            size: 16,
                            color: isDark
                                ? AppTheme.darkError
                                : AppTheme.lightError),
                        label: Text('حذف',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                color: isDark
                                    ? AppTheme.darkError
                                    : AppTheme.lightError)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
