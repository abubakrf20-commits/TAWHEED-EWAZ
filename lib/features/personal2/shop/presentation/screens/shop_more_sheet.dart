import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_cash_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_cheques_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_expenses_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_purchase_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_settings_screen.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/services/shop_reminders.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_stock_count_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_suppliers_screen.dart';

/// «بیشتر» — the stage-3 sheet inside the shop tool: تأمین‌کنندگان، خرید،
/// هزینه‌ها، چک‌ها، صندوق، انبارگردانی، تنظیمات. The brief's list; no new
/// entry anywhere outside the tool.
class ShopMoreSheet {
  ShopMoreSheet._();

  static Future<void> show(BuildContext context) async {
    final t = TimeThemeKit.of(context).palette;
    // Lazy re-arm: opening the More sheet is the natural moment the shopkeeper
    // is present; scheduling never runs at app start.
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await ShopReminders.rearm(
        shopDao: container.read(shopDaoProvider),
        shop3Dao: container.read(shop3DaoProvider),
      );
    } catch (_) {
      // A failed re-arm must not block the sheet.
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.elevated,
      builder: (sheetContext) => const SafeArea(child: _MoreList()),
    );
  }
}

class _MoreList extends StatelessWidget {
  const _MoreList();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final entries = [
      (Icons.local_shipping_outlined, 'تأمین‌کنندگان', 'فروشندگان و بدهی ما', () => _push(context, const ShopSuppliersScreen())),
      (Icons.shopping_bag_outlined, 'خرید', 'خرید کالا و ثبت هزینهٔ حمل', () => _push(context, const ShopPurchaseScreen())),
      (Icons.receipt_outlined, 'هزینه‌ها', 'اجاره، برق، حقوق و…', () => _push(context, const ShopExpensesScreen())),
      (Icons.receipt_long_outlined, 'چک‌ها', 'دریافتی و صادره', () => _push(context, const ShopChequesScreen())),
      (Icons.account_balance_wallet_outlined, 'صندوق', 'باز و بستن روز', () => _push(context, const ShopCashScreen())),
      (Icons.inventory_rounded, 'انبارگردانی', 'شمارش و تعدیل موجودی', () => _push(context, const ShopStockCountScreen())),
      (Icons.settings_outlined, 'تنظیمات', 'مشخصات، سیاست‌ها، سلامت داده', () => _push(context, const ShopSettingsScreen())),
    ];

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      children: [
        const SheetHandle(),
        const SizedBox(height: 6),
        Text(
          'حساب مغازه — بخش‌های بیشتر',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (final (icon, title, subtitle, onTap) in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onTap: () {
                Navigator.of(context).pop();
                onTap();
              },
              child: Row(
                children: [
                  DuotoneIconTile(
                      accent: const Color(0xFF0E7C86), icon: icon, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10,
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded,
                      size: 18, color: t.textMuted),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static void _push(BuildContext context, Widget screen) {
    // The tool's screens are full routes; pushing through the root navigator
    // keeps back behavior consistent with the other tabs.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => Directionality(textDirection: TextDirection.rtl, child: screen)),
    );
  }
}
