import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/failure_view.dart';

/// Loads heavy static JSON content on first build instead of blocking app
/// startup. The loader is idempotent (data classes skip re-loading when
/// already cached), so this is safe to reuse across screens.
class LazyContent extends StatefulWidget {
  final Future<void> Function() loader;
  final WidgetBuilder builder;

  const LazyContent({super.key, required this.loader, required this.builder});

  @override
  State<LazyContent> createState() => _LazyContentState();
}

class _LazyContentState extends State<LazyContent> {
  late Future<void> _loading;

  @override
  void initState() {
    super.initState();
    _loading = widget.loader();
  }

  void _retry() {
    setState(() {
      _loading = widget.loader();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadErrorView(onRetry: _retry);
        }
        return widget.builder(context);
      },
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // The old copy said «اتصال یا حافظهٔ دستگاه را بررسی کنید». This loader
    // reads JSON bundled inside the app — no socket, no download — so that
    // sentence sent the reader to check Wi-Fi for a failure that Wi-Fi cannot
    // cause or fix. The panel says where the content actually comes from.
    return FailureView(
      id: 'lazy_content',
      title: 'محتوای این بخش بارگذاری نشد',
      detail: 'این محتوا همراه برنامه ذخیره شده است و اینترنت لازم ندارد؛ '
          'با تلاش دوباره دوباره خوانده می‌شود.',
      onRetry: onRetry,
      layout: FailureLayout.page,
      icon: Icons.cloud_off_rounded,
    );
  }
}
