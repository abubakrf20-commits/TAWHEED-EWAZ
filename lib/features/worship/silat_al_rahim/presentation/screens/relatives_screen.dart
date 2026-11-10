import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_repository.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_providers.dart';
import 'package:tawheeed/features/personal/family_faith/presentation/family_faith_style.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/presentation/screens/relatives_sheets.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// «صله رحم» — one page, no hub. Reached from the single tile in
/// «اطلاعات من» inside the vault.
///
/// The page answers three questions without opening anything: who is overdue,
/// what the last month looked like, and — per person — when the last call,
/// visit and gift happened. Birthdays are deliberately absent (2026-11-07):
/// the reminder line, the gift occasions and this page are Islamic or
/// ordinary family life only.
class RelativesScreen extends ConsumerStatefulWidget {
  const RelativesScreen({super.key, this.nowOverride});

  /// Test seam: pins «today» for the status chips and the goldens.
  final DateTime? nowOverride;

  @override
  ConsumerState<RelativesScreen> createState() => _RelativesScreenState();
}

class _RelativesScreenState extends ConsumerState<RelativesScreen> {
  bool _showArchived = false;

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  /// The window the «اخیر» counters use. One month is what people mean by
  /// «این اواخر», and it keeps the chip honest as the log grows.
  static const int _recentWindowDays = 30;

