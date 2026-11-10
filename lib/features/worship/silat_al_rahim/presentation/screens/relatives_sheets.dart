import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/family_faith/family_custom_gifts.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_providers.dart';
import 'package:tawheeed/features/personal/family_faith/presentation/family_faith_style.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_gift_ideas.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_planner.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart'
    show CareChip, careJalaliLong;
import 'package:tawheeed/shared/utils/number_format.dart';

Future<void> showRelativeSheet(BuildContext context, {Relative? relative}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RelativeSheet(relative: relative),
  );
}

class _RelativeSheet extends ConsumerStatefulWidget {
  const _RelativeSheet({this.relative});

  final Relative? relative;

  @override
  ConsumerState<_RelativeSheet> createState() => _RelativeSheetState();
}

class _RelativeSheetState extends ConsumerState<_RelativeSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _custom;
  late final TextEditingController _note;
  late RelationKind _relation;
  late int _interval;
  late GiftAudience _audience;
  bool _busy = false;

  bool get _editing => widget.relative != null;

  @override
  void initState() {
    super.initState();
    final relative = widget.relative;
    _name = TextEditingController(text: relative?.name ?? '');
    _phone = TextEditingController(text: relative?.phone ?? '');
    _custom = TextEditingController(text: relative?.relationLabel ?? '');
    _note = TextEditingController(text: relative?.note ?? '');
    _relation = relative?.relation ?? RelationKind.father;
    _interval = relative?.intervalDays ?? _relation.defaultIntervalDays;
    _audience = relative?.effectiveAudience ?? _relation.defaultAudience;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _custom.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AppCard(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CareSheetTitle(
                    title: _editing ? 'ویرایش ${widget.relative!.name}' : 'افزودن به صله رحم',
                    subtitle: 'شماره و یادداشت‌ها فقط روی همین گوشی می‌مانند.',
                  ),
                  CareField(
                    controller: _name,
                    label: 'نام',
                    hint: 'مثلاً عمه زهرا',
                  ),
                  Text(
                    'نسبت',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final kind in RelationKind.values)
                        CareChip(
                          label: kind.labelFa,
                          selected: _relation == kind,
                          accent: familyRelativeColor,
                          onTap: () => setState(() {
                            _relation = kind;
                            _interval = kind.defaultIntervalDays;
                            _audience = kind.defaultAudience;
                          }),
                        ),
                    ],
                  ),
                  if (_relation == RelationKind.other)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: CareField(
                        controller: _custom,
                        label: 'نسبت دلخواه',
                        hint: 'مثلاً پسرخاله',
                      ),
                    ),
                  const SizedBox(height: 10),
                  CareField(
                    controller: _phone,
                    label: 'شمارهٔ تماس (اختیاری)',
                    hint: '۰۹…',
                    keyboardType: TextInputType.phone,
                    digitsOnly: true,
                    ltr: true,
                  ),
                  _StepperRow(
                    label: 'هر چند روز یک بار',
                    value: '$_interval روز',
                    onMinus: _interval > 1
                        ? () => setState(() => _interval = (_interval - 1).clamp(1, 365))
                        : null,
                    onPlus: () =>
                        setState(() => _interval = (_interval + 7).clamp(1, 365)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'پیشنهاد هدیه برای',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final audience in GiftAudience.values)
                        CareChip(
                          label: audience.labelFa,
                          selected: _audience == audience,
                          accent: familyRelativeColor,
                          onTap: () => setState(() => _audience = audience),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CareField(
                    controller: _note,
                    label: 'یادداشت',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  CareSheetSubmit(
                    label: _editing ? 'ذخیرهٔ تغییرات' : 'افزودن',
                    accent: familyRelativeColor,
                    busy: _busy,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final store = ref.read(relativesStoreProvider.notifier);
    try {
      if (_editing) {
        await store.updateRelative(widget.relative!.copyWith(
          name: name,
          relation: _relation,
          relationLabel: _custom.text.trim(),
          phone: _phone.text.trim(),
          note: _note.text.trim(),
          audience: _audience,
          intervalDays: _interval,
        ));
      } else {
        await store.addRelative(
          name: name,
          relation: _relation,
          relationLabel: _custom.text.trim(),
          phone: _phone.text.trim(),
          note: _note.text.trim(),
          intervalDays: _interval,
          audience: _audience,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    this.onMinus,
    this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textSecondary,
              ),
            ),
          ),
          IconButton(
            onPressed: onMinus,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          IconButton(
            onPressed: onPlus,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline, size: 20),
          ),
        ],
      ),
    );
  }
}

