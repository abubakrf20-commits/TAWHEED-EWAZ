import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';
import 'package:tawheeed/features/personal/presentation/providers/care_providers.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart';
import 'package:tawheeed/features/personal/services/care_attachment_store.dart';
import 'package:tawheeed/features/personal/services/care_settings.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «افزودن خودرو» — car details + the editable template selection.
Future<void> showAddCarSheet(
  BuildContext context, {
  required CareTemplates templates,
}) {
  return showCareSheet<void>(
    context,
    child: _AddCarSheet(templates: templates),
  );
}

class _AddCarSheet extends ConsumerStatefulWidget {
  const _AddCarSheet({required this.templates});
  final CareTemplates templates;

  @override
  ConsumerState<_AddCarSheet> createState() => _AddCarSheetState();
}

class _AddCarSheetState extends ConsumerState<_AddCarSheet> {
  final _name = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();
  final _odometer = TextEditingController();
  String _fuel = 'petrol';
  DateTime? _startDate;
  late final Map<String, bool> _selected = {
    for (final t in widget.templates.carDefaults) t.key: true,
  };
  bool _busy = false;

  static const _fuels = {
    'petrol': 'بنزین',
    'diesel': 'گازوئیل',
    'hybrid': 'هیبرید',
    'electric': 'برقی',
    'cng': 'CNG',
  };

