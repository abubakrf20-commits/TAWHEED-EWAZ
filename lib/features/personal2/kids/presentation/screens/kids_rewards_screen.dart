import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/features/personal2/kids/presentation/providers/kids_providers.dart';
import 'package:tawheeed/features/personal2/shared/parent_lock.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/personal2/shared/template_store.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// «جایزه‌ها» — the parent's approval card on top, then the star shop.
class KidsRewardsScreen extends ConsumerWidget {
  const KidsRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(kidsHomeProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          title: 'جایزه‌ها',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: home.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FailureView(
              id: 'kids_rewards_load',
              title: 'فروشگاه جایزه‌ها باز نشد',
              detail: 'جایزه‌ها و ستاره‌های ثبت‌شده پاک نشده‌اند؛ فقط '
                  'خواندنشان ناموفق بود.',
              onRetry: () => ref.invalidate(kidsHomeProvider),
              layout: FailureLayout.page,
              error: e,
            ),
            data: (data) => data.children.isEmpty
                ? const AppEmptyState(
                    icon: Icons.child_care_outlined,
                    message: 'فرزندی ثبت نشده',
                    subtitle: 'فروشگاه ستاره‌ها برای هر فرزند جدا ساخته '
                        'می‌شود؛ اول یک فرزند اضافه کنید.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 12, DsSpacing.page, 40),
                    children: [
                      if (data.pendingRequests.isNotEmpty)
                        _requestsCard(context, ref, data),
                      for (final child in data.children)
                        _childShop(context, ref, child),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Pending requests, each awaiting a PIN-protected decision.
  Widget _requestsCard(BuildContext context, WidgetRef ref, KidsHomeState data) {
    final t = TimeThemeKit.of(context).palette;
    final warning = DsStatus.warning(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        borderColor: warning.withValues(alpha: .45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions_rounded, color: warning, size: 20),
                const SizedBox(width: 8),
                // The heading is the row's only flexible child; without this
                // the card overflows at a raised text scale.
                Expanded(
                  child: Text(
                    'درخواست‌های در انتظار',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final req in data.pendingRequests)
              _requestRow(context, ref, req, data),
          ],
        ),
      ),
    );
  }

  Widget _requestRow(
    BuildContext context,
    WidgetRef ref,
    RewardRequestRecord req,
    KidsHomeState data,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final child = data.children.where((c) => c.id == req.kidId).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${child?.name ?? 'کودک'} می‌خواهد ${req.stars} ستاره خرج کند',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: t.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _decide(context, ref, req, approve: false),
            child: const Text('رد'),
          ),
          FilledButton(
            onPressed: () => _decide(context, ref, req, approve: true),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              backgroundColor: Personal2Colors.kids,
            ),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    RewardRequestRecord req, {
    required bool approve,
  }) async {
    // The brief: approving a reward needs the PIN. Rejecting it is also a
    // parent decision, so it is gated the same way — a child must not be able
    // to dismiss their own request to free the reservation.
    final allowed = await ParentLock.requirePin(
      context,
      reason: approve
          ? 'برای تأیید جایزه رمز والدین را وارد کنید'
          : 'برای رد درخواست رمز والدین را وارد کنید',
    );
    if (!allowed) return;
    await ref
        .read(kidsDaoProvider)
        .decideRewardRequest(requestId: req.id, approve: approve);
    ref.invalidate(kidsHomeProvider);
    ref.invalidate(kidDayProvider(req.kidId));
  }

