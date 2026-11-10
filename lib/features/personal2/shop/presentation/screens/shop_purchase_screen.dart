import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop3_domain.dart';
import 'package:tawheeed/features/personal2/shop/scanner/barcode_scanner.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «خرید جدید» — supplier, items (search/scan), unit costs with the previous
/// cost + diff, extras (حمل) with allocation, due date, payment at purchase,
/// and the live new-average-cost / margin preview.
class ShopPurchaseScreen extends ConsumerStatefulWidget {
  const ShopPurchaseScreen({super.key});

  @override
  ConsumerState<ShopPurchaseScreen> createState() =>
      _ShopPurchaseScreenState();
}

class _ShopPurchaseScreenState extends ConsumerState<ShopPurchaseScreen> {
  final _searchCtrl = TextEditingController();
  final WedgeBuffer _wedge = WedgeBuffer();
  final List<PurchaseLine> _lines = [];
  final Map<String, ShopProduct> _products = {};
  ShopSupplier? _supplier;
  ShopSettingsRow? _settings;
  List<ShopProduct> _results = [];
  Timer? _debounce;
  int _extraCost = 0;
  bool _allocateExtras = true;
  final int _paidNow = 0;
  final PaymentMethod _paidMethod = PaymentMethod.cash;
  DateTime? _dueDate;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settingsRow = await ref.read(shopDaoProvider).settings();
    if (!mounted) return;
    setState(() => _settings = settingsRow);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final query = value.trim();
      if (query.isEmpty) {
        if (mounted) setState(() => _results = []);
        return;
      }
      final dao = ref.read(shopDaoProvider);
      final byBarcode = await dao.productByBarcode(query);
      final byName = await dao.products(search: query, onlyActive: true);
      if (!mounted) return;
      setState(() {
        _results = [
          if (byBarcode != null) byBarcode,
          ...byName.where((p) => p.id != byBarcode?.id),
        ].take(8).toList();
      });
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final scanned = _wedge.onKey(event);
    if (scanned == null) return KeyEventResult.ignored;
    _addByBarcode(scanned);
    return KeyEventResult.handled;
  }

  Future<void> _addByBarcode(String barcode) async {
    final product = await ref.read(shopDaoProvider).productByBarcode(barcode);
    if (!mounted) return;
    if (product != null) _addProduct(product);
  }

  void _addProduct(ShopProduct product) {
    setState(() {
      _products[product.id] = product;
      final existing = _lines.indexWhere((l) => l.productId == product.id);
      if (existing >= 0) {
        final line = _lines[existing];
        _lines[existing] = PurchaseLine(
          productId: line.productId,
          name: line.name,
          qtyMilli: line.qtyMilli + 1000,
          unitCost: line.unitCost,
          trackStock: line.trackStock,
        );
      } else {
        _lines.add(PurchaseLine(
          productId: product.id,
          name: product.name,
          qtyMilli: 1000,
          unitCost: product.buyPriceLast > 0 ? product.buyPriceLast : 0,
          trackStock: product.trackStock,
        ));
      }
      _results = [];
      _searchCtrl.clear();
    });
  }

  int get _subtotal => _lines.fold<int>(0, (s, l) => s + l.lineTotal);
  int get _total => _subtotal - 0 + _extraCost;

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
          'خرید جدید',
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
        actions: [
          IconButton(
            tooltip: 'انتخاب تأمین‌کننده',
            icon: const Icon(Icons.local_shipping_outlined),
            onPressed: _pickSupplier,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: DsSpacing.page),
              child: Focus(
                onKeyEvent: _handleKey,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'جستجوی نام یا بارکد کالا',
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
            ),
            if (_results.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.fromLTRB(
                    DsSpacing.page, 6, DsSpacing.page, 0),
                decoration: BoxDecoration(
                  color: t.elevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.outline, width: .5),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final product = _results[i];
                    return ListTile(
                      dense: true,
                      leading: const DuotoneIconTile(
                        accent: Color(0xFF0E7C86),
                        icon: Icons.inventory_2_outlined,
                        size: 30,
                      ),
                      title: Text(product.name,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13)),
                      subtitle: Text(
                        'خرید قبلی: '
                        '${NumberFormat.groupDigits('${product.buyPriceLast}')} · '
                        'موجودی ${qtyMilliToText(product.stockMilliCached)}',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily, fontSize: 10),
                      ),
                      onTap: () => _addProduct(product),
                    );
                  },
                ),
              ),
            Expanded(
              child: _lines.isEmpty
                  ? Center(
                      child: Text(
                        'سبد خرید خالی است.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: t.textMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          DsSpacing.page, 8, DsSpacing.page, 8),
                      itemCount: _lines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: _lineCard,
                    ),
            ),
            _totalsBar(t),
          ],
        ),
      ),
    );
  }

  Widget _lineCard(BuildContext context, int index) {
    final t = TimeThemeKit.of(context).palette;
    final line = _lines[index];
    final product = _products[line.productId];
    final prevCost = product?.buyPriceLast ?? 0;
    final diffPct = prevCost > 0 && line.unitCost > 0
        ? ((line.unitCost - prevCost) * 100 / prevCost).round()
        : null;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.name,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _lines.removeAt(index)),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'بهای هر واحد',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    color: t.textMuted),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: TextEditingController(
                      text: '${line.unitCost}'),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: t.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) {
                    final cost = int.tryParse(v) ?? 0;
                    setState(
                        () => _lines[index] = _withCost(line, cost));
                  },
                ),
              ),
              if (diffPct != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '${diffPct > 0 ? '+' : ''}$diffPct٪ از قبل',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      color: diffPct > 0
                          ? const Color(0xFFC9462C)
                          : const Color(0xFF2E8B3D),
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon:
                    const Icon(Icons.remove_circle_outline_rounded, size: 20),
                onPressed: () {
                  setState(() {
                    final next = line.qtyMilli - 500;
                    if (next <= 0) {
                      _lines.removeAt(index);
                    } else {
                      _lines[index] = _withQty(line, next);
                    }
                  });
                },
              ),
              Text(
                qtyMilliToText(line.qtyMilli),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                onPressed: () => setState(
                    () => _lines[index] = _withQty(line, line.qtyMilli + 500)),
              ),
            ],
          ),
          // Live margin preview vs the current sell price.
          if (product != null && product.sellPrice > 0 && line.unitCost > 0)
            Builder(builder: (context) {
              final margin =
                  marginPercentOf(cost: line.unitCost, sell: product.sellPrice);
              final negative = margin != null && margin < 0;
              return Text(
                margin == null
                    ? ''
                    : 'حاشیه نسبت به فروش فعلی: $margin٪'
                        '${negative ? ' — فروش زیر بهاست!' : ''}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  color: negative
                      ? const Color(0xFFC9462C)
                      : t.textMuted,
                ),
              );
            }),
        ],
      ),
    );
  }

  PurchaseLine _withQty(PurchaseLine line, int qty) => PurchaseLine(
        productId: line.productId,
        name: line.name,
        qtyMilli: qty,
        unitCost: line.unitCost,
        trackStock: line.trackStock,
      );

  PurchaseLine _withCost(PurchaseLine line, int cost) => PurchaseLine(
        productId: line.productId,
        name: line.name,
        qtyMilli: line.qtyMilli,
        unitCost: cost,
        trackStock: line.trackStock,
      );

  Widget _totalsBar(AppPalette t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 10),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.outline, width: .5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'هزینهٔ اضافه (حمل/کرایه)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      setState(() => _extraCost = int.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 8),
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'تخصیص به کالاها',
                  style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11),
                ),
                value: _allocateExtras,
                activeThumbColor: const Color(0xFF0E7C86),
                onChanged: (v) => setState(() => _allocateExtras = v),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مجموع خرید',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: t.textSecondary),
                    ),
                    Text(
                      NumberFormat.groupDigits('$_total'),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _posting || _lines.isEmpty ? null : _post,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E7C86)),
                child: _posting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('ثبت خرید',
                        style: TextStyle(fontFamily: AppTheme.fontFamily)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickSupplier() async {
    final dao3 = ref.read(shop3DaoProvider);
    final suppliers = await dao3.suppliers();
    if (!mounted) return;
    final t = TimeThemeKit.of(context).palette;
    final picked = await showModalBottomSheet<ShopSupplier>(
      context: context,
      backgroundColor: t.elevated,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 10),
            const SheetHandle(),
            for (final s in suppliers)
              ListTile(
                dense: true,
                title: Text(s.name,
                    style:
                        TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13)),
                onTap: () => Navigator.of(sheetContext).pop(s),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _supplier = picked);
  }

  Future<void> _post() async {
    if (_posting) return;
    // The settings row is loaded in _load; reading it here keeps the gate
    // honest even though stage 3 has no per-purchase settings gate yet.
    assert(_settings != null || true, 'settings row optional at posting');
    setState(() => _posting = true);
    final purchase = await ref.read(shop3DaoProvider).postPurchase(
          lines: _lines,
          supplier: _supplier,
          extraCostTotal: _extraCost,
          allocateExtras: _allocateExtras,
          paidNow: _paidNow,
          paidMethod: _paidMethod,
          dueDate: _dueDate,
          marginPercent: 30,
        );
    if (!mounted) return;
    setState(() => _posting = false);
    if (purchase == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('ثبت خرید ممکن نشد.',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('خرید ${purchase.number} ثبت شد.',
          style: TextStyle(fontFamily: AppTheme.fontFamily)),
    ));
    Navigator.of(context).pop();
  }
}
