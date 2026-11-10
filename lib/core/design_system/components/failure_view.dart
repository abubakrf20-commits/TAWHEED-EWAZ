import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Where a [FailureView] is being drawn, which decides how loud it is.
enum FailureLayout {
  /// A section that failed while the rest of the page still works.
  ///
  /// Tinted, start-aligned, sized to the content it replaces. This is the
  /// honest shape for «this block did not load»: it sits exactly where the
  /// missing content would have been, so the reader can see what is absent
  /// instead of wondering why the page is empty.
  card,

  /// A page with nothing else on it. Centred, no fill, larger type.
  page,

  /// One row, for the foot of a list that already has content above it
  /// («بارگذاری بقیه ناموفق بود»).
  inline,
}

/// The ink a [FailureView] draws with.
///
/// Most callers never pass this: the default reads the ambient time-theme
/// palette and the app's own error red, which is right for every screen built
/// on the app's background. It exists for the screens that are not: the three
/// mushaf surfaces paint *paper* — a sepia or night-paper field with its own
/// `MushafPalette` and deliberately no error hue, because paper is not semantic
/// chrome. Those screens were the reason this component exists, so leaving them
/// with a hand-rolled panel because the default palette did not fit would have
/// reproduced the original defect in the original place.
class FailureInk {
  const FailureInk({
    required this.title,
    required this.detail,
    required this.danger,
    this.muted,
  });

  final Color title;
  final Color detail;
  final Color danger;

  /// Used for the debug-only technical block. Falls back to [detail].
  final Color? muted;
}

/// The one failure panel.
///
/// WHY this exists: seventeen screens each hand-built the same three things —
/// an error icon, a sentence naming what failed, and a retry — and by the time
/// this was written they had drifted on almost every one of them:
///
/// | | روزه | کارها | مطالعه |
/// |---|---|---|---|
/// | layout | tinted card | centred | centred |
/// | icon | 20 | 44 | 48 |
/// | title weight | w700 | w700 | w600 |
/// | title colour | textPrimary | textPrimary | danger |
/// | detail colour | textSecondary | textMuted | textSecondary |
/// | button | tonal | tonal | filled+icon |
/// | label | تلاش دوباره | تلاش دوباره | تلاش مجدد |
/// | findable by key | yes | no | no |
///
/// Only one of those eight rows is a content decision. The rest is the same
/// answer retyped, and the last row is why the drift survived: a panel with no
/// stable key cannot be asserted on, so the only way to test it was to match
/// Persian prose, so nobody tested it, so it regressed quietly. That is the
/// whole of defect family 3 — *a failure that says nothing* — and it is a
/// construction problem, not an attention problem.
///
/// So [id] and [title] are both required, and neither is decorative:
///
/// * [id] becomes `ValueKey('failure_$id')`, so a test asserts
///   `find.byKey(const ValueKey('failure_tasks_load'))` and survives any
///   rewording of the copy;
/// * [title] has to name the thing that failed. «خطا» is not a title; «کارها باز
///   نشدند» is. The reader's next question is always *what* failed, and the
///   component cannot answer it for them.
///
/// The retry label is deliberately not a parameter. Three labels for one action
/// is not three opinions, it is three copies.
class FailureView extends StatelessWidget {
  const FailureView({
    super.key,
    required this.id,
    required this.title,
    this.detail,
    this.onRetry,
    this.layout = FailureLayout.card,
    this.error,
    this.ink,
    this.icon = Icons.error_outline,
    this.retrying = false,
  })  : assert(id.length > 0, 'FailureView: id is the test handle'),
        assert(title.length > 0, 'FailureView: say what failed');

  /// Stable handle for tests. Rendered as `ValueKey('failure_$id')`.
  final String id;

  /// What failed, in the reader's words — «کارها باز نشدند», not «خطا».
  final String title;

  /// The second sentence: what this does *not* mean.
  ///
  /// Almost every real failure here needs one, because the dangerous reading is
  /// never "it broke" but "my data is gone" or "I have none". «کارهای شما پاک
  /// نشده‌اند؛ فقط خواندنشان ناموفق بود» is the whole point of the panel.
  final String? detail;

  /// Shown only when there is something to retry. Omitted means no button.
  final VoidCallback? onRetry;

