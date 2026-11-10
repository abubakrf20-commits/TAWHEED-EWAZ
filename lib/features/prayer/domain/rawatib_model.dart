import 'package:tawheeed/features/prayer/domain/entities/prayer_tracker_entities.dart';

/// Chip state on the rawatib card.
enum RawatibState { upcoming, suggested, past, done }

/// The relevance window of one rawatib: suggested from [start] to [end];
/// unchecked after [end] it is past.
class RawatibSpan {
  const RawatibSpan(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

/// The ONE relevance table for the rawatib card — the single source the
/// suggested styling, the «پیشنهاد این وقت: …» header text and the past
/// marks all read, so they can never disagree:
///
/// - فجر-قبل      [fajr → sunrise]
/// - ظهر-قبل/بعد  [dhuhr → asr] (both rakat sets share the window)
/// - مغرب-بعد     [maghrib → isha]
/// - عشاء-بعد     [isha → midnight]
/// - وتر          [isha → tomorrow's fajr]
///
/// Day framing (the same the prayer card uses): the spans come from
/// TODAY's schedule, so in the post-midnight stretch before fajr nothing
/// is suggested yet — the old currentPeriodLabel mapping agreed («شب»
/// mapped to nothing). [tomorrowFajr] is tomorrow's fajr adhan from the
/// schedule, not a clamp: witr stays suggested across midnight until it.
Map<SunnahPrayer, RawatibSpan> rawatibWindows({
  required DateTime fajr,
  required DateTime sunrise,
  required DateTime dhuhr,
  required DateTime asr,
  required DateTime maghrib,
  required DateTime isha,
  required DateTime tomorrowFajr,
}) {
  final midnight =
      DateTime(isha.year, isha.month, isha.day).add(const Duration(days: 1));
  return {
    SunnahPrayer.fajrRawatib: RawatibSpan(fajr, sunrise),
    SunnahPrayer.dhuhrRawatibBefore: RawatibSpan(dhuhr, asr),
    SunnahPrayer.dhuhrRawatibAfter: RawatibSpan(dhuhr, asr),
    SunnahPrayer.maghribRawatib: RawatibSpan(maghrib, isha),
    SunnahPrayer.ishaRawatib: RawatibSpan(isha, midnight),
    SunnahPrayer.witr: RawatibSpan(isha, tomorrowFajr),
  };
}

/// State of one chip at [now]. Ticking always wins (a prayer logged early
/// or late is still done — never past); otherwise suggested inside the
/// window, upcoming before it, past after it.
RawatibState rawatibStateAt({
  required RawatibSpan span,
  required DateTime now,
  required bool checked,
}) {
  if (checked) return RawatibState.done;
  if (span.contains(now)) return RawatibState.suggested;
  if (now.isBefore(span.start)) return RawatibState.upcoming;
  return RawatibState.past;
}
