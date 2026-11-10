part of 'period_widgets.dart';

/// Bottom sheet for a single day: record start/end, flow, istihadha subtype,
/// symptoms and notes. Shared by the calendar and the history list.
Future<void> showPeriodDayActions(
    BuildContext context, Period notifier, DateTime date) {
  // Bleeding records are facts about days that happened. Opening the sheet on
  // a future day would offer start/end actions the provider then refuses, so
  // say why instead of showing dead rows.
  final now = DateTime.now();
  if (DateTime(date.year, date.month, date.day)
      .isAfter(DateTime(now.year, now.month, now.day))) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('روزهای آینده را نمی‌توان ثبت کرد.'),
        duration: Duration(seconds: 2),
      ));
    return Future<void>.value();
  }
  final periodRecord = notifier.findRecordForDate(date);
  final isRecorded = periodRecord != null;
  final isActiveRecord = periodRecord?.isActive ?? false;
  final jDate = Jalali.fromDateTime(date);
  final dayStatus = _dayStatusTextFor(notifier, date);
  final dateOnly = DateTime(date.year, date.month, date.day);

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_num(jDate.year)}/${_num(jDate.month)}/${_num(jDate.day)}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w700),
              ),
              if (dayStatus != null) ...[
                const SizedBox(height: 6),
                Text(
                  dayStatus,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: isRecorded
                          ? periodAccentDeep
                          : TimeThemeKit.of(context).palette.secondary),
                ),
              ],
              const SizedBox(height: 16),
              if (!isRecorded) ...[
                ListTile(
                  leading: Icon(Icons.play_arrow, color: periodAccentDeep),
                  title: const Text('شروع حیض'),
                  subtitle: const Text('ثبت شروع دورهٔ قاعدگی در این تاریخ'),
                  onTap: () async {
                    final ok = await notifier.startPeriod(date);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('این روز قبلاً ثبت شده است.'),
                        duration: Duration(seconds: 3),
                      ));
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.child_care, color: periodAccentDeep),
                  title: const Text('شروع نفاس'),
                  subtitle: const Text('خونریزی پس از زایمان (تا 60 روز)'),
                  onTap: () async {
                    await notifier.startNifas(date);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading:
                      Icon(Icons.water_drop_outlined, color: periodAccentDeep),
                  title: const Text('شروع استحاضه'),
                  subtitle: const Text('خونریزی غیرحیض؛ نماز و روزه واجب است'),
                  onTap: () async {
                    await notifier.startIstihadha(date);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                // Extend the most recent completed record up to this day.
                if (notifier.latestCompletedBleeding != null &&
                    dateOnly.isAfter(DateTime(
                        notifier.latestCompletedBleeding!.endDate!.year,
                        notifier.latestCompletedBleeding!.endDate!.month,
                        notifier.latestCompletedBleeding!.endDate!.day)))
                  ListTile(
                    leading: Icon(Icons.update, color: periodAccentDeep),
                    title: const Text('تمدید دورهٔ قبلی تا این روز'),
                    subtitle: Text(
                        'پایان آخرین دورهٔ ثبت‌شده را به ${_faJalaliDay(date)} برسانید'),
                    onTap: () async {
                      await notifier.extendRecordEnd(
                          notifier.latestCompletedBleeding!.id, date);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
              ],
              if (isRecorded) ...[
                if (isActiveRecord) ...[
                  ListTile(
                    leading: Icon(Icons.stop,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkSuccess
                            : AppTheme.lightSuccess),
                    title: const Text('پایان دوره در این روز'),
                    subtitle: const Text('ثبت پایان دورهٔ جاری در همین تاریخ'),
                    onTap: () async {
                      await notifier.endPeriod(date);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ] else if (!dateOnly.isBefore(DateTime(
                    periodRecord.startDate.year,
                    periodRecord.startDate.month,
                    periodRecord.startDate.day))) ...[
                  ListTile(
                    leading: Icon(Icons.short_text, color: periodAccentDeep),
                    title: const Text('ثبت پایان در همین روز'),
                    subtitle: const Text(
                        'این رکورد را کوتاه کنید تا همین‌جا تمام شود'),
                    onTap: () async {
                      await notifier.setRecordEnd(periodRecord.id, date);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ],
                const Divider(height: 24),
                Text('علائم',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                PeriodSymptomSelector(
                  selectedSymptoms: (periodRecord.symptoms ?? '')
                      .split(',')
                      .where((s) => s.isNotEmpty)
                      .toList(),
                  onChanged: (symptoms) {
                    notifier.updateSymptoms(
                        periodRecord.id, symptoms.join(','));
                  },
                ),
                const SizedBox(height: 12),
                PeriodNotesTextField(
                  initialText: periodRecord.notes ?? '',
                  onChanged: (v) => notifier.updateNotes(periodRecord.id, v),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

String? _dayStatusTextFor(Period notifier, DateTime date) {
  final record = notifier.findRecordForDate(date);
  if (record != null) {
    switch (record.type) {
      case PeriodRecordType.nifas:
        return 'روز نفاس (ثبت‌شده)';
      case PeriodRecordType.istihadha:
        return 'روز استحاضه (ثبت‌شده)';
      case PeriodRecordType.hayz:
        return 'روز حیض (پریود ثبت‌شده)';
    }
  }
  final prediction = notifier.predict();
  if (prediction == null) return null;
  if (prediction.isFertileDate(date)) {
    final ov = prediction.ovulationDay;
    return ov.year == date.year && ov.month == date.month && ov.day == date.day
        ? 'روز تخمک‌گذاری (اوج باروری)'
        : 'روز باروری';
  }
  if (notifier.isPredictedPeriodDate(date)) {
    return 'احتمال حیض (پیش‌بینی)';
  }
  return null;
}

// ══════════════════════════════════════════════════════════════════════════
//  INPUT SECTION
// ══════════════════════════════════════════════════════════════════════════

class PeriodInputSection extends ConsumerStatefulWidget {
  final Period notifier;
  const PeriodInputSection({super.key, required this.notifier});

  @override
  ConsumerState<PeriodInputSection> createState() => _PeriodInputSectionState();
}

class _PeriodInputSectionState extends ConsumerState<PeriodInputSection> {
  PeriodRecordType _startType = PeriodRecordType.hayz;

  @override
  Widget build(BuildContext context) {
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
            Icon(Icons.edit_calendar, size: 20, color: gold),
            const SizedBox(width: 8),
            Expanded(
                child: Text('ثبت اطلاعات',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary))),
          ]),
          const SizedBox(height: 12),

          // نوع دوره (حیض / نفاس / استحاضه)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _typeChip(context, PeriodRecordType.hayz, 'حیض'),
              _typeChip(context, PeriodRecordType.nifas, 'نفاس'),
              _typeChip(context, PeriodRecordType.istihadha, 'استحاضه'),
            ],
          ),
          const SizedBox(height: 12),

          // Start period button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final date = await ShamsiDatePicker.show(
                  context,
                  latestDate: DateTime.now(),
                );
                if (date == null || !mounted) return;
                final ok = await widget.notifier.startPeriod(
                  date,
                  type: _startType,
                );
                if (!ok && mounted) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'این روز قبلاً در یک دوره ثبت شده است؛ ثبت جدید انجام نشد.'),
                    duration: Duration(seconds: 3),
                  ));
                }
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(_startType == PeriodRecordType.hayz
                  ? 'ثبت شروع دوره'
                  : _startType == PeriodRecordType.nifas
                      ? 'ثبت شروع نفاس'
                      : 'ثبت شروع استحاضه'),
              style: OutlinedButton.styleFrom(
                foregroundColor: periodAccentDeep,
                side: BorderSide(color: periodAccentDeep),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Settings
          Row(
            children: [
              Expanded(
                  child: PeriodSettingPicker(
                label: 'طول سیکل',
                value: state.defaultCycleLength,
                unit: 'روز',
                min: 16,
                max: 60,
                onChanged: widget.notifier.setCycleLength,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: PeriodSettingPicker(
                label: 'طول دوره',
                value: state.defaultPeriodLength,
                unit: 'روز',
                min: 1,
                max: 15,
                onChanged: widget.notifier.setPeriodLength,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeChip(BuildContext context, PeriodRecordType type, String label) {
    final selected = _startType == type;
    final gold = periodAccent;
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _startType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? gold.withValues(alpha: 0.15) : t.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? gold : t.outline),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w700,
                color: selected ? periodAccentDeep : t.textMuted)),
      ),
    );
  }
}
