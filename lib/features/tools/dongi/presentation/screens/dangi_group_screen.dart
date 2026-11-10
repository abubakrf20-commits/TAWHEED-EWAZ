import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/error/error_boundary.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_report.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement_text.dart';
import 'package:tawheeed/features/tools/dongi/presentation/widgets/dangi_settlement_share_card.dart';
import 'package:tawheeed/shared/services/share_widget_as_image.dart';
import 'package:tawheeed/features/tools/dongi/presentation/screens/dangi_report_screen.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';
import 'package:tawheeed/features/tools/dongi/presentation/widgets/dangi_form_sheets.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

const Color _accent = TopicHues.dangi;

class DangiGroupScreen extends ConsumerWidget {
  const DangiGroupScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dangiProvider);
    final loadError = state.loadError;
    final t = TimeThemeKit.of(context).palette;
    final group = state.groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => DangiGroupModel(
        id: groupId,
        name: 'گروه',
        colorHex: '#00ACC1',
        createdAt: DateTime.now(),
      ),
    );
    final members = state.membersOf(groupId);
    final expenses = state.expensesOf(groupId);
    final total = state.totalOf(groupId);
    final balances = DangiSettlement.balances(
      memberIds: [for (final m in members) m.id],
      expenses: [
        for (final e in expenses) (payerId: e.payerId, amount: e.amount),
      ],
      consumerSharesByIndex: {
        for (var i = 0; i < expenses.length; i++)
          if (expenses[i].consumers.isNotEmpty) i: expenses[i].consumers,
      },
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          title: group.name,
          actions: [
            IconButton(
              tooltip: 'گزارش و تاریخچهٔ هزینه‌ها',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AmbientBackground(
                      child: DangiReportScreen(groupId: groupId)),
                ),
              ),
              icon: const Icon(Icons.pie_chart_outline),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: !state.loaded
            ? loadError != null
                ? AppErrorDisplay(
                    error: loadError,
                    message: 'بارگذاری اطلاعات گروه ممکن نشد.',
                    onRetry: () => ref.read(dangiProvider.notifier).reload(),
                  )
                : const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Members header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 12, DsSpacing.page, 14),
                    color: _accent.withValues(alpha: 0.06),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m in members)
                              GestureDetector(
                                onLongPress: () =>
                                    _showMemberActions(context, ref, group, m),
                                child: Chip(
                                  avatar: CircleAvatar(
                                    backgroundColor:
                                        _accent.withValues(alpha: 0.2),
                                    child: Text(
                                      m.name.characters.first,
                                      style: TextStyle(
                                          color: _accent,
                                          fontSize: AppTheme.scaledFontSize(context, 13),
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  label: Text(m.name),
                                  labelStyle: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: AppTheme.scaledFontSize(context, 13)),
                                  backgroundColor: t.card,
                                  side: BorderSide(
                                      color: _accent.withValues(alpha: 0.3)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'مجموع هزینه‌ها: ${faMoney(total)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: t.textPrimary,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${en(members.length)} نفر',
                              style: TextStyle(
                                color: t.textMuted,
                                fontSize: AppTheme.scaledFontSize(context, 13),
                              ),
                            ),
                          ],
                        ),
                        if (expenses.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _BalanceChips(members: members, balances: balances),
                        ],
                      ],
                    ),
                  ),
                  // Expense list
                  Expanded(
                    child: expenses.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.receipt_long_outlined,
                            message: 'هزینه‌ای ثبت نشده',
                            subtitle:
                                'هزینه‌ها را ثبت کنید؛ در پایان دکمهٔ تسویه، بدهی هر نفر را محاسبه می‌کند.',
                            accent: _accent,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                DsSpacing.page, 12, DsSpacing.page, 16),
                            itemCount: expenses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final e = expenses[i];
                              final payer = members
                                  .where((m) => m.id == e.payerId)
                                  .firstOrNull;
                              return _ExpenseTile(
                                expense: e,
                                payerName: payer?.name ?? '—',
                                memberNames: {
                                  for (final m in members) m.id: m.name,
                                },
                                onEdit: () => showDangiExpenseSheet(
                                  context,
                                  ref,
                                  groupId,
                                  members,
                                  expense: e,
                                ),
                                onDelete: () =>
                                    _confirmDeleteExpense(context, ref, e),
                              );
                            },
                          ),
                  ),
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.page, 8, DsSpacing.page, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: members.isEmpty
                        ? null
                        : () => showDangiExpenseSheet(
                            context, ref, groupId, members),
                    icon: const Icon(Icons.add),
                    label: const Text('هزینه جدید'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: BorderSide(color: _accent.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: members.isEmpty || expenses.isEmpty
                        ? null
                        : () => _showSettlement(context, ref, groupId,
                            group.name, members, expenses),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('تسویه'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Long-press on a member: rename (keeps expenses) or remove (removes
  /// their expenses too).
  void _showMemberActions(BuildContext context, WidgetRef ref,
      DangiGroupModel group, DangiMemberModel member) {
    final danger = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkError
        : AppTheme.lightError;
    showModalBottomSheet(
      context: context,
      backgroundColor: TimeThemeKit.of(context).palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _accent.withValues(alpha: 0.2),
                child: Text(member.name.characters.first,
                    style: const TextStyle(color: _accent)),
              ),
              title: Text(member.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: _accent),
              title: const Text('تغییر نام'),
              subtitle: const Text('هزینه‌های او حفظ می‌شود'),
              onTap: () async {
                Navigator.pop(ctx);
                final newName = await _promptRename(context, member.name);
                if (newName == null || newName.trim().isEmpty) return;
                await ref
                    .read(dangiProvider.notifier)
                    .renameMember(member.id, group.id, newName.trim());
              },
            ),
            ListTile(
              leading: Icon(Icons.person_remove_outlined,
                  color: danger.withValues(alpha: 0.8)),
              title: Text('حذف عضو', style: TextStyle(color: danger)),
              onTap: () async {
                Navigator.pop(ctx);
                await _confirmDeleteMember(context, ref, group, member);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptRename(BuildContext context, String current) {
    final ctrl = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TimeThemeKit.of(ctx).palette.card,
        title: const Text('تغییر نام عضو'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(hintText: 'نام جدید'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  Future<void> _confirmDeleteMember(BuildContext context, WidgetRef ref,
      DangiGroupModel group, DangiMemberModel member) async {
    final state = ref.read(dangiProvider);
    final hasExpenses =
        state.expensesOf(group.id).any((e) => e.payerId == member.id);
    // Capture messenger + notifier before the dialog: the «بازگردانی» action
    // outlives this method and must not use a stale `ref`/`context`.
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
          title: const Text('حذف عضو؟'),
          content: Text(
            hasExpenses
                ? '«${member.name}» و هزینه‌های پرداخت‌شده توسط او حذف می‌شود.'
                : '«${member.name}» حذف شود؟',
            textAlign: TextAlign.center,
          ),
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
      final snapshot = await notifier.deleteMember(member.id, group.id);
      if (snapshot == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('«${member.name}» حذف شد'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'بازگردانی',
            onPressed: () => notifier.restoreMember(snapshot),
          ),
        ));
    }
  }

  Future<void> _confirmDeleteExpense(
      BuildContext context, WidgetRef ref, DangiExpenseModel expense) async {
    // Capture messenger + notifier before any async gap: the snackbar's
    // «بازگردانی» action outlives this dialog, and reading `ref` or using
    // `context` after the screen unmounts throws.
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
          title: const Text('حذف هزینه؟'),
          content: Text(
            '«${expense.title}» '
            'به مبلغ ${faMoney(expense.amount)} حذف شود؟',
            textAlign: TextAlign.center,
          ),
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
      await notifier.deleteExpense(expense.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('«${expense.title}» حذف شد'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'بازگردانی',
            onPressed: () => notifier.updateExpense(expense),
          ),
        ));
    }
  }

  void _showSettlement(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String groupName,
    List<DangiMemberModel> members,
    List<DangiExpenseModel> expenses,
  ) {
    final transfers = DangiSettlement.settle(
      memberIds: [for (final m in members) m.id],
      expenses: [
        for (final e in expenses) (payerId: e.payerId, amount: e.amount)
      ],
      consumerSharesByIndex: {
        for (var i = 0; i < expenses.length; i++)
          if (expenses[i].consumers.isNotEmpty) i: expenses[i].consumers,
      },
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TimeThemeKit.of(context).palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettlementSheet(
        groupId: groupId,
        groupName: groupName,
        members: members,
        transfers: transfers,
        // Settlement rows are transfers, not spendings — the header total
        // must not count them a second time.
        total: expenses
            .where((e) => !isDangiSettlement(e))
            .fold(0.0, (sum, e) => sum + e.amount),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.payerName,
    required this.onEdit,
    required this.onDelete,
    this.memberNames = const {},
  });

  final DangiExpenseModel expense;
  final String payerName;
  final Map<String, String> memberNames;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _name(String id) => memberNames[id] ?? id;

  /// «علی: 200 · رضا: 300» — the per-member consumed amounts of this expense.
  String get _consumersLabel {
    final parts = <String>[];
    expense.consumers.forEach((id, amt) {
      parts.add('${_name(id)}: ${faMoney(amt)}');
    });
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = TimeThemeKit.of(context).palette.textPrimary;
    final mutedColor = TimeThemeKit.of(context).palette.textMuted;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    // A recorded settlement is a transfer, not a spending — keep it visually
    // distinct from real expenses in the group history.
    final isSettlement = isDangiSettlement(expense);
    final tileAccent = isSettlement ? AppTheme.success : _accent;

    return AppCard(
      onLongPress: onEdit,
      padding: const EdgeInsets.all(12),
      radius: 14,
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tileAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSettlement ? Icons.handshake_outlined : Icons.receipt_outlined,
              color: tileAccent,
              size: 20,
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
                        expense.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ),
                    if (isSettlement) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: tileAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'تسویه',
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w700,
                            color: tileAccent,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'پرداخت‌کننده: $payerName',
                  style: TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 12)),
                ),
                if (expense.consumers.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _consumersLabel,
                    style: TextStyle(
                      color: _accent.withValues(alpha: 0.85),
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                faMoney(expense.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _accent,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'ویرایش',
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined,
                        size: 18, color: _accent.withValues(alpha: 0.7)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: danger.withValues(alpha: 0.6)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceChips extends StatelessWidget {
  const _BalanceChips({required this.members, required this.balances});

  final List<DangiMemberModel> members;
  final Map<String, double> balances;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = TimeThemeKit.of(context).palette.textPrimary;
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in members)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m.name,
                  style: TextStyle(
                    color: textColor,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatBalance(balances[m.id] ?? 0),
                  style: TextStyle(
                    color: (balances[m.id] ?? 0) >= -0.005
                        ? Colors.green.shade700
                        : Colors.red.shade600,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w800,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatBalance(double v) {
    if (v.abs() < 0.005) return '0';
    final s = faMoney(v.abs());
    return v > 0 ? '+$s' : '−$s';
  }
}

class _SettlementSheet extends ConsumerWidget {
  const _SettlementSheet({
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.transfers,
    required this.total,
  });

  final String groupId;
  final String groupName;
  final List<DangiMemberModel> members;
  final List<SettlementTransfer> transfers;
  final double total;

  /// «ثبت تسویه» accent — a settled account reads as success, not spending.
  static const Color settlementGreen = AppTheme.success;

  String _name(String id) =>
      members.where((m) => m.id == id).firstOrNull?.name ?? id;

  /// Records the drawn-up transfers in the database: every balance becomes
  /// zero and the group history keeps what was paid to whom. The snackbar
  /// offers «لغو» which deletes the whole batch again.
  Future<void> _record(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    // Capture the notifier now: the snackbar's «لغو» action outlives this
    // sheet, and using `ref` after the sheet unmounts throws.
    final notifier = ref.read(dangiProvider.notifier);
    final ids = await notifier.settleGroup(groupId);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ids.isEmpty
            ? 'چیزی برای تسویه نمانده است'
            : 'تسویه ثبت شد (${en(ids.length)} انتقال)'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'لغو',
          onPressed: () => notifier.undoSettlement(ids),
        ),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: mutedColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('تسویهٔ هزینه‌ها',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 17),
                    fontWeight: FontWeight.bold,
                    color: _accent,
                    fontFamily: AppTheme.fontFamily)),
            const SizedBox(height: 6),
            Text('مجموع: ${faMoney(total)}',
                style: TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 13))),
            const SizedBox(height: 16),
            if (transfers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text('همه چیز تسویه است — بدهی‌ای نیست!',
                        style: TextStyle(color: textColor)),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: transfers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final t = transfers[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: _accent.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_downward,
                              color: _accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: _name(t.fromId),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const TextSpan(text: ' به '),
                                  TextSpan(
                                    text: _name(t.toId),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const TextSpan(text: '  '),
                                  TextSpan(
                                    text: faMoney(t.amount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _accent),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                color: textColor,
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (transfers.isNotEmpty) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('dangi_record_settlement'),
                  style: FilledButton.styleFrom(
                    backgroundColor: settlementGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _record(context, ref),
                  icon: const Icon(Icons.handshake_outlined, size: 18),
                  label: const Text('ثبت تسویه'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'با ثبت تسویه، انتقال‌های بالا ذخیره و بدهی همه صفر می‌شود.',
                style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11), color: mutedColor),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: BorderSide(color: _accent.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _shareText(context),
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: const Text('اشتراک متن'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _shareImage(context),
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('اشتراک تصویر'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _shareText(BuildContext context) async {
    final text = buildSettlementShareText(
      groupName: groupName,
      members: members,
      transfers: transfers,
      total: total,
    );
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      AppLogger.warning('dangi_group_screen', 'error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اشتراک‌گذاری متن ممکن نشد؛ دوباره تلاش کنید.')),
        );
      }
    }
  }

  Future<void> _shareImage(BuildContext context) async {
    try {
      await shareWidgetAsImage(
        context,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: DangiSettlementShareCard(
            groupName: groupName,
            members: members,
            transfers: transfers,
            total: total,
          ),
        ),
        fileName:
            'dangi_settlement_${DateTime.now().millisecondsSinceEpoch}.png',
        text: 'تسویهٔ هزینه‌های گروه «$groupName»',
      );
    } catch (e) {
      AppLogger.warning('dangi_group_screen', 'error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ساخت تصویر ممکن نشد؛ دوباره تلاش کنید.')),
        );
      }
    }
  }
}
