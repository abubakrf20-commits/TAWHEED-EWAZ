/// «تنظیم پیش‌فرض‌ها» — the suggested service intervals become editable (G-6).
///
/// The asset is a suggestion, not a rule, so this sheet edits only the two
/// numbers a suggestion is made of (روز / کیلومتر) and stores the edit as an
/// override row. «بازگردانی» deletes that row and the shipped value returns.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';
import 'package:tawheeed/features/personal/presentation/providers/care_providers.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart';

Future<void> showCareDefaultsSheet(
  BuildContext context,
  WidgetRef ref, {
  CareAssetKind initialKind = CareAssetKind.home,
}) async {
  final templates = await ref.read(careTemplatesProvider.future);
  if (!context.mounted) return;
  if (templates.carDefaults.isEmpty && templates.homeDefaults.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('فهرست پیش‌فرض‌ها خوانده نشد؛ بعداً دوباره تلاش کنید.'),
    ));
    return;
  }

  var kind = initialKind;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final t = TimeThemeKit.of(sheetContext).palette;
        final accent = kind == CareAssetKind.car ? careCarColor : careHomeColor;
        final list = templates.of(kind);

        Future<void> edit(CareTemplate template) async {
          final result = await _editTemplateDialog(sheetContext, template);
          if (result == null) return;
          final store = ref.read(careTemplateOverridesProvider);
          if (result.reset) {
            await store.reset(template.key);
          } else {
            await store.save(
              template: template,
              intervalDays:
                  template.scheduleType.usesTime ? result.days : null,
              intervalKm:
                  template.scheduleType.usesDistance ? result.km : null,
            );
          }
          ref.invalidate(careTemplatesProvider);
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result.reset
                  ? '«${template.titleFa}» به مقدار پیشنهادی برگشت.'
                  : 'فاصلهٔ «${template.titleFa}» ذخیره شد.'),
            ));
          }
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * .8,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تنظیم پیش‌فرض‌ها',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'این اعداد فقط پیشنهاد هستند؛ ویرایش شما فقط روی همین دستگاه '
                    'ذخیره می‌شود و سرویس‌های ساخته‌شده را تغییر نمی‌دهد.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(sheetContext, 10),
                      height: 1.7,
                      color: t.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final option in const [
                        (CareAssetKind.car, 'خودرو'),
                        (CareAssetKind.home, 'خانه'),
                      ])
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => kind = option.$1),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: kind == option.$1
                                    ? accent.withValues(alpha: .13)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: kind == option.$1
                                      ? accent.withValues(alpha: .45)
                                      : t.divider,
                                  width: .5,
                                ),
                              ),
                              child: Text(
                                option.$2,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  fontWeight: kind == option.$1
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: kind == option.$1
                                      ? accent
                                      : t.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (final template in list)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: DuotoneIconTile(
                              accent: accent,
                              icon: careIconFor(template.iconKey),
                              size: 34,
                            ),
                            title: Text(
                              template.titleFa,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(sheetContext, 12),
                                color: t.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              template.reviewed
                                  ? template.intervalLabel
                                  : '${template.intervalLabel} · پیشنهادی',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(sheetContext, 10),
                                color: t.textMuted,
                              ),
                            ),
                            trailing: Icon(Icons.edit_outlined,
                                size: 16, color: t.textMuted),
                            onTap: () => edit(template),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// The edit dialog: two numeric fields, save, and «بازگردانی».
Future<({int days, int km, bool reset})?> _editTemplateDialog(
  BuildContext context,
  CareTemplate template,
) async {
  final daysCtrl = TextEditingController(
    text: template.intervalDays == null ? '' : '${template.intervalDays}',
  );
  final kmCtrl = TextEditingController(
    text: template.intervalKm == null ? '' : '${template.intervalKm}',
  );
  final result = await showDialog<({int days, int km, bool reset})>(
    context: context,
    builder: (dialogContext) {
      String? error;
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final t = TimeThemeKit.of(dialogContext).palette;
          return AlertDialog(
            title: Text(
              template.titleFa,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (template.scheduleType.usesTime)
                  TextField(
                    controller: daysCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'هر چند روز'),
                  ),
                if (template.scheduleType.usesDistance)
                  TextField(
                    controller: kmCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'هر چند کیلومتر'),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: DsStatus.danger(dialogContext),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'انصراف',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: t.textMuted,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext)
                    .pop((days: 0, km: 0, reset: true)),
                child: Text(
                  'بازگردانی',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: t.textSecondary,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  final days = int.tryParse(daysCtrl.text.trim());
                  final km = int.tryParse(kmCtrl.text.trim());
                  if (template.scheduleType.usesTime &&
                      (days == null || days <= 0)) {
                    setDialogState(() => error = 'عدد روز باید بزرگ‌تر از صفر باشد.');
                    return;
                  }
                  if (template.scheduleType.usesDistance &&
                      (km == null || km <= 0)) {
                    setDialogState(
                        () => error = 'عدد کیلومتر باید بزرگ‌تر از صفر باشد.');
                    return;
                  }
                  Navigator.of(dialogContext)
                      .pop((days: days ?? 0, km: km ?? 0, reset: false));
                },
                child: const Text('ذخیره'),
              ),
            ],
          );
        },
      );
    },
  );
  daysCtrl.dispose();
  kmCtrl.dispose();
  return result;
}
