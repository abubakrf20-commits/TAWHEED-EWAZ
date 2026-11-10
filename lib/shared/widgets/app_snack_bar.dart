import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';

/// A consistent, themed SnackBar helper for the entire app.
///
/// Usage:
///   AppSnackBar.show(context, 'ذخیره شد');
///   AppSnackBar.error(context, 'خطا در بارگذاری');
///   AppSnackBar.success(context, 'عملیات موفق');
class AppSnackBar {
  AppSnackBar._();

  static void show(BuildContext context, String message,
      {Duration duration = const Duration(seconds: 2)}) {
    if (!context.mounted) return;
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: onPrimary,
            )),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: t.textPrimary,
      ),
    );
  }

  static void success(BuildContext context, String message) {
    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final onPrimary = dsOnAccent(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle,
              color: onPrimary, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: onPrimary,
                  ))),
        ]),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: success,
      ),
    );
  }

  /// A failed **write**, said out loud.
  ///
  /// WHY the retry parameter exists: [AppSnackBar.error] was the app's answer
  /// to a failed read, but a failed write has no panel to live in — the user
  /// pressed a button and the screen went on looking untouched. Logging that is
  /// not surviving it: the reader is left to conclude either that the action
  /// worked (their data is gone) or that the app is broken, and both readings
  /// are wrong. Fifteen sites had exactly that shape, two of them losing the
  /// user's own content.
  ///
  /// Two rules the copy follows, both learned from the panels:
  ///
  /// 1. **Say what failed, in the reader's words** — «حذف انجام نشد», not «خطا».
  /// 2. **Say what it does not mean** — the dangerous reading of a failed delete
  ///    is not "it broke", it is "it worked", so [message] says the row is still
  ///    there.
  ///
  /// The retry is a plain callback, not a `Future`: every call site already owns
  /// the operation it wants to repeat, and awaiting it here would mean this
  /// helper had to catch and re-report — wrong for the sites that re-run three
  /// steps.
  static void error(BuildContext context, String message,
      {VoidCallback? onRetry, String retryLabel = 'تلاش دوباره'}) {
    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final onPrimary = dsOnAccent(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.error_outline,
              color: onPrimary, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: onPrimary,
                  ))),
        ]),
        // Longer when there is a button to read and hit, so a retry does not
        // vanish mid-reach.
        duration: Duration(seconds: onRetry == null ? 3 : 6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: danger,
        action: onRetry == null
            ? null
            : SnackBarAction(
                label: retryLabel,
                textColor: onPrimary,
                onPressed: onRetry,
              ),
      ),
    );
  }

  static void warning(BuildContext context, String message) {
    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final onPrimary = dsOnAccent(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.warning_amber,
              color: onPrimary, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: onPrimary,
                  ))),
        ]),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: warning,
      ),
    );
  }
}
