import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    show dsContentColor;
import 'package:tawheeed/features/expenses/domain/expense_categories.dart';
import 'package:tawheeed/features/expenses/presentation/providers/expense_categories_provider.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_common.dart';

/// The category chooser: the vocabulary as chips, plus a way to add and remove
/// the user's own.
///
/// WHY a widget and not the private `Wrap` that used to live in the dialog: the
/// add/remove flow needs state (the inline field, its error, a write in flight),
/// and keeping it inside `ExpenseDialogState` would have made one 600-line file
/// answer two questions. The dialog owns the transaction; this owns the
/// vocabulary.
///
/// A `ConsumerStatefulWidget` rather than taking a `WidgetRef` the way the dialog
/// does, so it can watch the choices itself — a category added here has to appear
/// in the budget dialog and the report without either screen being rebuilt by
/// hand.
class ExpenseCategoryPicker extends ConsumerStatefulWidget {
  const ExpenseCategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// The selected category. May be a name the vocabulary no longer lists (a row
  /// whose category was removed) — it is shown as an extra chip rather than
  /// leaving every chip unselected, which reads as "no category".
  final String value;

  final ValueChanged<String> onChanged;

  @override
  ConsumerState<ExpenseCategoryPicker> createState() =>
      _ExpenseCategoryPickerState();
}

