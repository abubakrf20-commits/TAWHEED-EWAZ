import 'dart:io';

import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/theme/tool_identity.dart';
import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/services/care_attachment_store.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

// Identity colours live in `core/theme/tool_identity.dart` — the same values
// the «بیشتر» tiles draw, so a tile and its tool can never drift apart.
const Color careCarColor = ToolIdentity.car;
const Color careHomeColor = ToolIdentity.home;

Color careAccentFor(CareAssetKind kind) =>
    kind == CareAssetKind.car ? careCarColor : careHomeColor;

/// Semantic status ink from the app's own tokens (never a new hex).
Color careLevelColor(BuildContext context, CareStatusLevel level) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return switch (level) {
    CareStatusLevel.good => isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess,
    CareStatusLevel.near => isDark ? AppTheme.darkWarning : AppTheme.lightWarning,
    CareStatusLevel.urgent ||
    CareStatusLevel.overdue =>
      isDark ? AppTheme.darkError : AppTheme.lightError,
  };
}

/// Glyph for a template / bill icon key.
IconData careIconFor(String key) => switch (key) {
      'oil' => Icons.water_drop_outlined,
      'filter' => Icons.filter_alt_outlined,
      'brake' => Icons.disc_full_outlined,
      'belt' => Icons.settings_outlined,
      'tire' => Icons.trip_origin,
      'battery' => Icons.battery_charging_full_outlined,
      'coolant' => Icons.ac_unit_outlined,
      'shield' => Icons.shield_outlined,
      'check' => Icons.fact_check_outlined,
      'receipt' => Icons.receipt_long_outlined,
      'boiler' => Icons.local_fire_department_outlined,
      'cooler' => Icons.air_outlined,
      'fire' => Icons.fire_extinguisher_outlined,
      'chimney' => Icons.smoke_free_outlined,
      'snow' => Icons.ac_unit,
      'sun' => Icons.wb_sunny_outlined,
      'electricity' => Icons.bolt_outlined,
      'water' => Icons.water_outlined,
      'gas' => Icons.local_fire_department_outlined,
      'phone' => Icons.phone_outlined,
      'internet' => Icons.wifi_outlined,
      'building' => Icons.apartment_outlined,
      'fuel' => Icons.local_gas_station_outlined,
      'warranty' => Icons.verified_outlined,
      'subscription' => Icons.autorenew_outlined,
      'car_wash' => Icons.cleaning_services_outlined,
      _ => Icons.build_outlined,
    };

/// Money in the app's selected unit («۴۲,۰۰۰ تومان»).
String careMoney(double value) =>
    NumberFormat.formatMoney(value, CurrencyStore.calculators.current.unit);

String careJalali(DateTime date) {
  final j = jalaliParts(date);
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/'
      '${j.day.toString().padLeft(2, '0')}';
}

String careJalaliLong(DateTime date) {
  final j = jalaliParts(date);
  // The app's ONE month table, so the Afghan display choice is respected here
  // too (settings guard: no local Iranian month tables outside the constants).
  return '${j.day} ${DateConstants.persianMonths[j.month - 1]} ${j.year}';
}

/// Small status pill («خوب / نزدیک / فوری / دیر»).
class CareStatusChip extends StatelessWidget {
  const CareStatusChip({super.key, required this.level, this.label});

  final CareStatusLevel level;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = careLevelColor(context, level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label ?? careLevelLabel(level),
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 11),
          fontWeight: FontWeight.w700,
          color: dsContentColor(context, color),
        ),
      ),
    );
  }
}

/// 7dp progress bar, clamped so an overdue task fills it exactly.
class CareProgressBar extends StatelessWidget {
  const CareProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 7,
  });

  final double progress;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final fraction = progress.isFinite ? progress.clamp(0.0, 1.0) : 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: t.surfaceAlt,
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: fraction,
          child: Container(
            height: height,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// One task row: duotone tile, title, remaining text, status chip, bar.
class CareTaskRow extends StatelessWidget {
  const CareTaskRow({
    super.key,
    required this.status,
    required this.accent,
    required this.onTap,
    this.trailing,
  });

  final CareStatus status;
  final Color accent;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final color = careLevelColor(context, status.level);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              DuotoneIconTile(
                accent: accent,
                icon: careIconFor(status.task.iconKey),
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.remainingText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing!
              else
                CareStatusChip(level: status.level),
            ],
          ),
          const SizedBox(height: 8),
          CareProgressBar(progress: status.progress, color: color),
        ],
      ),
    );
  }
}

