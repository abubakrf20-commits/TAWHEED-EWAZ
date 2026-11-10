import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';

/// Lifecycle status of a khatm, derived from its persisted state.
///
/// The store persists only `isCompleted` (plus which pages have been read),
/// so the status is a pure projection — no migration needed:
/// completed → در حال پیشرفت/تکمیل‌شده, else active once any page is read,
/// else pending. `cancelled` exists for future explicit abandonment (e.g. a
/// delete-with-history flow) and is never derived from stored data today.
enum KhatmStatus { pending, active, completed, cancelled }

extension KhatmStatusX on KhatmModel {
  /// Derived lifecycle status of this khatm (see [KhatmStatus]).
  KhatmStatus get status => isCompleted
      ? KhatmStatus.completed
      : (readPages > 0 ? KhatmStatus.active : KhatmStatus.pending);

  /// Persian label used by the history-card status chip.
  String get statusLabelFa => switch (status) {
        KhatmStatus.pending => 'شروع نشده',
        KhatmStatus.active => 'در جریان',
        KhatmStatus.completed => 'تکمیل شده',
        KhatmStatus.cancelled => 'لغو شده',
      };
}
