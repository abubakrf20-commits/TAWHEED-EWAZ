import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/services/attachment_dead_refs_scanner.dart';
import 'package:tawheeed/features/settings/presentation/providers/attachment_diagnostics_providers.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// One-shot maintenance page for the attachment store behind «اطلاعات من».
///
/// It surfaces the two ways a photo reference can rot — a file with no row
/// (orphan) and a row with no file (dangling) — and offers a single
/// «پاک‌سازی» button that deletes the orphan files and prunes the dangling
/// entries from their rows.
///
/// Reachable from Settings; the entry is shown only in debug builds because
/// this is a developer/one-off cleanup tool, not a user feature.
class AttachmentDiagnosticsScreen extends ConsumerStatefulWidget {
  const AttachmentDiagnosticsScreen({super.key});

  @override
  ConsumerState<AttachmentDiagnosticsScreen> createState() =>
      _AttachmentDiagnosticsScreenState();
}

class _AttachmentDiagnosticsScreenState
    extends ConsumerState<AttachmentDiagnosticsScreen> {
  DeadAttachmentReport? _report;
  DeadAttachmentSweepResult? _lastSweep;
  bool _busy = true;

  /// The thrown object, not its text: the panel shows it in debug builds only.
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _error = null;
      _lastSweep = null;
    });
    try {
      final report = await ref.read(attachmentDeadRefsScannerProvider).scan();
      if (!mounted) return;
      setState(() {
        _report = report;
        _busy = false;
      });
    } catch (e) {
      AppLogger.warning('AttachmentDiagnostics', 'scan failed: $e');
      if (!mounted) return;
      setState(() {
        _error = e;
        _busy = false;
      });
    }
  }

  Future<void> _sweep() async {
    final report = _report;
    if (report == null || report.isClean) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک‌سازی ارجاع‌های مرده'),
        content: Text(
          '${report.orphanFiles.length} فایل بی‌صاحب حذف می‌شود و '
          '${report.danglingRefs.length} ارجاع شکسته از ردیف‌های دیتابیس پاک می‌شود.\n\n'
          'این عملیات قابل بازگشت نیست. ادامه می‌دهید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                  ? AppTheme.darkError
                  : AppTheme.lightError,
              foregroundColor: Colors.white,
            ),
            child: const Text('پاک کن'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(attachmentDeadRefsScannerProvider).sweep();
      if (!mounted) return;
      setState(() {
        _lastSweep = result;
        _report = result.reportAfter;
        _busy = false;
      });
    } catch (e) {
      AppLogger.warning('AttachmentDiagnostics', 'sweep failed: $e');
      if (!mounted) return;
      setState(() {
        _error = e;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorHue = isDark ? AppTheme.darkError : AppTheme.lightError;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SettingsAppBar(
        title: 'پیوست‌های اطلاعات من',
        trailing: IconButton(
          tooltip: 'اسکن مجدد',
          icon: const Icon(Icons.refresh),
          onPressed: _busy ? null : _scan,
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 32),
        children: [
          if (_error != null)
            FailureView(
              id: 'attachment_scan',
              title: 'اسکن پیوست‌ها انجام نشد',
              detail: 'فایل‌ها و ردیف‌ها دست‌نخورده‌اند؛ فقط این اسکن '
                  'خوانده نشد.',
              onRetry: _scan,
              error: _error,
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (report != null) ...[
            if (_lastSweep != null) _SweepBanner(sweep: _lastSweep!),
            _SummaryCard(report: report),
            // The summary card above already states the clean outcome; a
            // second "nothing to clean" card said the same thing twice.
            if (!report.isClean) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _sweep,
                style: FilledButton.styleFrom(
                  backgroundColor: errorHue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.cleaning_services_outlined),
                label: Text(
                  'پاک‌سازی (${report.totalIssues} مورد)',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            if (report.orphanFiles.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(
                title: 'فایل‌های بی‌صاحب',
                count: '(${report.orphanFiles.length})',
              ),
              ...report.orphanFiles.map((f) => _PathTile(
                    icon: Icons.insert_drive_file_outlined,
                    title: p.basename(f),
                    subtitle: f,
                  )),
            ],
            if (report.danglingRefs.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(
                title: 'ارجاع‌های شکسته',
                count: '(${report.danglingRefs.length})',
              ),
              ...report.danglingRefs.map((r) => _PathTile(
                    icon: Icons.broken_image_outlined,
                    title: '${_ownerLabel(r.ownerType)} — ${r.ownerTitle}',
                    subtitle: r.path,
                    badge: _fieldLabel(r.field),
                  )),
            ],
            if (report.errors.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(
                title: 'هشدارها',
                count: '(${report.errors.length})',
              ),
              ...report.errors.map((e) => _PathTile(
                    icon: Icons.error_outline,
                    title: e,
                    subtitle: '',
                  )),
            ],
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  static String _ownerLabel(String type) {
    switch (type) {
      case 'profile':
        return 'پروفایل';
      case 'document':
        return 'مدرک';
      case 'asset':
        return 'دارایی';
      case 'insurance':
        return 'بیمه';
      default:
        return type;
    }
  }

  static String _fieldLabel(String field) {
    switch (field) {
      case 'avatarPath':
        return 'عکس پروفایل';
      case 'imagesJson':
        return 'عکس‌های مدرک';
      case 'attachmentsJson':
        return 'پیوست‌ها';
      default:
        return field;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final DeadAttachmentReport report;
  const _SummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clean = report.isClean;
    final color = clean
        ? (isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess)
        : (isDark ? AppTheme.darkWarning : AppTheme.lightWarning);
    final icon = clean ? Icons.verified_outlined : Icons.plumbing_outlined;
    final title =
        clean ? 'همه‌چیز مرتب است' : '${report.totalIssues} ارجاع مرده';
    final subtitle = clean
        ? 'هیچ فایل بی‌صاحب یا ارجاع شکسته‌ای پیدا نشد'
        : '${report.orphanFiles.length} فایل بی‌صاحب و '
            '${report.danglingRefs.length} ارجاع شکسته';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: dsContentColor(context, color), size: 36),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${report.liveRefCount} ارجاع سالم',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SweepBanner extends StatelessWidget {
  final DeadAttachmentSweepResult sweep;
  const _SweepBanner({required this.sweep});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final success = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSuccess
        : AppTheme.lightSuccess;
    final left = sweep.reportAfter.totalIssues;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: success.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'پاک‌سازی انجام شد: ${sweep.removedFiles} فایل حذف و '
              '${sweep.prunedRefs} ارجاع پاک شد. '
              '${left == 0 ? 'هیچ موردی باقی نمانده.' : '$left مورد باقی مانده.'}',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                // On-scale (12.5 snaps to 12): identical pixels.
                fontSize: AppTheme.scaledFontSize(context, 12),
                height: 1.5,
                color: t.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  const _PathTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: t.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            // On-scale (12.5 snaps to 12): identical pixels.
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                      if (badge != null) _Badge(text: badge!),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        // On-scale (10.5 snaps to 10): identical pixels.
                        fontSize: AppTheme.scaledFontSize(context, 10),
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
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final warning = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkWarning
        : AppTheme.lightWarning;
    return Container(
      // Directional: physical `right` broke badge placement under RTL.
      margin: const EdgeInsetsDirectional.only(end: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 10),
          fontWeight: FontWeight.w700,
          color: warning,
        ),
      ),
    );
  }
}
