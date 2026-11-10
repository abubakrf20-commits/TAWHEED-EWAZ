import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_bulk_price_sheet.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_csv_import_sheet.dart';
import 'package:tawheeed/features/personal2/shop/services/shop_csv.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «کالاها» — searchable list (name/barcode), filter chips, product cards with
/// stock status, and the add/edit sheet. Bulk price change and CSV live on the
/// tools row.
class ShopProductsTab extends ConsumerStatefulWidget {
  const ShopProductsTab({super.key});

  @override
  ConsumerState<ShopProductsTab> createState() => _ShopProductsTabState();
}

enum _ProductFilter { all, lowStock, outOfStock, inactive }

class _ShopProductsTabState extends ConsumerState<ShopProductsTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<ShopProduct> _products = [];
  _ProductFilter _filter = _ProductFilter.all;
  bool _loading = true;
  ShopSettingsRow? _settings;
  Map<int, String> _unitSymbols = const {};

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
    final settingsRow = await dao.settings();
    final products = await dao.products(
      search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      limit: 200,
    );
    final unitSymbols = await dao.unitSymbols();
    if (!mounted) return;
    setState(() {
      _settings = settingsRow;
      _products = products;
      _unitSymbols = unitSymbols;
      _loading = false;
    });
  }

  List<ShopProduct> get _visible {
    final lowDefault = _settings?.lowStockDefault ?? 3;
    switch (_filter) {
      case _ProductFilter.all:
        return _products;
      case _ProductFilter.lowStock:
        return _products
            .where((p) =>
                p.trackStock &&
                p.stockMilliCached > 0 &&
                isLowStock(
                  trackStock: p.trackStock,
                  stockMilli: p.stockMilliCached,
                  minStockMilli: p.minStockMilli,
                  lowStockDefaultUnits: lowDefault,
                ))
            .toList();
      case _ProductFilter.outOfStock:
        return _products
            .where((p) => p.trackStock && p.stockMilliCached <= 0)
            .toList();
      case _ProductFilter.inactive:
        return _products.where((p) => !p.active).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce =
                        Timer(const Duration(milliseconds: 150), _reload);
                  },
                  decoration: InputDecoration(
                    hintText: 'جستجوی نام یا بارکد',
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
                onPressed: () => showProductEditSheet(context, ref),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7C86),
                ),
                icon: const Icon(Icons.add_box_rounded,
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
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ActionChip(
                  avatar: const Icon(Icons.price_change_outlined, size: 14),
                  label: Text(
                    'تغییر قیمت گروهی',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily, fontSize: 11),
                  ),
                  onPressed: _visible.isEmpty
                      ? null
                      : () => showShopBulkPriceSheet(
                            context,
                            ref,
                            products: _visible,
                            roundingStep: _settings?.roundingStep ?? 0,
                            onApplied: _reload,
                          ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ActionChip(
                  avatar: const Icon(Icons.ios_share_rounded, size: 14),
                  label: Text(
                    'خروجی CSV',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily, fontSize: 11),
                  ),
                  onPressed: _exportCsv,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ActionChip(
                  avatar: const Icon(Icons.file_upload_outlined, size: 14),
                  label: Text(
                    'ورود CSV',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily, fontSize: 11),
                  ),
                  onPressed: () async {
                    await ShopCsvImportSheet.show(context, ref);
                    _reload();
                  },
                ),
              ),
              for (final f in _ProductFilter.values)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(
                      switch (f) {
                        _ProductFilter.all => 'همه',
                        _ProductFilter.lowStock => 'کم‌موجود',
                        _ProductFilter.outOfStock => 'بدون موجودی',
                        _ProductFilter.inactive => 'غیرفعال',
                      },
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily, fontSize: 11),
                    ),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
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
                        'کالایی نیست. با دکمهٔ بالا اضافه کنید.',
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
                          _productCard(context, _visible[i]),
                    ),
        ),
      ],
    );
  }

  Widget _productCard(BuildContext context, ShopProduct product) {
    final t = TimeThemeKit.of(context).palette;
    final lowDefault = _settings?.lowStockDefault ?? 3;
    final low = isLowStock(
      trackStock: product.trackStock,
      stockMilli: product.stockMilliCached,
      minStockMilli: product.minStockMilli,
      lowStockDefaultUnits: lowDefault,
    );
    final margin = product.buyPriceLast > 0
        ? ((product.sellPrice - product.buyPriceLast) * 100 /
                product.buyPriceLast)
            .round()
        : null;
    final unit = product.unitId == null
        ? ''
        : (_unitSymbols[product.unitId] ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () => _edit(product),
        child: Row(
          children: [
            DuotoneIconTile(
              accent: low ? const Color(0xFFD9922B) : const Color(0xFF0E7C86),
              icon: product.trackStock
                  ? Icons.inventory_2_outlined
                  : Icons.category_outlined,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'خرید ${NumberFormat.groupDigits('${product.buyPriceLast}')} · '
                    'فروش ${NumberFormat.groupDigits('${product.sellPrice}')} '
                    '${margin == null ? '' : '· حاشیه $margin٪'}',
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
                color: !product.trackStock
                    ? t.surfaceAlt
                    : product.stockMilliCached <= 0
                        ? const Color(0x14C9462C)
                        : low
                            ? const Color(0x14D9922B)
                            : const Color(0x142E8B3D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                !product.trackStock
                    ? 'بدون شمارش'
                    : '${qtyMilliToText(product.stockMilliCached)}'
                        '${unit.isEmpty ? '' : ' $unit'}'
                        '${low ? ' · کم' : ''}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: !product.trackStock
                      ? t.textMuted
                      : product.stockMilliCached <= 0
                          ? const Color(0xFFC9462C)
                          : low
                              ? const Color(0xFFD9922B)
                              : const Color(0xFF2E8B3D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(ShopProduct product) async {
    await showProductEditSheet(context, ref, existing: product);
    _reload();
  }

  /// CSV export runs the (cheap) string build directly — the data is already
  /// loaded; the IMPORT is the isolate-bound path.
  Future<void> _exportCsv() async {
    final csv = ShopCsv.exportProducts(_products);
    await ShareService.shareText(csv, subject: 'کالاهای مغازه');
  }
}

/// The add/edit product sheet (also opened from the POS's «کالای جدید»).
Future<void> showProductEditSheet(
  BuildContext context,
  WidgetRef ref, {
  ShopProduct? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final sellCtrl =
      TextEditingController(text: existing?.sellPrice.toString() ?? '');
  final buyCtrl =
      TextEditingController(text: existing?.buyPriceLast.toString() ?? '');
  final barcodeCtrl = TextEditingController();
  final minStockCtrl = TextEditingController(
      text: existing?.minStockMilli == null
          ? ''
          : (existing!.minStockMilli! ~/ 1000).toString());
  final openingCtrl = TextEditingController();
  final openingCostCtrl = TextEditingController();
  final t = TimeThemeKit.of(context).palette;
  final dao = ref.read(shopDaoProvider);
  var trackStock = existing?.trackStock ?? true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.elevated,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'نام کالا', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: buyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'قیمت خرید',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: sellCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'قیمت فروش',
                            border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: barcodeCtrl,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'بارکد (اختیاری)',
                    helperText: 'با اسکنر سخت‌افزاری هم همین‌جا تایپ می‌شود',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minStockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'حد هشدار موجودی',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SwitchListTile.adaptive(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: const Color(0xFF0E7C86),
                        title: Text(
                          'شمارش موجودی',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                          ),
                        ),
                        value: trackStock,
                        onChanged: (v) => setSheetState(() => trackStock = v),
                      ),
                    ),
                  ],
                ),
                if (existing == null && trackStock) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: openingCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'موجودی افتتاحیه',
                              border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: openingCostCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'بهای تمام‌شده',
                              border: OutlineInputBorder()),
                        ),
                      ),
                    ],
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
                        'prd_${DateTime.now().microsecondsSinceEpoch}';
                    final opening =
                        int.tryParse(openingCtrl.text.trim()) ?? 0;
                    final openingCost =
                        int.tryParse(openingCostCtrl.text.trim()) ?? 0;
                    final minUnits = int.tryParse(minStockCtrl.text.trim());
                    final ok = await dao.saveProduct(
                      id: id,
                      name: name,
                      normalizedName: name,
                      sellPrice:
                          int.tryParse(sellCtrl.text.trim()) ?? 0,
                      buyPrice: int.tryParse(buyCtrl.text.trim()) ?? 0,
                      minStockMilli:
                          minUnits == null ? null : minUnits * 1000,
                      trackStock: trackStock,
                      active: true,
                      openingStockMilli: opening,
                      openingCost: openingCost,
                      barcodes:
                          barcodeCtrl.text.trim().isEmpty
                              ? const []
                              : [barcodeCtrl.text.trim()],
                    );
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('ذخیره کالا ممکن نشد (بارکد تکراری؟)',
                            style:
                                TextStyle(fontFamily: AppTheme.fontFamily)),
                      ));
                    }
                  },
                  child: Text(existing == null ? 'افزودن کالا' : 'ذخیره'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
