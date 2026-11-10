import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/tools/zakat/data/zakat_live_price_service.dart';
import 'package:tawheeed/features/tools/zakat/data/zakat_price_store.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

class ZakatPriceState {
  /// Prices older than this are treated as stale everywhere — the screen
  /// badge and the state must never disagree.
  static const Duration staleAfter = Duration(hours: 24);

  final SavedZakatPrices? saved;
  final bool loading;
  final String? error;

  /// True when the last live refresh failed while older prices stayed on
  /// screen; those figures must not be presented as fresh.
  final bool refreshFailed;
  const ZakatPriceState(
      {this.saved,
      this.loading = false,
      this.error,
      this.refreshFailed = false});

  ZakatPriceState copyWith(
          {SavedZakatPrices? saved,
          bool? loading,
          String? error,
          bool? refreshFailed,
          bool clearError = false}) =>
      ZakatPriceState(
          saved: saved ?? this.saved,
          loading: loading ?? this.loading,
          error: clearError ? null : (error ?? this.error),
          refreshFailed: refreshFailed ?? this.refreshFailed);

  bool get isStale {
    if (saved == null) return true;
    if (refreshFailed) return true;
    final age = DateTime.now().millisecondsSinceEpoch - saved!.updatedAt;
    return age > staleAfter.inMilliseconds;
  }
}

class ZakatPriceNotifier extends Notifier<ZakatPriceState> {
  /// Resolved when the initial store read lands. The read assigns the whole
  /// state, so a refresh/save made while it was in flight was overwritten by
  /// the older stored prices.
  Completer<void> _ready = Completer<void>();

  @override
  ZakatPriceState build() {
    _ready = Completer<void>();
    _load();
    return const ZakatPriceState(loading: true);
  }

  Future<void> _awaitReady() async {
    if (!_ready.isCompleted) await _ready.future;
  }

  Future<void> _load() async {
    try {
      final saved = await ZakatPriceStore.load();
      if (!ref.mounted) return;
      state = ZakatPriceState(saved: saved);
    } catch (e) {
      AppLogger.warning('ZakatPrice', 'load failed: $e');
      if (ref.mounted) state = ZakatPriceState(error: e.toString());
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> refreshLive() async {
    await _awaitReady();
    if (!ref.mounted) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final live = await ZakatLivePriceService.fetch();
      await ZakatPriceStore.save(
          goldPerGram: live.goldPerGram,
          silverPerGram: live.silverPerGram,
          dollarPrice: live.dollarPrice);
      final saved = await ZakatPriceStore.load();
      if (!ref.mounted) return;
      state = ZakatPriceState(saved: saved);
    } catch (e) {
      AppLogger.warning('ZakatPrice', 'live fetch failed: $e');
      if (ref.mounted) {
        state = state.copyWith(
            loading: false, error: e.toString(), refreshFailed: true);
      }
    }
  }

  /// Manual entry: negative or non-finite figures are rejected and the
  /// previously stored set stays untouched.
  Future<void> saveManual(
      {required double goldPerGram,
      required double silverPerGram,
      required double dollarPrice}) async {
    await _awaitReady();
    if (!ref.mounted) return;
    bool invalid(double v) => v <= 0 || !v.isFinite;
    if (invalid(goldPerGram) ||
        invalid(silverPerGram) ||
        invalid(dollarPrice)) {
      state = state.copyWith(
          loading: false, error: 'مقادیر قیمت باید عددی مثبت باشند');
      return;
    }
    await ZakatPriceStore.save(
        goldPerGram: goldPerGram,
        silverPerGram: silverPerGram,
        dollarPrice: dollarPrice);
    final saved = await ZakatPriceStore.load();
    if (!ref.mounted) return;
    state = ZakatPriceState(saved: saved);
  }
}

final zakatPriceProvider =
    NotifierProvider<ZakatPriceNotifier, ZakatPriceState>(
        ZakatPriceNotifier.new);
