import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class InheritanceSectionCard extends StatefulWidget {
  final int id;
  final String title;
  final String icon;
  final List<Map<String, dynamic>> subsections;
  final Color accent;

  const InheritanceSectionCard({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    required this.subsections,
    required this.accent,
  });

  @override
  State<InheritanceSectionCard> createState() => _InheritanceSectionCardState();
}

class _InheritanceSectionCardState extends State<InheritanceSectionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accent.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.id}',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 15),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: TimeThemeKit.of(context).palette.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.expand_more,
                      size: 22,
                      color: widget.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildSubsections(context),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsections(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.subsections.asMap().entries.map((entry) {
          final idx = entry.key;
          final sub = entry.value;
          final subTitle = sub['title'] as String?;
          final body = sub['body'] as String?;
          final items = sub['items'] as List<dynamic>?;

          return Padding(
            padding: EdgeInsets.only(top: idx == 0 ? 0 : 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.accent.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subTitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 7),
                            decoration: BoxDecoration(
                              color: widget.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              subTitle,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w700,
                                color: widget.accent,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (body != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SelectionArea(
                        child: Text(
                          body,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12.5),
                            color: TimeThemeKit.of(context).palette.textSecondary,
                            height: 1.75,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    ),
                  if (items != null)
                    ...items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 12.5),
                                  color: widget.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Expanded(
                                child: SelectionArea(
                                  child: Text(
                                    item as String,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: AppTheme.scaledFontSize(
                                          context, 12.5),
                                      color: TimeThemeKit.of(context).palette.textSecondary,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
