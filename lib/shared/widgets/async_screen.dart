import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/error/error_boundary.dart';

typedef AsyncDataBuilder<T> = Widget Function(T data);
typedef AsyncErrorBuilder = Widget Function(
    BuildContext context, Object error, StackTrace? stack, VoidCallback retry);

class AsyncScreen<T> extends StatelessWidget {
  final AsyncValue<T> asyncValue;
  final AsyncDataBuilder<T> data;
  final AsyncErrorBuilder? error;
  final Widget? loading;
  final VoidCallback? onRetry;

  const AsyncScreen({
    super.key,
    required this.asyncValue,
    required this.data,
    this.error,
    this.loading,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () =>
          loading ?? const Center(child: CircularProgressIndicator()),
      error: (err, stack) => error != null
          ? error!(context, err, stack, onRetry ?? () {})
          : AppErrorDisplay(error: err, stackTrace: stack, onRetry: onRetry),
      data: data,
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final String? message;
  final Widget? child;

  const LoadingOverlay({super.key, this.message, this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (child != null) child!,
        Container(
          color: Colors.black26,
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Text(message!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
