import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart' as kit;
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/utils/time_formatters.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/widgets/latin_time_picker.dart';

/// Settings-family shared rows, restyled on the phase-1 design kit. Every
/// hue comes from the live palette ([TimeThemeKit]) instead of the legacy
/// AppColors statics. Section headers render through the kit's
/// [kit.SectionHeader] directly — no local copy.

class SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return kit.AppCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: children),
      ),
    );
  }
}

class SettingsDivider extends StatelessWidget {
  final double indent;
  final double endIndent;
  const SettingsDivider({super.key, this.indent = 62, this.endIndent = 14});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Divider(
      height: 1,
      indent: indent,
      endIndent: endIndent,
      color: t.divider,
    );
  }
}

/// A card of setting rows with hairline dividers between them; dividers
/// align with the 36px icon tiles. Shared by the settings surfaces — was a
/// private `_card()` copy on the main and widget pages.
Widget settingsCard(List<Widget> rows) => kit.AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SettingsDivider(),
            rows[i],
          ],
        ],
      ),
    );

class SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;

  /// Identity hue for the icon tile; defaults to the live phase primary.
  final Color? color;

  final bool value;

  /// `null` renders the row inert (dimmed switch, no tap) — for a value that
  /// has not been read yet, or one the current state does not allow changing.
  final ValueChanged<bool>? onChanged;

  const SwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            kit.IconTile(
                icon: icon, color: color ?? t.primary, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: t.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            kit.SettingsSwitch(
              value: value,
              semanticLabel: title,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class SelectTile<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<T> options;
  final String Function(T) labelBuilder;
  final T selected;

  /// `null` renders the row inert (no sheet, dimmed) — for a value that has not
  /// been read yet. Same contract as [SwitchTile.onChanged]: a picker that
  /// opens before its own value is known shows a selection that may be wrong
  /// and writes over it.
  final ValueChanged<T>? onChanged;

  const SelectTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.options,
    required this.labelBuilder,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final enabled = onChanged != null;
    return InkWell(
      onTap: enabled ? () => _showOptions(context) : null,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              kit.IconTile(icon: icon, color: t.primary, iconSize: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: t.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_left_rounded, size: 20, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: options.length > 6 ? 0.6 : 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary)),
            ),
            Divider(height: 1, color: t.divider),
            ...options.map((opt) {
              final isSelected = opt == selected;
              return ListTile(
                title: Text(labelBuilder(opt),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected ? t.primary : t.textPrimary)),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: t.primary)
                    : null,
                onTap: () {
                  onChanged?.call(opt);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class CollapsibleSection extends StatefulWidget {
  final String title;
  final bool initiallyExpanded;
  final Widget child;
  const CollapsibleSection(
      {super.key,
      required this.title,
      this.initiallyExpanded = true,
      required this.child});

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                    child: kit.SectionHeader(
                  title: widget.title,
                  margin: const EdgeInsets.only(bottom: 8, right: 4),
                )),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, size: 20, color: t.textMuted),
                ),
              ],
            ),
          ),
        ),
        ClipRect(
          clipBehavior: Clip.none,
          child: AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: widget.child,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ),
      ],
    );
  }
}

/// یک ردیف انتخاب ساعت برای تنظیمات. قالب نمایش (۱۲/۲۴ ساعته) از تنظیم
/// «ساعت ۱۲ ساعتهٔ» برنامه پیروی می‌کند تا همه‌جا یک‌شکل باشد.
class TimePickerTile extends ConsumerWidget {
  final TimeOfDay time;
  final String label;
  final String? note;
  final ValueChanged<TimeOfDay> onPicked;

  const TimePickerTile({
    super.key,
    required this.time,
    required this.label,
    this.note,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final use12Hour = ref.watch(use12HourProvider);
    final noteText = note;
    final raw =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: () async {
        final picked = await showLatinTimePicker(
          context,
          initialTime: time,
          title: label,
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            kit.IconTile(
                icon: Icons.access_time, color: t.primary, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary),
                  ),
                  if (noteText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      noteText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: t.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              TimeFormatters.formatTime(raw, use12Hour: use12Hour),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w700,
                  color: t.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-line notice that the last settings write did not reach disk.
///
/// The notifier publishes optimistically and rolls back on failure, so a failed
/// write looks exactly like a switch that refuses to move. This puts a reason
/// on screen. Renders nothing while writes are healthy, so it costs a watched
/// bool and no layout.
class SettingsSaveFailureBanner extends ConsumerWidget {
  const SettingsSaveFailureBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(settingsSaveFailedProvider)) {
      return const SizedBox.shrink();
    }
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        key: const ValueKey('settings_save_failed_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sync_problem_outlined, size: 18, color: danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'آخرین تغییر ذخیره نشد و به مقدار قبلی برگشت. '
                'دوباره امتحان کنید؛ اگر تکرار شد، فضای ذخیره‌سازی دستگاه را بررسی کنید.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  height: 1.6,
                  color: t.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
