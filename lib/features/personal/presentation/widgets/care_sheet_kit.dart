import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/shamsi_date_picker.dart';

/// Shared chrome + fields for every personal-tools bottom sheet.
Future<T?> showCareSheet<T>(
  BuildContext context, {
  required Widget child,
  Color? accent,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TimeThemeKit.of(context).palette.elevated,
    // No local `shape:`: every sheet inherits the theme's corner radius (the
    // app's sheet contract test enforces exactly that).
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetHandle()),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    ),
  );
}

/// Sheet heading.
class CareSheetTitle extends StatelessWidget {
  const CareSheetTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 16),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textMuted,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Labelled text field.
class CareField extends StatelessWidget {
  const CareField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.digitsOnly = false,
    this.ltr = false,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool digitsOnly;
  final bool ltr;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        textDirection: ltr ? TextDirection.ltr : null,
        inputFormatters: digitsOnly
            ? [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩,٬]')),
              ]
            : null,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 13),
          color: t.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: t.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: t.outline, width: .5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: t.outline, width: .5),
          ),
        ),
      ),
    );
  }
}

/// Jalali date button; returns the picked date through [onPicked].
class CareDateButton extends StatelessWidget {
  const CareDateButton({
    super.key,
    required this.label,
    required this.date,
    required this.onPicked,
    this.accent,
  });

  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPicked;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          final picked = await showShamsiDatePicker(
            context: context,
            initialDate: date,
            accentColor: accent,
          );
          if (picked != null) onPicked(picked);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.outline, width: .5),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 16, color: t.textMuted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                date == null ? 'انتخاب' : _jalali(date!),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _jalali(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final m = j.month.toString().padLeft(2, '0');
    final d = j.day.toString().padLeft(2, '0');
    return NumberFormat.ltrIsolated('${j.year}/$m/$d');
  }
}

/// Primary submit inside a sheet.
class CareSheetSubmit extends StatelessWidget {
  const CareSheetSubmit({
    super.key,
    required this.label,
    required this.onPressed,
    required this.accent,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: dsOnAccent(context),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      ),
    );
  }
}

/// Tappable warning/notice strip.
class CareNotice extends StatelessWidget {
  const CareNotice({
    super.key,
    required this.text,
    required this.accent,
    this.icon = Icons.info_outline,
  });

  final String text;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: .25), width: .5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: dsContentColor(context, accent)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable row used by the template pickers and task multi-select.
class CareSelectRow extends StatelessWidget {
  const CareSelectRow({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onChanged,
    required this.accent,
    this.icon,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: selected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? accent : t.outline,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 14, color: dsOnAccent(context))
                  : null,
            ),
            const SizedBox(width: 10),
            if (icon != null) ...[
              Icon(icon, size: 17, color: t.textMuted),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: t.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Switch row (reminder categories, full-tank toggle).
class CareSwitchRow extends StatelessWidget {
  const CareSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeThumbColor: accent,
      title: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 12),
          color: t.textPrimary,
        ),
      ),
    );
  }
}
