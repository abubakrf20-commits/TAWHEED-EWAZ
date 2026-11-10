import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/providers/dorar_hadith_provider.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/widgets/hadith_filter_bar.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/widgets/hadith_result_card.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// صفحه جستجوی احادیث الدرر السنية (dorar.net).
class DorarHadithSearchScreen extends ConsumerStatefulWidget {
  const DorarHadithSearchScreen({super.key});

  static const Color accent = TopicHues.dorarHadith;

  @override
  ConsumerState<DorarHadithSearchScreen> createState() =>
      _DorarHadithSearchScreenState();
}

class _DorarHadithSearchScreenState
    extends ConsumerState<DorarHadithSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search() {
    _focusNode.unfocus();
    ref.read(dorarHadithSearchProvider.notifier).searchNow(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    const accent = DorarHadithSearchScreen.accent;
    final results = ref.watch(dorarHadithSearchProvider);
    final notifier = ref.read(dorarHadithSearchProvider.notifier);
    final t = TimeThemeKit.of(context).palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'جستجوی حدیث',
        titleWidget: Row(
          children: [
            const Icon(Icons.search_rounded, color: accent),
            const SizedBox(width: 8),
            Text(
              'جستجوی احادیث',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                color: t.primary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onChanged: notifier.search,
              onSubmitted: (_) => _search(),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 15),
                color: TimeThemeKit.of(context).palette.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'متن حدیث را بنویسید…',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: TimeThemeKit.of(context).palette.textMuted,
                ),
                filled: true,
                fillColor: TimeThemeKit.of(context).palette.card,
                prefixIcon: const Icon(Icons.search_rounded, color: accent),
                suffixIcon: IconButton(
                  tooltip: 'جستجو',
                  icon: const Icon(Icons.arrow_forward_rounded, color: accent),
                  onPressed: _search,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const DorarHadithFilterBar(accent: accent),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              // This used to hand the raw exception to `AppEmptyState` as its
              // *message*: a reader whose search failed was shown a socket
              // error in 16pt type. The panel names the failure and keeps the
              // exception for debug builds.
              error: (e, _) => FailureView(
                id: 'dorar_search',
                title: 'جست‌وجو در الموسوعة انجام نشد',
                detail: 'این جست‌وجو به اینترنت نیاز دارد؛ نتیجه‌های قبلی و '
                    'متن حدیث‌ها جایی نرفته‌اند.',
                onRetry: () => notifier.searchNow(_controller.text.isEmpty
                    ? notifier.currentQuery
                    : _controller.text),
                layout: FailureLayout.page,
                icon: Icons.cloud_off_rounded,
                error: e,
              ),
              data: (items) {
                if (notifier.currentQuery.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.menu_book_rounded,
                    message: 'متن حدیث را جستجو کنید',
                    subtitle:
                        'جستجو در الموسوعة الحديثية — با ذکر الراوي والمحدث والمصدر ودرجة الصحة',
                    accent: DorarHadithSearchScreen.accent,
                  );
                }
                if (items.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'نتیجه‌ای یافت نشد',
                    subtitle: 'عبارت دیگری را امتحان کنید',
                    accent: DorarHadithSearchScreen.accent,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 20),
                  itemCount: items.length +
                      (notifier.hasNextPage || notifier.loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < items.length) {
                      return HadithResultCard(
                        hadith: items[index],
                        accent: accent,
                      );
                    }
                    if (notifier.loadingMore) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      );
                    }
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: TextButton.icon(
                          onPressed: notifier.loadMore,
                          icon: const Icon(Icons.expand_more, size: 20),
                          label: const Text('نمایش نتایج بیشتر'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