// ── gift sheet ─────────────────────────────────────────────────────────────

Future<void> showGiftSheet(BuildContext context, Relative relative) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GiftSheet(relative: relative),
  );
}

class _GiftSheet extends ConsumerStatefulWidget {
  const _GiftSheet({required this.relative});

  final Relative relative;

  @override
  ConsumerState<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends ConsumerState<_GiftSheet> {
  GiftOccasion _occasion = GiftOccasion.visit;
  GiftBudget _budget = GiftBudget.medium;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.relative.giftNote);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Records the gift in the contact log, so the card, the statistics and the
  /// history sheet all see it. Keeps the idea note too: what was given is
  /// exactly the thing worth remembering for next time.
  Future<void> _recordGift() async {
    final store = ref.read(relativesStoreProvider.notifier);
    final title = _note.text.trim();
    if (title.isNotEmpty) {
      await store.saveGiftNote(widget.relative, title);
    }
    await store.logContact(
      relative: widget.relative,
      kind: ContactKind.gift,
      note: title,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveIdea() async {
    await ref
        .read(relativesStoreProvider.notifier)
        .saveGiftNote(widget.relative, _note.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final ideasAsync = ref.watch(giftIdeasProvider);
    final audience = widget.relative.effectiveAudience;
    final ideas = ideasAsync.value ?? const <GiftIdea>[];
    final filtered = filterGiftIdeas(
      ideas,
      occasion: _occasion,
      budget: _budget,
      audience: audience,
    );
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AppCard(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .74,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CareSheetTitle(
                    title: 'هدیه برای ${widget.relative.name}',
                    subtitle: 'ایده‌ها ساده و بی‌هزینه‌اند؛ فقط برای شروع فکر کردن.',
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final occasion in GiftOccasion.values) ...[
                          CareChip(
                            label: occasion.labelFa,
                            selected: _occasion == occasion,
                            accent: familyRelativeColor,
                            onTap: () => setState(() => _occasion = occasion),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final budget in GiftBudget.values) ...[
                        Expanded(
                          child: CareChip(
                            label: budget.labelFa,
                            selected: _budget == budget,
                            accent: familyRelativeColor,
                            onTap: () => setState(() => _budget = budget),
                          ),
                        ),
                        if (budget != GiftBudget.special) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _CustomGiftsSection(
                    selected: _note.text,
                    onPick: (title) => setState(() => _note.text = title),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ideasAsync.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'برای این ترکیب ایده‌ای ثبت نشده است؛ '
                                  'دستهٔ دیگری را امتحان کنید.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: AppTheme.scaledFontSize(context, 11),
                                    color: t.textMuted,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final idea = filtered[index];
                                  return InkWell(
                                    onTap: () => setState(() =>
                                        _note.text = idea.title),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: t.surfaceAlt,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            idea.title,
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: AppTheme.scaledFontSize(
                                                  context, 12),
                                              fontWeight: FontWeight.w700,
                                              color: t.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            idea.tip,
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: AppTheme.scaledFontSize(
                                                  context, 10.5),
                                              color: t.textMuted,
                                              height: 1.45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 6),
                  CareField(
                    controller: _note,
                    label: 'هدیهٔ دلخواه (نام یا ایده)',
                    hint: 'مثلاً چای بی‌بو، کتاب، عسل',
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: CareSheetSubmit(
                          label: 'هدیه دادم',
                          accent: familyRelativeColor,
                          onPressed: _recordGift,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CareSheetSubmit(
                          label: 'ذخیرهٔ ایده',
                          accent: familyRelativeColor,
                          onPressed: _saveIdea,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── my own gift list ───────────────────────────────────────────────────────

/// «هدیه‌های دلخواه من» — the list the user writes, beside the bundled
/// catalogue. It is not a second catalogue: picking one just fills the gift
/// field, so a family's own repeatable gift is one tap away.
class _CustomGiftsSection extends ConsumerWidget {
  const _CustomGiftsSection({required this.selected, required this.onPick});

  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final gifts = ref.watch(customGiftsProvider).value ?? const <CustomGift>[];
    final store = ref.read(customGiftsProvider.notifier);

    Future<void> add() async {
      final draft = await showDialog<({String title, String note})>(
        context: context,
        builder: (_) => const _NewGiftDialog(),
      );
      if (draft == null) return;
      await store.add(draft.title, note: draft.note);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'هدیه‌های دلخواه من',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: t.textMuted,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: add,
              icon: const Icon(Icons.add, size: 15),
              label: Text(
                'افزودن',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11)),
              ),
            ),
          ],
        ),
        if (gifts.isEmpty)
          Text(
            'هر چه خودتان می‌دهید اینجا بنویسید تا دفعهٔ بعد یک ضربه در دسترس '
            'باشد.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10.5),
              color: t.textMuted,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final gift in gifts)
                InputChip(
                  label: Text(
                    gift.note.isEmpty
                        ? gift.title
                        : '${gift.title} · ${gift.note}',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11)),
                  ),
                  selected: selected.trim() == gift.title,
                  onPressed: () => onPick(gift.title),
                  onDeleted: () => store.remove(gift.id),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
      ],
    );
  }
}

/// The add dialog owns its controllers: disposing them while the route is
/// still animating out throws «used after being disposed» (and tore the sheet
/// down with it).
class _NewGiftDialog extends StatefulWidget {
  const _NewGiftDialog();

  @override
  State<_NewGiftDialog> createState() => _NewGiftDialogState();
}

class _NewGiftDialogState extends State<_NewGiftDialog> {
  final _title = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('هدیهٔ دلخواه'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'نام هدیه',
              hintText: 'مثلاً چای بی‌بو',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'یادداشت (اختیاری)',
              hintText: 'اندازه، رنگ، از کجا',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context)
              .pop((title: _title.text, note: _note.text)),
          child: const Text('افزودن'),
        ),
      ],
    );
  }
}

