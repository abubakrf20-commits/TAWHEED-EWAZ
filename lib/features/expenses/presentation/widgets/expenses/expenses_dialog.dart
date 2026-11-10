import 'package:flutter/material.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    show dsContentColor;
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expense_category_picker.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_common.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/domain/expense_categories.dart';
import 'package:tawheeed/features/expenses/domain/expense_recurrence.dart';
import 'package:tawheeed/features/expenses/presentation/providers/expense_categories_provider.dart';
import 'package:tawheeed/features/expenses/presentation/providers/expense_provider.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

class ExpenseDialog extends ConsumerStatefulWidget {
  /// واحد پول دفتر — برای برچسب فیلد مبلغ و پیام‌های بودجه.
  final String unit;

  final WidgetRef ref;
  final ExpenseModel? existingExpense;
  const ExpenseDialog({
    super.key,
    required this.ref,
    this.existingExpense,
    this.unit = 'تومان',
  });

  @override
  ConsumerState<ExpenseDialog> createState() => ExpenseDialogState();
}

class ExpenseDialogState extends ConsumerState<ExpenseDialog> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isIncome = false;
  String _category = kDefaultExpenseCategory;
  DateTime _date = DateTime.now();
  String? _recurring;

  /// Why the last save attempt was refused, shown inside the sheet.
  ///
  /// This used to be a SnackBar, which the modal sheet covers: the save button
  /// looked dead exactly when the reader needed to be told which field was
  /// empty. The message now lives where the mistake is.
  String? _formError;

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existingExpense!;
      _titleCtrl.text = e.title;
      _amountCtrl.text = NumberFormat.formatPlain(e.amount);
      _isIncome = e.isIncome;
      // The row's own category, canonicalised: a row saved as «عام» by the
      // pre-Drift import opens with the chip the picker actually offers for it,
      // instead of opening with nothing selected.
      _category = categoryForExpense(e);
      _noteCtrl.text = e.note ?? '';
      _date = e.date;
      _recurring = e.isRecurring ? e.recurringType : null;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await ShamsiDatePicker.show(context);
    if (picked != null && mounted) setState(() => _date = picked);
  }

  /// This month's spend for the selected category plus the typed amount,
  /// against its configured ceiling — null when no ceiling applies (income,
  /// no budget for the category, or a date outside the current month).
  ///
  /// Editing subtracts the old amount first, so re-saving an existing
  /// transaction is measured against what it would newly consume.
  ({double limit, double after})? _budgetForecast() {
    if (_isIncome) return null;
    final status = ref.read(budgetStatusProvider)[_category];
    if (status == null || !status.limit.isFinite) return null;
    final jNow = Jalali.now();
    final jDate = Jalali.fromDateTime(_date);
    if (jDate.year != jNow.year || jDate.month != jNow.month) return null;
    var spent = status.spent;
    final old = widget.existingExpense;
    if (old != null && !old.isIncome && old.category == _category) {
      final jo = Jalali.fromDateTime(old.date);
      if (jo.year == jNow.year && jo.month == jNow.month) spent -= old.amount;
    }
    return (
      limit: status.limit,
      after: spent + NumberFormat.parse(_amountCtrl.text)
    );
  }

  /// The next cycle an edited recurring row still owes.
  ///
  /// WHY this is not `existing.nextDueDate ?? _date`: a row that was NOT
  /// recurring but is being made recurring had no next-due date, so it took
  /// today — and the provider materializes every source whose due date is
  /// today or earlier, i.e. the reader's edit produced a duplicate of itself
  /// on the next launch. Same trap when the date moves past the stored cycle
  /// or the pattern changes: the stored date no longer follows from the row,
  /// so it is recomputed from the row's own date.
  DateTime? _nextDueFor({
    required DateTime? kept,
    required bool wasRecurring,
  }) {
    final type = _recurring;
    if (type == null || !ExpenseRecurrence.isSupported(type)) return null;
    final typeChanged =
        widget.existingExpense?.recurringType != type;
    if (wasRecurring &&
        !typeChanged &&
        kept != null &&
        kept.isAfter(_date)) {
      return kept;
    }
    return ExpenseRecurrence.next(_date, type);
  }

  /// Inline budget line under the category picker: what this transaction
  /// leaves of the ceiling, or how far it crosses it.
  Widget? _budgetNote(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final forecast = _budgetForecast();
    if (forecast == null) return null;
    final over = forecast.after > forecast.limit;
    return Text(
      over
          ? 'با این مبلغ، سقف بودجهٔ ماهانهٔ «$_category» ${NumberFormat.formatPlain(forecast.after - forecast.limit)} ${widget.unit} رد می‌شود'
          : 'سقف ماهانهٔ «$_category» ${NumberFormat.formatPlain(forecast.limit)} — با این تراکنش ${NumberFormat.formatPlain(forecast.after)} ${widget.unit} مصرف می‌شود',
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, 11),
        fontWeight: over ? FontWeight.w700 : FontWeight.w500,
        color: over ? expenseColor : t.textMuted,
      ),
    );
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final amount = NumberFormat.parse(_amountCtrl.text);
    if (title.isEmpty || amount <= 0) {
      // Was a silent `return`: the save button appeared to do nothing. Tell the
      // user which field is the problem — inside the sheet, where it is visible.
      final msg = title.isEmpty && amount <= 0
          ? 'عنوان و مبلغ را وارد کنید.'
          : title.isEmpty
              ? 'عنوان تراکنش را وارد کنید.'
              : 'مبلغ باید بزرگ‌تر از صفر باشد.';
      setState(() => _formError = msg);
      return;
    }
    if (_formError != null) setState(() => _formError = null);
    final forecast = _budgetForecast();
    if (_isEditing) {
      widget.ref.read(expenseListProvider.notifier).updateExpense(
            widget.existingExpense!.copyWith(
              title: title,
              amount: amount,
              isIncome: _isIncome,
              category: _category,
              date: _date,
              note: _noteCtrl.text.trim(),
              isRecurring: _recurring != null,
              recurringType: _recurring,
              nextDueDate: _nextDueFor(
                kept: widget.existingExpense!.nextDueDate,
                wasRecurring: widget.existingExpense!.isRecurring,
              ),
            ),
          );
    } else {
      widget.ref.read(expenseListProvider.notifier).addExpense(
            title: title,
            amount: amount,
            isIncome: _isIncome,
            category: _category,
            date: _date,
            note: _noteCtrl.text.trim(),
            isRecurring: _recurring != null,
            recurringType: _recurring,
          );
    }
    // The inline hint is gone the moment the sheet closes, so the crossing
    // gets one last toast on the list screen behind it.
    if (forecast != null && forecast.after > forecast.limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'بودجهٔ ماهانهٔ «$_category» رد شد — ${NumberFormat.formatPlain(forecast.after - forecast.limit)} ${widget.unit} بیش از سقف.',
          ),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final j = Jalali.fromDateTime(_date);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXLarge)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isEditing ? 'ویرایش تراکنش' : 'تراکنش جدید',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 17),
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildTypeToggle(),
              const SizedBox(height: 14),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'عنوان',
                  prefixIcon: const Icon(Icons.title, size: 20),
                  filled: true,
                  fillColor:
                      isDark ? t.surfaceAlt : Colors.white,
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_formError != null) setState(() => _formError = null);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountCtrl,
                decoration: InputDecoration(
                  labelText: 'مبلغ',
                  prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                  suffixText: widget.unit,
                  filled: true,
                  fillColor:
                      isDark ? t.surfaceAlt : Colors.white,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: const [LatinGroupingFormatter()],
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _formError = null),
              ),
              const SizedBox(height: 14),
              _buildCategoryField(context),
              if (_budgetNote(context) != null) ...[
                const SizedBox(height: 8),
                _budgetNote(context)!,
              ],
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color:
                        isDark ? t.surfaceAlt : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined,
                          size: 20, color: t.textMuted),
                      const SizedBox(width: 10),
                      // Expanded instead of a bare Text + Spacer: the label and
                      // the date together are wider than the sheet at 320 dp
                      // with the text scaled up.
                      Expanded(
                        child: Text(
                          'تاریخ تراکنش',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 14)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        jalaliYmdShort(j),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          color:
                              dsContentColor(context, expensesAccent),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_calendar_outlined,
                          size: 17, color: t.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildRecurrenceRow(context),
              const SizedBox(height: 14),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: 'توضیحات (اختیاری)',
                  prefixIcon: const Icon(Icons.notes, size: 20),
                  filled: true,
                  fillColor:
                      isDark ? t.surfaceAlt : Colors.white,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              if (_formError != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: expenseColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formError!,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: expenseColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.textSecondary,
                        side: BorderSide(color: t.outline),
                      ),
                      child: Text('انصراف',
                          style: TextStyle(fontFamily: AppTheme.fontFamily)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text('ذخیره',
                          style: TextStyle(fontFamily: AppTheme.fontFamily)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isIncome ? incomeColor : expensesAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecurrenceRow(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.repeat, size: 20, color: expensesAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _recurrenceChip('بدون تکرار', null),
              _recurrenceChip('روزانه', ExpenseRecurrence.daily),
              _recurrenceChip('هفتگی', ExpenseRecurrence.weekly),
              _recurrenceChip('ماهانه', ExpenseRecurrence.monthly),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recurrenceChip(String label, String? value) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _recurring == value;
    return InkWell(
      onTap: () => setState(() => _recurring = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? expensesAccent
              : (isDark ? t.surfaceAlt : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? expensesAccent : t.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : t.textSecondary,
          ),
        ),
      ),
    );
  }

  /// The category field.
  ///
  /// The chips themselves live in [ExpenseCategoryPicker], which owns the
  /// vocabulary — including the ability to add and remove the user's own
  /// categories. This method only wires the selection into the dialog's state, so
  /// the dialog keeps answering one question: what this transaction is.
  Widget _buildCategoryField(BuildContext context) {
    return ExpenseCategoryPicker(
      value: _category,
      onChanged: (c) => setState(() => _category = c),
    );
  }

  Widget _buildTypeToggle() {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isIncome = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: !_isIncome
                    ? expenseColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_isIncome ? expenseColor : t.outline,
                  width: !_isIncome ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_downward,
                      size: 16,
                      color: !_isIncome
                          ? expenseColor
                          : t.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'هزینه',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w700,
                      color: !_isIncome
                          ? expenseColor
                          : t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isIncome = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isIncome
                    ? incomeColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isIncome ? incomeColor : t.outline,
                  width: _isIncome ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_upward,
                      size: 16,
                      color: _isIncome
                          ? incomeColor
                          : t.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'درآمد',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w700,
                      color: _isIncome
                          ? incomeColor
                          : t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
