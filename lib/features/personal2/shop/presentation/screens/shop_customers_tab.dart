import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_customer_detail_screen.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «مشتریان» — list with balance chips, filters, sort and search; the add/edit
/// sheet carries the opening balance.
class ShopCustomersTab extends ConsumerStatefulWidget {
  const ShopCustomersTab({super.key});

  @override
  ConsumerState<ShopCustomersTab> createState() => _ShopCustomersTabState();
}

enum _CustomerFilter { all, debtors, creditors, overdue }
enum _CustomerSort { balance, activity, overdue }

class _ShopCustomersTabState extends ConsumerState<ShopCustomersTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<ShopCustomer> _customers = [];
  Map<String, int> _balances = {};
  Map<String, int> _oldestDebtDays = {};
  _CustomerFilter _filter = _CustomerFilter.all;
  final _CustomerSort _sort = _CustomerSort.balance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final dao = ref.read(shopDaoProvider);
    final customers =
        await dao.customers(onlyActive: true, search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text);
    final balances = <String, int>{};
    final ages = <String, int>{};
    final now = DateTime.now();
    for (final c in customers) {
      balances[c.id] = await dao.customerBalance(c.id);
      final open = await dao.openInvoices(c.id);
      final age = oldestDebtDays(openInvoices: open, now: now);
      if (age != null) ages[c.id] = age;
    }
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _balances = balances;
      _oldestDebtDays = ages;
      _loading = false;
    });
    _applyFilter();
  }

  List<ShopCustomer> _visible = const [];

  void _applyFilter() {
    var list = [..._customers];
    switch (_filter) {
      case _CustomerFilter.all:
        break;
      case _CustomerFilter.debtors:
        list = list.where((c) => (_balances[c.id] ?? 0) > 0).toList();
      case _CustomerFilter.creditors:
        list = list.where((c) => (_balances[c.id] ?? 0) < 0).toList();
      case _CustomerFilter.overdue:
        list = list.where((c) => (_oldestDebtDays[c.id] ?? 0) > 30).toList();
    }
    int balanceOf(ShopCustomer c) => (_balances[c.id] ?? 0).abs();
    switch (_sort) {
      case _CustomerSort.balance:
        list.sort((a, b) => balanceOf(b).compareTo(balanceOf(a)));
      case _CustomerSort.overdue:
        list.sort((a, b) =>
            (_oldestDebtDays[b.id] ?? 0).compareTo(_oldestDebtDays[a.id] ?? 0));
      case _CustomerSort.activity:
        // Name order is the honest fallback until Stage 3 stores an
        // activity stamp per customer; balance ordering is the default.
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    setState(() => _visible = list);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 150), _reload);
                  },
                  decoration: InputDecoration(
                    hintText: 'جستجوی مشتری',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: t.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _editCustomer(context),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7C86),
                ),
                icon: const Icon(Icons.person_add_alt_rounded,
                    size: 20, color: Colors.white),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.page, vertical: 6),
            children: [
              for (final f in _CustomerFilter.values)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(
                      switch (f) {
                        _CustomerFilter.all => 'همه',
                        _CustomerFilter.debtors => 'بدهکاران',
                        _CustomerFilter.creditors => 'بستانکاران',
                        _CustomerFilter.overdue => 'دیرکرد',
                      },
                      style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11),
                    ),
                    selected: _filter == f,
                    onSelected: (_) {
                      setState(() => _filter = f);
                      _applyFilter();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _visible.isEmpty
                  ? Center(
                      child: Text(
                        'مشتری‌ای نیست. با دکمهٔ بالا اضافه کنید.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: t.textMuted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          DsSpacing.page, 0, DsSpacing.page, 110),
                      itemCount: _visible.length,
                      itemBuilder: (context, i) =>
                          _row(context, _visible[i]),
                    ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, ShopCustomer customer) {
    final t = TimeThemeKit.of(context).palette;
    final balance = _balances[customer.id] ?? 0;
    final age = _oldestDebtDays[customer.id];
    final isDebtor = balance > 0;
    final isCreditor = balance < 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () => _openDetail(customer),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF0E7C86),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                customer.name.characters.first,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  if (customer.phone.isNotEmpty)
                    Text(
                      customer.phone,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                        color: t.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (age != null && age > 30)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x14C9462C),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$age روز',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 9,
                      color: const Color(0xFFC9462C),
                    ),
                  ),
                ),
              ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDebtor
                    ? const Color(0x142E8B3D)
                    : isCreditor
                        ? const Color(0x142F6FB5)
                        : t.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                balance == 0
                    ? 'تسویه'
                    : isDebtor
                        ? 'بدهکار ${NumberFormat.groupDigits('$balance')}'
                        : 'بستانکار ${NumberFormat.groupDigits('${-balance}')}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDebtor
                      ? const Color(0xFF2E8B3D)
                      : isCreditor
                          ? const Color(0xFF2F6FB5)
                          : t.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(ShopCustomer customer) {
    // Pushed through the router so back and deep links behave; the detail
    // screen re-reads everything by id.
    ShopCustomerDetailOpen.go(context, customer.id);
  }

  Future<void> _editCustomer(BuildContext context, {ShopCustomer? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    final limitCtrl = TextEditingController(
        text: existing?.creditLimit?.toString() ?? '');
    final openingCtrl = TextEditingController();
    final t = TimeThemeKit.of(context).palette;
    final dao = ref.read(shopDaoProvider);

    await showModalBottomSheet<void>(
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
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'نام', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'تلفن (اختیاری)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'سقف اعتبار (اختیاری)',
                    border: OutlineInputBorder()),
              ),
              if (existing == null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: openingCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ماندهٔ افتتاحیه (اختیاری)',
                    helperText: 'بدهی اولیه؛ منفی یعنی بستانکار',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E7C86)),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final id = existing?.id ??
                      'cus_${DateTime.now().microsecondsSinceEpoch}';
                  await dao.saveCustomer(
                    id: id,
                    name: name,
                    normalizedName: name,
                    phone: phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    note: noteCtrl.text.trim(),
                    creditLimit: int.tryParse(limitCtrl.text.trim()),
                    active: true,
                  );
                  final opening = int.tryParse(openingCtrl.text.trim());
                  if (existing == null && opening != null && opening != 0) {
                    await dao.openingBalance(
                      customerId: id,
                      signedAmount: opening,
                      date: DateTime.now(),
                    );
                  }
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  _reload();
                },
                child: Text(existing == null ? 'افزودن' : 'ذخیره'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Router-independent opener so the tab and the dashboard deep link share one
/// path.
class ShopCustomerDetailOpen {
  ShopCustomerDetailOpen._();

  static void go(BuildContext context, String customerId) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => ShopCustomerDetailScreen(customerId: customerId),
    ));
  }
}
