import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/app_card.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';

/// The expense-category manager: rename, deactivate (archive — a category
/// with history is never deleted), add. Reached from shop settings.
class ExpenseCategoryManagerSheet extends StatefulWidget {
  const ExpenseCategoryManagerSheet({
    super.key,
    required this.dao3,
    required this.onChanged,
  });

  final Shop3Dao dao3;

  /// Called after any change so the caller can reload its pickers.
  final VoidCallback onChanged;

  static Future<void> show(
    BuildContext context, {
    required Shop3Dao dao3,
    required VoidCallback onChanged,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TimeThemeKit.of(context).palette.elevated,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .65,
          child: ExpenseCategoryManagerSheet(dao3: dao3, onChanged: onChanged),
        ),
      ),
    );
  }

  @override
  State<ExpenseCategoryManagerSheet> createState() =>
      _ExpenseCategoryManagerSheetState();
}

class _ExpenseCategoryManagerSheetState
    extends State<ExpenseCategoryManagerSheet> {
  List<({int id, String name, bool active})> _categories = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rows = await widget.dao3.db.customSelect(
      'SELECT id, name, active FROM p2_shop_expense_category '
      'ORDER BY active DESC, sort ASC',
    ).get();
    if (!mounted) return;
    setState(() {
      _categories = [
        for (final r in rows)
          (
            id: r.read<int>('id'),
            name: r.read<String>('name'),
            active: r.read<int>('active') == 1,
          ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      children: [
        const SheetHandle(),
        Row(
          children: [
            Expanded(
              child: Text(
                'دسته‌های هزینه',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.add_rounded), onPressed: _add),
          ],
        ),
        Text(
          'دستهٔ دارای سابقه حذف نمی‌شود؛ غیرفعال می‌شود تا گزارش‌ها سالم بمانند.',
          style: TextStyle(
              fontFamily: AppTheme.fontFamily, fontSize: 10, color: t.textMuted),
        ),
        const SizedBox(height: 8),
        for (final c in _categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: c.name),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: c.active
                            ? t.textPrimary
                            : t.textMuted,
                      ),
                      decoration: const InputDecoration(
                          border: InputBorder.none),
                      onSubmitted: (v) => _rename(c.id, v),
                    ),
                  ),
                  Switch(
                    value: c.active,
                    activeThumbColor: const Color(0xFF0E7C86),
                    onChanged: (v) => _toggle(c.id, v),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _rename(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await widget.dao3.db.customStatement(
      'UPDATE p2_shop_expense_category SET name = ? WHERE id = ?',
      [trimmed, id],
    );
    widget.onChanged();
    _reload();
  }

  Future<void> _toggle(int id, bool active) async {
    await widget.dao3.db.customStatement(
      'UPDATE p2_shop_expense_category SET active = ? WHERE id = ?',
      [active ? 1 : 0, id],
    );
    widget.onChanged();
    _reload();
  }

  Future<void> _add() async {
    final ctrl = TextEditingController();
    final t = TimeThemeKit.of(context).palette;
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'نام دستهٔ تازه', border: OutlineInputBorder()),
                onSubmitted: (_) {
                  final v = ctrl.text.trim();
                  if (v.isNotEmpty) Navigator.of(sheetContext).pop(v);
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E7C86)),
                onPressed: () {
                  final v = ctrl.text.trim();
                  if (v.isNotEmpty) Navigator.of(sheetContext).pop(v);
                },
                child: const Text('افزودن'),
              ),
            ],
          ),
        ),
      ),
    );
    if (name == null || name.isEmpty) return;
    final maxRow = await widget.dao3.db
        .customSelect(
            'SELECT COALESCE(MAX(sort), 0) AS m FROM p2_shop_expense_category')
        .get();
    await widget.dao3.db.customStatement(
      'INSERT INTO p2_shop_expense_category (name, active, sort) '
      'VALUES (?, 1, ?)',
      [name, maxRow.first.read<int>('m') + 1],
    );
    widget.onChanged();
    _reload();
  }
}
