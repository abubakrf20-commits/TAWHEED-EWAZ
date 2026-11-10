import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/presentation/providers/shop_providers.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_receipt_sheet.dart';
import 'package:tawheeed/features/personal2/shop/scanner/barcode_scanner.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «فروش جدید» — the POS.
///
/// The accounting rules live in the pure layer ([evaluateSale]) and the DAO's
/// transaction; this screen only collects intent and shows the evaluation's
/// verdict. Keyboard-wedge scanners feed the search field through
/// [WedgeBuffer]; the search itself is normalized Persian
/// (`normalizeSearchKey`) against the indexed `normalized_name` column.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key, this.invoiceId});

  /// When set, the screen shows a past invoice's receipt instead of the cart.
  final String? invoiceId;

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final WedgeBuffer _wedge = WedgeBuffer();

  final List<CartLine> _cart = [];
  final List<SalePayment> _payments = [];
  ShopCustomer? _customer;
  ShopSettingsRow? _settings;
  int? _customerBalance;

  List<ShopProduct> _results = [];
  List<ShopProduct> _favorites = [];
  Map<int, String> _unitSymbols = const {};
  Timer? _debounce;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchFocus.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dao = ref.read(shopDaoProvider);
    final settingsRow = await dao.settings();
    if (!mounted) return;
    setState(() => _settings = settingsRow);
    await dao.ensureSeeded();
    if (!mounted) return;
    final unitSymbols = await dao.unitSymbols();
    if (!mounted) return;
    setState(() => _unitSymbols = unitSymbols);
    // Favorites: the 12 most recently sold products, falling back to the
    // first products by name when the shop is new.
    final favorites = await dao.db.customSelect(
      'SELECT * FROM p2_shop_product WHERE active = 1 '
      'ORDER BY (last_sold_at IS NULL), last_sold_at DESC, normalized_name '
      'LIMIT 12',
    ).get();
    if (!mounted) return;
    setState(() {
      _favorites = [for (final r in favorites) ShopDao.productFromRow(r)];
    });
  }

  /// The 150 ms debounced search the performance budget requires.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final query = value.trim();
      if (query.isEmpty) {
        if (mounted) setState(() => _results = []);
        return;
      }
      final dao = ref.read(shopDaoProvider);
      // Barcode first (exact, indexed), then the normalized-name prefix.
      final byBarcode = await dao.productByBarcode(query);
      final normalized = normalizeSearchKey(query);
      final byName = await dao.products(search: normalized, onlyActive: true);
      if (!mounted) return;
      setState(() {
        _results = [
          if (byBarcode != null) byBarcode,
          ...byName.where((p) => p.id != byBarcode?.id),
        ].take(8).toList();
      });
    });
  }

  /// Hardware scanner input, wired as a Focus onKeyEvent so the wedge burst
  /// never needs the field to be focused in a special mode.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final scanned = _wedge.onKey(event);
    if (scanned == null) return KeyEventResult.ignored;
    _addByBarcode(scanned);
    return KeyEventResult.handled;
  }

  Future<void> _addByBarcode(String barcode) async {
    final dao = ref.read(shopDaoProvider);
    final product = await dao.productByBarcode(barcode);
    final settingsRow = _settings ?? await dao.settings();
    await scanFeedback(settings: settingsRow, success: product != null);
    if (!mounted) return;
    if (product == null) {
      // Not found: leave the code in the search so the operator can pick a
      // product manually and attach the code from its sheet.
      _searchCtrl.text = barcode;
      return;
    }
    _addProduct(product);
  }

  void _addProduct(ShopProduct product) {
    setState(() {
      final existing = _cart.indexWhere((l) => l.productId == product.id);
      if (existing >= 0) {
        final line = _cart[existing];
        _cart[existing] = CartLine(
          productId: line.productId,
          name: line.name,
          unitName: line.unitName,
          qtyMilli: line.qtyMilli + 1000,
          unitPrice: line.unitPrice,
          discount: line.discount,
          trackStock: line.trackStock,
          avgCost: line.avgCost,
        );
      } else {
        _cart.add(CartLine(
          productId: product.id,
          name: product.name,
          unitName: _unitName(product.unitId),
          qtyMilli: 1000,
          unitPrice: product.sellPrice,
          trackStock: product.trackStock,
          avgCost: product.avgCost,
        ));
      }
      _results = [];
      _searchCtrl.clear();
    });
    _searchFocus.requestFocus();
  }

  String _unitName(int? unitId) =>
      unitId == null ? 'عدد' : (_unitSymbols[unitId] ?? 'عدد');

  SaleEvaluation get _evaluation => evaluateSale(
        lines: _cart,
        payments: _payments,
        roundingStep: _settings?.roundingStep ?? 0,
        creditMode: _settings?.creditLimitMode ?? CreditLimitMode.warn,
        hasCustomer: _customer != null,
        customerBalance: _customerBalance,
        customerCreditLimit: _customer?.creditLimit,
      );

  Future<void> _post() async {
    final settingsRow = _settings;
    if (settingsRow == null || _posting) return;
    final evaluation = _evaluation;

    // A warning verdict requires one explicit confirmation — the brief's
    // «warn» credit mode, surfaced once instead of blocking silently.
    if (evaluation.verdict == CreditVerdict.warnOverLimit) {
      final confirmed = await _confirmCreditWarning(evaluation);
      if (!confirmed || !mounted) return;
    }
    if (!evaluation.canPost) {
      if (evaluation.problem != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(evaluation.problem!,
              style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ));
      }
      return;
    }

    setState(() => _posting = true);
    final dao = ref.read(shopDaoProvider);
    try {
      final balance = _customer == null
          ? 0
          : await dao.customerBalance(_customer!.id);
      final posted = await dao.postSale(
        cart: _cart,
        payments: _payments,
        customer: _customer,
        settingsRow: settingsRow,
        customerBalance: balance,
        ignoreCreditLimitWarn: evaluation.verdict == CreditVerdict.warnOverLimit,
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _payments.clear();
        _customer = null;
        _customerBalance = null;
        _posting = false;
      });
      ref.invalidate(shopHomeProvider);
      await _showSuccess(posted);
    } on PostingException catch (e) {
      AppLogger.warning('PosScreen.post', 'posting refused: ${e.message}');
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message,
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
      ));
    } catch (e, st) {
      AppLogger.error('PosScreen.post', e, st);
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('ثبت فروش ممکن نشد.',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
      ));
    }
  }

  Future<bool> _confirmCreditWarning(SaleEvaluation evaluation) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('سقف اعتبار'),
        content: Text(
          'با این فروش، بدهی ${_customer?.name ?? ''} از سقف تعیین‌شده می‌گذرد. '
          'ثبت شود؟',
          style: TextStyle(fontFamily: AppTheme.fontFamily, height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ثبت'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showSuccess(PostedInvoice posted) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TimeThemeKit.of(context).palette.elevated,
      builder: (_) => ShopReceiptSheet(posted: posted),
    );
    if (mounted) _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final evaluation = _evaluation;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: t.primary,
          iconTheme: IconThemeData(color: t.primary),
          title: Text(
            'فروش جدید',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              color: t.primary,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'سبدنگه‌داشته‌ها',
              icon: const Icon(Icons.bookmark_border_rounded),
              onPressed: _showHeldCarts,
            ),
            IconButton(
              tooltip: 'نگه‌داشتن سبد',
              icon: const Icon(Icons.bookmark_added_outlined),
              onPressed: _cart.isEmpty ? null : _holdCart,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _searchField(t),
              if (_results.isNotEmpty) _resultsList(t),
              if (_favorites.isNotEmpty && _results.isEmpty) _favoritesRow(t),
              Expanded(child: _cartList(t)),
              _totalsBar(t, evaluation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField(AppPalette t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      child: Focus(
        onKeyEvent: _handleKey,
        child: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'جستجوی نام یا بارکد (اسکنر هم اینجا می‌خواند)',
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
    );
  }

  Widget _resultsList(AppPalette t) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.fromLTRB(DsSpacing.page, 6, DsSpacing.page, 0),
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
            title: Text(
              product.name,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: t.textPrimary,
              ),
            ),
            subtitle: Text(
              'موجودی: ${qtyMilliToText(product.stockMilliCached)} · '
              '${NumberFormat.groupDigits('${product.sellPrice}')}',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 10,
                color: t.textMuted,
              ),
            ),
            onTap: () => _addProduct(product),
          );
        },
      ),
    );
  }

  Widget _favoritesRow(AppPalette t) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.page, vertical: 8),
        itemCount: _favorites.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final product = _favorites[i];
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            onTap: () => _addProduct(product),
            child: SizedBox(
              width: 88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    NumberFormat.groupDigits('${product.sellPrice}'),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cartList(AppPalette t) {
    if (_cart.isEmpty) {
      return Center(
        child: Text(
          'سبد خالی است. کالا را جستجو یا اسکن کنید.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            color: t.textMuted,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 8),
      itemCount: _cart.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final line = _cart[i];
        return Dismissible(
          key: ValueKey('line-$i-${line.productId}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: const Color(0x14C9462C),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFC9462C)),
          ),
          onDismissed: (_) => setState(() => _cart.removeAt(i)),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                      Text(
                        '${NumberFormat.groupDigits('${line.unitPrice}')} × '
                        '${qtyMilliToText(line.qtyMilli)} ${line.unitName}',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _qtyStepper(t, i, line),
                const SizedBox(width: 8),
                Text(
                  NumberFormat.groupDigits('${line.lineTotal}'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _qtyStepper(AppPalette t, int index, CartLine line) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
          onPressed: () {
            setState(() {
              final next = line.qtyMilli - 500;
              if (next <= 0) {
                _cart.removeAt(index);
              } else {
                _cart[index] = _withQty(line, next);
              }
            });
          },
        ),
        // The qty itself opens the numeric sheet (fractional quantities).
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _editQty(index, line),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              qtyMilliToText(line.qtyMilli),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          onPressed: () => setState(
              () => _cart[index] = _withQty(line, line.qtyMilli + 500)),
        ),
      ],
    );
  }

  CartLine _withQty(CartLine line, int qtyMilli) => CartLine(
        productId: line.productId,
        name: line.name,
        unitName: line.unitName,
        qtyMilli: qtyMilli,
        unitPrice: line.unitPrice,
        discount: line.discount,
        trackStock: line.trackStock,
        avgCost: line.avgCost,
      );

  /// The numeric sheet for fractional quantities («۰٫۳۳۳ کیلو»).
  Future<void> _editQty(int index, CartLine line) async {
    final ctrl = TextEditingController(text: qtyMilliToText(line.qtyMilli));
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
              Text(
                'تعداد ${line.name}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: InputDecoration(
                  labelText: 'مقدار (${line.unitName})',
                  helperText: 'کسر اعشاری مجاز است، مثلاً ۰٫۵',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  final milli = parseQtyToMilli(ctrl.text);
                  if (milli != null && milli > 0) {
                    Navigator.of(sheetContext).pop(milli);
                  }
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final milli = parseQtyToMilli(ctrl.text);
                  if (milli == null || milli <= 0) return;
                  Navigator.of(sheetContext).pop(milli);
                },
                child: const Text('تأیید'),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _totalsBar(AppPalette t, SaleEvaluation evaluation) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 8, DsSpacing.page, 10),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.outline, width: .5)),
      ),
      child: Column(
        children: [
          // Payment mode + customer chip row.
          Row(
            children: [
              Expanded(child: _paymentSegment(t, evaluation)),
              const SizedBox(width: 8),
              _customerChip(t, evaluation),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قابل پرداخت',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: t.textSecondary,
                      ),
                    ),
                    Text(
                      NumberFormat.groupDigits('${evaluation.total}'),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 20),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed:
                    _posting || !evaluation.canPost ? null : _post,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7C86),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 12),
                ),
                child: _posting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'ثبت فروش',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The payment-mode segmented row: نقد | کارت | نسیه | ترکیبی.
  ///
  /// «چک» stays hidden until the Stage 3 cheque module exists, exactly as the
  /// brief instructs; the method enum already carries it.
  Widget _paymentSegment(AppPalette t, SaleEvaluation evaluation) {
    // «چک» waits for the Stage 3 cheque module (brief): the enum already
    // carries it, the option appears when that module lands. The list is
    // built without a const-false branch so no dead code warns.
    final options = <(PaymentMethod, String)>[
      (PaymentMethod.cash, 'نقد'),
      (PaymentMethod.card, 'کارت'),
      (PaymentMethod.transfer, 'ترکیبی'),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final (method, label) = options[i];
          final active =
              _payments.isNotEmpty && _payments.first.method == method;
          return GestureDetector(
            onTap: () => _choosePayment(method, evaluation),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF0E7C86).withValues(alpha: .14)
                    : t.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? const Color(0xFF0E7C86)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? const Color(0xFF0E7C86)
                      : t.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _choosePayment(
      PaymentMethod method, SaleEvaluation evaluation) async {
    if (method == PaymentMethod.transfer) {
      // «ترکیبی» opens the split-payments sheet.
      await _splitPayments(evaluation);
      return;
    }
    setState(() {
      _payments
        ..clear()
        ..add(SalePayment(method: method, amount: evaluation.total));
    });
  }

  /// Split payments: several methods, their sum must not exceed the total.
  Future<void> _splitPayments(SaleEvaluation evaluation) async {
    final cashCtrl = TextEditingController();
    final cardCtrl = TextEditingController();
    final t = TimeThemeKit.of(context).palette;

    final result = await showModalBottomSheet<(int, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final cash = int.tryParse(_asciiDigits(cashCtrl.text)) ?? 0;
          final card = int.tryParse(_asciiDigits(cardCtrl.text)) ?? 0;
          final sum = cash + card;
          final remaining = evaluation.total - sum;
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
                    'پرداخت ترکیبی',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cashCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'نقد',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cardCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'کارت',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    remaining >= 0
                        ? 'مانده به عنوان نسیه: '
                            '${NumberFormat.groupDigits('$remaining')}'
                        : 'مجموع پرداخت‌ها از مبلغ فاکتور بیشتر است.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: remaining >= 0
                          ? t.textSecondary
                          : const Color(0xFFC9462C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: remaining < 0
                        ? null
                        : () => Navigator.of(sheetContext).pop((cash, card)),
                    child: const Text('تأیید'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    final (cash, card) = result;
    setState(() {
      _payments.clear();
      if (cash > 0) {
        _payments.add(SalePayment(method: PaymentMethod.cash, amount: cash));
      }
      if (card > 0) {
        _payments.add(SalePayment(method: PaymentMethod.card, amount: card));
      }
    });
  }

  Widget _customerChip(AppPalette t, SaleEvaluation evaluation) {
    final isCredit = evaluation.creditPortion > 0;
    final color = isCredit
        ? const Color(0xFFC9462C)
        : const Color(0xFF0E7C86);
    return GestureDetector(
      onTap: _pickCustomer,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              _customer?.name ?? 'مشتری',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomer() async {
    final t = TimeThemeKit.of(context).palette;
    final dao = ref.read(shopDaoProvider);
    final customers = await dao.customers(onlyActive: true, limit: 500);
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    final picked = await showModalBottomSheet<ShopCustomer>(
      context: context,
      backgroundColor: t.elevated,
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.72;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final query = normalizeForSearch(searchCtrl.text.trim());
            final visible = query.isEmpty
                ? customers
                : customers
                    .where((c) =>
                        normalizeForSearch(c.name).contains(query) ||
                        toAsciiDigits(c.phone).contains(toAsciiDigits(query)))
                    .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      const SheetHandle(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'جستجوی نام یا شمارهٔ مشتری',
                            hintStyle: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: t.textMuted,
                            ),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            filled: true,
                            fillColor: t.surfaceAlt,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            color: t.textPrimary,
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                      Flexible(
                        child: visible.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'مشتری‌ای با این مشخصات یافت نشد.',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 12,
                                    color: t.textMuted,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: visible.length,
                                itemBuilder: (_, i) {
                                  final c = visible[i];
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: t.surfaceAlt,
                                      child: Icon(Icons.person_outline,
                                          size: 16, color: t.textMuted),
                                    ),
                                    title: Text(
                                      c.name,
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 13,
                                        color: t.textPrimary,
                                      ),
                                    ),
                                    subtitle: c.phone.trim().isEmpty
                                        ? null
                                        : Text(
                                            c.phone,
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 11,
                                              color: t.textMuted,
                                            ),
                                          ),
                                    onTap: () =>
                                        Navigator.of(sheetContext).pop(c),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    searchCtrl.dispose();
    if (picked == null || !mounted) return;
    final balance = await dao.customerBalance(picked.id);
    setState(() {
      _customer = picked;
      _customerBalance = balance;
    });
  }

  Future<void> _holdCart() async {
    final dao = ref.read(shopDaoProvider);
    final ok = await dao.holdCart(
      cart: _cart,
      customerId: _customer?.id,
      note: _customer?.name ?? '',
    );
    if (!ok || !mounted) return;
    setState(() {
      _cart.clear();
      _payments.clear();
      _customer = null;
      _customerBalance = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('سبد نگه داشته شد.',
          style: TextStyle(fontFamily: AppTheme.fontFamily)),
    ));
  }

  Future<void> _showHeldCarts() async {
    final dao = ref.read(shopDaoProvider);
    final held = await dao.heldCarts();
    if (!mounted) return;
    final t = TimeThemeKit.of(context).palette;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.elevated,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 10),
            const SheetHandle(),
            if (held.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'سبد نگه‌داشته‌ای نیست.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: t.textMuted,
                  ),
                ),
              ),
            for (final cart in held)
              ListTile(
                dense: true,
                leading: const Icon(Icons.bookmark_rounded,
                    size: 20, color: Color(0xFF0E7C86)),
                title: Text(
                  cart.note.isEmpty
                      ? '${cart.cart.length} قلم'
                      : cart.note,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  jalaliLabelFa(cart.createdAt),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: () async {
                    await dao.deleteHeldCart(cart.id);
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (!mounted) return;
                  setState(() {
                    _cart
                      ..clear()
                      ..addAll(cart.cart);
                    _customer = null;
                    _customerBalance = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}

String _asciiDigits(String input) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final out = StringBuffer();
  for (final ch in input.runes) {
    final idx = fa.indexOf(String.fromCharCode(ch));
    out.write(idx >= 0 ? idx.toString() : String.fromCharCode(ch));
  }
  return out.toString();
}
