import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart';
import 'package:tawheeed/features/worship/presentation/utils/worship_colors.dart';

/// Persian names for the icon picker's choices — the chips render icon-only
/// (empty label), so TalkBack reads these instead of nothing.
const Map<String, String> _iconChoiceNames = {
  'star': 'ستاره',
  'favorite': 'قلب',
  'menu_book': 'کتاب',
  'nightlight': 'ماه',
  'restaurant': 'غذا',
  'wb_sunny': 'خورشید',
  'people': 'گروه',
  'mosque': 'مسجد',
  'done_outline': 'انجام‌شده',
  'volunteer_activism': 'نیکوکاری',
  'self_improvement': 'آرامش',
  'broken_image': 'تصویر',
  'spa': 'گل',
  'clean_hands': 'دست‌شستن',
  'shower': 'دوش',
  'back_hand': 'کف دست',
};

/// Confirm dialog for removing one طاعت: default items are hidden (they can
/// be restored from settings later), custom ones are deleted for good.
/// Shared by the checklist screen and the home «طاعات روزانه» card so the
/// two can never offer different wording or behaviour.
Future<void> showDeleteWorshipItemDialog(
  BuildContext context,
  Evaluation service,
  WorshipItem item,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
  final isDefault = !item.id.startsWith('custom_');
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isDefault ? 'پنهان کردن طاعت' : 'حذف طاعت'),
      content: Text(isDefault
          ? 'آیا می‌خواهید "${item.label}" را از لیست طاعات روزانه پنهان کنید؟ می‌توانید بعداً از تنظیمات آن را بازگردانید.'
          : 'آیا مطمئن هستید که می‌خواهید "${item.label}" را حذف کنید؟'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
        TextButton(
          onPressed: () {
            if (isDefault) {
              service.toggleHideDefaultItem(item.id);
            } else {
              service.removeCustomWorshipItem(item.id);
            }
            Navigator.pop(ctx);
          },
          child: Text(isDefault ? 'پنهان' : 'حذف',
              style: TextStyle(color: danger)),
        ),
      ],
    ),
  );
}

/// Add-item dialog: a name field, the fixed 5-point value every طاعات item
/// is worth, and an icon picker. Shared by the checklist screen and the
/// home «طاعات روزانه» card.
Future<void> showAddWorshipItemDialog(
  BuildContext context,
  Evaluation service,
) {
  final nameCtrl = TextEditingController();
  IconData selectedIcon = Icons.star;
  final iconEntries = Evaluation.iconMap.entries.toList();

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('طاعت جدید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'نام طاعت',
                border: OutlineInputBorder(),
                hintText: 'مثلاً: قرائت قرآن',
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('امتیاز:',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 13))),
                const SizedBox(width: 8),
                // Every طاعات item is worth the same fixed 5 points — no
                // per-item choice needed.
                Text('5',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            // A horizontal SingleChildScrollView rather than a ListView: a
            // viewport inside AlertDialog's intrinsic-width measurement
            // asserts (flutter#88960), so the picker must not be one.
            SizedBox(
              height: 50,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final e in iconEntries)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 6),
                        child: ChoiceChip(
                          avatar: Icon(e.value, size: 18,
                              color: WorshipColors.forIcon(e.value)),
                          label: Text('',
                              semanticsLabel:
                                  _iconChoiceNames[e.key] ?? e.key),
                          selected: selectedIcon == e.value,
                          onSelected: (_) =>
                              setState(() => selectedIcon = e.value),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                service.addCustomWorshipItem(
                    nameCtrl.text.trim(), selectedIcon, 5);
                Navigator.pop(ctx);
              }
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    ),
  ).then((_) => nameCtrl.dispose());
}