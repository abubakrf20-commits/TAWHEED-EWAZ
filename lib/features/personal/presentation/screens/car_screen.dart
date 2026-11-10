import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';
import 'package:tawheeed/features/personal/presentation/providers/care_providers.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_car_sheets.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_defaults_sheet.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «خودرو» — the first personal tool. Flat, lazy, and driven by the shared
/// care engine; no dashboard, no hub.
class CarScreen extends ConsumerStatefulWidget {
  const CarScreen({super.key, this.initialTaskId, this.nowOverride});

  /// Deep link target from a tap on a care reminder.
  final String? initialTaskId;

  /// Pins «now» so a golden can render the same statuses forever. Production
  /// never passes it.
  final DateTime? nowOverride;

  @override
  ConsumerState<CarScreen> createState() => _CarScreenState();
}

class _CarScreenState extends ConsumerState<CarScreen> {
  static const _accent = careCarColor;
  bool _openedDeepLink = false;

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDeepLink());
  }

  void _openDeepLink() {
    final id = widget.initialTaskId;
    if (id == null || _openedDeepLink || !mounted) return;
    final snapshot = ref.read(careStoreProvider).value;
    if (snapshot == null) return;
    CareTask? task;
    for (final t in snapshot.tasks) {
      if (t.id == id) task = t;
    }
    if (task == null) return;
    _openedDeepLink = true;
    CareAsset? asset;
    for (final a in snapshot.assets) {
      if (a.id == task.assetId) asset = a;
    }
    if (asset == null) return;
    ref.read(selectedCarProvider.notifier).state = asset.id;
    showCareTaskSheet(context,
        asset: asset, task: task, snapshot: snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(careStoreProvider);
    final templates = ref.watch(careTemplatesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CareScreenAppBar(
        title: 'خودرو',
        onBack: () => context.pop(),
        onHistory: () => context.push('/personal-info/car/history'),
        onSettings: () =>
            showCareSettingsSheet(context, kind: CareAssetKind.car),
      ),
      body: SafeArea(
        child: switch (async) {
          AsyncData(:final value) => _buildBody(value, templates),
          AsyncError(:final error) => _ErrorBody(
              message: '$error',
              onRetry: () => ref.invalidate(careStoreProvider),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _buildBody(CareSnapshot snapshot, AsyncValue<CareTemplates> templates) {
    final t = TimeThemeKit.of(context).palette;
    final cars = snapshot.assetsOf(CareAssetKind.car);
    if (cars.isEmpty) {
      return CareEmptyState(
        accent: _accent,
        icon: Icons.directions_car_outlined,
        title: 'هنوز خودرویی ثبت نشده',
        body: 'با افزودن خودرو، سرویس‌های پیشنهادی (روغن، لنت، بیمه و…) '
            'ساخته می‌شوند و سررسیدشان را یادآوری می‌کنیم.',
        actionLabel: 'افزودن خودرو',
        onAction: () => _addCar(templates),
      );
    }

    final selectedId = ref.watch(selectedCarProvider);
    final asset = cars.firstWhere(
      (a) => a.id == selectedId,
      orElse: () => cars.first,
    );
    final currentKm = snapshot.currentKm(asset.id);
    // One read reused by the status maths and the header: readingsOf builds a
    // fresh list each call, so querying it three times was pure waste.
    final readings = snapshot.readingsOf(asset.id);
    final statuses = snapshot
        .tasksOf(asset.id)
        .where((task) => task.active)
        .map((task) => careStatusOf(
              task,
              _now,
              currentKm: currentKm,
              readings: readings,
            ))
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));

    final now = _now;
    final records = snapshot.recordsOf(asset.id);
    final fuel = snapshot.fuelOf(asset.id);
    final yearCost = careYearCost(records, fuel, now);
    final consumption = careFuelConsumption(fuel);
    final totalCost = records.fold<double>(
      0, (sum, r) => sum + (r.cost ?? 0));
    final serviceCount = records.where((r) => r.taskId != null).length;

    // Cost by category (from task's categoryKey)
    final taskById = {for (final t in snapshot.tasks) t.id: t};
    final costByCategory = <String, double>{};
    for (final r in records) {
      if (r.taskId == null || r.cost == null) continue;
      final task = taskById[r.taskId];
      if (task == null) continue;
      costByCategory[task.categoryKey] = (costByCategory[task.categoryKey] ?? 0) + r.cost!;
    }
    // `.take` is lazy — `..take(3)` on a cascade was a no-op and rendered
    // every category. Materialise the top three instead.
    final sortedCategories = costByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final lastReading = readings.isEmpty
        ? null
        : (List<OdometerReading>.of(readings)
              ..sort((a, b) => a.date.compareTo(b.date)))
            .last;

    // Insurance already lives in `care_templates.json` as two yearly care
    // tasks; there is no separate policy model to build. Surface those tasks
    // in one glanceable card instead of burying them next to oil changes.
    final insuranceStatuses = statuses
        .where((s) =>
            s.task.templateKey.endsWith('_insurance') ||
            s.task.iconKey == 'shield')
        .toList();

    // Price history is derived from fuel fill-ups: an explicit per-litre price
    // when the user entered one, otherwise total cost ÷ litres.
    final pricePoints = <({DateTime date, double price})>[];
    for (final fill in fuel) {
      final derived = fill.pricePerLiter ??
          (fill.liters > 0 && fill.totalCost != null
              ? fill.totalCost! / fill.liters
              : null);
      if (derived != null && derived > 0) {
        pricePoints.add((date: fill.date, price: derived));
      }
    }
    pricePoints.sort((a, b) => a.date.compareTo(b.date));
    final recentPrices = pricePoints.length > 8
        ? pricePoints.sublist(pricePoints.length - 8)
        : pricePoints;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        if (cars.length > 1) ...[
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cars.length,
              separatorBuilder: (_, index) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final car = cars[i];
                return CareChip(
                  label: car.displayName,
                  selected: car.id == asset.id,
                  accent: _accent,
                  onTap: () => ref
                      .read(selectedCarProvider.notifier)
                      .state = car.id,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        _HeaderCard(
          asset: asset,
          currentKm: currentKm,
          lastReading: lastReading,
          accent: _accent,
          now: _now,
          onLogOdometer: () => showOdometerSheet(
            context,
            asset: asset,
            currentKm: currentKm,
          ),
        ),
        const SizedBox(height: 8),
        _StatsRow(
          accent: _accent,
          yearCost: yearCost,
          consumption: consumption,
        ),
        const SizedBox(height: 8),
        if (insuranceStatuses.isNotEmpty) ...[
          _InsurancePolicyCard(
            statuses: insuranceStatuses,
            accent: _accent,
            onStatusTap: (status) => _openStatus(asset, snapshot, status),
          ),
          const SizedBox(height: 8),
        ],
        if (recentPrices.length >= 2) ...[
          _FuelPriceCard(points: recentPrices, accent: _accent),
          const SizedBox(height: 8),
        ],
        if (sortedCategories.isNotEmpty) ...[
          _CategoryDonutCard(
            categories: sortedCategories.take(6).toList(),
            accent: _accent,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: dsContentColor(context, _accent),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'هزینه کل',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: t.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      careMoney(totalCost),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      size: 18,
                      color: dsContentColor(context, _accent),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'سرویس‌های انجام‌شده',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: t.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormat.ltrIsolated('$serviceCount'),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SectionHeader(
          title: 'سررسیدهای بعدی',
          count: '${statuses.length}',
          accent: _accent,
        ),
        if (statuses.isEmpty)
          const _Hint(
            text: 'سرویسی فعال نیست. از تنظیمات خودرو، سرویس تازه اضافه کنید.',
          )
        else
          for (final status in statuses)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CareTaskRow(
                status: status,
                accent: _accent,
                onTap: () => _openStatus(asset, snapshot, status),
              ),
            ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => showCareDefaultsSheet(
              context,
              ref,
              initialKind: CareAssetKind.car,
            ),
            icon: const Icon(Icons.tune_rounded, size: 15),
            label: Text(
              'تنظیم پیش‌فرض‌ها',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: TimeThemeKit.of(context).palette.textMuted,
              ),
            ),
          ),
        ),
        CarePrimaryPill(
          label: 'ثبت سرویس انجام‌شده',
          icon: Icons.build_circle_outlined,
          accent: _accent,
          onPressed: () => _complete(asset, snapshot, const []),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CarePrimaryPill(
                label: 'ثبت سوخت',
                icon: Icons.local_gas_station_outlined,
                accent: _accent,
                outline: true,
                onPressed: () => showFuelSheet(
                  context,
                  asset: asset,
                  currentKm: currentKm,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CarePrimaryPill(
                label: 'افزودن خودرو',
                icon: Icons.add,
                accent: _accent,
                outline: true,
                onPressed: () => _addCar(templates),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CarePrimaryPill(
                label: 'افزودن سرویس دلخواه',
                icon: Icons.add_circle_outline,
                accent: _accent,
                outline: true,
                onPressed: () => showCustomTaskSheet(
                  context,
                  assetId: asset.id,
                ),
              ),
            ),
          ],
        ),
        if (records.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionHeader(title: 'آخرین ثبت‌ها', accent: _accent),
          _ServiceJourney(
            records: records.take(4).toList(),
            accent: _accent,
            onTap: () => context.push('/personal-info/car/history'),
          ),
        ],
      ],
    );
  }

  /// The one way to open a due task, shared by the due list and the policy
  /// card so a «complete» action behaves identically in both places.
  Future<void> _openStatus(
    CareAsset asset,
    CareSnapshot snapshot,
    CareStatus status,
  ) async {
    final action = await showCareTaskSheet(
      context,
      asset: asset,
      task: status.task,
      snapshot: snapshot,
    );
    if (action == 'complete' && mounted) {
      await _complete(asset, snapshot, [status.task.id]);
    }
  }

  Future<void> _addCar(AsyncValue<CareTemplates> templates) async {
    final CareTemplates resolved =
        templates.value ?? await ref.read(careTemplatesProvider.future);
    if (!mounted) return;
    await showAddCarSheet(context, templates: resolved);
  }

  Future<void> _complete(
    CareAsset asset,
    CareSnapshot snapshot,
    List<String> initial,
  ) async {
    final result = await showCompleteServiceSheet(
      context,
      asset: asset,
      snapshot: snapshot,
      initialTaskIds: initial,
    );
    if (result != null && mounted) {
      showCompletionSnack(context, result);
    }
  }
}

/// A perforated stub line — the tiny visual cue that makes the insurance
/// block read like a paper policy rather than yet another settings card.
class _Perforation extends StatelessWidget {
  const _Perforation({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(
          28,
          (i) => Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              color: i.isEven ? color : Colors.transparent,
            ),
          ),
        ),
      );
}

/// «بیمه‌نامه» — all insurance care tasks for the selected car in one card.
///
/// Insurance is not a separate entity: the two yearly templates
/// (`third_party_insurance`, `body_insurance`) are ordinary care tasks. This
/// card is a view over them, so a tap still goes through the same edit/complete
/// sheet as any other due service.
class _InsurancePolicyCard extends StatelessWidget {
  const _InsurancePolicyCard({
    required this.statuses,
    required this.accent,
    required this.onStatusTap,
  });

  final List<CareStatus> statuses;
  final Color accent;
  final ValueChanged<CareStatus> onStatusTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final worst = statuses.reduce(
      (a, b) => a.level.index >= b.level.index ? a : b,
    );
    final ink = careLevelColor(context, worst.level);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      borderColor: ink.withValues(alpha: .38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DuotoneIconTile(
                accent: ink,
                icon: Icons.shield_outlined,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'پوشش بیمه‌ای',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'سررسید بیمهنامهها در یک نگاه',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              CareStatusChip(level: worst.level),
            ],
          ),
          const SizedBox(height: 10),
          _Perforation(color: t.outline),
          for (final status in statuses)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onStatusTap(status),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          careIconFor(status.task.iconKey),
                          size: 16,
                          color: dsContentColor(context, accent),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            status.task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status.dueDate == null
                              ? status.remainingText
                              : careJalaliLong(status.dueDate!),
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 10.5),
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CareProgressBar(
                      progress: status.progress,
                      color: careLevelColor(context, status.level),
                      height: 5,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// «روند قیمت سوخت» — a compact sparkline over the last eight fill-ups.
/// Hidden until there are at least two usable prices, so a fresh car never
/// sees an empty chart.
class _FuelPriceCard extends StatelessWidget {
  const _FuelPriceCard({required this.points, required this.accent});

  final List<({DateTime date, double price})> points;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final latest = points.last.price;
    final previous = points[points.length - 2].price;
    final delta = latest - previous;
    final flat = delta.abs() < 0.5;
    final rising = delta > 0;
    final trend = flat
        ? t.textMuted
        : careLevelColor(
            context,
            rising ? CareStatusLevel.near : CareStatusLevel.good,
          );
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_gas_station_outlined,
                size: 17,
                color: dsContentColor(context, accent),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'قیمت هر لیتر سوخت',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trend.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      flat
                          ? Icons.remove_rounded
                          : (rising
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded),
                      size: 13,
                      color: dsContentColor(context, trend),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      flat ? 'بدون تغییر' : careMoney(delta.abs()),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w700,
                        color: dsContentColor(context, trend),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            careMoney(latest),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 18),
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: CustomPaint(
              painter: _SparklinePainter(
                values: [for (final p in points) p.price],
                color: trend,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                careJalali(points.first.date),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 10),
                  color: t.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                careJalali(points.last.date),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 10),
                  color: t.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final span = max - min < 0.0001 ? 1.0 : max - min;
    final dx = size.width / (values.length - 1);
    Offset at(int i) => Offset(
          i * dx,
          size.height - 6 - ((values[i] - min) / span) * (size.height - 12),
        );

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = color.withValues(alpha: .13)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final last = at(values.length - 1);
    canvas.drawCircle(last, 6, Paint()..color = color.withValues(alpha: .20));
    canvas.drawCircle(last, 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.color != color || old.values.length != values.length;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.asset,
    required this.currentKm,
    required this.lastReading,
    required this.accent,
    required this.onLogOdometer,
    required this.now,
  });

  final CareAsset asset;
  final int? currentKm;
  final OdometerReading? lastReading;
  final Color accent;
  final VoidCallback onLogOdometer;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final daysSince = lastReading == null
        ? null
        : now.difference(lastReading!.date).inDays;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              DuotoneIconTile(
                accent: accent,
                icon: Icons.directions_car_outlined,
                size: 54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 15),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    if (asset.plate.isNotEmpty)
                      Text(
                        asset.plate,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: t.textMuted,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currentKm == null
                              ? '—'
                              : NumberFormat.formatPlain(
                                  currentKm!.toDouble()),
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 22),
                            fontWeight: FontWeight.w800,
                            color: t.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            'km',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 11),
                              color: t.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      lastReading == null
                          ? 'هنوز کیلومتری ثبت نشده'
                          : 'آخرین ثبت: ${daysSince ?? 0} روز پیش',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogOdometer,
              style: OutlinedButton.styleFrom(
                foregroundColor: dsContentColor(context, accent),
                side: BorderSide(color: accent.withValues(alpha: .45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              icon: const Icon(Icons.speed_outlined, size: 17),
              label: const Text('ثبت کیلومتر'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.accent,
    required this.yearCost,
    required this.consumption,
  });

  final Color accent;
  final double yearCost;
  final double? consumption;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    Widget card(String label, String value, IconData icon, {Widget? badge}) =>
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge ??
                    Icon(icon, size: 18, color: dsContentColor(context, accent)),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
    return Row(
      children: [
        card('هزینهٔ امسال', careMoney(yearCost), Icons.payments_outlined),
        const SizedBox(width: 8),
        card(
          'مصرف سوخت',
          consumption == null
              ? 'داده کافی نیست'
              : '${consumption!.toStringAsFixed(1)} L/100km',
          Icons.local_gas_station_outlined,
          badge: _FuelGauge(
            value: consumption,
            color: dsContentColor(context, accent),
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 12),
          color: t.textMuted,
          height: 1.5,
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'خواندن اطلاعات ممکن نشد.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: t.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 10.5),
                color: t.textMuted,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('تلاش دوباره')),
          ],
        ),
      ),
    );
  }
}


