/// Decides whether the mushaf pager may move, and on whose authority.
///
/// The reader had several independent writers on one [PageController]: the
/// recitation follow, the translation follow, the global search, bookmark
/// restore, the retry sheet — plus the user's own drag. Whichever wrote last
/// won, so a swipe could be cancelled or redirected mid-gesture and the reader
/// would settle on a page nobody asked for. Keeping the arbitration in a pure
/// value object (rather than inline in the widget) is what makes that rule
/// testable without a live pager, fonts, or a real gesture.
library;

/// Who is asking the pager to move.
enum MushafNavSource {
  /// The reader dragging / flicking the pager. Always wins.
  user,

  /// A recitation or translation advancing to the next ayah. Follows the
  /// reader, but yields to them.
  audioFollow,

  /// An explicit jump: search result, surah list, bookmark restore, retry.
  explicitJump,
}

/// The single authority that arbitrates mushaf pager navigation.
///
/// The invariants it encodes:
///
///  * a **user gesture is never overridden** — a follow request during a drag
///    (or just after a flick settles) is dropped, not queued;
///  * an **explicit jump is not redirected** — a follow must not cancel or
///    retarget a jump that is still in flight;
///  * **no request is a no-op** — asking for the page already shown does
///    nothing, so a follow firing on every word tick cannot restart the
///    pager's snapping animation.
class MushafNavPolicy {
  const MushafNavPolicy({
    required this.currentPage,
    required this.userDragging,
    this.dragGraceActive = false,
    this.pendingNavPage = 0,
  });

  /// The page the pager has actually settled on.
  final int currentPage;

  /// True while a finger is on the pager.
  final bool userDragging;

  /// True for a short grace period after a drag ends, so a follow that fires
  /// the instant the flick settles still yields.
  final bool dragGraceActive;

  /// Page an explicit animated jump is currently heading for, or 0. While
  /// non-zero the jump owns the pager.
  final int pendingNavPage;

  /// True while a follow must not touch the pager: the user is in charge of
  /// it, either right now or for the length of the post-drag grace.
  bool get userInControl => userDragging || dragGraceActive;

  /// Whether a request from [source] may move the pager to [page].
  bool allows(MushafNavSource source, int page) {
    // A drag is the user asserting a page change. Overriding it mid-gesture is
    // the failure this whole class exists to prevent, so a follow is simply
    // dropped — not queued, because by the time the drag ends the reader has
    // moved on and the followed page is no longer relevant.
    if (source == MushafNavSource.audioFollow && userInControl) return false;

    // A follow must not hijack an explicit jump that is still animating: it
    // would cancel the animation and snap to a different page.
    if (source == MushafNavSource.audioFollow && pendingNavPage != 0) {
      return false;
    }

    // Asking for the page already shown is a no-op. This matters most for the
    // follow, which re-evaluates on every word of the recitation: without it
    // each tick would restart the snapping animation and the page would never
    // settle.
    if (page == currentPage) return false;

    return true;
  }

  /// Resolves a request to the concrete zero-based page the pager should be
  /// told about, or `null` when the request must be ignored.
  ///
  /// The result is clamped into the mushaf so an out-of-range target can never
  /// reach the [PageController] (which would throw).
  int? resolve(MushafNavSource source, int page, {required int pageCount}) {
    if (!allows(source, page)) return null;
    return page.clamp(1, pageCount) - 1;
  }
}
