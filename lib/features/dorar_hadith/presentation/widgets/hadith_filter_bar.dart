import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/providers/dorar_hadith_provider.dart';

/// نوار فیلتر درجه صحت؛ اگر فیلتر عوض شود و جستجویی انجام شده باشد، همان
/// نتایج با فیلتر تازه دوباره خوانده می‌شود (این رفتار در DorarHadithSearch
/// با listen وصل شده است).
class DorarHadithFilterBar extends ConsumerWidget {
  final Color accent;

  const DorarHadithFilterBar({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(dorarSearchFilterProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (final filter in DorarHadithFilter.values) ...[
            ChoiceChip(
              label: Text(filter.label),
              selected: selected == filter,
              onSelected: (_) =>
                  ref.read(dorarSearchFilterProvider.notifier).select(filter),
              selectedColor: accent.withValues(alpha: 0.18),
              labelStyle: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
                color: selected == filter ? accent : null,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
