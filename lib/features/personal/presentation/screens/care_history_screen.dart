import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/presentation/providers/care_providers.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart';
import 'package:tawheeed/features/personal/services/care_attachment_store.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// History of completed services / expenses for one asset, with task and
/// Jalali-year filters, totals, edit, delete and a plain-text export.
class CareHistoryScreen extends ConsumerStatefulWidget {
  const CareHistoryScreen({
    super.key,
    required this.kind,
    this.assetId,
  });

  final CareAssetKind kind;
  final String? assetId;

  @override
  ConsumerState<CareHistoryScreen> createState() => _CareHistoryScreenState();
}

class _CareHistoryScreenState extends ConsumerState<CareHistoryScreen> {
  String? _taskId;
  int? _year;

  @override
  Widget build(BuildContext context) {
    final accent = careAccentFor(widget.kind);
    final async = ref.watch(careStoreProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CareScreenAppBar(
        title: widget.kind == CareAssetKind.car
            ? 'تاریخچهٔ خودرو'
            : 'تاریخچهٔ خانه',
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: switch (async) {
          AsyncData(:final value) => _buildBody(value, accent),
          AsyncError() => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(careStoreProvider),
                child: const Text('تلاش دوباره'),
              ),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _buildBody(CareSnapshot snapshot, Color accent) {
    final t = TimeThemeKit.of(context).palette;
    final assets = snapshot.assetsOf(widget.kind);
    final asset = assets.isEmpty
        ? null
        : assets.firstWhere(
            (a) => a.id == widget.assetId,
            orElse: () => assets.first,
          );
    if (asset == null) {
      return Center(
        child: Text(
          'ابتدا یک مورد اضافه کنید.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: t.textMuted,
          ),
        ),
      );
    }

    final tasks = snapshot.tasksOf(asset.id);
    final all = snapshot.recordsOf(asset.id);
    final years = <int>{
      for (final r in all) jalaliParts(r.date).year,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    final filtered = all.where((r) {
      if (_taskId != null && r.taskId != _taskId) return false;
      if (_year != null && jalaliParts(r.date).year != _year) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final total = filtered.fold<double>(0, (sum, r) => sum + (r.cost ?? 0));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _FilterDropdown<String>(
                      value: _taskId,
                      hint: 'همهٔ سرویس‌ها',
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('همهٔ سرویس‌ها'),
                        ),
                        for (final task in tasks)
                          DropdownMenuItem<String>(
                            value: task.id,
                            child: Text(task.title),
                          ),
                      ],
                      onChanged: (v) => setState(
                          () => _taskId = (v == null || v.isEmpty) ? null : v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterDropdown<int>(
                      value: _year,
                      hint: 'همهٔ سال‌ها',
                      items: [
                        const DropdownMenuItem<int>(
                          value: 0,
                          child: Text('همهٔ سال‌ها'),
                        ),
                        for (final year in years)
                          DropdownMenuItem<int>(
                            value: year,
                            child: Text('$year'),
                          ),
                      ],
                      onChanged: (v) => setState(
                          () => _year = (v == null || v == 0) ? null : v),
                    ),
                  ),
                ],
              ),
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 18, color: dsContentColor(context, accent)),
                    const SizedBox(width: 8),
                    Text(
                      'جمع انتخاب‌شده',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: t.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      careMoney(total),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'ثبتی برای این فیلتر نیست.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textMuted,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final record = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () => _edit(record, accent),
                        child: Row(
                          children: [
                            DuotoneIconTile(
                              accent: accent,
                              icon: Icons.receipt_long_outlined,
                              size: 34,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.title.isEmpty
                                        ? 'سرویس'
                                        : record.title,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: AppTheme.scaledFontSize(
                                          context, 12),
                                      fontWeight: FontWeight.w600,
                                      color: t.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    [
                                      careJalali(record.date),
                                      if (record.odometerKm != null)
                                        '${NumberFormat.formatPlain(record.odometerKm!.toDouble())} km',
                                    ].join(' · '),
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: AppTheme.scaledFontSize(
                                          context, 10.5),
                                      color: t.textMuted,
                                    ),
                                  ),
                                  if (record.note.isNotEmpty)
                                    Text(
                                      record.note,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 10.5),
                                        color: t.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (record.cost != null)
                                  Text(
                                    careMoney(record.cost!),
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: AppTheme.scaledFontSize(
                                          context, 11),
                                      fontWeight: FontWeight.w600,
                                      color: t.textSecondary,
                                    ),
                                  ),
                                if (record.attachmentPaths.isNotEmpty)
                                  Icon(Icons.photo_outlined,
                                      size: 14, color: t.textMuted),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: filtered.isEmpty
                  ? null
                  : () => _export(filtered, total, asset),
              style: OutlinedButton.styleFrom(
                foregroundColor: dsContentColor(context, accent),
                side: BorderSide(color: accent.withValues(alpha: .45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              icon: const Icon(Icons.ios_share, size: 17),
              label: const Text('اشتراک‌گذاری متن تاریخچه'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _export(
    List<CareRecord> records,
    double total,
    CareAsset asset,
  ) async {
    final lines = <String>[
      'تاریخچهٔ ${asset.displayName}',
      for (final record in records)
        [
          careJalali(record.date),
          record.title,
          if (record.odometerKm != null)
            '${NumberFormat.formatPlain(record.odometerKm!.toDouble())} km',
          if (record.cost != null) careMoney(record.cost!),
          if (record.note.isNotEmpty) record.note,
        ].join(' — '),
      'جمع: ${careMoney(total)}',
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  Future<void> _edit(CareRecord record, Color accent) async {
    await showCareSheet<void>(
      context,
      child: _RecordEditSheet(record: record, accent: accent),
    );
  }
}

class _RecordEditSheet extends ConsumerStatefulWidget {
  const _RecordEditSheet({required this.record, required this.accent});
  final CareRecord record;
  final Color accent;

  @override
  ConsumerState<_RecordEditSheet> createState() => _RecordEditSheetState();
}

class _RecordEditSheetState extends ConsumerState<_RecordEditSheet> {
  late final _cost = TextEditingController(
      text: widget.record.cost == null ? '' : '${widget.record.cost!.round()}');
  late final _km = TextEditingController(
      text: widget.record.odometerKm == null
          ? ''
          : '${widget.record.odometerKm}');
  late final _note = TextEditingController(text: widget.record.note);
  late DateTime _date = widget.record.date;

  @override
  void dispose() {
    _cost.dispose();
    _km.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = CareRecord(
      id: widget.record.id,
      assetId: widget.record.assetId,
      taskId: widget.record.taskId,
      title: widget.record.title,
      date: _date,
      odometerKm:
          _km.text.trim().isEmpty ? null : NumberFormat.parse(_km.text).round(),
      cost: _cost.text.trim().isEmpty
          ? null
          : NumberFormat.parse(_cost.text),
      note: _note.text.trim(),
      attachmentPaths: widget.record.attachmentPaths,
    );
    await ref.read(careStoreProvider.notifier).saveRecord(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف ثبت؟'),
        content: const Text('این مورد از تاریخچه و جمع هزینه‌ها حذف می‌شود.'),
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
    if (ok != true || !mounted) return;
    await ref.read(careStoreProvider.notifier).deleteRecord(widget.record.id);
    await CareAttachmentStore.deleteAll(widget.record.attachmentPaths);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: widget.record.title.isEmpty ? 'ثبت سرویس' : widget.record.title,
          subtitle: careJalaliLong(widget.record.date),
        ),
        CareDateButton(
          label: 'تاریخ',
          date: _date,
          accent: widget.accent,
          onPicked: (d) => setState(() => _date = d),
        ),
        CareField(
          controller: _km,
          label: 'کارکرد (km)',
          digitsOnly: true,
          keyboardType: TextInputType.number,
          ltr: true,
        ),
        CareField(
          controller: _cost,
          label: 'هزینه',
          digitsOnly: true,
          keyboardType: TextInputType.number,
          ltr: true,
        ),
        CareField(controller: _note, label: 'یادداشت', maxLines: 2),
        if (widget.record.attachmentPaths.isNotEmpty) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.record.attachmentPaths.length,
              separatorBuilder: (_, index) => const SizedBox(width: 6),
              itemBuilder: (_, i) => CareAttachmentThumb(
                relativePath: widget.record.attachmentPaths[i],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        CareSheetSubmit(
          label: 'ذخیره',
          accent: widget.accent,
          onPressed: _save,
        ),
        TextButton(
          onPressed: _delete,
          style: TextButton.styleFrom(
            foregroundColor: careLevelColor(context, CareStatusLevel.overdue),
          ),
          child: const Text('حذف این ثبت'),
        ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.outline, width: .5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value ?? items.first.value,
          isExpanded: true,
          hint: Text(hint),
          items: items,
          onChanged: onChanged,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: t.textPrimary,
          ),
        ),
      ),
    );
  }
}
