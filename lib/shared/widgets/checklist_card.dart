import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/theme/theme.dart';

class ChecklistCard extends StatefulWidget {
  final String sectionKey;
  final String title;
  final IconData icon;
  final List<String> items;
  final Color accentColor;

  const ChecklistCard({
    super.key,
    required this.sectionKey,
    required this.title,
    required this.icon,
    required this.items,
    this.accentColor = AppTheme.goldPale,
  });

  @override
  State<ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<ChecklistCard> {
  Set<int> _checked = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('hajj_checklist_${widget.sectionKey}');
    if (saved != null && saved.isNotEmpty) {
      _checked = saved
          .split(',')
          .map((e) => int.tryParse(e) ?? -1)
          .where((e) => e >= 0)
          .toSet();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(int index) async {
    setState(() {
      if (_checked.contains(index)) {
        _checked.remove(index);
      } else {
        _checked.add(index);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'hajj_checklist_${widget.sectionKey}', _checked.join(','));
  }

  Future<void> _reset() async {
    setState(() => _checked.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hajj_checklist_${widget.sectionKey}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final doneCount = _checked.length;
    final totalCount = widget.items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: 18, color: widget.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$doneCount/$totalCount',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                  ),
                ),
              ),
            ],
          ),
          if (doneCount > 0 && doneCount == totalCount) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 16, color: success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'همه موارد انجام شد ✓',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w600,
                        color: success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...widget.items
              .asMap()
              .entries
              .map((entry) => _buildItem(context, entry.key, entry.value)),
          const SizedBox(height: 8),
          if (doneCount > 0)
            Center(
              child: TextButton.icon(
                onPressed: _reset,
                icon: Icon(Icons.refresh,
                    size: 14, color: t.textMuted),
                label: Text(
                  'بازنشانی',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, String text) {
    final t = TimeThemeKit.of(context).palette;
    final checked = _checked.contains(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _toggle(index),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: checked ? widget.accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked
                      ? widget.accentColor
                      : (t.outline),
                  width: checked ? 0 : 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: checked
                      ? t.textMuted
                      : t.textSecondary,
                  height: 1.5,
                  decoration: checked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