  Widget _childShop(BuildContext context, WidgetRef ref, KidRecord child) {
    return Consumer(
      builder: (context, ref, _) {
        final t = TimeThemeKit.of(context).palette;
        final color = KidColors.of(child.colorKey);
        final day = ref.watch(kidDayProvider(child.id));

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: '${child.name} · فروشگاه ستاره‌ها', accent: color),
              const SizedBox(height: 6),
              day.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => FailureView(
                  id: 'kid_shop_${child.id}',
                  title: 'فروشگاه این فرزند خوانده نشد',
                  onRetry: () => ref.invalidate(kidDayProvider(child.id)),
                  layout: FailureLayout.inline,
                  error: e,
                ),
                data: (state) {
                  if (state == null) return const Text('—');
                  if (state.rewards.isEmpty) {
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'جایزه‌ای تعریف نشده.',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _addReward(context, ref, child, state),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('افزودن از پیشنهادها'),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Text(
                        'موجودی قابل خرج: ${state.spendable} ستاره',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: t.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final reward in state.rewards)
                        _rewardRow(context, ref, state, reward, color),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => _addReward(context, ref, child, state),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('افزودن جایزه'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rewardRow(
    BuildContext context,
    WidgetRef ref,
    KidDayState state,
    RewardRecord reward,
    Color color,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final pending = state.requests
        .where((r) => r.rewardId == reward.id &&
            r.status == RewardRequestStatus.requested)
        .firstOrNull;
    final progress = rewardProgress(
      cost: reward.costStars,
      available: state.spendable,
    );
    final affordable = state.spendable >= reward.costStars;

    final infoRow = Row(
          children: [
            DuotoneIconTile(
              accent: color,
              icon: KidIcons.of(reward.iconKey),
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // The price rides with the bar: it is part of what the
                  // reward is. As a fourth cell in the row it pushed the
                  // action off the card at 320 dp with the text at 1.3×.
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            height: 6,
                            child: Stack(
                              children: [
                                Container(
                                    color: t.outline.withValues(alpha: .3)),
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(color: color),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${reward.costStars} ★',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

    final action = pending != null
        ? TextButton(
            onPressed: () async {
              await ref.read(kidsDaoProvider).cancelRewardRequest(pending.id);
              ref.invalidate(kidDayProvider(state.kid.id));
              ref.invalidate(kidsHomeProvider);
            },
            child: const Text('لغو درخواست'),
          )
        : FilledButton.tonal(
            onPressed: affordable
                ? () => _requestReward(context, ref, state, reward)
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              affordable ? 'درخواست' : 'ادامه بده',
              style: const TextStyle(fontSize: 11),
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        // One row while there is room for the bar, the price and the action;
        // narrower than that the action moves under the title instead of
        // squeezing the title column to nothing.
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 300
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    infoRow,
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: action,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: infoRow),
                    const SizedBox(width: 8),
                    action,
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _requestReward(
    BuildContext context,
    WidgetRef ref,
    KidDayState state,
    RewardRecord reward,
  ) async {
    final result = await ref.read(kidsDaoProvider).requestReward(
          kidId: state.kid.id,
          rewardId: reward.id,
          costStars: reward.costStars,
          dayKey: state.dayKey,
          weeklyLimit: reward.weeklyLimit,
        );
    ref.invalidate(kidDayProvider(state.kid.id));
    ref.invalidate(kidsHomeProvider);
    if (result.error == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.error == 'insufficient'
              ? 'ستاره‌های کافی نداری.'
              : result.error == 'weekly_limit'
                  ? 'سقف هفتگی این جایزه پر شده است.'
                  : 'ثبت درخواست ممکن نشد.',
          style: TextStyle(fontFamily: AppTheme.fontFamily),
        ),
      ),
    );
  }

  Future<void> _addReward(
    BuildContext context,
    WidgetRef ref,
    KidRecord child,
    KidDayState state,
  ) async {
    final templates = await ref.read(personal2TemplatesProvider.future);
    if (!context.mounted) return;
    final t = TimeThemeKit.of(context).palette;
    final chosen = <String>{};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          height: MediaQuery.of(sheetContext).size.height * .72,
          decoration: BoxDecoration(
            color: t.elevated,
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'افزودن جایزه',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        for (final key in chosen) {
                          final tpl =
                              templates.rewards.firstWhere((r) => r.key == key);
                          await ref.read(kidsDaoProvider).saveReward(
                                id: 'rew_${child.id}_${tpl.key}',
                                kidId: child.id,
                                title: tpl.titleFa,
                                costStars: tpl.costStars,
                                iconKey: tpl.iconKey,
                                templateKey: tpl.key,
                              );
                        }
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        ref.invalidate(kidDayProvider(child.id));
                        ref.invalidate(kidsHomeProvider);
                      },
                      child: const Text('افزودن'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                  itemCount: templates.rewards.length,
                  itemBuilder: (context, i) {
                    final tpl = templates.rewards[i];
                    final selected = chosen.contains(tpl.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        borderColor: selected ? KidColors.of(child.colorKey) : null,
                        onTap: () => setSheetState(() {
                          if (selected) {
                            chosen.remove(tpl.key);
                          } else {
                            chosen.add(tpl.key);
                          }
                        }),
                        child: Row(
                          children: [
                            DuotoneIconTile(
                              accent: KidColors.of(child.colorKey),
                              icon: KidIcons.of(tpl.iconKey),
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tpl.titleFa,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13,
                                  color: t.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${tpl.costStars} ★',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                color: t.textSecondary,
                              ),
                            ),
                            if (selected)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(Icons.check_circle_rounded,
                                    size: 18,
                                    color: KidColors.of(child.colorKey)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
