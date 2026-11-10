import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_categories.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_report.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'package:tawheeed/features/tools/dongi/presentation/dangi_colors.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';
import 'package:tawheeed/core/design_system/components/components.dart';

const Color _accent = TopicHues.dangi;

const List<String> dangiPalette = [
  '#00ACC1',
  '#E53935',
  '#1E88E5',
  '#8E24AA',
  '#F9A825',
  '#2E7D32',
  '#EC407A',
  '#5E35B1',
  '#F4511E',
  '#455A64',
];

/// Create or edit a dangi group (name + members).
Future<void> showDangiGroupFormSheet(
  BuildContext context,
  WidgetRef ref, {
  DangiGroupModel? group,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    builder: (_) => _GroupFormSheet(group: group),
  );
}

class _GroupFormSheet extends ConsumerStatefulWidget {
  const _GroupFormSheet({this.group});
  final DangiGroupModel? group;

  @override
  ConsumerState<_GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends ConsumerState<_GroupFormSheet> {
  late final TextEditingController _nameCtrl;
  late String _color;
  final List<_MemberField> _memberFields = [];
  final _membersKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.group?.name ?? '');
    _color = widget.group?.colorHex ?? dangiPalette.first;
    // For editing, prefill with current members (fetched below).
    _memberFields.add(_MemberField(id: null, ctrl: TextEditingController()));
    if (widget.group != null) {
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    // اگر دیتابیس هنوز لود نشده، صبر می‌کنیم تا اعضای واقعی گروه
    // وارد فرم شوند وگرنه ممکن است ویرایش، اعضای موجود را حذف کند.
    var state = ref.read(dangiProvider);
    // حداکثر ~6 ثانیه صبر می‌کنیم؛ اگر لود نشد فرم را می‌بندیم تا کاربر با
    // لیست خالی ذخیره نکند و اعضای موجود ناخواسته حذف نشوند.
    for (var i = 0; i < 150 && !state.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      state = ref.read(dangiProvider);
    }
    if (!mounted) return;
    if (!state.loaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('داده‌ها هنوز بارگذاری نشده‌اند؛ دوباره تلاش کنید'),
      ));
      Navigator.of(context).pop();
      return;
    }
    final members = state.membersOf(widget.group!.id);
    setState(() {
      // اگر کاربر همزمان نامی تایپ کرده باشد آن را حفظ می‌کنیم و اعضای
      // لودشده را قبل از فیلدهای دستی می‌نشانیم.
      final typed = [
        for (final f in _memberFields)
          if (f.ctrl.text.trim().isNotEmpty) f,
      ];
      for (final f in _memberFields) {
        if (!typed.contains(f)) f.ctrl.dispose();
      }
      _memberFields
        ..clear()
        ..addAll([
          for (final m in members)
            _MemberField(id: m.id, ctrl: TextEditingController(text: m.name)),
          ...typed,
        ]);
      if (_memberFields.isEmpty) {
        _memberFields
            .add(_MemberField(id: null, ctrl: TextEditingController()));
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _memberFields) {
      c.ctrl.dispose();
    }
    super.dispose();
  }

  void _addMember() {
    setState(() => _memberFields
        .add(_MemberField(id: null, ctrl: TextEditingController())));
  }

  void _removeMember(int index) {
    if (_memberFields.length <= 1) return;
    setState(() {
      _memberFields.removeAt(index).ctrl.dispose();
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final members = <({String? id, String name})>[
      for (final f in _memberFields)
        if (f.ctrl.text.trim().isNotEmpty) (id: f.id, name: f.ctrl.text.trim()),
    ];
    if (_membersKey.currentState?.validate() != true) {
      return;
    }
    if (name.isEmpty || members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام گروه و حداقل یک عضو لازم است')),
      );
      return;
    }
    // هشدار: حذف عضوی که هزینه دارد، هزینه‌های او را هم حذف می‌کند.
    if (widget.group != null && !await _confirmRemovals(members)) {
      return;
    }
    final notifier = ref.read(dangiProvider.notifier);
    if (widget.group == null) {
      await notifier.addGroup(
          name: name,
          colorHex: _color,
          memberNames: [for (final m in members) m.name]);
    } else {
      await notifier.updateGroup(
        widget.group!.copyWith(name: name, colorHex: _color),
        members,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Returns true when removing members with recorded expenses is confirmed.
  Future<bool> _confirmRemovals(
      List<({String? id, String name})> members) async {
    final state = ref.read(dangiProvider);
    final expenses = state.expensesOf(widget.group!.id);
    if (expenses.isEmpty) return true;
    final keptIds = members.map((m) => m.id).whereType<String>().toSet();
    final removed = state
        .membersOf(widget.group!.id)
        .where((m) => !keptIds.contains(m.id))
        .toList();
    if (removed.isEmpty) return true;
    final removedWithExpenses =
        removed.where((m) => expenses.any((e) => e.payerId == m.id)).toList();
    if (removedWithExpenses.isEmpty) return true;
    final names = removedWithExpenses.map((m) => '«${m.name}»').join('، ');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final danger = Theme.of(ctx).brightness == Brightness.dark
            ? AppTheme.darkError
            : AppTheme.lightError;
        return AlertDialog(
          backgroundColor: TimeThemeKit.of(ctx).palette.card,
          title: const Text('حذف عضو؟'),
        content: Text(
          'با حذف $names هزینه‌های پرداخت‌شده توسط آن‌ها هم حذف می‌شود. ادامه می‌دهید؟',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف', style: TextStyle(color: danger)),
          ),
        ],
      );
    },
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onPrimary = dsOnAccent(context);
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Form(
          key: _membersKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TimeThemeKit.of(context).palette.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.group == null ? 'گروه جدید' : 'ویرایش گروه',
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 17),
                  fontWeight: FontWeight.bold,
                  color: _accent,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameCtrl,
                textDirection: TextDirection.rtl,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'نام گروه را وارد کنید'
                    : null,
                decoration: _inputDec(context, 'نام گروه', 'مثلاً سفر شیراز'),
              ),
              const SizedBox(height: 14),
              Text('رنگ گروه',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13), color: TimeThemeKit.of(context).palette.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in dangiPalette)
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: dangiColorFromHex(c),
                          shape: BoxShape.circle,
                          border: _color == c
                              ? Border.all(color: onPrimary, width: 3)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('اعضا',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 13), color: TimeThemeKit.of(context).palette.textMuted)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addMember,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('افزودن'),
                  ),
                ],
              ),
              for (var i = 0; i < _memberFields.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _memberFields[i].ctrl,
                          textDirection: TextDirection.rtl,
                          decoration:
                              _inputDec(context, 'نام عضو', 'مثلاً علی'),
                        ),
                      ),
                      if (_memberFields.length > 1)
                        IconButton(
                          onPressed: () => _removeMember(i),
                          icon:
                              const Icon(Icons.remove_circle_outline, size: 20),
                          color: danger.withValues(alpha: 0.7),
                          tooltip: 'حذف عضو',
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _save,
                  child: const Text('ذخیره'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for adding (or editing, when [expense] is given) an expense.
Future<void> showDangiExpenseSheet(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  List<DangiMemberModel> members, {
  DangiExpenseModel? expense,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    builder: (_) =>
        _ExpenseSheet(groupId: groupId, members: members, expense: expense),
  );
}

class _ExpenseSheet extends ConsumerStatefulWidget {
  const _ExpenseSheet({
    required this.groupId,
    required this.members,
    this.expense,
  });

  final String groupId;
  final List<DangiMemberModel> members;
  final DangiExpenseModel? expense;

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _payerId;
  String _category = DangiExpenseCategory.other.id;
  late DateTime _date;

  /// When true, the expense is NOT split equally: each member gets their own
  /// consumed amount (the «مصرف‌کننده» mode, e.g. sandwich 200 / pizza 500).
  bool _hasConsumers = false;
  final Map<String, TextEditingController> _consumerCtrls = {};
  final _scrollCtrl = ScrollController();
  final _fieldsKey = GlobalKey();

  TextEditingController _consumerCtrl(String memberId) =>
      _consumerCtrls.putIfAbsent(memberId, TextEditingController.new);

  Map<String, double> get _consumerAmounts {
    if (!_hasConsumers) return const {};
    final out = <String, double>{};
    for (final entry in _consumerCtrls.entries) {
      final v = parseDangiAmount(entry.value.text);
      if (v != null && v > 0) out[entry.key] = v;
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _date = e?.date ?? DateTime.now();
    if (e != null) {
      _titleCtrl.text = e.title;
      _amountCtrl.text = _amountText(e.amount);
      _payerId = e.payerId;
      _category = e.category;
      _hasConsumers = e.consumers.isNotEmpty;
      e.consumers.forEach((memberId, amount) {
        _consumerCtrl(memberId).text = _amountText(amount);
      });
    } else if (widget.members.isNotEmpty) {
      _payerId = widget.members.first.id;
    }
  }

  /// The amount as the field shows it: grouped thousands, a fraction only
  /// when there is one — `parseDangiAmount` accepts that shape back.
  static String _amountText(double v) => NumberFormat.groupDigits(
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  /// Fills every member's consumed amount with an equal split of the expense
  /// total (the last member receives the remainder, so the sum always exact).
  void _fillEqualSplit() {
    final amount = parseDangiAmount(_amountCtrl.text);
    final n = widget.members.length;
    if (amount == null || amount <= 0 || n == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ابتدا مبلغ خرج را وارد کنید'),
      ));
      return;
    }
    setState(() {
      _hasConsumers = true;
      var assigned = 0.0;
      for (var i = 0; i < n; i++) {
        final m = widget.members[i];
        final isLast = i == n - 1;
        final v = isLast ? amount - assigned : _round2(amount / n);
        assigned += v;
        _consumerCtrl(m.id).text = _amountText(v);
      }
    });
    _afterConsumersEnabled();
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    for (final c in _consumerCtrls.values) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// بعد از ظاهر شدن ردیف‌های مصرف‌کننده، اگر زیر خط دید باشند اسکرول
  /// می‌کند تا اسم افراد بلافاصله قابل مشاهده باشند (بدون جابه‌جایی
  /// وقتی ردیف‌ها از قبل دیده می‌شوند).
  void _afterConsumersEnabled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _fieldsKey.currentContext;
      if (ctx == null || !_scrollCtrl.hasClients) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  List<TextEditingController> get _consumerControllers =>
      [for (final m in widget.members) _consumerCtrl(m.id)];

  double _consumersTotal() =>
      _consumerAmounts.values.fold(0.0, (sum, value) => sum + value);

  Widget _dragHandle(Color muted) => Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: TimeThemeKit.of(context).palette.textMuted,
            fontSize: AppTheme.scaledFontSize(context, 13),
            fontWeight: FontWeight.w600,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      );

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final muted = TimeThemeKit.of(context).palette.textMuted;
    return ChoiceChip(
      avatar:
          icon == null ? null : Icon(icon, size: 16, color: selected ? color : muted),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.16),
      labelStyle: TextStyle(
        color: selected ? color : muted,
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, 12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (_) => onTap(),
    );
  }

  Widget _consumersToggle(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.only(start: 12, end: 2),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: _hasConsumers ? 0.10 : 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _accent.withValues(alpha: _hasConsumers ? 0.35 : 0.18),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.groups_outlined, size: 18, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'مصرف هر عضو',
                style: TextStyle(
                  color: TimeThemeKit.of(context).palette.textPrimary,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _fillEqualSplit,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: BorderSide(color: _accent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                textStyle: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              child: const Text('تقسیم برابری'),
            ),
            Switch(
              value: _hasConsumers,
              activeThumbColor: _accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) {
                setState(() => _hasConsumers = value);
                if (value) _afterConsumersEnabled();
              },
            ),
          ],
        ),
      );

  Widget _consumersSummary(BuildContext context, Color muted) => AnimatedBuilder(
        animation: Listenable.merge([..._consumerControllers, _amountCtrl]),
        builder: (context, _) {
          final amount = parseDangiAmount(_amountCtrl.text) ?? 0;
          final total = _consumersTotal();
          final remaining = amount - total;
          final exact = amount > 0 && remaining.abs() < 0.01;
          final over = amount > 0 && remaining < -0.01;
          final color = exact
              ? AppTheme.success
              : over
                  ? AppTheme.error
                  : muted;
          final icon = exact
              ? Icons.check_circle_outline
              : over
                  ? Icons.error_outline
                  : Icons.info_outline;
          final String text;
          if (amount <= 0) {
            text = 'ابتدا مبلغ خرج را وارد کنید';
          } else if (exact) {
            text = 'جمع مصرف با مبلغ خرج برابر است (${faMoney(total)})';
          } else if (over) {
            text = '${faMoney(-remaining)} بیشتر از مبلغ خرج است';
          } else if (total == 0) {
            text = 'سهم مصرف هر عضو را وارد کنید — مبلغ خرج ${faMoney(amount)}';
          } else {
            text = '${faMoney(remaining)} از مبلغ خرج باقی مانده';
          }
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: color,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _dateTile(BuildContext context, Color muted) => InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: _accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'تاریخ',
                style: TextStyle(
                  color: muted,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const Spacer(),
              Text(
                dangiDateLabel(_date),
                style: TextStyle(
                  color: TimeThemeKit.of(context).palette.textPrimary,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_calendar_outlined, color: muted, size: 18),
            ],
          ),
        ),
      );

  Widget _footer(BuildContext context, Color muted) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: TimeThemeKit.of(context).palette.surface,
          border: Border(
            top: BorderSide(color: muted.withValues(alpha: 0.18)),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _save,
            child: Text(widget.expense == null ? 'ثبت هزینه' : 'ذخیره تغییرات'),
          ),
        ),
      );

  Future<void> _pickDate() async {
    final picked = await ShamsiDatePicker.show(context, initialDate: _date);
    if (picked != null && mounted) setState(() => _date = picked);
  }

  /// «عنوان» نباید خالی باشد.
  String? _validateTitle(String? value) =>
      (value ?? '').trim().isEmpty ? 'عنوان هزینه را وارد کنید' : null;

  /// «مبلغ» باید عددی معتبر و بزرگ‌تر از صفر باشد.
  String? _validateAmount(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'مبلغ را وارد کنید';
    final parsed = parseDangiAmount(raw);
    if (parsed == null) return 'مبلغ باید عدد باشد';
    if (parsed <= 0) return 'مبلغ باید بزرگ‌تر از صفر باشد';
    return null;
  }

  /// «پرداخت‌کننده» از میان اعضای گروه باید انتخاب شده باشد.
  String? _validatePayer() =>
      _payerId == null ? 'پرداخت‌کننده را انتخاب کنید' : null;

  /// True once the user has pressed save at least once, so the payer hint shows
  /// only after a failed attempt instead of nagging while typing.
  bool _showErrors = false;

  /// Inline hint under the payer chips (not a FormField, so it is rendered
  /// directly rather than through a validator).
  Widget? _payerErrorHint() {
    if (_payerId != null || !_showErrors) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        _validatePayer() ?? '',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: AppTheme.scaledFontSize(context, 12),
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = parseDangiAmount(_amountCtrl.text);
    _showErrors = true;
    if (_formKey.currentState?.validate() != true) {
      setState(() {});
      return;
    }
    if (title.isEmpty || amount == null || amount <= 0 || _payerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عنوان، مبلغ و پرداخت‌کننده لازم است')),
      );
      return;
    }
    final notifier = ref.read(dangiProvider.notifier);
    final existing = widget.expense;
    final consumers = _consumerAmounts;
    // Warn when the per-member amounts do not add up to the expense total.
    if (_hasConsumers && consumers.isNotEmpty) {
      final sum = consumers.values.fold(0.0, (s, v) => s + v);
      if ((sum - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('مجموع مصرف‌کننده‌ها ($sum) با مبلغ خرج ($amount) یکی نیست'),
        ));
        return;
      }
    }
    if (existing == null) {
      await notifier.addExpense(
        groupId: widget.groupId,
        payerId: _payerId!,
        title: title,
        category: _category,
        amount: amount,
        consumers: consumers,
        date: _date,
      );
    } else {
      await notifier.updateExpense(existing.copyWith(
        payerId: _payerId,
        title: title,
        category: _category,
        amount: amount,
        date: _date,
        consumers: consumers,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mutedColor = TimeThemeKit.of(context).palette.textMuted;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dragHandle(mutedColor),
          Flexible(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.expense == null ? 'هزینه جدید' : 'ویرایش هزینه',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 17),
                        fontWeight: FontWeight.bold,
                        color: _accent,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleCtrl,
                      textDirection: TextDirection.rtl,
                      validator: _validateTitle,
                      decoration: _inputDec(
                          context, 'عنوان', 'مثلاً شام رستوران',
                          dense: true),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [LatinGroupingFormatter()],
                      textDirection: TextDirection.ltr,
                      validator: _validateAmount,
                      decoration: _inputDec(context, 'مبلغ', 'مثلاً 250000',
                          dense: true),
                    ),
                    _sectionLabel(context, 'پرداخت‌کننده'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in widget.members)
                          _chip(
                            context,
                            label: m.name,
                            selected: _payerId == m.id,
                            color: _accent,
                            onTap: () => setState(() => _payerId = m.id),
                          ),
                      ],
                    ),
                    if (_payerErrorHint() != null) _payerErrorHint()!,
                    _sectionLabel(context, 'دسته'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in DangiExpenseCategory.values)
                        _chip(
                          context,
                          label: c.label,
                          icon: categoryIcon(c),
                          selected: _category == c.id,
                          color: categoryColor(c),
                          onTap: () => setState(() => _category = c.id),
                        ),
                    ],
                  ),
                  _sectionLabel(context, 'تقسیم هزینه'),
                  _consumersToggle(context),
                  if (_hasConsumers) ...[
                    const SizedBox(height: 8),
                    KeyedSubtree(
                      key: _fieldsKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final m in widget.members)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      m.name,
                                      style: TextStyle(
                                        color: TimeThemeKit.of(context).palette.textPrimary,
                                        fontSize: AppTheme.scaledFontSize(context, 13),
                                        fontFamily: AppTheme.fontFamily,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _consumerCtrl(m.id),
                                      keyboardType: const TextInputType
                                          .numberWithOptions(decimal: true),
                                      inputFormatters: const [
                                        LatinGroupingFormatter()
                                      ],
                                      textDirection: TextDirection.ltr,
                                      decoration: _inputDec(
                                          context, 'سهم', '0',
                                          dense: true),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _consumersSummary(context, mutedColor),
                        ],
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'مبلغ خرج به‌طور مساوی بین ${widget.members.length} نفر تقسیم می‌شود.',
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _dateTile(context, mutedColor),
                ],
              ),
                ),
            ),
          ),
          _footer(context, mutedColor),
        ],
      ),
    );
  }
}


/// A member input row: the optional [id] links it to an existing member so
/// renaming keeps the member's expenses.
class _MemberField {
  _MemberField({required this.id, required this.ctrl});
  final String? id;
  final TextEditingController ctrl;
}

InputDecoration _inputDec(BuildContext context, String label, String hint,
    {bool dense = false}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    isDense: dense,
    contentPadding:
        dense ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12) : null,
    labelStyle: TextStyle(color: TimeThemeKit.of(context).palette.textMuted),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}
