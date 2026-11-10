import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_period_report.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_report_range.dart';

/// What the report tab is showing: the preset the user tapped *and* the window
/// it resolved to.
///
/// Both are kept because a preset is not derivable from its window — «۷ روز»
/// ending today and a custom range that happens to be seven days long print
/// the same dates but must highlight different chips. Resolving the preset to
/// a range once, on tap, also freezes the window: a tab left open across
/// midnight keeps reporting the period the user asked for instead of silently
/// sliding to a new one under the numbers.
class ShopReportSelection {
  const ShopReportSelection({required this.preset, required this.range});

  final ShopReportPreset preset;
  final ShopReportRange range;

  ShopReportSelection copyWith({
    ShopReportPreset? preset,
    ShopReportRange? range,
  }) =>
      ShopReportSelection(
        preset: preset ?? this.preset,
        range: range ?? this.range,
      );

  @override
  bool operator ==(Object other) =>
      other is ShopReportSelection &&
      other.preset == preset &&
      other.range == range;

  @override
  int get hashCode => Object.hash(preset, range);
}

class ShopReportSelectionNotifier extends Notifier<ShopReportSelection> {
  @override
  ShopReportSelection build() {
    const preset = ShopReportPreset.last7;
    return ShopReportSelection(
      preset: preset,
      range: preset.rangeAt(DateTime.now())!,
    );
  }

  /// Taps a chip. [custom] has no window of its own — the tab keeps the current
  /// one until the user picks endpoints, so nothing flickers to an empty range.
  void selectPreset(ShopReportPreset preset) {
    final range = preset.rangeAt(DateTime.now());
    state = range == null
        ? state.copyWith(preset: preset)
        : ShopReportSelection(preset: preset, range: range);
  }

  /// A picked «از … تا …» window: the chip becomes «بازهٔ دلخواه», because that
  /// is what it is now, whatever the day count looks like.
  void selectRange(ShopReportRange range) {
    state = ShopReportSelection(
      preset: ShopReportPreset.custom,
      range: range,
    );
  }
}

final shopReportSelectionProvider =
    NotifierProvider<ShopReportSelectionNotifier, ShopReportSelection>(
  ShopReportSelectionNotifier.new,
);

/// The tab's whole figure set for one window. `null` = the database refused the
/// query (the tab shows its error state); an empty shop is a real report.
final shopPeriodReportProvider =
    FutureProvider.family<ShopPeriodReport?, ShopReportRange>(
  (ref, range) => ref.read(shop3DaoProvider).periodReport(range),
);

/// Products that held stock through the window without selling it.
final shopSlowMoversProvider =
    FutureProvider.family<List<ShopSlowMover>, ShopReportRange>(
  (ref, range) => ref.read(shop3DaoProvider).slowMovers(range),
);

/// The rows behind a drill-down tap. A value object rather than six providers,
/// so the invoice list has one cache entry per distinct filter combination.
class ShopInvoiceQuery {
  const ShopInvoiceQuery({
    required this.range,
    this.productName,
    this.method,
    this.creditOnly = false,
    this.includeReturns = true,
  });

  final ShopReportRange range;
  final String? productName;
  final PaymentMethod? method;
  final bool creditOnly;
  final bool includeReturns;

  @override
  bool operator ==(Object other) =>
      other is ShopInvoiceQuery &&
      other.range == range &&
      other.productName == productName &&
      other.method == method &&
      other.creditOnly == creditOnly &&
      other.includeReturns == includeReturns;

  @override
  int get hashCode => Object.hash(
        range,
        productName,
        method,
        creditOnly,
        includeReturns,
      );
}

final shopRangeInvoicesProvider =
    FutureProvider.family<List<ShopInvoice>, ShopInvoiceQuery>(
  (ref, query) => ref.read(shop3DaoProvider).rangeInvoices(
        query.range,
        productName: query.productName,
        method: query.method,
        creditOnly: query.creditOnly,
        includeReturns: query.includeReturns,
      ),
);
