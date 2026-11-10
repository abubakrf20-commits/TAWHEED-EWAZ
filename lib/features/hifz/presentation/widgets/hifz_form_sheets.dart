import 'package:flutter/material.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/hifz/domain/hifz_helpers.dart';
import 'package:tawheeed/features/hifz/presentation/providers/hifz_provider.dart';
import 'package:tawheeed/features/hifz/presentation/widgets/hifz_range_picker.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';

const List<String> avatarPalette = [
  '#1976D2',
  '#2E7D32',
  '#E53935',
  '#8E24AA',
  '#F9A825',
  '#00897B',
  '#EC407A',
  '#5E35B1',
  '#F4511E',
  '#455A64',
];

/// `#RRGGBB` → Color. A restored backup (or a hand-edited row) can carry a
/// value that is not a hex colour; `int.parse` threw inside build and took
/// the whole screen down, so an unreadable value falls back to the module
/// accent instead.
Color _hex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', '0xFF'));
  return value == null ? TopicHues.hifz : Color(value);
}

// ── Hafiz form ──────────────────────────────────────────────────────

Future<void> showHafizFormSheet(
  BuildContext context,
  WidgetRef ref, {
  HafizModel? hafiz,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    builder: (_) => _HafizFormSheet(hafiz: hafiz),
  );
}

class _HafizFormSheet extends ConsumerStatefulWidget {
  const _HafizFormSheet({this.hafiz});
  final HafizModel? hafiz;

  @override
  ConsumerState<_HafizFormSheet> createState() => _HafizFormSheetState();
}