  @override
  Widget build(BuildContext context) {
    // The header belongs to this page, not to the time-of-day palette: it
    // takes the same pink ink the cards and chips below it are drawn in, so
    // the bar and the content read as one tool. `dsContentColor` keeps that
    // hue legible on the day and night papers alike.
    // The pushed-page chrome is the shared one now: the bar takes the section's
    // own ink, so the title, the back arrow and the band below it are drawn in
    // the same hue as the section's tile.
    final async = ref.watch(relativesStoreProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          accent: familyRelativeColor,
          title: 'صله رحم',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'تنظیم یادآوری‌ها',
              icon: const Icon(Icons.tune),
              onPressed: () => showFamilySettingsSheet(context, ref),
            ),
            IconButton(
              tooltip: 'افزودن',
              icon: const Icon(Icons.add),
              onPressed: () => showRelativeSheet(context),
            ),
          ],
        ),
        body: SafeArea(
          child: switch (async) {
            AsyncData(:final value) => _body(value),
            AsyncError(:final error) => FailureView(
                id: 'relatives_list',
                title: 'خواندن فهرست ممکن نشد',
                detail: 'فهرست خویشاوندان و یادآوری‌هایتان پاک نشده‌اند؛ '
                    'فقط خواندنشان ناموفق بود.',
                onRetry: () => ref.invalidate(relativesStoreProvider),
                error: error,
                layout: FailureLayout.page,
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  Widget _body(RelativesSnapshot snapshot) {
    final now = _now;
    final active = snapshot.active;
    final archived = [
      for (final relative in snapshot.relatives)
        if (relative.archived) relative,
    ];

    var overdue = 0;
    var recentVisits = 0;
    var recentGifts = 0;
    final since = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: _recentWindowDays));
    for (final relative in active) {
      final period = relativeStatus(relative, now: now);
      if (period.state == RelativeState.overdue) overdue++;
      final summary = RelativeContactSummary.from(
        snapshot.contactsFor(relative.id),
        recentSince: since,
      );
      recentVisits += summary.recent(ContactKind.visit);
      recentGifts += summary.recent(ContactKind.gift);
    }

    if (active.isEmpty && archived.isEmpty) {
      return ListView(
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 24, DsSpacing.page, 40),
        children: [
          AppEmptyState(
            accent: familyRelativeColor,
            icon: Icons.favorite_outline,
            message: 'هنوز کسی را اضافه نکرده‌اید',
            subtitle:
                'نام پدر و والدین و نزدیکان را اضافه کنید تا یادآوری تماس و '
                'دیدارها را به شما بسپاریم. شماره‌ها فقط روی همین گوشی می‌مانند.',
            actionLabel: 'افزودن نخستین نفر',
            onAction: () => showRelativeSheet(context),
          ),
        ],
      );
    }

    final visible = _showArchived ? archived : active;
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 6, DsSpacing.page, 32),
      children: [
        _RelativesHero(
          overdue: overdue,
          activeCount: active.length,
          recentVisits: recentVisits,
          recentGifts: recentGifts,
        ),
        const SizedBox(height: 12),
        // Nothing archived yet means the toggle would only open an empty page;
        // it appears as the header's trailing action once there is something
        // to return to.
        SectionHeader(
          title: _showArchived ? 'بایگانی' : 'خویشاوندان',
          accent: familyRelativeColor,
          count: '${visible.length}',
          trailing: archived.isEmpty && !_showArchived
              ? null
              : TextButton(
                  onPressed: () =>
                      setState(() => _showArchived = !_showArchived),
                  child: Text(
                    _showArchived
                        ? 'نمایش افراد فعال (${active.length})'
                        : 'بایگانی (${archived.length})',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                    ),
                  ),
                ),
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _showArchived
                  ? 'کسی در بایگانی نیست.'
                  : 'همهٔ افراد بایگانی شده‌اند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: TimeThemeKit.of(context).palette.textMuted,
              ),
            ),
          )
        else
          for (final relative in visible) ...[
            _RelativeCard(
              relative: relative,
              now: now,
              summary: RelativeContactSummary.from(
                snapshot.contactsFor(relative.id),
                recentSince: since,
              ),
              onCall: () => _contact(relative, ContactKind.call),
              onMessage: () => _contact(relative, ContactKind.message),
              onGift: () => showGiftSheet(context, relative),
              onVisit: () => _contact(relative, ContactKind.visit),
              onHistory: () => showRelativeHistorySheet(context, relative),
              onEdit: () => showRelativeSheet(context, relative: relative),
              onSnooze: () => _snooze(relative),
              onToggleMute: () =>
                  ref.read(relativesStoreProvider.notifier).setMuted(
                        relative,
                        !relative.muted,
                      ),
              onArchive: () =>
                  ref.read(relativesStoreProvider.notifier).setArchived(
                        relative,
                        !relative.archived,
                      ),
              onDelete: () => _confirmDelete(relative),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Future<void> _contact(Relative relative, ContactKind kind) async {
    final store = ref.read(relativesStoreProvider.notifier);
    final launcher = ref.read(familyUriLauncherProvider);
    final phone = relative.phone.trim();
    final previous = relative.lastContactAt;

    if (kind == ContactKind.call || kind == ContactKind.message) {
      if (phone.isEmpty) {
        _snack('برای این نفر شماره‌ای ثبت نشده است؛ از «ویرایش» اضافه کنید.');
        return;
      }
      final uri = kind == ContactKind.call
          ? Uri(scheme: 'tel', path: phone)
          : Uri(scheme: 'sms', path: phone);
      var opened = false;
      try {
        opened = await launcher(uri);
      } catch (e) {
        AppLogger.warning('Relatives', 'launch failed: $e');
      }
      if (!opened) {
        // The dialer never opened, so no conversation happened. Refreshing the
        // cycle here would tick a call the user never made.
        if (!mounted) return;
        _snack('باز کردن ${kind.labelFa} ممکن نشد؛ چیزی ثبت نشد.');
        return;
      }
    }

    ContactLog? contact;
    try {
      contact = await store.logContact(relative: relative, kind: kind);
    } catch (e) {
      AppLogger.warning('Relatives', 'contact log failed: $e');
      if (!mounted) return;
      _snack('ثبت ${kind.labelFa} ممکن نشد؛ دوباره تلاش کنید.');
      return;
    }
    if (!mounted) return;
    _snack(
      '${kind.labelFa} ثبت شد ✓',
      onUndo: contact == null
          ? null
          : () => store.undoContact(
                relative: relative,
                contact: contact!,
                previousLastContact: previous,
              ),
    );
  }

  Future<void> _snooze(Relative relative) async {
    final choice = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final t = TimeThemeKit.of(sheetContext).palette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'تا کِی به تعویق بیفتد؟',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in const [
                    ('یک هفته', Duration(days: 7)),
                    ('دو هفته', Duration(days: 14)),
                    ('یک ماه', Duration(days: 30)),
                  ])
                    ListTile(
                      dense: true,
                      title: Text(entry.$1),
                      onTap: () => Navigator.of(sheetContext).pop(entry.$2),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (choice == null) return;
    await ref.read(relativesStoreProvider.notifier).snooze(relative, choice);
  }

  Future<void> _confirmDelete(Relative relative) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف کامل؟'),
        content: Text(
          '«${relative.name}» و تاریخچهٔ تماس‌هایش حذف می‌شود. '
          'اگر فقط می‌خواهید از فهرست خارج شود، «بایگانی» را انتخاب کنید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(relativesStoreProvider.notifier).deleteRelative(relative.id);
    if (!mounted) return;
    _snack('«${relative.name}» حذف شد');
  }

  void _snack(String message, {VoidCallback? onUndo}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: onUndo == null
            ? null
            : SnackBarAction(label: 'بازگردانی', onPressed: onUndo),
      ));
  }
}

