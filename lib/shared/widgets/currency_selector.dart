import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/models/app_currency.dart';

/// ردیف انتخاب واحد پول — یک پیاده‌سازی برای همهٔ بخش‌های مالی.
///
/// تک‌تک ابزارها (زکات، زکات فطر، میراث، کفاره، قلک، بدهی و مالی، دفتر
/// هزینه‌ها، حساب مغازه) باید یک ظاهر و یک رفتار داشته باشند، وگرنه کاربر فکر
/// می‌کند هر کدام یک تنظیم جداست.
///
/// آخرین چیپ «دلخواه» است: واحدهایی که در فهرست نیستند (سکه، لیر، من…) را
/// کاربر خودش می‌نویسد و همان نام در برچسب فیلدها و متن نتیجه می‌آید.
class CurrencySelector extends StatelessWidget {
  const CurrencySelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accent,
    this.title = 'واحد پول',
    this.hint,
  });

  final AppCurrency value;
  final ValueChanged<AppCurrency> onChanged;
  final Color accent;

  final String title;

  /// توضیح زیر چیپ‌ها؛ اگر خالی باشد نمایش داده نمی‌شود.
  final String? hint;

  /// نام واحد دلخواه را می‌پرسد و انتخاب را برمی‌گرداند؛ `null` یعنی انصراف.
  Future<String?> _askCustomName(BuildContext context) {
    var text = value.isCustom ? value.label : '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('واحد دلخواه'),
        content: TextFormField(
          initialValue: text,
          autofocus: true,
          maxLength: 24,
          textDirection: TextDirection.rtl,
          onChanged: (v) => text = v,
          decoration: const InputDecoration(
            labelText: 'نام واحد',
            hintText: 'مثلاً سکه، لیر، من',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(text.trim()),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustom(BuildContext context) async {
    final name = await _askCustomName(context);
    if (name == null || name.trim().isEmpty) return;
    onChanged(AppCurrency.custom(name));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onAccent = dsOnAccent(context);
    final palette = TimeThemeKit.of(context).palette;

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Semantics(
        button: true,
        selected: selected,
        label: 'واحد پول: $label',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? accent
                  : (isDark
                      ? AppTheme.darkSurfaceAlt
                      : AppTheme.lightSurfaceAlt),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? accent
                    : (isDark ? AppTheme.darkOutline : AppTheme.lightOutline),
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                fontWeight: FontWeight.w700,
                color: selected ? onAccent : palette.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            textDirection: TextDirection.rtl,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w700,
                color: accent)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in AppCurrency.values)
              chip(
                label: c.label,
                selected: value == c,
                onTap: () => onChanged(c),
              ),
            chip(
              label: value.isCustom ? value.label : 'دلخواه…',
              selected: value.isCustom,
              onTap: () => _pickCustom(context),
            ),
          ],
        ),
        if (hint != null && hint!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(hint!,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: palette.textMuted,
                  height: 1.5)),
        ],
      ],
    );
  }
}
