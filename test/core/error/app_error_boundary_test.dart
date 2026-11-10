import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/core/error/error_boundary.dart';

/// Shared across State recreation: the framework DESTROYS the child's State
/// when its first build throws (ErrorWidget replaces the subtree), so a
/// per-instance flag would throw again on every retry rebuild.
bool _childHasThrown = false;

/// Builds [child] normally; throws [firstBuildError] on the very first build
/// (once per test — see [_childHasThrown]).
class _FlakyChild extends StatefulWidget {
  final bool shouldThrowFirstBuild;
  final Object firstBuildError;
  final Widget child;

  const _FlakyChild({
    required this.shouldThrowFirstBuild,
    required this.firstBuildError,
    required this.child,
  });

  @override
  State<_FlakyChild> createState() => _FlakyChildState();
}

class _FlakyChildState extends State<_FlakyChild> {
  @override
  Widget build(BuildContext context) {
    if (widget.shouldThrowFirstBuild && !_childHasThrown) {
      _childHasThrown = true;
      throw widget.firstBuildError;
    }
    return widget.child;
  }
}

void main() {
  group('isBenignError', () {
    test('classifies known-benign first-frame errors', () {
      expect(
        AppErrorBoundary.isBenignError(
          Exception(
            'A RenderFlex overflowed by 12 pixels on the right.',
          ),
        ),
        isTrue,
      );
      expect(
        AppErrorBoundary.isBenignError(
          Exception('NetworkImageLoadException: HTTP 404'),
        ),
        isTrue,
      );
      expect(
        AppErrorBoundary.isBenignError(
          Exception('failed to load font asset assets/fonts/x.ttf'),
        ),
        isTrue,
      );
    });

    test('does not classify fatal errors as benign', () {
      expect(
        AppErrorBoundary.isBenignError(
          StateError('field has not been initialized'),
        ),
        isFalse,
      );
      expect(
        AppErrorBoundary.isBenignError(Exception('db open failed')),
        isFalse,
      );
    });
  });

  group('AppErrorBoundary', () {
    testWidgets(
        'fatal first-frame error swaps in the retry UI, and retry recovers',
        (tester) async {
      _childHasThrown = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AppErrorBoundary(
            child: _FlakyChild(
              shouldThrowFirstBuild: true,
              firstBuildError: Exception('fatal db open failed'),
              child:
                  const Text('child-shown', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      // The deferred setState lands on the next frame.
      await tester.pump();
      expect(find.byType(AppErrorDisplay), findsOneWidget);
      // One label for one action, app-wide (FailureView.retryLabel).
      expect(find.text(FailureView.retryLabel), findsOneWidget);
      expect(find.text('child-shown'), findsNothing);

      // First-frame exception already consumed by the boundary handler.
      final firstException = tester.takeException();
      expect(firstException, isNotNull);

      // Retry rebuilds the child (which is healthy now).
      await tester.tap(find.text(FailureView.retryLabel));
      await tester.pump();
      expect(find.byType(AppErrorDisplay), findsNothing);
      expect(find.text('child-shown'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('benign first-frame error never blanks the UI', (tester) async {
      _childHasThrown = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AppErrorBoundary(
            child: _FlakyChild(
              shouldThrowFirstBuild: true,
              firstBuildError: Exception(
                'A RenderFlex overflowed by 12 pixels on the right.',
              ),
              child:
                  const Text('benign-child', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      await tester.pump();

      // No fallback screen: the filter kept the child subtree.
      expect(find.byType(AppErrorDisplay), findsNothing);
      // The framework still reports the child's exception — consume it.
      expect(tester.takeException(), isNotNull);

      // After the first good frame the boundary is armed.
      await tester.pump();
      expect(find.byType(AppErrorDisplay), findsNothing);
    });

    testWidgets('errors after the first good frame are logged, not swapped',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppErrorBoundary(
            child: Text('stable', textDirection: TextDirection.ltr),
          ),
        ),
      );
      await tester.pump(); // arm _everBuiltOk

      // Dispatch through the boundary's installed handler: it logs, forwards to
      // the framework's test handler (which records the exception), and must
      // NOT swap in the fallback after the first good frame.
      FlutterError.onError?.call(
        FlutterErrorDetails(exception: Exception('late leaf failure')),
      );
      await tester.pump();

      expect(tester.takeException().toString(), contains('late leaf failure'));
      expect(find.byType(AppErrorDisplay), findsNothing);
      expect(find.text('stable'), findsOneWidget);
      // No manual restore: AppErrorBoundary.dispose puts the saved handler back.
    });
  });
}