/// The primary action pill of both pages.
class CarePrimaryPill extends StatelessWidget {
  const CarePrimaryPill({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.accent,
    this.outline = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color accent;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, size: 18);
    final text = Text(
      label,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, 13),
        fontWeight: FontWeight.w600,
      ),
    );
    if (outline) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: dsContentColor(context, accent),
            side: BorderSide(color: accent.withValues(alpha: .45)),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          icon: child,
          label: text,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: dsOnAccent(context),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        icon: child,
        label: text,
      ),
    );
  }
}

/// Empty state used when the tool has no asset yet.
class CareEmptyState extends StatelessWidget {
  const CareEmptyState({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DuotoneIconTile(accent: accent, icon: icon, size: 72),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 16),
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textMuted,
                height: 1.50,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: dsOnAccent(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 11),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact selector chip for “several cars / homes”.
class CareChip extends StatelessWidget {
  const CareChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: .14) : t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: .55)
                : t.outline,
            width: .5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? dsContentColor(context, accent)
                : t.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Add button used at the end of the home tabs.
class CareInlineAdd extends StatelessWidget {
  const CareInlineAdd({
    super.key,
    required this.label,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: dsContentColor(context, accent),
        ),
        icon: const Icon(Icons.add, size: 17),
        label: Text(label),
      ),
    );
  }
}

/// Thumbnail of a stored attachment (relative path → file), downscaled at
/// decode time so a 1600px receipt never costs a full-size bitmap in a list.
class CareAttachmentThumb extends StatelessWidget {
  const CareAttachmentThumb({super.key, required this.relativePath, this.size = 48});

  final String relativePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return FutureBuilder<String?>(
      future: CareAttachmentStore.absolutePath(relativePath),
      builder: (context, snapshot) {
        final path = snapshot.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: size,
            height: size,
            child: path == null
                ? ColoredBox(color: t.surfaceAlt)
                : Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: (size * 3).round(),
                    errorBuilder: (_, error, stack) =>
                        ColoredBox(color: t.surfaceAlt),
                  ),
          ),
        );
      },
    );
  }
}

/// Label/value line used in details sheets.
class CareDetailRow extends StatelessWidget {
  const CareDetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: t.textMuted,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// «CareScreenBase» step 1 — the app-bar shell shared by خودرو, خانه and their
/// history page. The three pages used to repeat the same transparent AppBar,
/// the same RTL back button and the same history/settings actions. Extracting
/// just this seam removes the drift without rewriting three 1700-line bodies.
///
/// The callbacks keep go_router and the sheets out of this widget's imports,
/// so the design-system layer stays independent of navigation and data.
class CareScreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CareScreenAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.onHistory,
    this.onSettings,
    this.actions = const <Widget>[],
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onHistory;
  final VoidCallback? onSettings;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: t.primary,
      iconTheme: IconThemeData(color: t.primary),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          color: t.primary,
        ),
      ),
      leading: IconButton(
        // `arrow_back` is matchTextDirection=true: in this RTL app Flutter
        // flips it so it points right, i.e. back. `arrow_right_alt` would
        // flip to the left and read as "forward".
        icon: const Icon(Icons.arrow_back),
        tooltip: 'بازگشت',
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      ),
      actions: [
        if (onHistory != null)
          IconButton(
            tooltip: 'تاریخچه',
            icon: const Icon(Icons.history),
            onPressed: onHistory,
          ),
        if (onSettings != null)
          IconButton(
            tooltip: 'تنظیمات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: onSettings,
          ),
        ...actions,
      ],
    );
  }
}
