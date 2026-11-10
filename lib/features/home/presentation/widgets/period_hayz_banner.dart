import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';

/// Banner shown while today falls inside a hayz/nifas record.
///
/// Wired to [periodProvider] — the same source the evaluation scores use — so
/// recording or deleting a period updates the banner instantly. The Home page
/// renders it as its own block under «دسترسی سریع» (with [trackerNote])
/// because period days change what the prayer rows mean: prayer is not
/// obligatory there, so an unlogged row is not a missed one.
///
/// The sentence always renders in full: `TextOverflow.ellipsis` here made the
/// paragraph refuse to wrap, so on every phone width the note ended behind a
/// «…» (measured: 320/360/412dp × text scale 1.0/1.3 all gave 1 line with
/// `didExceedMaxLines == true`). Wrapping is the fix — this is a shar'i note,
/// never a headline to be shortened.
class PeriodHayzBanner extends ConsumerWidget {
  final String? trackerNote;

  /// The day the host is rendering for. Home pins this from the shared minute
  /// ticker (tests, goldens), which is the same day the wall clock would give —
  /// so only deterministic tests see a difference. Defaults to the real clock.
  final DateTime? now;
  const PeriodHayzBanner({super.key, this.trackerNote, this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the state (not just reading the notifier) keeps the provider
    // alive and rebuilds the banner when a record is added or removed.
    final period = ref.watch(periodProvider);
    if (period.value == null) return const SizedBox.shrink();
    final now = this.now ?? DateTime.now();
    if (!ref.read(periodProvider.notifier).isDateInPeriod(now)) {
      return const SizedBox.shrink();
    }
    final ink = dsContentColor(context, TopicHues.period);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: TopicHues.period.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TopicHues.period.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.woman, size: 16, color: TopicHues.period),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                trackerNote ??
                    'در ایام حیض هستید — نماز و روزه ساقط است؛ طاعات دیگر را دستی ثبت کنید تا امتیاز بگیرید',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11), color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
