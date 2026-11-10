import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';

import 'package:tawheeed/core/theme/theme.dart';

import 'package:tawheeed/core/theme/time_theme.dart';

/// Unified card widget for all Islamic content sections.
/// Provides consistent styling, copy functionality, and semantic structure.
class BaseCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color? iconColor;
  final Color? accentColor;
  final bool showCopyButton;
  final bool showDivider;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final List<Widget>? actions;
  final Widget? header;
  final Widget? footer;
  final CrossAxisAlignment crossAxisAlignment;

  const BaseCard({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.article_outlined,
    this.iconColor,
    this.accentColor,
    this.showCopyButton = true,
    this.showDivider = true,
    this.padding,
    this.borderRadius,
    this.actions,
    this.header,
    this.footer,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final color = iconColor ?? (isDark ? t.primary : t.tertiary);
    final effectiveAccent = accentColor ?? color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(borderRadius ?? 14),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (header != null) ...[
            header!,
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: crossAxisAlignment,
                  children: [
                    SelectableText(title,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary)),
                    if (showDivider) ...[
                      const SizedBox(height: 10),
                      Container(
                          width: double.infinity,
                          height: 1,
                          color: effectiveAccent.withValues(alpha: 0.1)),
                      const SizedBox(height: 10),
                    ],
                    SelectableText(body,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            color: t.textSecondary,
                            height: 1.6)),
                  ],
                ),
              ),
            ],
          ),
          if (actions != null) ...[
            const SizedBox(height: 8),
            Row(children: actions!),
          ],
          if (footer != null) ...[
            const SizedBox(height: 8),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Reusable step card for guided sequences (prayer steps, wudu steps).
class StepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String body;
  final String? note;
  final String? extra;
  final Color accentColor;
  final bool isLast;

  const StepCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.body,
    this.note,
    this.extra,
    this.accentColor = AppTheme.goldPale,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;


    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Timeline ──
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  '$stepNumber',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w700,
                      color: dsContentColor(context, accentColor)),
                ),
              ),
            ),
            if (!isLast)
              Container(
                  width: 2,
                  height: 40,
                  color: accentColor.withValues(alpha: 0.15)),
          ],
        ),
        const SizedBox(width: 14),
        // ── Content ──
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(title,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 15),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary)),
                const SizedBox(height: 6),
                SelectableText(body,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        color: t.textSecondary,
                        height: 1.6)),
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 14, color: accentColor),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(note!,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 12),
                                    color: dsContentColor(context, accentColor),
                                    height: 1.5))),
                      ],
                    ),
                  ),
                ],
                if (extra != null && extra!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(extra!,
                        style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: AppTheme.scaledFontSize(context, 18),
                            color: t.textPrimary,
                            height: 1.8),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable ruling/info card for educational content.
class RulingCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color? iconColor;
  final bool showDivider;

  const RulingCard({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.article_outlined,
    this.iconColor,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gold = isDark ? t.primary : t.tertiary;
    final color = iconColor ?? gold;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: SelectableText(title,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary))),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(body,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: t.textSecondary,
                  height: 1.6)),
        ],
      ),
    );
  }
}

/// Compact info box for tips, notes, and warnings.
class InfoBox extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;
  final bool isWarning;

  const InfoBox(
      {super.key,
      required this.text,
      this.icon = Icons.info_outline,
      this.color,
      this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final c = color ??
        (isWarning ? warning : (isDark ? t.primary : t.tertiary));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: dsContentColor(context, c),
                      height: 1.5))),
        ],
      ),
    );
  }
}

/// Section header — boxed card style with icon, matching Hajj/Ramadan pattern.
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? accentColor;
  final String? subtitle;
  const SectionHeader(
      {super.key,
      required this.title,
      this.icon,
      this.accentColor,
      this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = accentColor ?? (isDark ? t.primary : t.tertiary);
    final displayIcon = icon ?? Icons.auto_stories;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(displayIcon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: dsContentColor(context, color))),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: dsContentColor(context, color))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Category list card (for arkans, wajibat, etc.)
class CategoryListCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final Color accentColor;
  final String? note;

  const CategoryListCard(
      {super.key,
      required this.title,
      required this.icon,
      required this.items,
      this.accentColor = AppTheme.goldPale,
      this.note});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;


    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: SelectableText(title,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${items.length}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: dsContentColor(context, accentColor))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 8),
                        decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.4),
                            shape: BoxShape.circle)),
                    Expanded(
                        child: SelectableText(item,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                color: t.textSecondary,
                                height: 1.5))),
                  ],
                ),
              )),
          if (note != null) ...[
            const SizedBox(height: 8),
            InfoBox(text: note!, color: accentColor),
          ],
        ],
      ),
    );
  }
}