// ── history + per-person statistics ────────────────────────────────────────

Future<void> showRelativeHistorySheet(
        BuildContext context, Relative relative) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RelativeHistorySheet(relative: relative),
    );

/// The per-person answers: how many calls, messages, visits and gifts, when
/// each kind happened last, and the full log with a delete per row.
class _RelativeHistorySheet extends ConsumerWidget {
  const _RelativeHistorySheet({required this.relative});

  final Relative relative;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final snapshot = ref.watch(relativesStoreProvider).value;
    final now = DateTime.now();
    final rows = snapshot?.contactsFor(relative.id) ?? const <ContactLog>[];
    final summary = RelativeContactSummary.from(
      rows,
      recentSince:
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AppCard(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CareSheetTitle(
                  title: 'تاریخچهٔ ${relative.name}',
                  subtitle: 'همهٔ چیزهایی که با هم ثبت کرده‌اید، فقط روی این گوشی.',
                ),
                Row(
                  children: [
                    for (final kind in ContactKind.values) ...[
                      Expanded(
                        child: _StatTile(
                          kind: kind,
                          total: summary.total(kind),
                          recent: summary.recent(kind),
                          last: summary.lastOf(kind)?.date,
                          now: now,
                        ),
                      ),
                      if (kind != ContactKind.gift) const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: Text(
                            'هنوز چیزی ثبت نشده. از دکمه‌های کارت «تماس»، «دیدار» یا '
                            '«هدیه» شروع کنید.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 11),
                              color: t.textMuted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (rowContext, index) {
                            final row = rows[index];
                            return _HistoryRow(
                              row: row,
                              onDelete: () => ref
                                  .read(relativesStoreProvider.notifier)
                                  .removeContact(
                                    relative: relative,
                                    contact: row,
                                  ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 6),
                CareSheetSubmit(
                  label: 'بستن',
                  accent: familyRelativeColor,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.kind,
    required this.total,
    required this.recent,
    required this.last,
    required this.now,
  });

  final ContactKind kind;
  final int total;
  final int recent;
  final DateTime? last;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final icon = switch (kind) {
      ContactKind.call => Icons.call_outlined,
      ContactKind.message => Icons.chat_bubble_outline,
      ContactKind.visit => Icons.directions_walk,
      ContactKind.gift => Icons.card_giftcard_outlined,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: familyRelativeColor.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: familyRelativeColor.withValues(alpha: .18), width: .5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: dsContentColor(context, familyRelativeColor)),
          const SizedBox(height: 3),
          Text(
            '$total',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          Text(
            kind.labelFa,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 9.5),
              color: t.textMuted,
            ),
          ),
          Text(
            last == null ? '—' : daysAgoLabel(last!, now),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 9.5),
              color: recent > 0 ? dsContentColor(context, familyRelativeColor) : t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.row, required this.onDelete});

  final ContactLog row;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final icon = switch (row.kind) {
      ContactKind.call => Icons.call_outlined,
      ContactKind.message => Icons.chat_bubble_outline,
      ContactKind.visit => Icons.directions_walk,
      ContactKind.gift => Icons.card_giftcard_outlined,
    };
    return Row(
      children: [
        Icon(icon, size: 14, color: dsContentColor(context, familyRelativeColor)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.note.isEmpty
                    ? row.kind.labelFa
                    : '${row.kind.labelFa} · ${row.note}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary,
                ),
              ),
              Text(
                careJalaliLong(row.date),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 10),
                  color: t.textMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'حذف این ردیف',
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline, color: t.textMuted),
        ),
      ],
    );
  }
}

