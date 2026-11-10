import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// A widget that catches errors in its child widget tree and displays
/// a user-friendly error screen instead of crashing the app.
class AppErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? fallbackBuilder;

  const AppErrorBoundary({
    super.key,
    required this.child,
    this.fallbackBuilder,
  });

  /// Known-benign errors that must never replace the UI with the fallback.
  static bool isBenignError(Object error) {
    final msg = error.toString();
    return msg.contains('A RenderFlex overflowed') ||
        msg.contains('overflowed by') ||
        msg.contains('NetworkImageLoadException') ||
        msg.contains('HTTP request failed with status code') ||
        msg.contains('failed to load font asset');
  }

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  FlutterExceptionHandler? _previousHandler;

  /// True once the FIRST frame has completed without a reported error. While
  /// false, the first fatal error swaps in the friendly retry UI (deferred to
  /// end-of-frame — see the handler below); benign errors are filtered out so
  /// a first-frame overflow/image hiccup never blanks the app. Later build
  /// errors only get LOGGED — taking over the whole Navigator for a minor
  /// leaf failure used to blank the entire app.
  bool _everBuiltOk = false;

  @override
  void initState() {
    super.initState();
    _previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      _previousHandler?.call(details);

      if (AppErrorBoundary.isBenignError(details.exception)) {
        AppLogger.warning(
          'AppErrorBoundary',
          'benign error ignored: ${details.exceptionAsString()}',
        );
        return;
      }

      AppLogger.error('AppErrorBoundary', details.exception, details.stack);

      // Fatal + before the first good frame → show the retry UI. setState
      // must not run while the framework is building/layouting, so the swap
      // is deferred to end-of-frame; at error time the flag decides.
      if (mounted && !_everBuiltOk && _error == null) {
        final error = details.exception;
        final stackTrace = details.stack;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _error != null) return;
          setState(() {
            _error = error;
            _stackTrace = stackTrace;
          });
        });
      }
    };
    // Arm "first build ok" only AFTER the first frame: child build/layout
    // errors are reported after this initState returns, so flipping the flag
    // during our own build() made the first-build fallback dead code.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _error == null) _everBuiltOk = true;
    });
  }

  @override
  void dispose() {
    FlutterError.onError = _previousHandler;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.fallbackBuilder != null) {
        return widget.fallbackBuilder!(_error!, _stackTrace);
      }
      return AppErrorDisplay(
        error: _error!,
        stackTrace: _stackTrace,
        onRetry: () {
          setState(() {
            _error = null;
            _stackTrace = null;
          });
        },
      );
    }
    return widget.child;
  }
}

/// Unified error display widget used across the app.
///
/// This is the *route-level* entry point: the fallback the [AppErrorBoundary]
/// paints when a subtree throws, and what [AsyncScreen] renders for an
/// `AsyncValue.error`. It does not draw anything itself any more — it turns an
/// exception into a sentence and hands that to [FailureView].
///
/// WHY the delegation: the app had two visual definitions of "something broke".
/// The in-section panels drew a tinted card with a plain retry; this widget drew
/// a bare centred column with a different icon family and the label «تلاش مجدد».
/// Two definitions meant two things to keep in sync, and they had already
/// drifted on the label — the same action, named two ways, in the same app. The
/// panel now has one definition and this is a caller of it.
class AppErrorDisplay extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorDisplay({
    super.key,
    required this.error,
    this.stackTrace,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FailureView(
      id: 'app_error',
      title: message ?? _humanReadableError(error),
      detail: message == null
          ? 'این خطا رخ داده است؛ کار شما از دست نرفته. '
              'اگر تکرار شد، برنامه را ببندید و دوباره باز کنید.'
          : null,
      onRetry: onRetry,
      layout: FailureLayout.page,
      error: error,
    );
  }

  String _humanReadableError(Object err) {
    final msg = err.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'خطا در ارتباط با سرور. اتصال اینترنت خود را بررسی کنید.';
    }
    if (msg.contains('TimeoutException')) {
      return 'درخواست با شکست مواجه شد. لطفاً دوباره تلاش کنید.';
    }
    return 'متأسفانه مشکلی پیش آمد. لطفاً دوباره تلاش کنید.';
  }
}

/// A loading indicator widget with optional message.
class AppLoadingWidget extends StatelessWidget {
  final String? message;

  const AppLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 14),
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