  @override
  void dispose() {
    for (final c in [_name, _make, _model, _color, _plate, _odometer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final chosen = widget.templates.carDefaults
        .where((t) => _selected[t.key] == true)
        .toList();
    await ref.read(careStoreProvider.notifier).addCar(
          name: _name.text,
          make: _make.text,
          model: _model.text,
          color: _color.text,
          plate: _plate.text,
          fuelType: _fuel,
          templates: chosen,
          firstDueDate: _startDate,
          odometerKm: _odometer.text.trim().isEmpty
              ? null
              : NumberFormat.parse(_odometer.text).round(),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = careCarColor;
    final defaults = widget.templates.carDefaults;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareSheetTitle(
          title: 'افزودن خودرو',
          subtitle: 'نام و مشخصات خودرو را وارد کنید؛ سرویس‌های پیشنهادی '
              'همراهش ساخته می‌شوند و هر کدام را می‌توانید ویرایش کنید.',
        ),
        CareField(controller: _name, label: 'نام دلخواه (اختیاری)',
            hint: 'مثلاً خودروی من'),
        Row(
          children: [
            Expanded(
              child: CareField(controller: _make, label: 'سازنده', hint: 'پژو'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CareField(controller: _model, label: 'مدل', hint: '206'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: CareField(controller: _color, label: 'رنگ (اختیاری)'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CareField(
                controller: _plate,
                label: 'پلاک (اختیاری)',
                ltr: true,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in _fuels.entries)
              CareChip(
                label: entry.value,
                selected: _fuel == entry.key,
                accent: accent,
                onTap: () => setState(() => _fuel = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 10),
        CareField(
          controller: _odometer,
          label: 'کارکرد فعلی (km، اختیاری)',
          digitsOnly: true,
          keyboardType: TextInputType.number,
          ltr: true,
        ),
        CareDateButton(
          label: 'تاریخ مبدأ سرویس‌ها (اختیاری)',
          date: _startDate,
          accent: accent,
          onPicked: (date) => setState(() => _startDate = date),
        ),
        if (defaults.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'سرویس‌های پیشنهادی',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w700,
              color: TimeThemeKit.of(context).palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          for (final template in defaults)
            CareSelectRow(
              selected: _selected[template.key] == true,
              title: template.titleFa,
              subtitle: template.intervalLabel,
              icon: careIconFor(template.iconKey),
              accent: accent,
              onChanged: (v) => setState(() => _selected[template.key] = v),
            ),
          if (widget.templates.note.isNotEmpty)
            CareNotice(text: widget.templates.note, accent: accent),
        ],
        const SizedBox(height: 4),
        CareSheetSubmit(
          label: 'ساخت خودرو',
          accent: accent,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

/// «ثبت کیلومتر» — also the correction path (a lower value asks first).
Future<void> showOdometerSheet(
  BuildContext context, {
  required CareAsset asset,
  required int? currentKm,
}) {
  return showCareSheet<void>(
    context,
    child: _OdometerSheet(asset: asset, currentKm: currentKm),
  );
}

class _OdometerSheet extends ConsumerStatefulWidget {
  const _OdometerSheet({required this.asset, required this.currentKm});
  final CareAsset asset;
  final int? currentKm;

  @override
  ConsumerState<_OdometerSheet> createState() => _OdometerSheetState();
}

class _OdometerSheetState extends ConsumerState<_OdometerSheet> {
  final _km = TextEditingController();
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentKm != null) _km.text = '${widget.currentKm}';
  }

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final km = NumberFormat.parse(_km.text).round();
    if (km <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کارکرد باید بزرگتر از صفر باشد.')),
      );
      return;
    }
    final current = widget.currentKm;
    if (current != null && km < current) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('اصلاح کیلومتر؟'),
          content: Text(
            'کارکرد وارد شده ($km) از آخرین ثبت ($current) کمتر است. '
            'با تأیید، به‌عنوان اصلاح کیلومتر ثبت می‌شود و تاریخچه حفظ می‌شود.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('اصلاح کیلومتر'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    await ref
        .read(careStoreProvider.notifier)
        .logOdometer(widget.asset.id, km, _date);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = careAccentFor(widget.asset.kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: 'ثبت کیلومتر',
          subtitle: widget.currentKm == null
              ? 'اولین کارکرد این خودرو را ثبت کنید.'
              : 'آخرین ثبت: ${NumberFormat.formatPlain(widget.currentKm!.toDouble())} km',
        ),
        CareField(
          controller: _km,
          label: 'کارکرد (km)',
          digitsOnly: true,
          keyboardType: TextInputType.number,
          ltr: true,
        ),
        CareDateButton(
          label: 'تاریخ ثبت',
          date: _date,
          accent: accent,
          onPicked: (d) => setState(() => _date = d),
        ),
        CareSheetSubmit(
          label: 'ثبت',
          accent: accent,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

/// «ثبت سرویس انجام‌شده» — multi-task completion with one cost/photos.
Future<CareCompletionResult?> showCompleteServiceSheet(
  BuildContext context, {
  required CareAsset asset,
  required CareSnapshot snapshot,
  List<String> initialTaskIds = const [],
}) {
  return showCareSheet<CareCompletionResult>(
    context,
    child: _CompleteSheet(
      asset: asset,
      snapshot: snapshot,
      initialTaskIds: initialTaskIds,
    ),
  );
}

class _CompleteSheet extends ConsumerStatefulWidget {
  const _CompleteSheet({
    required this.asset,
    required this.snapshot,
    required this.initialTaskIds,
  });

  final CareAsset asset;
  final CareSnapshot snapshot;
  final List<String> initialTaskIds;

  @override
  ConsumerState<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends ConsumerState<_CompleteSheet> {
  late final Set<String> _selected = {...widget.initialTaskIds};
  final _cost = TextEditingController();
  final _note = TextEditingController();
  final _km = TextEditingController();
  final List<String> _photos = [];
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final km = widget.snapshot.currentKm(widget.asset.id);
    if (km != null) _km.text = '$km';
    if (_selected.isEmpty) {
      final first = widget.snapshot
          .tasksOf(widget.asset.id)
          .where((t) => t.active)
          .toList();
      if (first.length == 1) _selected.add(first.first.id);
    }
  }

  @override
  void dispose() {
    _cost.dispose();
    _note.dispose();
    _km.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final stored = await CareAttachmentStore.pickAndStore();
    if (!mounted || stored.isEmpty) return;
    setState(() => _photos.addAll(stored));
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) return;
    setState(() => _busy = true);
    final result = await ref.read(careStoreProvider.notifier).completeTasks(
          assetId: widget.asset.id,
          taskIds: _selected.toList(),
          date: _date,
          odometerKm:
              _km.text.trim().isEmpty ? null : NumberFormat.parse(_km.text).round(),
          cost: _cost.text.trim().isEmpty
              ? null
              : NumberFormat.parse(_cost.text),
          note: _note.text.trim(),
          attachmentPaths: List.of(_photos),
        );
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final accent = careAccentFor(widget.asset.kind);
    final tasks = widget.snapshot
        .tasksOf(widget.asset.id)
        .where((t) => t.active)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareSheetTitle(
          title: 'ثبت سرویس انجام‌شده',
          subtitle: 'هر تعداد سرویس را با یک تاریخ ثبت کنید؛ هزینه فقط یک بار در '
              'گزارش سالانه شمرده می‌شود.',
        ),
        for (final task in tasks)
          CareSelectRow(
            selected: _selected.contains(task.id),
            title: task.title,
            subtitle: '',
            accent: accent,
            icon: careIconFor(task.iconKey),
            onChanged: (v) => setState(() {
              if (v) {
                _selected.add(task.id);
              } else {
                _selected.remove(task.id);
              }
            }),
          ),
        if (tasks.isEmpty)
          Text(
            'سرویسی برای این خودرو تعریف نشده است.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: TimeThemeKit.of(context).palette.textMuted,
            ),
          ),
        const Divider(height: 20),
        CareDateButton(
          label: 'تاریخ انجام',
          date: _date,
          accent: accent,
          onPicked: (d) => setState(() => _date = d),
        ),
        CareField(
          controller: _km,
          label: 'کارکرد در زمان سرویس (km)',
          digitsOnly: true,
          keyboardType: TextInputType.number,
          ltr: true,
        ),
        CareField(
          controller: _cost,
          label: 'هزینه (اختیاری)',
          digitsOnly: true,
          keyboardType: TextInputType.number,
          ltr: true,
        ),
        CareField(controller: _note, label: 'یادداشت (اختیاری)', maxLines: 2),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _addPhoto,
              style: OutlinedButton.styleFrom(
                foregroundColor: dsContentColor(context, accent),
                side: BorderSide(color: accent.withValues(alpha: .45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.add_a_photo_outlined, size: 17),
              label: const Text('افزودن عکس'),
            ),
            const SizedBox(width: 8),
            if (_photos.isNotEmpty)
              Text(
                '${_photos.length} عکس',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted,
                ),
              ),
          ],
        ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, index) => const SizedBox(width: 6),
              itemBuilder: (_, i) => CareAttachmentThumb(
                relativePath: _photos[i],
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        CareSheetSubmit(
          label: 'ثبت انجام شد',
          accent: accent,
          busy: _busy,
          onPressed: _selected.isEmpty ? null : _submit,
        ),
      ],
    );
  }
}

/// Task details / edit / history.
Future<String?> showCareTaskSheet(
  BuildContext context, {
  required CareAsset asset,
  required CareTask task,
  required CareSnapshot snapshot,
}) {
  return showCareSheet<String>(
    context,
    child: _TaskSheet(asset: asset, task: task, snapshot: snapshot),
  );
}

class _TaskSheet extends ConsumerStatefulWidget {
  const _TaskSheet({
    required this.asset,
    required this.task,
    required this.snapshot,
  });

  final CareAsset asset;
  final CareTask task;
  final CareSnapshot snapshot;

  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late final _days =
      TextEditingController(text: widget.task.intervalDays?.toString() ?? '');
  late final _km =
      TextEditingController(text: widget.task.intervalKm?.toString() ?? '');
  late final _remindDays =
      TextEditingController(text: '${widget.task.remindBeforeDays}');
  late final _remindKm =
      TextEditingController(text: '${widget.task.remindBeforeKm}');
  late final _notes = TextEditingController(text: widget.task.notes);
  late bool _active = widget.task.active;

  @override
  void dispose() {
    for (final c in [_days, _km, _remindDays, _remindKm, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final next = widget.task.copyWith(
      intervalDays: _days.text.trim().isEmpty
          ? null
          : NumberFormat.parse(_days.text).round(),
      clearIntervalDays: _days.text.trim().isEmpty,
      intervalKm: _km.text.trim().isEmpty
          ? null
          : NumberFormat.parse(_km.text).round(),
      clearIntervalKm: _km.text.trim().isEmpty,
      remindBeforeDays: NumberFormat.parse(_remindDays.text).round(),
      remindBeforeKm: NumberFormat.parse(_remindKm.text).round(),
      notes: _notes.text.trim(),
      active: _active,
    );
    await ref.read(careStoreProvider.notifier).saveTask(next);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _complete() async {
    // The page owns the completion sheet: popping this one first would leave
    // the callback holding a defunct sheet context.
    Navigator.of(context).pop('complete');
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف سرویس؟'),
        content: Text(
          '«${widget.task.title}» و تنظیماتش حذف می‌شود. تاریخچهٔ ثبت‌های قبلی '
          'باقی می‌ماند.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(careStoreProvider.notifier).deleteTask(widget.task.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = careAccentFor(widget.asset.kind);
    final t = TimeThemeKit.of(context).palette;
    final status = careStatusOf(
      widget.task,
      DateTime.now(),
      currentKm: widget.snapshot.currentKm(widget.asset.id),
      readings: widget.snapshot.readingsOf(widget.asset.id),
    );
    final history = widget.snapshot
        .recordsOf(widget.asset.id)
        .where((r) => r.taskId == widget.task.id)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: widget.task.title,
          subtitle: widget.task.notes.isEmpty ? null : widget.task.notes,
        ),
        Row(
          children: [
            CareStatusChip(level: status.level),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status.remainingText,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.task.scheduleType.usesDistance)
          CareField(
            controller: _km,
            label: 'فاصلهٔ سرویس (km)',
            digitsOnly: true,
            keyboardType: TextInputType.number,
            ltr: true,
          ),
        if (widget.task.scheduleType.usesTime)
          CareField(
            controller: _days,
            label: 'فاصلهٔ زمانی (روز)',
            digitsOnly: true,
            keyboardType: TextInputType.number,
            ltr: true,
          ),
        Row(
          children: [
            Expanded(
              child: CareField(
                controller: _remindDays,
                label: 'یادآوری چند روز قبل',
                digitsOnly: true,
                keyboardType: TextInputType.number,
                ltr: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CareField(
                controller: _remindKm,
                label: 'یادآوری چند کیلومتر قبل',
                digitsOnly: true,
                keyboardType: TextInputType.number,
                ltr: true,
              ),
            ),
          ],
        ),
        CareField(controller: _notes, label: 'یادداشت', maxLines: 2),
        CareSwitchRow(
          label: 'فعال باشد',
          value: _active,
          accent: accent,
          onChanged: (v) => setState(() => _active = v),
        ),
        CareDetailRow(
          label: 'آخرین انجام',
          value: widget.task.lastDoneDate == null
              ? 'ثبت نشده'
              : careJalali(widget.task.lastDoneDate!),
        ),
        if (status.predictedDueDate != null)
          CareDetailRow(
            label: 'تخمین سررسید',
            value: careJalali(status.predictedDueDate!),
          ),
        if (history.isNotEmpty) ...[
          const Divider(height: 20),
          Text(
            'تاریخچه',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          for (final record in history.take(6))
            CareDetailRow(
              label: careJalali(record.date),
              value: [
                if (record.odometerKm != null)
                  '${NumberFormat.formatPlain(record.odometerKm!.toDouble())} km',
                if (record.cost != null) careMoney(record.cost!),
              ].join(' · '),
            ),
        ],
        const SizedBox(height: 12),
        CarePrimaryPill(
          label: 'انجام شد',
          icon: Icons.check_circle_outline,
          accent: accent,
          onPressed: _complete,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _save,
                style: OutlinedButton.styleFrom(
                  foregroundColor: dsContentColor(context, accent),
                  side: BorderSide(color: accent.withValues(alpha: .45)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: const Text('ذخیرهٔ تغییرات'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _delete,
              tooltip: 'حذف سرویس',
              icon: Icon(Icons.delete_outline, color: t.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

/// «ثبت سوخت».
Future<void> showFuelSheet(
  BuildContext context, {
  required CareAsset asset,
  required int? currentKm,
}) {
  return showCareSheet<void>(
    context,
    child: _FuelSheet(asset: asset, currentKm: currentKm),
  );
}

class _FuelSheet extends ConsumerStatefulWidget {
  const _FuelSheet({required this.asset, required this.currentKm});
  final CareAsset asset;
  final int? currentKm;

  @override
  ConsumerState<_FuelSheet> createState() => _FuelSheetState();
}

class _FuelSheetState extends ConsumerState<_FuelSheet> {
  final _liters = TextEditingController();
  final _cost = TextEditingController();
  final _km = TextEditingController();
  DateTime _date = DateTime.now();
  bool _full = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentKm != null) _km.text = '${widget.currentKm}';
  }

  @override
  void dispose() {
    _liters.dispose();
    _cost.dispose();
    _km.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final liters = NumberFormat.parse(_liters.text);
    final km = NumberFormat.parse(_km.text).round();
    if (liters <= 0 || km <= 0) return;
    setState(() => _busy = true);
    final notifier = ref.read(careStoreProvider.notifier);
    final total = _cost.text.trim().isEmpty
        ? null
        : NumberFormat.parse(_cost.text);
    await notifier.addFuel(FuelLog(
      id: notifier.newId('fuel'),
      assetId: widget.asset.id,
      date: _date,
      liters: liters,
      totalCost: total,
      pricePerLiter:
          total == null || liters == 0 ? null : total / liters,
      odometerKm: km,
      fullTank: _full,
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = careCarColor;
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareSheetTitle(title: 'ثبت سوخت'),
        CareField(
          controller: _liters,
          label: 'مقدار سوخت (لیتر)',
          digitsOnly: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ltr: true,
        ),
        CareField(
          controller: _cost,
          label: 'هزینه (اختیاری)',
          digitsOnly: true,
          keyboardType: TextInputType.number,
          ltr: true,
        ),
        CareField(
          controller: _km,
          label: 'کارکرد (km)',
          digitsOnly: true,
          keyboardType: TextInputType.number,
          ltr: true,
        ),
        CareDateButton(
          label: 'تاریخ',
          date: _date,
          accent: accent,
          onPicked: (d) => setState(() => _date = d),
        ),
        CareSwitchRow(
          label: 'باک پر شد',
          value: _full,
          accent: accent,
          onChanged: (v) => setState(() => _full = v),
        ),
        Text(
          'مصرف سوخت فقط از باک‌های پُر محاسبه می‌شود.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 10.5),
            color: t.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        CareSheetSubmit(
          label: 'ثبت',
          accent: accent,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

/// «تنظیمات» — reminder hour, quiet hours, per-category switches.
Future<void> showCareSettingsSheet(
  BuildContext context, {
  required CareAssetKind kind,
}) {
  return showCareSheet<void>(context, child: _SettingsSheet(kind: kind));
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet({required this.kind});
  final CareAssetKind kind;

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  CareReminderSettings? _settings;

  static const _categories = {
    'service': 'سرویس‌ها',
    'bills': 'قبض‌ها',
    'warranty': 'گارانتی',
    'subscriptions': 'اشتراک‌ها',
  };

  @override
  void initState() {
    super.initState();
    CareSettingsStore.load().then((value) {
      if (mounted) setState(() => _settings = value);
    });
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null) return;
    await CareSettingsStore.save(settings);
    if (!mounted) return;
    await ref.read(careStoreProvider.notifier).refreshReminders();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = careAccentFor(widget.kind);
    final t = TimeThemeKit.of(context).palette;
    final settings = _settings;
    if (settings == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareSheetTitle(
          title: 'تنظیمات یادآوری‌ها',
          subtitle: 'یادآوری‌ها در فاصلهٔ ۳۰ روز آینده و با حداکثر روزانه '
              'مشخص‌شده زمان‌بندی می‌شوند.',
        ),
        CareSwitchRow(
          label: 'یادآوری فعال باشد',
          value: settings.enabled,
          accent: accent,
          onChanged: (v) =>
              setState(() => _settings = settings.copyWith(enabled: v)),
        ),
        _HourRow(
          label: 'ساعت یادآوری',
          value: settings.hour,
          onChanged: (h) =>
              setState(() => _settings = settings.copyWith(hour: h)),
        ),
        _HourRow(
          label: 'شروع ساعات سکوت',
          value: settings.quietStart,
          onChanged: (h) =>
              setState(() => _settings = settings.copyWith(quietStart: h)),
        ),
        _HourRow(
          label: 'پایان ساعات سکوت',
          value: settings.quietEnd,
          onChanged: (h) =>
              setState(() => _settings = settings.copyWith(quietEnd: h)),
        ),
        Text(
          'دسته‌بندی‌ها',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 13),
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        for (final entry in _categories.entries) ...[
          CareSwitchRow(
            label: entry.value,
            value: settings.allowsCategory(entry.key),
            accent: accent,
            onChanged: (v) {
              final disabled = {...settings.disabledCategories};
              if (v) {
                disabled.remove(entry.key);
              } else {
                disabled.add(entry.key);
              }
              setState(() =>
                  _settings = settings.copyWith(disabledCategories: disabled));
            },
          ),
          _HourRow(
            label: 'ساعت یادآوری ${entry.value}',
            value: settings.categoryHours[entry.key] ?? settings.hour,
            onChanged: (h) {
              final map = {...settings.categoryHours};
              if (h == settings.hour) {
                map.remove(entry.key);
              } else {
                map[entry.key] = h;
              }
              setState(() => _settings = settings.copyWith(categoryHours: map));
            },
          ),
        ],
        const SizedBox(height: 6),
        CareSheetSubmit(
          label: 'ذخیره',
          accent: accent,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: t.textPrimary,
            ),
          ),
          const Spacer(),
          DropdownButton<int>(
            value: value,
            underline: const SizedBox.shrink(),
            items: [
              for (var h = 0; h < 24; h++)
                DropdownMenuItem(
                  value: h,
                  child: Text(
                    '${h.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                    ),
                  ),
                ),
            ],
            onChanged: (h) {
              if (h != null) onChanged(h);
            },
          ),
        ],
      ),
    );
  }
}

/// Shared snackbar with undo for a completion.
void showCompletionSnack(
  BuildContext context,
  CareCompletionResult result,
) {
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context);
  messenger.showSnackBar(SnackBar(
    content: Text('${result.records.length} سرویس ثبت شد.'),
    action: SnackBarAction(
      label: 'بازگردانی',
      onPressed: () {
        container.read(careStoreProvider.notifier).undoCompletion(result);
        final attachments = <String>[
          for (final r in result.records) ...r.attachmentPaths,
        ];
        CareAttachmentStore.deleteAll(attachments);
      },
    ),
  ));
}

/// «افزودن سرویس دلخواه» — تعریف یک سرویس جدید که فراتر از قالب‌های پیش‌فرض است.
Future<void> showCustomTaskSheet(
  BuildContext context, {
  required String assetId,
  CareTask? task,
}) {
  return showCareSheet<String>(
    context,
    child: _CustomTaskSheet(assetId: assetId, task: task),
  );
}

class _CustomTaskSheet extends ConsumerStatefulWidget {
  const _CustomTaskSheet({required this.assetId, this.task});
  final String assetId;
  final CareTask? task;

  @override
  ConsumerState<_CustomTaskSheet> createState() => _CustomTaskSheetState();
}

class _CustomTaskSheetState extends ConsumerState<_CustomTaskSheet> {
  late final _title = TextEditingController();
  late final _notes = TextEditingController();
  int? _intervalDays;
  int? _intervalKm;
  late CareScheduleType _scheduleType;
  String? _iconKey;
  bool _busy = false;

  static const _scheduleOptions = {
    CareScheduleType.time: 'معمولاً (روز)',
    CareScheduleType.distance: 'با کارکرد (کیلومتر)',
    CareScheduleType.both: 'هر دو (روز و کیلومتر)',
  };

  static const _iconOptions = {
    'build': 'سرویس',
    'oil': 'روغن',
    'filter': 'فیلتر',
    'brake': 'ترمز',
    'battery': 'باتری',
    'car_wash': 'شستن ماشین',
    'tire': 'لاستیک',
    'shield': 'بیمه',
    'check': 'معاینه',
  };

  @override
  void initState() {
    super.initState();
    _title.text = widget.task?.title ?? '';
    _notes.text = widget.task?.notes ?? '';
    _intervalDays = widget.task?.intervalDays;
    _intervalKm = widget.task?.intervalKm;
    _scheduleType = widget.task?.scheduleType ?? CareScheduleType.both;
    _iconKey = widget.task?.iconKey ?? 'build';
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _busy = true);

    final next = widget.task == null
        ? CareTask(
            id: ref.read(careStoreProvider.notifier).newId('task'),
            assetId: widget.assetId,
            title: title,
            categoryKey: 'general',
            iconKey: _iconKey ?? 'build',
            scheduleType: _scheduleType,
            intervalDays: _scheduleType.usesTime ? _intervalDays : null,
            intervalKm: _scheduleType.usesDistance ? _intervalKm : null,
            notes: _notes.text.trim(),
            createdAt: DateTime.now(),
          )
        : widget.task!.copyWith(
            title: title,
            iconKey: _iconKey,
            scheduleType: _scheduleType,
            intervalDays: _scheduleType.usesTime ? _intervalDays : null,
            clearIntervalDays: !_scheduleType.usesTime,
            intervalKm: _scheduleType.usesDistance ? _intervalKm : null,
            clearIntervalKm: !_scheduleType.usesDistance,
            notes: _notes.text.trim(),
          );

    await ref.read(careStoreProvider.notifier).saveTask(next);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: widget.task == null ? 'افزودن سرویس دلخواه' : 'ویرایش سرویس',
          subtitle: 'یک سرویس جدید تعریف کنید و بازهٔ تکرار آن را مشخص کنید.',
        ),
        CareField(controller: _title, label: 'عنوان سرویس', hint: 'مثلاً شستن ماشین'),
        Row(
          children: [
            Expanded(
              child: CareField(
                controller: _notes,
                label: 'یادداشت (اختیاری)',
              ),
            ),
          ],
        ),
        Text(
          'بازهٔ تکرار',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: t.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in _scheduleOptions.entries)
              CareChip(
                label: entry.value,
                selected: _scheduleType == entry.key,
                accent: careCarColor,
                onTap: () => setState(() => _scheduleType = entry.key),
              ),
          ],
        ),
        if (_scheduleType.usesTime) ...[
          const SizedBox(height: 10),
          CareField(
            controller: TextEditingController(
              text: '${_intervalDays ?? ''}',
            ),
            label: 'هر چند روز تکرار شود',
            digitsOnly: true,
            keyboardType: TextInputType.number,
            ltr: true,
            onChanged: (v) {
              final d = int.tryParse(v.trim());
              if (d != null && d > 0) _intervalDays = d;
            },
          ),
        ],
        if (_scheduleType.usesDistance) ...[
          const SizedBox(height: 10),
          CareField(
            controller: TextEditingController(
              text: '${_intervalKm ?? ''}',
            ),
            label: 'هر چند کیلومتر تکرار شود',
            digitsOnly: true,
            keyboardType: TextInputType.number,
            ltr: true,
            onChanged: (v) {
              final k = int.tryParse(v.trim());
              if (k != null && k > 0) _intervalKm = k;
            },
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'آیکون',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: t.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in _iconOptions.entries)
              CareChip(
                label: entry.value,
                selected: _iconKey == entry.key,
                accent: careCarColor,
                onTap: () => setState(() => _iconKey = entry.key),
              ),
          ],
        ),
        CareSheetSubmit(
          label: widget.task == null ? 'افزودن سرویس' : 'ذخیره تغییرات',
          accent: careCarColor,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

