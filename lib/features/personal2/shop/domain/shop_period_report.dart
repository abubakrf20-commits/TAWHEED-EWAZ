import 'package:tawheeed/features/personal2/shop/domain/shop3_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_report_range.dart';

/// One product's contribution to a report window.
class ShopProductSale {
  const ShopProductSale({
    required this.name,
    required this.qtyMilli,
    required this.total,
    required this.cost,
  });

  final String name;
  final int qtyMilli;

  /// Σ line totals (after the line's own discount).
  final int total;

  /// Σ `qty × unit_cost_snapshot` — what the sold units had cost the shop.
  final int cost;

  /// Profit of these lines: revenue minus the cost snapshot taken at sale
  /// time. Later price edits never rewrite it, so a report can be re-run.
  int get profit => total - cost;
}

/// A product that sold nothing in the window but still sits on the shelf.
class ShopSlowMover {
  const ShopSlowMover({
    required this.id,
    required this.name,
    required this.stockMilli,
    required this.lastSoldAtMs,
    required this.sellPrice,
    required this.avgCost,
  });

  final String id;
  final String name;
  final int stockMilli;

  /// Null = never sold since the product was created.
  final int? lastSoldAtMs;

  final int sellPrice;
  final int avgCost;

  /// The money frozen in this product's stock (`qty × avgCost`, rounded once).
  int get tiedUpValue => roundHalfUpDiv(stockMilli * avgCost, 1000);

  /// `null` when it has never sold — «هرگز فروش نرفته» reads differently from
  /// a number, and formatting it as 0 days would be a lie.
  int? idleDays(DateTime now) {
    final last = lastSoldAtMs;
    if (last == null) return null;
    final days = (now.millisecondsSinceEpoch - last) ~/ 86400000;
    return days < 0 ? 0 : days;
  }
}

/// Everything the «گزارش» tab prints for one window, computed once.
///
/// The stage-2 tab only had sales/count/average/payment mix/top-5. A shop
/// report that cannot say what the profit was, how it compares with the
/// previous window, or which stock is not moving was the P1-F gap; the figures
/// below are the missing half, and [ReportFigures] is the single place that
/// defines net sales / gross profit / net profit (already pinned by the domain
/// tests) rather than a second set of formulas in the widget.
class ShopPeriodReport {
  const ShopPeriodReport({
    required this.range,
    required this.figures,
    required this.invoiceCount,
    required this.returnCount,
    required this.byMethod,
    required this.topProducts,
    required this.previousNetSales,
    required this.hasPreviousData,
  });

  final ShopReportRange range;
  final ReportFigures figures;

  /// Posted sale invoices in the window (returns are counted separately).
  final int invoiceCount;
  final int returnCount;

  final Map<PaymentMethod, int> byMethod;
  final List<ShopProductSale> topProducts;

  /// Net sales of the equally long window before this one.
  final int previousNetSales;

  /// False when the previous window holds no invoice at all — then a percentage
  /// is meaningless and the widget must print nothing instead of «۱۰۰٪».
  final bool hasPreviousData;

  int get averageTicket =>
      invoiceCount == 0 ? 0 : figures.netSales ~/ invoiceCount;

  /// Percent change against the previous window, or null when there is nothing
  /// to compare with.
  int? get salesChangePercent {
    if (!hasPreviousData || previousNetSales == 0) return null;
    return roundHalfUpDiv(
      (figures.netSales - previousNetSales) * 100,
      previousNetSales.abs(),
    );
  }

  /// Margin of net sales that survived as gross profit (0..100), or null when
  /// there were no sales to take a percentage of.
  int? get grossMarginPercent {
    if (figures.netSales <= 0) return null;
    return roundHalfUpDiv(figures.grossProfit * 100, figures.netSales);
  }
}
