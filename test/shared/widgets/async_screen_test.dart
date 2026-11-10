import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/shared/widgets/async_screen.dart';

void main() {
  Widget buildApp(AsyncValue<String> value) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: AsyncScreen<String>(
            asyncValue: value,
            data: (data) => Text('Data: $data'),
            onRetry: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('AsyncScreen shows loading indicator when loading',
      (tester) async {
    await tester.pumpWidget(buildApp(const AsyncValue.loading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AsyncScreen shows data when AsyncData', (tester) async {
    await tester.pumpWidget(buildApp(const AsyncValue.data('Hello')));
    expect(find.text('Data: Hello'), findsOneWidget);
  });

  testWidgets('AsyncScreen shows error with retry button', (tester) async {
    await tester.pumpWidget(
        buildApp(const AsyncValue.error('Error!', StackTrace.empty)));
    // The default error builder is AppErrorDisplay, which now delegates to the
    // shared FailureView — so the label and the glyph come from one place.
    expect(find.text(FailureView.retryLabel), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byKey(const ValueKey('failure_app_error')), findsOneWidget);
  });

  testWidgets('AsyncScreen uses custom error builder when provided',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AsyncScreen<String>(
              asyncValue: const AsyncValue.error('Error!', StackTrace.empty),
              data: (data) => Text('Data: $data'),
              error: (ctx, err, stack, retry) => const Text('Custom Error'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Custom Error'), findsOneWidget);
  });

  testWidgets('AsyncScreen uses custom loading when provided', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AsyncScreen<String>(
              asyncValue: const AsyncValue.loading(),
              data: (data) => Text('Data: $data'),
              loading: const Text('Custom Loading'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Custom Loading'), findsOneWidget);
  });
}
