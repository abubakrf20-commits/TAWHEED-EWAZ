import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «انبارگردانی» — create a count (all/category), enter counted quantities,
/// review differences with the value impact, post with confirmation, history.
class ShopStockCountScreen extends ConsumerStatefulWidget {
  const ShopStockCountScreen({super.key});

  @override
  ConsumerState<ShopStockCountScreen> createState() =>
      _ShopStockCountScreenState();
}

class _ShopStockCountScreenState extends ConsumerState<ShopStockCountScreen> {
  String? _openCountId;
  List<({String productId, String name, int systemQty, int? counted})> _lines =
      [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final dao3 = ref.read(shop3DaoProvider);
    // Find the open count, if any.
    final open = await dao3.db.customSelect(
      "SELECT id FROM p2_shop_stock_count WHERE status = 'open' "
      'ORDER BY created_at DESC LIMIT 1',
    ).get();
    final openId = open.isEmpty ? null : open.first.read<String>('id');
    List<({String productId, String name, int systemQty, int? counted})> lines =
        [];
    if (openId != null) {
      final rows = await dao3.db.customSelect(
        'SELECT l.product_id, l.system_qty_milli, l.counted_qty_milli, '
        'p.name FROM p2_shop_stock_count_line l '
        'JOIN p2_shop_product p ON p.id = l.product_id '
        'WHERE l.count_id = ? ORDER BY p.normalized_name ASC',
        variables: [Variable.withString(openId)],
      ).get();
      lines = [
        for (final r in rows)
          (
            productId: r.read<String>('product_id'),
            name: r.read<String>('name'),
            systemQty: r.read<int>('system_qty_milli'),
            counted: r.readNullable<int>('counted_qty_milli'),
          ),
      ];
    }
    if (!mounted) return;
    setState(() {
      _openCountId = openId;
      _lines = lines;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final counted = _lines.where((l) => l.counted != null).length;

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
          'انبارگردانی',
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
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _openCountId == null
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 12, DsSpacing.page, 40),
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'انبارگردانی جدید',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'یک شمارش باز می‌شود؛ موجودی سیستم هر کالا ثبت '
                              'می‌شود و شما تعداد واقعی را وارد می‌کنید. پس از '
                              'پس گرفتن تأیید، اختلاف‌ها به‌عنوان تعدیل ثبت '
                              'می‌شوند.',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                height: 1.8,
                                color: t.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _create,
                              style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0E7C86)),
                              icon: const Icon(Icons.inventory_rounded,
                                  size: 18),
                              label: const Text('شروع شمارش کل انبار'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DsSpacing.page),
                        child: AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'شمارش‌شده: $counted از ${_lines.length}',
                                  style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              FilledButton(
                                onPressed: counted == 0
                                    ? null
                                    : () => _post(countId: _openCountId!),
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0E7C86)),
                                child: const Text('ثبت نهایی'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(DsSpacing.page,
                              10, DsSpacing.page, 40),
                          itemCount: _lines.length,
                          itemBuilder: (context, i) => _lineCard(
                              context, i, _openCountId!),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _lineCard(BuildContext context, int index, String countId) {
    final t = TimeThemeKit.of(context).palette;
    final line = _lines[index];
    final counted = line.counted;
    final diff = counted == null ? null : counted - line.systemQty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'سیستم: ${qtyMilliToText(line.systemQty)}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                        color: t.textMuted),
                  ),
                ],
              ),
            ),
            if (diff != null && diff != 0)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '${diff > 0 ? '+' : ''}${qtyMilliToText(diff)}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: diff > 0
                        ? const Color(0xFF2E8B3D)
                        : const Color(0xFFC9462C),
                  ),
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _enterQty(index, countId, line),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: counted == null
                      ? t.surfaceAlt
                      : const Color(0xFF0E7C86).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  counted == null ? 'شمارش' : qtyMilliToText(counted),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: counted == null
                        ? t.textSecondary
                        : const Color(0xFF0E7C86),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enterQty(
    int index,
    String countId,
    ({String productId, String name, int systemQty, int? counted}) line,
  ) async {
    final ctrl = TextEditingController(
        text: line.counted == null ? '' : qtyMilliToText(line.counted!));
    final t = TimeThemeKit.of(context).palette;
    final popped = await showModalBottomSheet<int>(
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
                'شمارش ${line.name}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
              Text(
                'موجودی سیستم: ${qtyMilliToText(line.systemQty)}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: t.textMuted),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'تعداد شمرده‌شده',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  final milli = parseQtyToMilli(ctrl.text);
                  if (milli != null && milli >= 0) {
                    Navigator.of(sheetContext).pop(milli);
                  }
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E7C86)),
                onPressed: () {
                  final milli = parseQtyToMilli(ctrl.text);
                  if (milli != null && milli >= 0) {
                    Navigator.of(sheetContext).pop(milli);
                  }
                },
                child: const Text('تأیید'),
              ),
            ],
          ),
        ),
      ),
    );
    if (popped == null || !mounted) return;
    await ref
        .read(shop3DaoProvider)
        .setCountedQty(
            countId: countId, productId: line.productId, countedMilli: popped);
    _reload();
  }

  Future<void> _create() async {
    final id = await ref.read(shop3DaoProvider).createStockCount();
    if (!mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('کالای قابل شمارش نیست.',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
      ));
      return;
    }
    _reload();
  }

  Future<void> _post({required String countId}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ثبت نهایی انبارگردانی'),
        content: Text(
          'اختلاف‌ها به‌عنوان تعدیل موجودی ثبت می‌شوند و موجودی کش با شمارش '
          'جایگزین می‌شود. ادامه می‌دهد؟',
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
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final impact = await ref.read(shop3DaoProvider).postStockCount(
          countId: countId,
        );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(
        impact == null
            ? 'ثبت ممکن نشد.'
            : 'ثبت شد؛ اثر ارزشی: ${NumberFormat.groupDigits('$impact')}',
        style: TextStyle(fontFamily: AppTheme.fontFamily),
      ),
    ));
    _reload();
  }
}
