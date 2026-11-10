import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop3_domain.dart';
import 'package:tawheeed/features/personal2/shop/presentation/providers/shop_providers.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Stage-3 stat loaders — each reads only what its card shows.
///
/// They live beside the other shop providers, not beside the screen that reads
/// them: a provider declared inside a screen file is what the strict gate's
/// third check exists to stop.
class ShopStage3Loaders {
  ShopStage3Loaders(this.ref);

  final Ref ref;

  /// Expected drawer cash for the open day (0 when the day is not open).
  Future<int> cashExpected() async {
    try {
      final day = await ref.read(shop3DaoProvider).cashDayToday();
      if (day == null || !day.isOpen) return 0;
      return await ref.read(shop3DaoProvider).expectedCashForDay(DateTime.now());
    } catch (e, st) {
      // The card shows zero either way; the read still has to leave a trail,
      // or a permanently broken query looks exactly like a quiet day.
      AppLogger.error('ShopStage3Loaders.cashExpected', e, st);
      return 0;
    }
  }

  /// Total payables: the sum of suppliers' positive balances.
  Future<int> payablesTotal() async {
    try {
      final rows = await ref.read(shopDaoProvider).db.customSelect(
        'SELECT COALESCE(SUM(bal), 0) AS total FROM ('
        'SELECT COALESCE(SUM(signed_amount), 0) AS bal FROM p2_shop_ledger_entry '
        "WHERE party_type = 'supplier' GROUP BY party_id) WHERE bal > 0",
      ).get();
      return rows.first.read<int>('total');
    } catch (e, st) {
      AppLogger.error('ShopStage3Loaders.payablesTotal', e, st);
      return 0;
    }
  }

  /// Cheques due within 7 days, both directions.
  Future<int> chequesDue() async {
    try {
      final cheques =
          await ref.read(shop3DaoProvider).cheques(onlyInFlight: true);
      final now = DateTime.now();
      return cheques
          .where((c) =>
              dueSoon(dueDate: c.dueDate, now: now) || c.dueDate.isBefore(now))
          .fold<int>(0, (s, c) => s + c.amount);
    } catch (e, st) {
      AppLogger.error('ShopStage3Loaders.chequesDue', e, st);
      return 0;
    }
  }

  /// Today's expense total.
  Future<int> expenseToday() async {
    try {
      final from = startOfToday().millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;
      return await ref
          .read(shop3DaoProvider)
          .expenseTotal(fromMs: from, toMs: now + 1);
    } catch (e, st) {
      AppLogger.error('ShopStage3Loaders.expenseToday', e, st);
      return 0;
    }
  }
}

final shopStage3LoadersProvider =
    Provider<ShopStage3Loaders>(ShopStage3Loaders.new);