class _ExpenseCategoryPickerState extends ConsumerState<ExpenseCategoryPicker> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  bool _adding = false;
  bool _saving = false;

  /// Why the typed name was refused. Null when nothing is wrong with it.
  ExpenseCategoryRejection? _rejection;
  String? _duplicateOf;

  /// A write that did not land, and what to run if the reader asks again.
  ///
  /// Reported inline rather than through `AppSnackBar`: this runs inside a modal
  /// bottom sheet, and a floating snackbar is placed in the Scaffold *behind* it
  /// — the one message that matters would never be seen. The retry is a stored
  /// callback because the two writes (add, remove) need different ones.
  String? _writeError;
  VoidCallback? _retry;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clearWriteError() {
    if (_writeError == null) return;
    _writeError = null;
    _retry = null;
  }

  void _startAdding() {
    setState(() {
      _adding = true;
      _rejection = null;
      _duplicateOf = null;
      _clearWriteError();
    });
    // After the field exists — requesting focus on a node with no attached
    // editable throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _stopAdding() {
    setState(() {
      _adding = false;
      _rejection = null;
      _duplicateOf = null;
      _clearWriteError();
    });
    _controller.clear();
  }

  /// The message under the field, for a name the rules refused.
  String? get _validationError {
    switch (_rejection) {
      case ExpenseCategoryRejection.empty:
        return 'نام دسته را وارد کنید.';
      case ExpenseCategoryRejection.tooLong:
        return 'نام دسته حداکثر $kMaxExpenseCategoryLength نویسه می‌تواند باشد.';
      case ExpenseCategoryRejection.duplicate:
        return _duplicateOf == null
            ? 'این دسته از قبل وجود دارد.'
            : 'این دسته از قبل وجود دارد؛ «$_duplicateOf» انتخاب شد.';
      case ExpenseCategoryRejection.full:
        return 'بیش از $kMaxCustomExpenseCategories دستهٔ دلخواه نمی‌توانید بسازید.';
      case null:
        return null;
    }
  }

  Future<void> _submit() async {
    final draft = validateNewExpenseCategory(
      _controller.text,
      existing: ref.read(expenseCategoryChoicesProvider),
      customCount: ref.read(expenseCategoryStoreProvider).custom.length,
    );

    if (!draft.ok) {
      setState(() {
        _rejection = draft.rejection;
        _duplicateOf = draft.match;
        _clearWriteError();
      });
      // A duplicate is a correction rather than a refusal: the reader typed a
      // name that already exists, so select the one they meant. The field stays
      // open so the message sits next to the chip it chose.
      final match = draft.match;
      if (match != null) widget.onChanged(match);
      return;
    }

    setState(() {
      _saving = true;
      _rejection = null;
      _duplicateOf = null;
      _clearWriteError();
    });
    // Select it *before* the write. The save button lives further down the same
    // sheet, so a reader who types a name and immediately taps «ذخیره» can reach
    // it while this await is still in flight — and would then record the
    // transaction under the previous category, silently. Selecting first makes
    // the dialog's state agree with what is on screen the whole time; a failed
    // write puts the old selection back.
    final previous = widget.value;
    widget.onChanged(draft.value);
    final ok = await ref
        .read(expenseCategoryStoreProvider.notifier)
        .addCategory(draft.value);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) {
        _writeError = 'دستهٔ «${draft.value}» ذخیره نشد؛ پس از باز کردن دوباره '
            'در فهرست نمی‌ماند.';
        _retry = _submit;
      }
    });
    if (!ok) {
      widget.onChanged(previous);
      return;
    }
    setState(() {
      _adding = false;
      _rejection = null;
      _duplicateOf = null;
    });
    _controller.clear();
  }

  /// Asks, then removes.
  ///
  /// The question is asked here and the work is done by [_remove] so the retry
  /// button can re-run the removal alone — re-opening the confirmation the
  /// reader already answered would be asking twice for one decision.
  Future<void> _confirmRemove(String category) async {
    final usage = ref.read(expenseCategoryUsageProvider)[category] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'حذف دستهٔ «$category»؟',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(ctx, 16),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          usage == 0
              ? 'این دسته در هیچ تراکنشی به کار نرفته و فقط از فهرست انتخاب حذف می‌شود.'
              : '$usage تراکنش این برچسب را دارند. برچسبشان عوض نمی‌شود و در فهرست '
                  'تراکنش‌ها می‌مانند؛ فقط این دسته از فهرست انتخاب حذف می‌شود.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(ctx, 13),
            height: 1.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('انصراف',
                style: TextStyle(fontFamily: AppTheme.fontFamily)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'حذف',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                color: expenseColor,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _remove(category);
  }

  Future<void> _remove(String category) async {
    final ok = await ref
        .read(expenseCategoryStoreProvider.notifier)
        .removeCategory(category);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _writeError = 'دستهٔ «$category» حذف نشد و هنوز در فهرست است.';
        _retry = () => _remove(category);
      });
      return;
    }
    setState(_clearWriteError);
    // Selecting the default when the removed category was the current choice
    // keeps the field from pointing at a name that is no longer offered.
    if (widget.value == category) widget.onChanged(kDefaultExpenseCategory);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final choices = ref.watch(expenseCategoryChoicesProvider);
    final customKeys = ref.watch(customExpenseCategoryKeysProvider);

    final chips = widget.value.isNotEmpty && !choices.contains(widget.value)
        ? [...choices, widget.value]
        : choices;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: isDark ? t.surfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category_outlined, size: 20, color: t.textMuted),
              const SizedBox(width: 10),
              // Expanded + Flexible: the count is decorative but its width is
              // not, and at 320 dp with the text scale at 1.3 the two labels plus
              // the icon were wider than the field. The title gives way first.
              Expanded(
                child: Text(
                  'دسته‌بندی',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: AppTheme.scaledFontSize(context, 14)),
                ),
              ),
              if (!_adding && customKeys.isNotEmpty)
                Flexible(
                  child: Text(
                    '${customKeys.length} دستهٔ دلخواه',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10.5),
                      color: t.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in chips)
                _CategoryChip(
                  key: ValueKey('expense_category_$c'),
                  label: c,
                  selected: widget.value == c,
                  onTap: () => widget.onChanged(c),
                  onRemove: isRemovableExpenseCategory(c, customKeys)
                      ? () => _confirmRemove(c)
                      : null,
                ),
              if (!_adding) _addChip(context),
            ],
          ),
          if (_adding) ...[
            const SizedBox(height: 10),
            _addField(context),
          ],
          if (_writeError != null) ...[
            const SizedBox(height: 8),
            _inlineError(context, _writeError!),
          ],
        ],
      ),
    );
  }

  Widget _addChip(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return GestureDetector(
      key: const ValueKey('expense_category_add'),
      onTap: _startAdding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add,
                size: 14, color: dsContentColor(context, expensesAccent)),
            const SizedBox(width: 4),
            Text(
              'دستهٔ جدید',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w600,
                color: dsContentColor(context, expensesAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addField(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('expense_category_field'),
            controller: _controller,
            focusNode: _focus,
            textInputAction: TextInputAction.done,
            // No `maxLength`: a hard cap stops the keyboard without saying why,
            // and the rules already name the limit in a sentence the reader can
            // act on.
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              // Clear a stale complaint the moment the reader edits — an error
              // that outlives its cause teaches them to ignore errors.
              if (_rejection != null) {
                setState(() {
                  _rejection = null;
                  _duplicateOf = null;
                });
              }
            },
            decoration: InputDecoration(
              isDense: true,
              labelText: 'نام دستهٔ جدید',
              labelStyle: TextStyle(fontFamily: AppTheme.fontFamily),
              errorText: _validationError,
              errorMaxLines: 2,
              filled: true,
              fillColor: t.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          key: const ValueKey('expense_category_submit'),
          onPressed: _saving ? null : _submit,
          tooltip: 'افزودن',
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle, size: 22),
          color: expensesAccent,
        ),
        IconButton(
          key: const ValueKey('expense_category_cancel'),
          onPressed: _saving ? null : _stopAdding,
          tooltip: 'انصراف',
          icon: const Icon(Icons.close, size: 20),
          color: t.textMuted,
        ),
      ],
    );
  }

  Widget _inlineError(BuildContext context, String message) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              height: 1.6,
              color: expenseColor,
            ),
          ),
        ),
        if (_retry != null)
          TextButton(
            key: const ValueKey('expense_category_retry'),
            onPressed: _retry,
            child: Text(
              'تلاش دوباره',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11.5),
                fontWeight: FontWeight.w700,
                color: expenseColor,
              ),
            ),
          ),
      ],
    );
  }
}

/// One category chip.
///
/// The remove affordance is drawn on every custom chip rather than only on the
/// selected one. Selecting first would be the safer-looking rule, but selecting a
/// chip *is* a choice — it changes the transaction's category through
/// `onChanged` — so revealing the × that way would re-categorise the row as a
/// side effect of intending to delete a label. The × is a separate target with
/// its own hit area instead, and the confirmation dialog is the guard.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.fromLTRB(12, 7, onRemove != null ? 6 : 12, 7),
        decoration: BoxDecoration(
          color: selected
              ? expensesAccent.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? expensesAccent : t.outline,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flexible with two lines: a name at the length limit, or one a
            // restored backup carried in from a build with a larger limit, must
            // never be wider than the row it sits in. Wrapping keeps the whole
            // name readable; ellipsis on a category would hide the very word the
            // reader is trying to recognise.
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12.5),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? dsContentColor(context, expensesAccent)
                      : t.textSecondary,
                ),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: dsContentColor(context, expensesAccent),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
