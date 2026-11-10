import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/features/personal2/kids/presentation/providers/kids_providers.dart';
import 'package:tawheeed/features/personal2/shared/parent_lock.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// «صف تأیید» — pending habit and prayer logs, with bulk approve.
///
/// The brief asks for the PIN once per session with a 5-minute window. The
/// window is tracked here (the screen's own state) and the verification itself
/// is [ParentLock], so there is still exactly one PIN implementation.
class KidsApprovalsScreen extends ConsumerStatefulWidget {
  const KidsApprovalsScreen({super.key});

  @override
  ConsumerState<KidsApprovalsScreen> createState() =>
      _KidsApprovalsScreenState();
}

class _KidsApprovalsScreenState extends ConsumerState<KidsApprovalsScreen> {
  /// When the current approval session expires. Null = not unlocked.
  DateTime? _unlockedUntil;

  static const Duration _sessionWindow = Duration(minutes: 5);

  Future<bool> _ensureUnlocked({String? reason}) async {
    final until = _unlockedUntil;
    if (until != null && DateTime.now().isBefore(until)) return true;
    final allowed = await ParentLock.requirePin(
      context,
      reason: reason ?? 'برای تأیید کارها رمز والدین را وارد کنید',
    );
    if (!allowed) return false;
    if (mounted) {
      setState(() => _unlockedUntil = DateTime.now().add(_sessionWindow));
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(kidsHomeProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          title: 'صف تأیید',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
          actions: [
            if (home.value?.pendingApprovals.isNotEmpty ?? false)
              TextButton(
                onPressed: () => _approveAll(home.value!.pendingApprovals),
                child: const Text('تأیید همه'),
              ),
          ],
        ),
        body: SafeArea(
          child: home.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FailureView(
              id: 'kids_approvals_load',
              title: 'کارهای در انتظار تأیید باز نشد',
              detail: 'درخواست‌ها پاک نشده‌اند؛ فقط این فهرست باز نشد.',
              onRetry: () => ref.invalidate(kidsHomeProvider),
              layout: FailureLayout.page,
              error: e,
            ),
            data: (data) {
              final pending = data.pendingApprovals;
              if (pending.isEmpty) {
                return AppEmptyState(
                  icon: Icons.task_alt_rounded,
                  accent: KidColors.of('orange'),
                  message: 'چیزی برای تأیید نیست',
                  subtitle: 'وقتی کاری به تأیید شما نیاز داشته باشد اینجا می‌آید.',
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    DsSpacing.page, 12, DsSpacing.page, 40),
                children: [
                  for (final log in pending) _row(context, data, log),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, KidsHomeState data, KidLogRecord log) {
    final t = TimeThemeKit.of(context).palette;
    final child = data.children.where((c) => c.id == log.kidId).firstOrNull;
    final color = KidColors.of(child?.colorKey ?? 'orange');
    final what = log.habitId != null ? 'عادت' : 'نماز';
    // A log row stores only `habit_id`. Printing it would put «سارا · hab_1729…»
    // in the queue the parent approves from, so the habit's own title is read
    // (and falls back to the id only while that read is in flight).
    final habits =
        ref.watch(kidHabitsProvider(log.kidId)).value ?? const <HabitSpec>[];
    final habitTitle = log.habitId == null
        ? null
        : habits.where((h) => h.id == log.habitId).firstOrNull?.title;
    final title = habitTitle ?? log.prayer?.titleFa ?? (log.habitId ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                (child?.name ?? '?').characters.first,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
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
                  Text(
                    '${child?.name ?? 'کودک'} · $title',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  Text(
                    '$what · ${log.stars} ستاره${log.late ? ' · بعد از وقت' : ''}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'رد',
              icon: Icon(Icons.close_rounded,
                  size: 20, color: DsStatus.danger(context)),
              onPressed: () => _decide(log, approve: false),
            ),
            IconButton(
              tooltip: 'تأیید',
              icon: Icon(Icons.check_rounded, size: 20, color: color),
              onPressed: () => _decide(log, approve: true),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(KidLogRecord log, {required bool approve}) async {
    if (!await _ensureUnlocked()) return;
    await ref
        .read(kidsDaoProvider)
        .decideLog(logId: log.id, approve: approve);
    ref.invalidate(kidsHomeProvider);
    ref.invalidate(kidDayProvider(log.kidId));
  }

  Future<void> _approveAll(List<KidLogRecord> pending) async {
    if (!await _ensureUnlocked(reason: 'برای تأیید همه رمز والدین را وارد کنید')) {
      return;
    }
    final dao = ref.read(kidsDaoProvider);
    for (final log in pending) {
      await dao.decideLog(logId: log.id, approve: true);
    }
    ref.invalidate(kidsHomeProvider);
    for (final kidId in pending.map((l) => l.kidId).toSet()) {
      ref.invalidate(kidDayProvider(kidId));
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
