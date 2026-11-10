import 'package:flutter/material.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_section_hues.dart';
import 'package:tawheeed/features/settings/services/storage_insights_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';

/// «مدیریت فضا» — the app's own storage, measured and safely reclaimable.
///
/// Rows are clearable exactly when the app can fetch the bytes again — the
/// downloaded content databases included, each cleared through its own
/// section's service. Personal attachments and local backups are measured but
/// never cleared here: they exist nowhere else, so they stay in their own
/// sections and the page says so in their subtitles.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key, this.service});

  /// Test seam; the page builds its own service in production.
  final StorageInsightsService? service;

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  late final StorageInsightsService _service =
      widget.service ?? StorageInsightsService();

  StorageReport? _report;
  bool _loading = true;
  bool _failed = false;
  String? _clearingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_report != null && mounted) setState(() => _loading = true);
    try {
      final report = await _service.measure();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      AppLogger.warning('StorageScreen', 'measure failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _confirmClear(StorageItemUsage item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'پاک کردن «${item.title}»؟',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(dialogContext, 16),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '${item.subtitle}\n\n'
          '${NumberFormat.formatBytes(item.bytes)} آزاد می‌شود.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(dialogContext, 13),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          // U6-P2-4/U6-05: the destructive action wears the error colors and
          // carries an explicit semantics hint — a plain accent-colored
          // button next to «انصراف» read as the safe default.
          Semantics(
            button: true,
            hint: 'داده‌هایی که برنامه دوباره دانلود می‌کند حذف می‌شوند',
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(dialogContext).colorScheme.error,
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('پاک کن'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearingId = item.id);
    final cleared = await _service.clear(item.id);
    if (!mounted) return;
    setState(() => _clearingId = null);
    if (cleared) {
      AppSnackBar.success(context, '«${item.title}» پاک شد.');
      await _load();
    } else {
      AppSnackBar.error(context, 'پاک کردن «${item.title}» ناموفق بود.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SettingsAppBar(title: 'مدیریت فضا'),
      body: _buildBody(context, t),
    );
  }

  Widget _buildBody(BuildContext context, AppPalette t) {
    final report = _report;
    if (report == null) {
      if (_loading) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        );
      }
      // A failed read and an empty report are two different statements, and
      // this branch used to make one panel say both — «خواندن حجم داده‌ها ممکن
      // نشد.» next to a «تلاش دوباره» button that a reader with genuinely no
      // data would press forever. The empty case has nothing to retry.
      if (_failed) {
        return FailureView(
          id: 'storage_load',
          title: 'خواندن حجم داده‌ها ممکن نشد',
          detail: 'داده‌ای پاک نشده است؛ فقط اندازه‌گیری انجام نشد.',
          onRetry: _loading ? null : _load,
          layout: FailureLayout.page,
        );
      }
      // Nothing stored is not a failure, so it does not get the failure panel.
      return AppEmptyState(
        icon: Icons.pie_chart_outline_rounded,
        message: 'داده‌ای برای نمایش پیدا نشد',
        subtitle: 'وقتی کتاب، صدا یا نسخهٔ پشتیبانی ذخیره کنید، '
            'حجمش اینجا نمایش داده می‌شود.',
        actionLabel: 'اندازه‌گیری دوباره',
        onAction: _loading ? null : _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 32),
        children: [
          _TotalCard(report: report, loading: _loading),
          const SizedBox(height: 20),
          for (final group in report.groups) ...[
            SectionHeader(
              title: group.title,
              // «مدیریت فضا» inherits the account/storage hue.
              accent: SettingsSectionHues.on(
                  context, SettingsSectionHues.account),
              count: NumberFormat.formatBytes(group.bytes),
              description: _largestItemNote(group),
              margin: const EdgeInsets.only(bottom: 8, right: 4),
            ),
            settingsCard([
              for (final item in group.items)
                settingsRow(_itemRow(context, t, item)),
            ]),
            const SizedBox(height: 20),
          ],
          Text(
            'میان‌برهای پاک‌سازی فقط داده‌هایی را حذف می‌کنند که خود برنامه '
            'دوباره دانلود می‌کند. پشتیبان‌ها و پیوست‌های شخصی دست‌نخورده می‌مانند.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              height: 1.7,
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, AppPalette t, StorageItemUsage item) {
    final clearing = _clearingId == item.id;
    // Nothing downloaded means nothing to delete — an empty row keeps the
    // plain trailing blank instead of offering a no-op clear.
    final deletable = item.clearable && item.bytes > 0;
    return SettingRow(
      icon: _iconFor(item.id),
      title: item.title,
      subtitle: item.subtitle,
      showChevron: false,
      onTap: deletable && !clearing ? () => _confirmClear(item) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            NumberFormat.formatBytes(item.bytes),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          if (clearing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: t.accent,
              ),
            )
          else if (deletable)
            Icon(
              Icons.delete_outline_rounded,
              size: 17,
              color: t.textMuted,
            )
          else
            const SizedBox(width: 17),
        ],
      ),
    );
  }

  /// Names the group's heaviest row so a large group total has an owner — a
  /// title only, never a second byte figure, since the figure is already the
  /// header's count and would read as a competing measurement against the rows.
  static String? _largestItemNote(StorageGroupUsage group) {
    if (group.items.length < 2) return null;
    StorageItemUsage? largest;
    for (final item in group.items) {
      if (largest == null || item.bytes > largest.bytes) largest = item;
    }
    if (largest == null || largest.bytes <= 0) return null;
    return 'بیشترین حجم: ${largest.title}';
  }

  static IconData _iconFor(String id) => switch (id) {
        'quran.recitation' => Icons.headphones_rounded,
        'quran.translation' => Icons.translate_rounded,
        'quran.content' => Icons.menu_book_rounded,
        'books.data' => Icons.library_books_rounded,
        'hadith.books' => Icons.auto_stories_rounded,
        'hadith.riyad' => Icons.local_florist_rounded,
        'hadith.taraghib' => Icons.menu_book_rounded,
        'hadith.fatwa' => Icons.gavel_rounded,
        'hadith.encyclopedia' => Icons.text_snippet_rounded,
        'media.audioLibrary' => Icons.library_music_rounded,
        'media.ruqyah' => Icons.self_improvement_rounded,
        'personal.attachments' => Icons.photo_library_rounded,
        'personal.backups' => Icons.cloud_sync_rounded,
        'personal.azans' => Icons.notifications_active_rounded,
        'caches.quran' => Icons.cached_rounded,
        'caches.diagnostics' => Icons.build_rounded,
        'caches.logs' => Icons.receipt_long_rounded,
        'caches.dorar' => Icons.search_rounded,
        _ => Icons.folder_rounded,
      };
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.report, required this.loading});

  final StorageReport report;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      child: Row(
        children: [
          IconTile(
            icon: Icons.pie_chart_rounded,
            color: t.accent,
            iconSize: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'فضای مصرفی برنامه',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    NumberFormat.formatBytes(report.totalBytes),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 26),
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'فقط داده‌های شناسایی‌شدهٔ برنامه؛ حجم کل دستگاه در دسترس برنامه نیست.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    height: 1.6,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (loading) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
            ),
          ],
        ],
      ),
    );
  }
}