  /// A retry is already in flight.
  ///
  /// The button is disabled and replaced by a small spinner, because a retry
  /// that produces no visible change for a second reads as a dead button and
  /// gets tapped again — three screens had invented their own answer to this,
  /// and two of them left the button live, so the reader could queue up
  /// requests against a read that had not finished failing.
  final bool retrying;

  final FailureLayout layout;

  /// Technical detail, rendered in debug builds only. Never shown to readers.
  final Object? error;

  /// Overrides the default time-theme ink. See [FailureInk].
  final FailureInk? ink;

  /// The glyph, when the *kind* of failure is worth naming.
  ///
  /// A search that never reached the server and a local read that threw are
  /// different events, and `cloud_off` versus `error_outline` says which
  /// without a word. This is a meaning knob, not a styling one — the sizes and
  /// weights it used to be confused with are fixed per [layout] and are not
  /// parameters.
  final IconData icon;

  static const String retryLabel = 'تلاش دوباره';

  Key get failureKey => ValueKey('failure_$id');

  FailureInk _ink(BuildContext context) {
    final override = ink;
    if (override != null) return override;
    final t = TimeThemeKit.of(context).palette;
    return FailureInk(
      title: t.textPrimary,
      detail: t.textSecondary,
      muted: t.textMuted,
      danger: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkError
          : AppTheme.lightError,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: switch (layout) {
        FailureLayout.card => _card(context, _ink(context)),
        FailureLayout.page => _page(context, _ink(context)),
        FailureLayout.inline => _inline(context, _ink(context)),
      },
    );
  }

  // ── card ────────────────────────────────────────────────────────────────

  Widget _card(BuildContext context, FailureInk k) {
    return Container(
      key: failureKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: k.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: k.danger.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: k.danger),
              const SizedBox(width: 8),
              Expanded(child: _titleText(context, k, size: 13.5)),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            _detailText(context, k, size: 11.5),
          ],
          if (error != null) _debugBlock(context, k),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            _retryButton(context, k, dense: false),
          ],
        ],
      ),
    );
  }

  // ── page ────────────────────────────────────────────────────────────────

  Widget _page(BuildContext context, FailureInk k) {
    return Center(
      key: failureKey,
      // Scrollable so that a long error message plus the debug block cannot
      // overflow on a short viewport. An error screen that itself throws a
      // RenderFlex overflow is the one place the reader has no way out.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: k.danger),
            const SizedBox(height: 12),
            _titleText(context, k, size: 15, align: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 4),
              _detailText(context, k, size: 12, align: TextAlign.center),
            ],
            if (error != null) _debugBlock(context, k),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              _retryButton(context, k, dense: false),
            ],
          ],
        ),
      ),
    );
  }

  // ── inline ──────────────────────────────────────────────────────────────

  Widget _inline(BuildContext context, FailureInk k) {
    return Container(
      key: failureKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: k.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: k.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11.5),
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: k.title,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      height: 1.6,
                      color: k.detail,
                    ),
                  ),
              ],
            ),
          ),
          if (onRetry != null) _retryButton(context, k, dense: true),
        ],
      ),
    );
  }

  // ── shared pieces ───────────────────────────────────────────────────────

  Widget _retryButton(BuildContext context, FailureInk k, {required bool dense}) {
    if (retrying) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 0),
        child: SizedBox(
          width: dense ? 16 : 18,
          height: dense ? 16 : 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: k.danger),
        ),
      );
    }
    if (dense) {
      return TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: k.danger,
        ),
        child: const Text(retryLabel),
      );
    }
    return FilledButton.tonal(
        onPressed: onRetry, child: const Text(retryLabel));
  }

  Widget _titleText(BuildContext context, FailureInk k,
      {required double size, TextAlign align = TextAlign.start}) {
    return Text(
      title,
      textAlign: align,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, size),
        fontWeight: FontWeight.w700,
        height: 1.5,
        color: k.title,
      ),
    );
  }

  Widget _detailText(BuildContext context, FailureInk k,
      {required double size, TextAlign align = TextAlign.start}) {
    return Text(
      detail!,
      textAlign: align,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, size),
        height: 1.75,
        color: k.detail,
      ),
    );
  }

  Widget _debugBlock(BuildContext context, FailureInk k) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        '$error',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: AppTheme.scaledFontSize(context, 10.5),
          color: k.muted ?? k.detail,
        ),
      ),
    );
  }
}
