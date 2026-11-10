import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop3_domain.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «تأمین‌کنندگان» — list with «بدهی ما» chips, add/edit, and the pay sheet
/// (FIFO via the shared allocator).
class ShopSuppliersScreen extends ConsumerStatefulWidget {
  const ShopSuppliersScreen({super.key});

  @override
  ConsumerState<ShopSuppliersScreen> createState() =>
      _ShopSuppliersScreenState();
}

class _ShopSuppliersScreenState extends ConsumerState<ShopSuppliersScreen> {
  List<ShopSupplier> _suppliers = [];
  Map<String, int> _balances = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final dao3 = ref.read(shop3DaoProvider);
    final suppliers = await dao3.suppliers();
    final balances = <String, int>{};
    for (final s in suppliers) {
      balances[s.id] = await dao3.supplierBalance(s.id);
    }
    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _balances = balances;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: t.primary,
        iconTheme: IconThemeData(color: t.primary),
        title: Text(
          'تأمین‌کنندگان',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            color: t.primary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        backgroundColor: const Color(0xFF0E7C86),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('تأمین‌کننده',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _suppliers.isEmpty
                ? Center(
                    child: Text(
                      'تأمین‌کننده‌ای ثبت نشده.',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: t.textMuted),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 12, DsSpacing.page, 90),
                    children: [
                      for (final s in _suppliers) _row(context, s),
                    ],
                  ),
      ),
    );
  }

  Widget _row(BuildContext context, ShopSupplier s) {
    final t = TimeThemeKit.of(context).palette;
    final balance = _balances[s.id] ?? 0;
    final weOwe = balance > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () => _pay(s),
        child: Row(
          children: [
            const DuotoneIconTile(
              accent: Color(0xFF0E7C86),
              icon: Icons.local_shipping_outlined,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  if (s.phone.isNotEmpty)
                    Text(
                      s.phone,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                        color: t.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: weOwe
                    ? const Color(0x14C9462C)
                    : balance < 0
                        ? const Color(0x142E8B3D)
                        : t.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                balance == 0
                    ? 'تسویه'
                    : weOwe
                        ? 'بدهی ما ${NumberFormat.groupDigits('$balance')}'
                        : 'بستانکار ${NumberFormat.groupDigits('${-balance}')}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: weOwe
                      ? const Color(0xFFC9462C)
                      : balance < 0
                          ? const Color(0xFF2E8B3D)
                          : t.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit({ShopSupplier? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final t = TimeThemeKit.of(context).palette;
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
                    labelText: 'نام تأمین‌کننده', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'تلفن (اختیاری)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E7C86)),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  await ref.read(shop3DaoProvider).saveSupplier(
                        id: existing?.id ??
                            'sup_${DateTime.now().microsecondsSinceEpoch}',
                        name: name,
                        phone: phoneCtrl.text.trim(),
                      );
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

  Future<void> _pay(ShopSupplier s) async {
    final dao3 = ref.read(shop3DaoProvider);
    final open = await dao3.openPurchases(s.id);
    if (!mounted) return;
    final t = TimeThemeKit.of(context).palette;
    final amountCtrl = TextEditingController();
    var method = PaymentMethod.cash;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final amount = int.tryParse(amountCtrl.text) ?? 0;
          final preview = amount <= 0
              ? null
              : allocateSupplierPayment(
                  payment: amount, openPurchases: open);
          return Padding(
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
                  Text(
                    'پرداخت به ${s.name}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'مبلغ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final m in const [
                        (PaymentMethod.cash, 'نقد'),
                        (PaymentMethod.card, 'کارت'),
                        (PaymentMethod.transfer, 'انتقال'),
                        (PaymentMethod.cheque, 'چک'),
                      ])
                        ChoiceChip(
                          label: Text(m.$2),
                          selected: method == m.$1,
                          onSelected: (_) =>
                              setSheetState(() => method = m.$1),
                        ),
                    ],
                  ),
                  if (preview != null && preview.slices.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'تخصیص خودکار (قدیمی‌ترین اول):',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: t.textSecondary,
                      ),
                    ),
                    for (final slice in preview.slices.take(3))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'خرید ${slice.invoiceNumber}: '
                          '${NumberFormat.groupDigits('${slice.amount}')}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0E7C86)),
                    onPressed: amount <= 0
                        ? null
                        : () => Navigator.of(sheetContext).pop(true),
                    child: const Text('ثبت پرداخت'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;
    final amount = int.tryParse(amountCtrl.text) ?? 0;
    await dao3.paySupplier(
      supplierId: s.id,
      amount: amount,
      method: method,
    );
    _reload();
  }
}
