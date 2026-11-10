import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// A shimmer-style skeleton loading placeholder.
/// Used to show a nice loading state instead of a plain spinner.
class SkeletonLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool enabled;

  const SkeletonLoading({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    this.enabled = true,
  });

  /// Convenience: a full-width skeleton line.
  const SkeletonLoading.line({
    super.key,
    this.height = 14,
    this.borderRadius = 6,
  })  : width = double.infinity,
        enabled = true;

  /// Convenience: a small circle (for avatars/icons).
  const SkeletonLoading.circle({
    super.key,
    this.width = 40,
    this.height = 40,
  })  : borderRadius = 999,
        enabled = true;

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? AppTheme.darkSurfaceMuted : AppTheme.lightSurfaceAlt;
    final shimmerColor = isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightCard;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [baseColor, shimmerColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: _SlidingGradientTransform(
                slidePercent: _animation.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

/// A skeleton card that mimics a typical GlassSurface card layout.
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCard
            : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkOutline.withValues(alpha: 0.5)
              : AppTheme.lightOutline,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoading(
            width: 120,
            height: 14,
            borderRadius: 6,
          ),
          const SizedBox(height: 12),
          SkeletonLoading(
            height: height - 50,
          ),
        ],
      ),
    );
  }
}

/// A skeleton layout that mimics the home tab.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Clock card skeleton
        const SkeletonLoading(height: 220, borderRadius: 24),
        const SizedBox(height: 16),
        // Prayer summary skeleton
        const SkeletonLoading(height: 180, borderRadius: 22),
        const SizedBox(height: 16),
        // Reading streak skeleton
        const SkeletonLoading(height: 100, borderRadius: 22),
        const SizedBox(height: 16),
        // Stats skeleton
        const SkeletonLoading(height: 120, borderRadius: 22),
        const SizedBox(height: 16),
        // Quick actions skeleton
        const SkeletonLoading(height: 80, borderRadius: 22),
      ],
    );
  }
}