/// «مسیر سفر» — the last services as stops on a road instead of four
/// unrelated cards. The newest stop is filled, older ones fade into the line.
class _ServiceJourney extends StatelessWidget {
  const _ServiceJourney({
    required this.records,
    required this.accent,
    required this.onTap,
  });

  final List<CareRecord> records;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      children: [
        for (var i = 0; i < records.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? accent
                            : accent.withValues(alpha: .45),
                        shape: BoxShape.circle,
                        border: Border.all(color: t.card, width: 2),
                      ),
                    ),
                    if (i < records.length - 1)
                      Container(
                        width: 2,
                        height: 58,
                        color: accent.withValues(alpha: .22),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    onTap: onTap,
                    child: Row(
                      children: [
                        DuotoneIconTile(
                          accent: accent,
                          icon: Icons.build_circle_outlined,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                records[i].title.isEmpty
                                    ? 'سرویس'
                                    : records[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 12),
                                  fontWeight: FontWeight.w600,
                                  color: t.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                careJalali(records[i].date),
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 10.5),
                                  color: t.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (records[i].cost != null)
                          Flexible(
                            child: Text(
                              careMoney(records[i].cost!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w600,
                                color: t.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A small dashboard needle for L/100km — 0..20 maps to the half dial.
class _FuelGauge extends StatelessWidget {
  const _FuelGauge({required this.value, required this.color});

  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 34,
        height: 20,
        child: CustomPaint(
          painter: _GaugePainter(
            fraction: ((value ?? 0) / 20).clamp(0.0, 1.0),
            color: color,
          ),
        ),
      );
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const pi = 3.1415926535897932;
    final center = Offset(size.width / 2, size.height - 2);
    final radius = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = color.withValues(alpha: .20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi, false, track);
    canvas.drawArc(
      rect,
      pi,
      pi * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final angle = pi + pi * fraction;
    final tip = Offset(
      center.dx + math.cos(angle) * (radius - 1),
      center.dy + math.sin(angle) * (radius - 1),
    );
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}


/// A colour per cost category, derived from the section accent so the chart
/// stays on-brand while categories stay distinguishable.
Color _careCategoryColor(int index, Color accent) {
  final hsv = HSVColor.fromColor(accent);
  return hsv.withHue((hsv.hue + index * 36) % 360).withValue(.72).toColor();
}

/// «داشبورد هزینه» — the cost breakdown as a donut with exact amounts
/// beside it, instead of a strip of cards that showed only three categories.
class _CategoryDonutCard extends StatelessWidget {
  const _CategoryDonutCard({
    required this.categories,
    required this.accent,
  });

  final List<MapEntry<String, double>> categories;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final total = categories.fold<double>(0, (sum, e) => sum + e.value);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'هزینهٔ دسته‌بندی‌شده',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              MiniDonutChart(
                size: 92,
                thickness: 13,
                slices: [
                  for (var i = 0; i < categories.length; i++)
                    DonutSlice(
                      label: categories[i].key,
                      value: categories[i].value,
                      color: _careCategoryColor(i, accent),
                    ),
                ],
                center: Text(
                  NumberFormat.ltrIsolated('${categories.length}'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 15),
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < categories.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _careCategoryColor(i, accent),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                categories[i].key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  color: t.textSecondary,
                                ),
                              ),
                            ),
                            // Both trailing texts are loose-flex: a long
                            // currency string at 320dp x1.3 must shrink, not
                            // push the row past the card edge.
                            Flexible(
                              child: Text(
                                careMoney(categories[i].value),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: t.textPrimary,
                                ),
                              ),
                            ),
                            if (total > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                NumberFormat.ltrIsolated(
                                    '${((categories[i].value / total) * 100).round()}%'),
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10,
                                  color: t.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
