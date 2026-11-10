import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/books/presentation/providers/reading_plan_provider.dart';
import 'package:tawheeed/features/education/presentation/widgets/study_widgets.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  /// The section chrome, once.
  ///
  /// This page had three copies of it — data, provider error, and the catch
  /// below — which is how the third copy ended up without the two elevation
  /// pins the other two had.
  AppBar _appBar(AppPalette t) => AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: t.primary,
        iconTheme: IconThemeData(color: t.primary),
        title: Text('مطالعه آزاد',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                color: t.primary)),
      );

  /// Both failure branches render the same thing.
  ///
  /// The copy used to be «خطا در بارگذاری» in one branch and «خطا در بارگذاری»
  /// plus a raw exception in the other, so the same failure had two faces
  /// depending on whether the provider threw or `build` threw. The exception is
  /// now the panel's debug-only `error`, and the reader gets a sentence about
  /// their reading plan instead of a stack trace.
  Widget _failure(Object? error) => FailureView(
        id: 'study_load',
        title: 'برنامهٔ مطالعه باز نشد',
        detail: 'پیشرفت مطالعهٔ شما پاک نشده است؛ فقط خواندن برنامه ناموفق '
            'بود.',
        onRetry: () {
          if (mounted) ref.invalidate(readingPlanProvider);
        },
        layout: FailureLayout.page,
        error: error,
      );

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    try {
      final planAsync = ref.watch(readingPlanProvider);
      return planAsync.when(
        data: (plan) {
          final notifier = ref.read(readingPlanProvider.notifier);
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _appBar(t),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.page, 12, DsSpacing.page, 24),
              children: [
                StudyTodayProgressCard(state: plan, notifier: notifier),
                const SizedBox(height: 20),
                StudyBooksSection(state: plan, notifier: notifier),
              ],
            ),
          );
        },
        // The loading branch had no app bar, so a slow read left the reader on
        // a bare spinner with no title and no way back.
        loading: () => Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _appBar(t),
            body: const Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _appBar(t),
          body: _failure(e),
        ),
      );
    } catch (e) {
      AppLogger.warning('study_screen', 'operation failed: $e');
      // A synchronous build throw previously returned a permanent spinner the
      // reader could not escape; show the same retryable error the provider's
      // error branch renders instead.
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _appBar(t),
        body: _failure(e),
      );
    }
  }
}