// ── settings sheet ─────────────────────────────────────────────────────────

Future<void> showFamilySettingsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FamilySettingsSheet(),
  );
}

class _FamilySettingsSheet extends ConsumerWidget {
  const _FamilySettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(familySettingsProvider);
    final settings = async.value ?? const FamilyReminderSettings();
    final store = ref.read(relativesStoreProvider.notifier);

    void update(FamilyReminderSettings next) => store.saveSettings(next);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AppCard(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CareSheetTitle(
                  title: 'یادآوری‌های صله رحم',
                  subtitle: 'آرام و بی‌سرزنش؛ هر وقت خواستید خاموشش کنید.',
                ),
                CareSwitchRow(
                  label: 'یادآوری فعال باشد',
                  value: settings.enabled,
                  accent: familyRelativeColor,
                  onChanged: (value) => update(settings.copyWith(enabled: value)),
                ),
                CareSwitchRow(
                  label: 'یادآوری هفتگی وقتی عقب افتاده',
                  value: settings.weeklyNudge,
                  accent: familyRelativeColor,
                  onChanged: (value) =>
                      update(settings.copyWith(weeklyNudge: value)),
                ),
                _StepperRow(
                  label: 'ساعت یادآوری',
                  value: '${settings.deliveryHour.toString().padLeft(2, '0')}:۰۰',
                  onMinus: () => update(
                      settings.copyWith(hour: (settings.hour - 1).clamp(0, 23))),
                  onPlus: () => update(
                      settings.copyWith(hour: (settings.hour + 1).clamp(0, 23))),
                ),
                _StepperRow(
                  label: 'حداکثر یادآوری هر دوره',
                  value: NumberFormat.en(settings.maxNudges),
                  onMinus: () => update(settings.copyWith(
                      maxNudges: (settings.maxNudges - 1).clamp(1, 8))),
                  onPlus: () => update(settings.copyWith(
                      maxNudges: (settings.maxNudges + 1).clamp(1, 8))),
                ),
                CareSheetSubmit(
                  label: 'بستن',
                  accent: familyRelativeColor,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
