import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/features/tools/calculator/data/units/local_unit.dart';
import 'package:tawheeed/features/tools/calculator/data/units/unit_converter.dart';
import 'package:tawheeed/features/tools/calculator/data/units/unit_models.dart';
import 'package:tawheeed/features/tools/calculator/data/units/unit_prefs.dart';
import 'package:tawheeed/features/tools/calculator/data/units/unit_providers.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// The «تبدیل واحد» tab of the calculator.
///
/// The keypad below stays the calculator's own: this view exposes
/// [UnitConverterViewState.applyKeypad] so the existing buttons type into the
/// «از» field instead of a second keypad.
class UnitConverterView extends ConsumerStatefulWidget {
  const UnitConverterView({super.key});

  @override
  ConsumerState<UnitConverterView> createState() => UnitConverterViewState();
}

class UnitConverterViewState extends ConsumerState<UnitConverterView> {
  static const _engine = UnitConverterEngine();

  String _categoryId = 'length';
  String _fromId = 'm';
  String _toId = 'cm';
  final TextEditingController _input = TextEditingController();
  bool _persian = false;
  bool _ready = false;
  List<String> _favorites = const [];
  List<ConversionEntry> _history = const [];
  bool _swapping = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final category = await UnitPrefs.lastCategory();
    final persian = await UnitPrefs.persianDigits();
    final favorites = await UnitPrefs.favorites();
    final history = await UnitPrefs.history();
    if (!mounted) return;
    setState(() {
      _persian = persian;
      _favorites = favorites;
      _history = history;
      if (category != null) _categoryId = category;
      _ready = true;
    });
  }

  /// Typed from the calculator keypad: digits, one dot, backspace, clear.
  void applyKeypad(String key) {
    switch (key) {
      case '⌫':
        final text = _input.text;
        if (text.isNotEmpty) {
          _input.text = text.substring(0, text.length - 1);
        }
      case 'C':
        _input.clear();
      case '.':
        if (!_input.text.contains('.')) _input.text = '${_input.text}.';
      case '+/-':
        if (_input.text.startsWith('-')) {
          _input.text = _input.text.substring(1);
        } else if (_input.text.isNotEmpty) {
          _input.text = '-$_input.text';
        }
      case '=':
        _commitHistory();
      default:
        if (RegExp(r'^[0-9۰-۹٠-٩]+$').hasMatch(key)) {
          _input.text = '${_input.text}$key';
        }
    }
    _input.selection = TextSelection.fromPosition(
      TextPosition(offset: _input.text.length),
    );
    setState(() {});
  }

  UnitCategory? _category(UnitsCatalog catalog) =>
      catalog.categoryById(_categoryId);

  List<UnitDef> _units(UnitCategory category, List<LocalUnit> locals) =>
      _engine.unitsOf(category, locals);

  double? _converted(UnitCategory category, List<LocalUnit> locals) {
    final value = _parseInput(_input.text);
    if (value == null) return null;
    return _engine.convert(
      category: category,
      fromId: _fromId,
      toId: _toId,
      value: value,
      localUnits: locals,
    );
  }

  double? _parseInput(String raw) {
    if (raw.trim().isEmpty) return null;
    final text = _normalizeDigits(raw.trim());
    if (text == '-') return null;
    final asDouble = double.tryParse(text);
    return asDouble;
  }

  static String _normalizeDigits(String input) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final p = persian.indexOf(ch);
      if (p >= 0) {
        buffer.write(p);
        continue;
      }
      final a = arabic.indexOf(ch);
      buffer.write(a >= 0 ? a : ch);
    }
    return buffer.toString().replaceAll(',', '').replaceAll('٬', '');
  }

  String _label(UnitDef unit) => unit.label;

  void _selectCategory(UnitCategory category, List<LocalUnit> locals) {
    final units = _units(category, locals);
    setState(() {
      _categoryId = category.id;
      _fromId = units.first.id;
      _toId = units.length > 1 ? units[1].id : units.first.id;
    });
    UnitPrefs.saveLastCategory(category.id);
  }

  Future<void> _commitHistory() async {
    final category = _categoryId;
    final value = _input.text.trim();
    if (value.isEmpty) return;
    final catalog = ref.read(unitsCatalogProvider).value;
    if (catalog == null) return;
    final cat = catalog.categoryById(category);
    if (cat == null) return;
    final result = _converted(cat, ref.read(localUnitsStoreProvider).value ?? []);
    if (result == null) return;
    final entry = ConversionEntry(
      categoryId: category,
      fromId: _fromId,
      toId: _toId,
      input: value,
      output: formatConvertedValue(result, persianDigits: _persian),
    );
    final next = [
      entry,
      ..._history.where((e) =>
          !(e.categoryId == category &&
              e.fromId == _fromId &&
              e.toId == _toId &&
              e.input == value)),
    ].take(25).toList();
    setState(() => _history = next);
    await UnitPrefs.saveHistory(next);
  }

  Future<void> _toggleFavorite() async {
    final key = '$_categoryId|$_fromId>$_toId';
    final next = [..._favorites];
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    setState(() => _favorites = next);
    await UnitPrefs.saveFavorites(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final catalogAsync = ref.watch(unitsCatalogProvider);
    final locals = ref.watch(localUnitsStoreProvider).value ?? const <LocalUnit>[];
    final catalog = catalogAsync.value;

    if (catalog == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final category = _category(catalog);
    if (category == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'جدول واحدها خوانده نشد.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            color: t.textMuted,
          ),
        ),
      );
    }
    final units = _units(category, locals);
    if (_ready && units.isNotEmpty) {
      if (category.unitById(_fromId) == null && !category.isLocal) {
        _fromId = units.first.id;
      }
      if (units.every((u) => u.id != _fromId)) _fromId = units.first.id;
      if (units.every((u) => u.id != _toId)) {
        _toId = units.length > 1 ? units[1].id : units.first.id;
      }
    }
    final result = _converted(category, locals);
    final isFavorite = _favorites.contains('$_categoryId|$_fromId>$_toId');
    final formula = _formula(units);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      children: [
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final cat in catalog.categories)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _CategoryChip(
                    label: cat.label,
                    selected: cat.id == _categoryId,
                    onTap: () => _selectCategory(cat, locals),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            children: [
              _UnitField(
                label: 'از',
                value: _input.text.isEmpty ? '۰' : _input.text,
                unitLabel: _label(units.firstWhere(
                  (u) => u.id == _fromId,
                  orElse: () => units.first,
                )),
                onPickUnit: () => _pickUnit(
                  units,
                  selected: _fromId,
                  onPicked: (id) => setState(() => _fromId = id),
                  category: category,
                  locals: locals,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'جابه‌جایی',
                    onPressed: () {
                      setState(() {
                        final from = _fromId;
                        _fromId = _toId;
                        _toId = from;
                        _swapping = !_swapping;
                      });
                    },
                    icon: AnimatedRotation(
                      turns: _swapping ? .5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(Icons.swap_vert,
                          color: dsContentColor(context, t.primary)),
                    ),
                  ),
                  IconButton(
                    tooltip: isFavorite ? 'حذف از موردعلاقه' : 'افزودن به موردعلاقه',
                    onPressed: _toggleFavorite,
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite ? t.primary : t.textMuted,
                    ),
                  ),
                ],
              ),
              _UnitField(
                label: 'به',
                value: result == null
                    ? '—'
                    : formatConvertedValue(result, persianDigits: _persian),
                unitLabel: _label(units.firstWhere(
                  (u) => u.id == _toId,
                  orElse: () => units.first,
                )),
                onPickUnit: () => _pickUnit(
                  units,
                  selected: _toId,
                  onPicked: (id) => setState(() => _toId = id),
                  category: category,
                  locals: locals,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formula,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        color: t.textMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'کپی نتیجه',
                    onPressed: result == null
                        ? null
                        : () => ShareService.copyText(
                              context,
                              formatConvertedValue(result,
                                  persianDigits: _persian),
                            ),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: _persian ? 'رقم لاتین' : 'رقم فارسی',
                    onPressed: () {
                      setState(() => _persian = !_persian);
                      UnitPrefs.savePersianDigits(_persian);
                    },
                    icon: Icon(
                      _persian ? Icons.numbers : Icons.pin_outlined,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (category.isLocal) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => showLocalUnitsSheet(context, category: category),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.outline, width: .5),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: t.textMuted),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${catalog.localNote} — '
                      '${catalog.note}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 9),
                        color: t.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ),
                  Text(
                    'ویرایش مبنا',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w600,
                      color: dsContentColor(context, t.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_favorites.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionHeader(title: 'موردعلاقه‌ها', accent: t.primary),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final key in _favorites)
                ActionChip(
                  label: Text(
                    _favoriteLabel(key, catalog),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 9),
                    ),
                  ),
                  onPressed: () => _applyFavorite(key, catalog),
                ),
            ],
          ),
        ],
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionHeader(title: 'آخرین تبدیل‌ها', accent: t.primary),
          for (final entry in _history.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.input}  →  ${entry.output}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    entry.categoryId == _categoryId ? '' : entry.categoryId,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 8),
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  String _formula(List<UnitDef> units) {
    final from = units.firstWhere(
      (u) => u.id == _fromId,
      orElse: () => units.first,
    );
    final to = units.firstWhere(
      (u) => u.id == _toId,
      orElse: () => units.first,
    );
    final one = _engine.convert(
      category: _category(ref.read(unitsCatalogProvider).value!)!,
      fromId: from.id,
      toId: to.id,
      value: 1,
      localUnits: ref.read(localUnitsStoreProvider).value ?? const [],
    );
    if (one == null) return '';
    return '۱ ${from.label} = '
        '${formatConvertedValue(one, persianDigits: _persian)} ${to.label}';
  }

  String _favoriteLabel(String key, UnitsCatalog catalog) {
    final parts = key.split('|');
    if (parts.length != 2) return key;
    final category = catalog.categoryById(parts[0]);
    final ids = parts[1].split('>');
    if (category == null || ids.length != 2) return key;
    final from = category.unitById(ids[0]);
    final to = category.unitById(ids[1]);
    if (from == null || to == null) return key;
    return '${from.label} ← ${to.label}';
  }

  void _applyFavorite(String key, UnitsCatalog catalog) {
    final parts = key.split('|');
    if (parts.length != 2) return;
    final ids = parts[1].split('>');
    if (ids.length != 2) return;
    setState(() {
      _categoryId = parts[0];
      _fromId = ids[0];
      _toId = ids[1];
    });
    UnitPrefs.saveLastCategory(parts[0]);
  }

  Future<void> _pickUnit(
    List<UnitDef> units, {
    required String selected,
    required ValueChanged<String> onPicked,
    required UnitCategory category,
    required List<LocalUnit> locals,
  }) {
    return showCareSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CareSheetTitle(
            title: category.label,
            subtitle: category.isLocal
                ? 'واحدهای محلی؛ مبنا را خودتان تعیین کرده‌اید.'
                : 'واحد را انتخاب کنید.',
          ),
          for (final unit in units)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                unit.label,
                style: TextStyle(fontFamily: AppTheme.fontFamily),
              ),
              subtitle: unit.verified
                  ? null
                  : Text(
                      'مبنای پیش‌فرض (قابل ویرایش)',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 9),
                      ),
                    ),
              trailing: unit.id == selected
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () {
                onPicked(unit.id);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? t.primarySoft : t.surfaceAlt,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? t.primary : t.outline,
            width: .5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 10),
            fontWeight: selected ? FontWeight.w700 : null,
            color: selected ? dsContentColor(context, t.primary) : t.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _UnitField extends StatelessWidget {
  const _UnitField({
    required this.label,
    required this.value,
    required this.unitLabel,
    required this.onPickUnit,
  });

  final String label;
  final String value;
  final String unitLabel;
  final VoidCallback onPickUnit;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.outline, width: .5),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              color: t.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 17),
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
          ),
          InkWell(
            onTap: onPickUnit,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: t.outline, width: .5),
              ),
              child: Row(
                children: [
                  Text(
                    unitLabel,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      color: t.textSecondary,
                    ),
                  ),
                  Icon(Icons.expand_more, size: 15, color: t.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «ویرایش مبنا» — edit the shipped local bases, add a region's own unit, or
/// reset everything back to the defaults.
Future<void> showLocalUnitsSheet(
  BuildContext context, {
  required UnitCategory category,
}) {
  return showCareSheet<void>(
    context,
    child: _LocalUnitsSheet(category: category),
  );
}

class _LocalUnitsSheet extends ConsumerStatefulWidget {
  const _LocalUnitsSheet({required this.category});

  final UnitCategory category;

  @override
  ConsumerState<_LocalUnitsSheet> createState() => _LocalUnitsSheetState();
}

class _LocalUnitsSheetState extends ConsumerState<_LocalUnitsSheet> {
  final _name = TextEditingController();
  final _factor = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _factor.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    final factor = double.tryParse(_normalize(_factor.text));
    if (name.isEmpty || factor == null || factor <= 0) return;
    setState(() => _busy = true);
    await ref.read(localUnitsStoreProvider.notifier).save(LocalUnit(
          id: 'user_${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          factor: factor,
          baseUnit: widget.category.baseLabel,
          isUserEdited: true,
        ));
    if (!mounted) return;
    _name.clear();
    _factor.clear();
    setState(() => _busy = false);
  }

  static String _normalize(String input) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final p = persian.indexOf(ch);
      buffer.write(p >= 0 ? p : ch);
    }
    return buffer.toString().replaceAll('٫', '.');
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final catalog = ref.watch(unitsCatalogProvider).value;
    final userRows = ref.watch(localUnitsStoreProvider).value ?? const [];
    final defaults = catalog?.categoryById('local')?.units ?? const [];
    final merged = <String, UnitDef>{
      for (final u in defaults) u.id: u,
      for (final u in userRows)
        u.id: UnitDef(id: u.id, label: u.name, factor: u.factor),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareSheetTitle(
          title: 'مبنای واحدهای محلی',
          subtitle: 'مبنا در هر منطقه فرق دارد؛ مقدار درست منطقهٔ خودتان را '
              'وارد کنید. «گرم» مبنای محاسبه است.',
        ),
        for (final unit in merged.values)
          _LocalRow(
            unit: unit,
            baseUnit: widget.category.baseLabel,
            onSave: (factor) async {
              await ref.read(localUnitsStoreProvider.notifier).save(
                    LocalUnit(
                      id: unit.id,
                      name: unit.label,
                      factor: factor,
                      baseUnit: widget.category.baseLabel,
                      isUserEdited: true,
                    ),
                  );
            },
          ),
        const Divider(height: 22),
        Row(
          children: [
            Expanded(
              child: CareField(
                controller: _name,
                label: 'واحد تازه (مثلاً ذرع)',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CareField(
                controller: _factor,
                label: 'مبنا به ${widget.category.baseLabel}',
                keyboardType: TextInputType.number,
                ltr: true,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => ref
                    .read(localUnitsStoreProvider.notifier)
                    .resetToDefaults(),
                child: Text(
                  'بازگردانی به پیش‌فرض',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    color: t.textMuted,
                  ),
                ),
              ),
            ),
            Expanded(
              child: CareSheetSubmit(
                label: 'افزودن',
                accent: t.primary,
                busy: _busy,
                onPressed: _add,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocalRow extends StatelessWidget {
  const _LocalRow({
    required this.unit,
    required this.baseUnit,
    required this.onSave,
  });

  final UnitDef unit;
  final String baseUnit;
  final ValueChanged<double> onSave;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                if (!unit.verified)
                  Text(
                    'مبنای پیش‌فرض (قابل ویرایش)',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 8),
                      color: t.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '= ${unit.factor} $baseUnit',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              color: t.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'ویرایش مبنا',
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: () => _edit(context),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: '${unit.factor}');
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('مبنای ${unit.label}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: baseUnit),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed != null && parsed > 0) Navigator.of(ctx).pop(parsed);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) onSave(value);
  }
}

/// Logs a converter failure without swallowing it silently in a widget.
void logConverterIssue(Object error) {
  AppLogger.warning('UnitConverter', '$error');
}
