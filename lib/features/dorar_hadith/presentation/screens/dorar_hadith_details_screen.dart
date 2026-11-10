import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/providers/dorar_hadith_provider.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/screens/dorar_hadith_search_screen.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/widgets/hadith_degree_chip.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/widgets/hadith_result_card.dart';

/// جزئیات یک حدیث: متن کامل، شرح، حدیث بدیل صحیح و احادیث مشابه.
class DorarHadithDetailsScreen extends ConsumerWidget {
  final String hadithId;

  const DorarHadithDetailsScreen({super.key, required this.hadithId});

  static const Color accent = DorarHadithSearchScreen.accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(dorarHadithDetailsProvider(hadithId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'حدیث',
        actions: [
          if (detail.hasValue)
            IconButton(
              tooltip: 'مشاركة',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                    text: HadithResultCard.shareText(detail.value!.hadith)),
              ),
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // A failed detail read gets its own wording and a retry; the raw
        // exception is never a user-facing message.
        error: (_, __) => FailureView(
          id: 'dorar_hadith_detail',
          title: 'دریافت این حدیث ممکن نشد',
          detail: 'این متن از سرور می‌آید؛ اتصال را بررسی کنید و دوباره '
              'بخوانید.',
          onRetry: () =>
              ref.invalidate(dorarHadithDetailsProvider(hadithId)),
          layout: FailureLayout.page,
          icon: Icons.cloud_off_rounded,
        ),
        data: (data) => _DetailBody(detail: data),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final DorarHadithDetail detail;

  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hadith = detail.hadith;
    final explanation =
        ref.watch(dorarHadithExplanationProvider(hadith.hadithText));
    const accent = DorarHadithDetailsScreen.accent;

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 28),
      children: [
        HadithResultCard(hadith: hadith, accent: accent),
        const SizedBox(height: 8),
        const _SectionTitle('شرح الحديث', icon: Icons.description_outlined),
        _SharhSection(
          explanation: explanation,
          hadith: hadith,
          accent: accent,
        ),
        if (detail.authenticAlternative != null) ...[
          const SizedBox(height: 8),
          const _SectionTitle('حدیث بدیل صحیح', icon: Icons.verified_outlined),
          _AlternativeCard(hadith: detail.authenticAlternative!),
        ],
        if (detail.similar.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _SectionTitle('الأحاديث المشابهة',
              icon: Icons.dashboard_outlined),
          for (final similar in detail.similar)
            HadithResultCard(hadith: similar, accent: accent),
        ],
      ],
    );
  }
}

class _SharhSection extends ConsumerWidget {
  final AsyncValue<String?> explanation;
  final DorarHadithEntity hadith;
  final Color accent;

  const _SharhSection({
    required this.explanation,
    required this.hadith,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        color: TimeThemeKit.of(context).palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: explanation.when(
            loading: () => const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
            error: (_, __) => FailureView(
              id: 'dorar_hadith_explanation',
              title: 'دریافت شرح ممکن نشد',
              onRetry: () => ref.invalidate(
                  dorarHadithExplanationProvider(hadith.hadithText)),
              layout: FailureLayout.inline,
              icon: Icons.cloud_off_rounded,
            ),
            data: (text) => text == null
                ? Text(
                    'شرحي برای این حدیث یافت نشد.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: TimeThemeKit.of(context).palette.textMuted,
                    ),
                  )
                : Directionality(
                    textDirection: TextDirection.rtl,
                    child: SelectableText(
                      text,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        height: 2.0,
                        color: TimeThemeKit.of(context).palette.textPrimary,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AlternativeCard extends StatelessWidget {
  final DorarHadithEntity hadith;

  const _AlternativeCard({required this.hadith});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSuccess
        : AppTheme.lightSuccess;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        color: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: SelectableText(
                  hadith.hadithText,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    height: 2.0,
                    color: TimeThemeKit.of(context).palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  HadithDegreeChip(degree: hadith.degree),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [
                        if (hadith.mohdith != null) hadith.mohdith!,
                        if (hadith.book != null) hadith.book!,
                      ].join(' — '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: TimeThemeKit.of(context).palette.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle(this.title, {required this.icon});

  @override
  Widget build(BuildContext context) {
    const accent = DorarHadithDetailsScreen.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