/// The page's one headline: how many calls are overdue, and what the last
/// month actually held. It is the same flat accent band the other tool pages
/// carry — one solid fill, no gradient, white ink — so the bar and the band
/// read as a single tool instead of two tinted chips floating over the page.
class _RelativesHero extends StatelessWidget {
  const _RelativesHero({
    required this.overdue,
    required this.activeCount,
    required this.recentVisits,
    required this.recentGifts,
  });

  final int overdue;
  final int activeCount;
  final int recentVisits;
  final int recentGifts;

  @override
  Widget build(BuildContext context) {
    final recent = recentVisits + recentGifts;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dsContentColor(context, familyRelativeColor),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: .9),
              ),
              const SizedBox(width: 6),
              Text(
                'یادآوری',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: .95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            overdue == 0 ? 'همه به‌روز' : '$overdue تماس عقب‌افتاده',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 21),
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          _heroChip(
            context,
            overdue == 0
                ? Icons.check_circle_outline
                : Icons.call_missed_outgoing,
            overdue == 0
                ? 'هیچ خویشاوندی از یادآوری عقب نیست'
                : 'این عزیزان منتظر یک تماس‌اند',
          ),
          const SizedBox(height: 6),
          _heroChip(
            context,
            Icons.insights_outlined,
            recent == 0
                ? 'در ۳۰ روز اخیر دیداری ثبت نشده'
                : '$recentVisits دیدار · $recentGifts هدیه در ۳۰ روز',
          ),
          const SizedBox(height: 6),
          _heroChip(
            context,
            Icons.people_outline,
            activeCount == 0 ? 'فهرست خالی است' : '$activeCount نفر در فهرست',
          ),
        ],
      ),
    );
  }

  /// One fact per line, full width: the 30-day sentence is long enough that a
  /// side-by-side pair overflows at 320 dp with large text, and a clipped
  /// sentence is worse than a taller band.
  Widget _heroChip(BuildContext context, IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: .95)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 10.5),
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelativeCard extends StatelessWidget {
  const _RelativeCard({
    required this.relative,
    required this.now,
    required this.summary,
    required this.onCall,
    required this.onMessage,
    required this.onGift,
    required this.onVisit,
    required this.onHistory,
    required this.onEdit,
    required this.onSnooze,
    required this.onToggleMute,
    required this.onArchive,
    required this.onDelete,
  });

  final Relative relative;
  final DateTime now;
  final RelativeContactSummary summary;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback onGift;
  final VoidCallback onVisit;
  final VoidCallback onHistory;
  final VoidCallback onEdit;
  final VoidCallback onSnooze;
  final VoidCallback onToggleMute;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final accent = relativeAvatarColor(relative.id);
    final period = relativeStatus(relative, now: now);

    final lastText = relative.lastContactAt == null
        ? 'هنوز ارتباطی ثبت نشده'
        : 'آخرین ارتباط: ${careJalaliLong(relative.lastContactAt!)}';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onHistory,
            borderRadius: BorderRadius.circular(12),
            // Column, not Row: the date line and the history line belong to
            // the whole card. Inside the name column they had ~120 dp next to
            // the status chip, so «هر ۷ روز» wrapped onto a line of its own
            // and the history trailed off in an ellipsis.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A solid disc, like every other tool row in the app: the
                    // tinted, bordered circle was the only avatar of its kind left.
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        relativeInitial(relative.name),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 15),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  relative.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 13.5),
                                    fontWeight: FontWeight.w700,
                                    color: t.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: t.surfaceAlt,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  relative.displayRelation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 10),
                                    color: t.textMuted,
                                  ),
                                ),
                              ),
                              if (relative.muted)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(Icons.notifications_off_outlined,
                                      size: 13, color: t.textMuted),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: CareStatusChip(
                          level: switch (period.state) {
                            RelativeState.ok => CareStatusLevel.good,
                            RelativeState.dueSoon => CareStatusLevel.near,
                            RelativeState.overdue => CareStatusLevel.overdue,
                          },
                          label: period.chipLabel,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: 'بیشتر',
                      onSelected: (value) => switch (value) {
                        'history' => onHistory(),
                        'edit' => onEdit(),
                        'snooze' => onSnooze(),
                        'mute' => onToggleMute(),
                        'archive' => onArchive(),
                        _ => onDelete(),
                      },
                      itemBuilder: (menuContext) => [
                        const PopupMenuItem(
                            value: 'history', child: Text('تاریخچه و آمار')),
                        const PopupMenuItem(
                            value: 'edit', child: Text('ویرایش')),
                        const PopupMenuItem(
                            value: 'snooze', child: Text('به تعویق انداختن')),
                        PopupMenuItem(
                          value: 'mute',
                          child: Text(
                            relative.muted
                                ? 'روشن کردن یادآوری'
                                : 'یادآوری خاموش',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(
                              relative.archived ? 'بازگرداندن' : 'بایگانی'),
                        ),
                        const PopupMenuItem(
                            value: 'delete', child: Text('حذف')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$lastText · هر ${relative.intervalDays} روز',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                _ContactHistoryLine(summary: summary, now: now),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              children: [
                Expanded(
                  child: _ActionPill(
                    icon: Icons.call_outlined,
                    label: 'تماس',
                    onTap: onCall,
                    accent: familyRelativeColor,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionPill(
                    icon: Icons.chat_bubble_outline,
                    label: 'پیام',
                    onTap: onMessage,
                    accent: familyRelativeColor,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionPill(
                    icon: Icons.directions_walk,
                    label: 'دیدار',
                    onTap: onVisit,
                    accent: familyRelativeColor,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionPill(
                    icon: Icons.card_giftcard_outlined,
                    label: 'هدیه',
                    onTap: onGift,
                    accent: familyRelativeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One compact line with the last visit and the last gift — the two facts the
/// user asked to see per person. Missing ones stay honest («ثبت نشده»).
class _ContactHistoryLine extends StatelessWidget {
  const _ContactHistoryLine({required this.summary, required this.now});

  final RelativeContactSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final visit = summary.lastVisit;
    final gift = summary.lastGift;
    final parts = <String>[
      if (visit != null)
        'دیدار: ${daysAgoLabel(visit.date, now)}'
      else
        'دیداری ثبت نشده',
      if (gift != null)
        'هدیه: ${gift.note.isEmpty ? daysAgoLabel(gift.date, now) : gift.note}'
      else
        'هدیه‌ای ثبت نشده',
    ];
    return Row(
      children: [
        Icon(Icons.history, size: 12, color: t.textMuted),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            parts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10.5),
              color: t.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
        ),
        // Scale the pair down instead of ellipsising the label: at 412 dp with
        // the Persian face, «تماس» was cut to «ما» in its quarter of the row,
        // and a pill that hides its own verb is worse than a smaller one.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: dsContentColor(context, accent)),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: dsContentColor(context, accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
