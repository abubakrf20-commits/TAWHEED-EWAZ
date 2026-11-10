import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/error/error_boundary.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_report.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/features/tools/dongi/presentation/dangi_colors.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';
import 'package:tawheeed/features/tools/dongi/presentation/screens/dangi_group_screen.dart';
import 'package:tawheeed/features/tools/dongi/presentation/widgets/dangi_form_sheets.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

class DangiScreen extends ConsumerWidget {
  const DangiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dangiProvider);
    final loadError = state.loadError;
    const accent = TopicHues.dangi;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          title: 'دنگی',
          actions: [
            IconButton(
              tooltip: 'افزودن گروه',
              icon: const Icon(Icons.add),
              onPressed: () => showDangiGroupFormSheet(context, ref),
            ),
          ],
        ),
        body: !state.loaded
            ? loadError != null
                ? AppErrorDisplay(
                    error: loadError,
                    message: 'بارگذاری اطلاعات دنگی ممکن نشد.',
                    onRetry: () => ref.read(dangiProvider.notifier).reload(),
                  )
                : const Center(child: CircularProgressIndicator())
            : state.groups.isEmpty
                ? _EmptyState(
                    accent: accent,
                    onCreate: () {
                      showDangiGroupFormSheet(context, ref);
                    })
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 8, DsSpacing.page, 32),
                    itemCount: state.groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final g = state.groups[i];
                      final color = dangiColorFromHex(g.colorHex);
                      final members = state.membersOf(g.id);
                      final total = state.totalOf(g.id);
                      return _GroupCard(
                        group: g,
                        color: color,
                        memberCount: members.length,
                        total: total,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AmbientBackground(
                                  child: DangiGroupScreen(groupId: g.id)),
                            ),
                          );
                        },
                        onEdit: () =>
                            showDangiGroupFormSheet(context, ref, group: g),
                        onDelete: () => _confirmDelete(context, ref, g),
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, DangiGroupModel g) async {
    // Capture messenger + notifier before the dialog: the snackbar's
    // «بازگردانی» action outlives this method and must not touch a dead `ref`.
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(dangiProvider.notifier);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final danger = Theme.of(ctx).brightness == Brightness.dark
            ? AppTheme.darkError
            : AppTheme.lightError;
        return AlertDialog(
          backgroundColor: TimeThemeKit.of(ctx).palette.card,
          title: const Text('حذف گروه؟'),
          content: Text('گروه «${g.name}» با همهٔ اعضا و هزینه‌ها حذف شود؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('حذف', style: TextStyle(color: danger)),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      final snapshot = await notifier.deleteGroup(g.id);
      if (snapshot == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('گروه «${g.name}» حذف شد'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'بازگردانی',
            onPressed: () => notifier.restoreGroup(snapshot),
          ),
        ));
    }
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.color,
    required this.memberCount,
    required this.total,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final DangiGroupModel group;
  final Color color;
  final int memberCount;
  final double total;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: 16,
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.groups, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontWeight: FontWeight.bold,
                    color: t.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${en(memberCount)} نفر · مجموع: ${faMoney(total)}',
                  style: TextStyle(color: t.textMuted, fontSize: AppTheme.scaledFontSize(context, 13)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, size: 20, color: t.textMuted),
            visualDensity: VisualDensity.compact,
            tooltip: 'ویرایش',
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline,
                size: 20, color: danger.withValues(alpha: 0.7)),
            visualDensity: VisualDensity.compact,
            tooltip: 'حذف',
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.accent, required this.onCreate});
  final Color accent;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.groups_outlined,
      message: 'هنوز گروهی ندارید',
      subtitle:
          'یک گروه بسازید (مثلاً «سفر شیراز»)، اعضا را اضافه کنید و هزینه‌ها را ثبت کنید تا در پایان تسویه محاسبه شود.',
      accent: accent,
      actionLabel: 'ساخت گروه',
      onAction: onCreate,
    );
  }
}
