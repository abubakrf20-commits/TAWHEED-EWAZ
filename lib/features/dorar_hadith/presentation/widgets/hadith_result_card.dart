import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/providers/dorar_hadith_provider.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/widgets/hadith_degree_chip.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// کارت یک حدیثِ نتایج جستجو: متن، درجه، راوي/محدث/مصدر و عملیات.
class HadithResultCard extends ConsumerWidget {
  final DorarHadithEntity hadith;
  final Color accent;

  const HadithResultCard({
    super.key,
    required this.hadith,
    required this.accent,
  });

  static String shareText(DorarHadithEntity h) {
    final buffer = StringBuffer(h.hadithText);
    buffer.write('\n\n');
    if (h.narrator != null) buffer.write('الراوي: ${h.narrator}\n');
    if (h.mohdith != null) buffer.write('المحدث: ${h.mohdith}\n');
    if (h.book != null) buffer.write('المصدر: ${h.book}');
    if (h.hadithNumber != null) buffer.write(' (${h.hadithNumber})');
    if (h.degree != null) buffer.write('\nالحكم: ${h.degree}');
    buffer.write('\n— dorar.net');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites =
        ref.watch(dorarHadithFavoritesProvider).value ?? const <String>{};
    final isFavorite = favorites.contains(hadith.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.15)),
      ),
      color: TimeThemeKit.of(context).palette.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: SelectableText(
                hadith.hadithText,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  height: 2.0,
                  color: TimeThemeKit.of(context).palette.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (hadith.degree != null) ...[
              HadithDegreeChip(degree: hadith.degree),
              const SizedBox(height: 8),
            ],
            Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (hadith.narrator != null)
                    _meta(context, 'الراوي', hadith.narrator!),
                  if (hadith.mohdith != null)
                    _meta(context, 'المحدث', hadith.mohdith!),
                  if (hadith.book != null)
                    _meta(context, 'المصدر', hadith.book!),
                  if (hadith.hadithNumber != null)
                    _meta(context, 'الرقم', hadith.hadithNumber!),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (hadith.canViewDetails)
                  TextButton.icon(
                    onPressed: () => context
                        .push(RouteNames.dorarHadithDetailsPath(hadith.id)),
                    icon: Icon(Icons.feed_outlined, size: 18, color: accent),
                    label: Text(
                      'جزئیات',
                      style: TextStyle(
                        color: accent,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                _actionButton(
                  context,
                  tooltip: 'شرح الحديث',
                  icon: Icons.description_outlined,
                  onPressed: () => showDorarSharhSheet(context,
                      hadith: hadith, accent: accent),
                ),
                _actionButton(
                  context,
                  tooltip: isFavorite ? 'حذف از المفضلة' : 'حفظ در المفضلة',
                  icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? const Color(0xFFE53935) : null,
                  onPressed: () => ref
                      .read(dorarHadithFavoritesProvider.notifier)
                      .toggle(hadith),
                ),
                _actionButton(
                  context,
                  tooltip: 'کپی',
                  icon: Icons.copy_outlined,
                  onPressed: () => _copy(context, hadith),
                ),
                _actionButton(
                  context,
                  tooltip: 'مشاركة',
                  icon: Icons.share_outlined,
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: shareText(hadith)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, String label, String value) => Text(
        '$label: $value',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 12),
          color: TimeThemeKit.of(context).palette.textMuted,
        ),
      );

  Widget _actionButton(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
  }) =>
      IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        color: color ?? TimeThemeKit.of(context).palette.textMuted,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      );

  Future<void> _copy(BuildContext context, DorarHadithEntity hadith) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: shareText(hadith)));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('حدیث کپی شد'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// BottomSheet شرح الحديث — متن شرح از درر گرفته و نمایش داده می‌شود.
Future<void> showDorarSharhSheet(
  BuildContext context, {
  required DorarHadithEntity hadith,
  required Color accent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TimeThemeKit.of(context).palette.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SharhSheet(hadith: hadith, accent: accent),
  );
}

class _SharhSheet extends ConsumerWidget {
  final DorarHadithEntity hadith;
  final Color accent;

  const _SharhSheet({required this.hadith, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final explanation =
        ref.watch(dorarHadithExplanationProvider(hadith.hadithText));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, size: 20, color: accent),
                const SizedBox(width: 8),
                Text(
                  'شرح الحديث',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    color: TimeThemeKit.of(context).palette.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'بستن',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: explanation.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, __) => FailureView(
                  id: 'dorar_explanation',
                  title: 'شرح این حدیث دریافت نشد',
                  detail: 'متن حدیث سر جای خودش است؛ فقط شرح از سرور نیامد.',
                  onRetry: () => ref.invalidate(
                      dorarHadithExplanationProvider(hadith.hadithText)),
                  layout: FailureLayout.page,
                  icon: Icons.cloud_off_rounded,
                  error: e,
                ),
                data: (text) => SingleChildScrollView(
                  child: text == null
                      ? const AppEmptyState(
                          icon: Icons.menu_book_outlined,
                          message: 'شرحي برای این حدیث یافت نشد',
                        )
                      : Directionality(
                          textDirection: TextDirection.rtl,
                          child: SelectableText(
                            text,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 14.5),
                              height: 2.0,
                              color:
                                  TimeThemeKit.of(context).palette.textPrimary,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