class _HafizFormSheetState extends ConsumerState<_HafizFormSheet> {
  late final TextEditingController _nameCtrl;
  late String _color;
  late int _windowDays;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.hafiz?.name ?? '');
    _color = widget.hafiz?.colorHex ?? avatarPalette.first;
    _windowDays = widget.hafiz?.sabaqWindowDays ?? 7;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final notifier = ref.read(hifzProvider.notifier);
    if (widget.hafiz == null) {
      await notifier.addHafiz(
          name: name, colorHex: _color, sabaqWindowDays: _windowDays);
    } else {
      await notifier.updateHafiz(widget.hafiz!.copyWith(
          name: name, colorHex: _color, sabaqWindowDays: _windowDays));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                widget.hafiz == null ? 'افزودن حافظ' : 'ویرایش حافظ',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              autofocus: widget.hafiz == null,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'نام حافظ',
                hintText: 'مثلاً محمد، فاطمه، …',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Text('رنگ آواتار', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < avatarPalette.length; i++)
                  Semantics(
                    button: true,
                    selected: _color == avatarPalette[i],
                    label: 'رنگ آواتار ${i + 1}',
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _color = avatarPalette[i]),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _hex(avatarPalette[i]),
                          shape: BoxShape.circle,
                          border: _color == avatarPalette[i]
                              ? Border.all(color: t.textPrimary, width: 3)
                              : null,
                        ),
                        child: _color == avatarPalette[i]
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('پنجرهٔ سبق (مرور محفوظات نزدیک)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final days in const [3, 5, 7, 10, 15])
                  ChoiceChip(
                    label: Text('$days روز'),
                    selected: _windowDays == days,
                    onSelected: (_) => setState(() => _windowDays = days),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('ذخیره')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lesson form (حفظ جدید) ──────────────────────────────────────────

Future<void> showLessonFormSheet(
  BuildContext context,
  WidgetRef ref,
  HafizModel hafiz, {
  HifzLessonModel? lesson,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    builder: (_) => _LessonFormSheet(hafiz: hafiz, lesson: lesson),
  );
}

class _LessonFormSheet extends ConsumerStatefulWidget {
  const _LessonFormSheet({required this.hafiz, this.lesson});
  final HafizModel hafiz;
  final HifzLessonModel? lesson;

  @override
  ConsumerState<_LessonFormSheet> createState() => _LessonFormSheetState();
}

class _LessonFormSheetState extends ConsumerState<_LessonFormSheet> {
  late DateTime _date;
  HifzRange _range = (sFrom: 1, aFrom: 1, sTo: 1, aTo: 5, pages: 1);
  ReviewQuality _quality = ReviewQuality.excellent;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final l = widget.lesson;
    _date = l?.date ?? DateTime.now();
    _quality = l?.quality ?? ReviewQuality.excellent;
    _range = (
      sFrom: l?.surahFrom ?? 1,
      aFrom: l?.ayahFrom ?? 1,
      sTo: l?.surahTo ?? 1,
      aTo: l?.ayahTo ?? 5,
      pages: l?.pages ?? 1,
    );
    _notesCtrl = TextEditingController(text: l?.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!isRangeValid(_range.sFrom, _range.aFrom, _range.sTo, _range.aTo)) {
      return;
    }
    final pages = _range.pages;
    if (pages < 1) return;
    final notifier = ref.read(hifzProvider.notifier);
    if (widget.lesson == null) {
      await notifier.addLesson(
        hafizId: widget.hafiz.id,
        date: _date,
        surahFrom: _range.sFrom,
        ayahFrom: _range.aFrom,
        surahTo: _range.sTo,
        ayahTo: _range.aTo,
        pages: pages,
        quality: _quality,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    } else {
      await notifier.updateLesson(widget.lesson!.copyWith(
        date: _date,
        surahFrom: _range.sFrom,
        ayahFrom: _range.aFrom,
        surahTo: _range.sTo,
        ayahTo: _range.aTo,
        pages: pages,
        quality: _quality,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                widget.lesson == null ? 'ثبت حفظ جدید' : 'ویرایش حفظ',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('مقداری که امروز تازه حفظ شده است',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text('تاریخ: ${jalaliLabelFa(_date)}'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final picked = await ShamsiDatePicker.show(context);
                // The sheet can be dismissed while the picker is open.
                if (picked == null || !mounted) return;
                setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 12),
            HifzRangePicker(
              initialSurahFrom: _range.sFrom,
              initialAyahFrom: _range.aFrom,
              initialSurahTo: _range.sTo,
              initialAyahTo: _range.aTo,
              helperText:
                  'بازهٔ حفظ جدید را مشخص کنید — تعداد صفحه بهصورت خودکار محاسبه میشود.',
              onChanged: (r) => setState(() => _range = r),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              textAlign: TextAlign.right,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'یادداشت (اختیاری)',
                hintText: 'مثلاً سورهٔ بقره از حفظ خوانده شد',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Text('کیفیت حفظ', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final q in ReviewQuality.values) ...[
                  Expanded(
                    child: ChoiceChip(
                      label: Text(q.label),
                      selected: _quality == q,
                      onSelected: (_) => setState(() => _quality = q),
                    ),
                  ),
                  if (q != ReviewQuality.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('ذخیره')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Review form (سبق / مراجعه) ─────────────────────────────────────

Future<void> showReviewFormSheet(
  BuildContext context,
  WidgetRef ref,
  HafizModel hafiz, {
  required ReviewType type,
  HifzReviewModel? review,
  HifzRange? suggested,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    builder: (_) => _ReviewFormSheet(
      hafiz: hafiz,
      type: type,
      review: review,
      suggested: suggested,
    ),
  );
}

class _ReviewFormSheet extends ConsumerStatefulWidget {
  const _ReviewFormSheet({
    required this.hafiz,
    required this.type,
    this.review,
    this.suggested,
  });
  final HafizModel hafiz;
  final ReviewType type;
  final HifzReviewModel? review;
  final HifzRange? suggested;

  @override
  ConsumerState<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends ConsumerState<_ReviewFormSheet> {
  late DateTime _date;
  late ReviewQuality _quality;
  late HifzRange _range;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final r = widget.review;
    final sug = widget.suggested;
    _date = r?.date ?? DateTime.now();
    _quality = r?.quality ?? ReviewQuality.medium;
    _range = (
      sFrom: r?.surahFrom ?? sug?.sFrom ?? 1,
      aFrom: r?.ayahFrom ?? sug?.aFrom ?? 1,
      sTo: r?.surahTo ?? sug?.sTo ?? 1,
      aTo: r?.ayahTo ?? sug?.aTo ?? 5,
      pages: r?.pages ?? sug?.pages ?? 1,
    );
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!isRangeValid(_range.sFrom, _range.aFrom, _range.sTo, _range.aTo)) {
      return;
    }
    if (_range.pages < 1) return;
    final notifier = ref.read(hifzProvider.notifier);
    if (widget.review == null) {
      await notifier.addReview(
        hafizId: widget.hafiz.id,
        date: _date,
        type: widget.type,
        surahFrom: _range.sFrom,
        ayahFrom: _range.aFrom,
        surahTo: _range.sTo,
        ayahTo: _range.aTo,
        pages: _range.pages,
        quality: _quality,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    } else {
      await notifier.updateReview(widget.review!.copyWith(
        date: _date,
        surahFrom: _range.sFrom,
        ayahFrom: _range.aFrom,
        surahTo: _range.sTo,
        ayahTo: _range.aTo,
        pages: _range.pages,
        quality: _quality,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final error = isDark ? AppTheme.darkError : AppTheme.lightError;
    final title = widget.review == null
        ? 'ثبت ${widget.type.label}'
        : 'ویرایش ${widget.type.label}';
    final helper = widget.type == ReviewType.sabaq
        ? 'پیشنهاد خودکار: محفوظات ${en(widget.hafiz.sabaqWindowDays)} روز اخیر — در صورت نیاز ویرایش کنید.'
        : 'بازهٔ مرور حفظ قدیم را مشخص کنید (مثلاً نیم جزء).';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                widget.type == ReviewType.sabaq
                    ? 'مرور محفوظاتِ نزدیک (${en(widget.hafiz.sabaqWindowDays)} روز اخیر)'
                    : 'مرور محفوظات قدیمی (حفظ دور)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text('تاریخ: ${jalaliLabelFa(_date)}'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final picked = await ShamsiDatePicker.show(context);
                // The sheet can be dismissed while the picker is open.
                if (picked == null || !mounted) return;
                setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 12),
            HifzRangePicker(
              initialSurahFrom: _range.sFrom,
              initialAyahFrom: _range.aFrom,
              initialSurahTo: _range.sTo,
              initialAyahTo: _range.aTo,
              helperText: helper,
              onChanged: (r) => setState(() => _range = r),
            ),
            const SizedBox(height: 16),
            Text('کیفیت مرور', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final q in ReviewQuality.values)
                  ChoiceChip(
                    label: Text(q.label),
                    selected: _quality == q,
                    avatar: Icon(
                      q == ReviewQuality.weak
                          ? Icons.thumb_down_alt_outlined
                          : q == ReviewQuality.medium
                              ? Icons.remove_circle_outline
                              : Icons.thumb_up_alt_outlined,
                      size: 16,
                      color: q == ReviewQuality.weak
                          ? error
                          : q == ReviewQuality.medium
                              ? warning
                              : success,
                    ),
                    onSelected: (_) => setState(() => _quality = q),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              textAlign: TextAlign.right,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'یادداشت (اختیاری)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('ذخیره')),
            ),
          ],
        ),
      ),
    );
  }
}
