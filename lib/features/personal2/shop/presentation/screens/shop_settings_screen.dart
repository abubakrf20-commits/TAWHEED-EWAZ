import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shared/parent_lock.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_expense_categories_sheet.dart';
import 'package:tawheeed/features/personal2/shop/services/shop_reminders.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/presentation/providers/shop_providers.dart';

/// تنظیمات مغازه — shop info, receipt footer, invoice numbering (only
/// increases), rounding step, negative-stock policy, credit-limit mode,
/// price-edit permission, scan feedback, privacy, integrity check and the
/// PIN-guarded data reset.
class ShopSettingsScreen extends ConsumerStatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  ConsumerState<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends ConsumerState<ShopSettingsScreen> {
  ShopSettingsRow? _settings;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  final _nextCtrl = TextEditingController();
  final _lowStockCtrl = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _footerCtrl.dispose();
    _prefixCtrl.dispose();
    _nextCtrl.dispose();
    _lowStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dao = ref.read(shopDaoProvider);
    await dao.ensureSeeded();
    final s = await dao.settings();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _nameCtrl.text = s.shopName;
      _phoneCtrl.text = s.phone;
      _addressCtrl.text = s.address;
      _footerCtrl.text = s.receiptFooterText;
      _prefixCtrl.text = s.invoicePrefix;
      _nextCtrl.text = '${s.nextInvoiceNumber}';
      _lowStockCtrl.text = '${s.lowStockDefault}';
      _loaded = true;
    });
  }

  Future<void> _save(ShopSettingsRow Function(ShopSettingsRow) update) async {
    final current = _settings ?? const ShopSettingsRow();
    final next = update(current);
    setState(() => _settings = next);
    await ref.read(shopDaoProvider).saveSettings(next);
    ref.invalidate(shopHomeProvider);
    ref.invalidate(shopSettingsProvider);
    // Every settings change re-arms the reminders (lazy: only when the user
    // is already in this screen — never at app start).
    await ShopReminders.rearm(
      shopDao: ref.read(shopDaoProvider),
      shop3Dao: ref.read(shop3DaoProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final s = _settings;

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
            'تنظیمات مغازه',
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
        ),
        body: SafeArea(
          child: !_loaded || s == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                      DsSpacing.page, 12, DsSpacing.page, 40),
                  children: [
                    const SectionHeader(
                        title: 'مشخصات فروشگاه', accent: Color(0xFF0E7C86)),
                    const SizedBox(height: 4),
                    AppCard(
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                                labelText: 'نام فروشگاه',
                                border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                                labelText: 'تلفن', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _addressCtrl,
                            decoration: const InputDecoration(
                                labelText: 'نشانی',
                                border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _footerCtrl,
                            decoration: const InputDecoration(
                              labelText: 'متن پایین رسید',
                              helperText: 'روی رسید چاپی و اشتراک می‌آید',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0E7C86)),
                      onPressed: () => _save((s) => s.copyWith2(
                            shopName: _nameCtrl.text.trim(),
                            phone: _phoneCtrl.text.trim(),
                            address: _addressCtrl.text.trim(),
                            receiptFooterText: _footerCtrl.text.trim(),
                          )),
                      child: const Text('ذخیره مشخصات'),
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(
                        title: 'فاکتور و گرد کردن', accent: Color(0xFF0E7C86)),
                    const SizedBox(height: 4),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _prefixCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'پیشوند شماره',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _nextCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'شمارهٔ بعدی',
                                    helperText: 'فقط بیشتر می‌شود',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'گرد کردن نهایی فاکتور',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final (label, step) in const [
                                ('بدون', 0),
                                ('۱۰', 10),
                                ('۱۰۰', 100),
                                ('۱۰۰۰', 1000),
                              ])
                                ChoiceChip(
                                  label: Text(label),
                                  selected: s.roundingStep == step,
                                  onSelected: (_) =>
                                      _save((x) => x.copyWith2(roundingStep: step)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: () async {
                        final currentNext = _settings?.nextInvoiceNumber ?? 1;
                        final typed = int.tryParse(_nextCtrl.text.trim()) ?? 0;
                        if (typed < currentNext) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'شمارهٔ بعدی نمی‌تواند از $currentNext کمتر باشد.',
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily)),
                          ));
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        await _save((s) => s.copyWith2(
                              invoicePrefix: _prefixCtrl.text.trim(),
                              nextInvoiceNumber: typed,
                            ));
                        if (!mounted) return;
                        messenger.showSnackBar(SnackBar(
                          content: Text('شماره‌گذاری به‌روز شد.',
                              style: TextStyle(fontFamily: AppTheme.fontFamily)),
                        ));
                      },
                      child: const Text('به‌روزرسانی شماره‌گذاری'),
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(
                        title: 'سیاست‌ها', accent: Color(0xFF0E7C86)),
                    const SizedBox(height: 4),
                    AppCard(
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: const Color(0xFF0E7C86),
                            title: Text(
                              'اجازهٔ فروش با موجودی منفی',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13),
                            ),
                            value: s.allowNegativeStock,
                            onChanged: (v) => _save(
                                (x) => x.copyWith2(allowNegativeStock: v)),
                          ),
                          SwitchListTile.adaptive(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: const Color(0xFF0E7C86),
                            title: Text(
                              'اجازهٔ تغییر قیمت در فروش',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13),
                            ),
                            value: s.allowPriceEdit,
                            onChanged: (v) =>
                                _save((x) => x.copyWith2(allowPriceEdit: v)),
                          ),
                          SwitchListTile.adaptive(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: const Color(0xFF0E7C86),
                            title: Text(
                              'پنهان کردن مبالغ به‌صورت پیش‌فرض',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13),
                            ),
                            value: s.hideBalances,
                            onChanged: (v) =>
                                _save((x) => x.copyWith2(hideBalances: v)),
                          ),
                          const Divider(height: 18),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'سقف اعتبار مشتری',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                color: t.textSecondary,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final (label, mode) in const [
                                ('خاموش', CreditLimitMode.off),
                                ('هشدار', CreditLimitMode.warn),
                                ('مسدود', CreditLimitMode.block),
                              ])
                                ChoiceChip(
                                  label: Text(label),
                                  selected: s.creditLimitMode == mode,
                                  onSelected: (_) => _save(
                                      (x) => x.copyWith2(creditLimitMode: mode)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _lowStockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'حد پیش‌فرض هشدار موجودی (عدد)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: () async {
                        final units =
                            int.tryParse(_lowStockCtrl.text.trim()) ?? 3;
                        await _save((s) =>
                            s.copyWith2(lowStockDefault: units.clamp(0, 9999)));
                      },
                      child: const Text('ذخیرهٔ حد هشدار'),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => ExpenseCategoryManagerSheet.show(
                        context,
                        dao3: ref.read(shop3DaoProvider),
                        onChanged: () {},
                      ),
                      icon: const Icon(Icons.category_rounded, size: 18),
                      label: const Text('مدیریت دسته‌های هزینه'),
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(
                        title: 'سلامت داده‌ها', accent: Color(0xFF0E7C86)),
                    const SizedBox(height: 4),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _runIntegrity,
                            icon: const Icon(Icons.fact_check_outlined,
                                size: 18),
                            label: const Text('بررسی سازگاری موجودی و دفتر'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(
                        title: 'پاک‌کردن داده‌های مغازه',
                        accent: Color(0xFFC9462C)),
                    const SizedBox(height: 4),
                    AppCard(
                      borderColor: const Color(0xFFC9462C).withValues(alpha: .4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'همهٔ کالاها، فاکتورها، مشتریان و دفتر مغازه پاک '
                            'می‌شود. این کار برگشت‌پذیر نیست.',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              height: 1.8,
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFC9462C),
                            ),
                            onPressed: _resetShopData,
                            child: const Text('پاک‌کردن داده‌های مغازه'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _runIntegrity() async {
    final problems = await ref.read(shopDaoProvider).verifyIntegrity();
    if (!mounted) return;
    final t = TimeThemeKit.of(context).palette;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(problems.isEmpty ? 'همه‌چیز سازگار است' : 'ناسازگاری یافت شد'),
        content: problems.isEmpty
            ? Text(
                'موجودی‌ها با جمع حرکات و مانده‌ها با جمع دفتر مطابقت دارند.',
                style: TextStyle(fontFamily: AppTheme.fontFamily, height: 1.8),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final p in problems.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${p.description}\n${p.details}',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            height: 1.6),
                      ),
                    ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('بستن',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily, color: t.primary)),
          ),
        ],
      ),
    );
  }

  /// The reset: ParentLock first, then a typed confirmation, then the wipe —
  /// in one transaction so a half-deleted shop is impossible.
  Future<void> _resetShopData() async {
    final allowed = await ParentLock.requirePin(
      context,
      reason: 'برای پاک‌کردن داده‌های مغازه رمز را وارد کنید',
    );
    if (!allowed || !mounted) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأیید نهایی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'برای تأیید، واژهٔ «پاک» را بنویسید.',
              style: TextStyle(fontFamily: AppTheme.fontFamily, height: 1.7),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC9462C)),
            onPressed: () => Navigator.of(dialogContext)
                .pop(controller.text.trim() == 'پاک'),
            child: const Text('پاک کن'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(shopDaoProvider).wipeShopData();
    ref.invalidate(shopHomeProvider);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text('داده‌های مغازه پاک شد.',
          style: TextStyle(fontFamily: AppTheme.fontFamily)),
    ));
    _load();
  }
}
