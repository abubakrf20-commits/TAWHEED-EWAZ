import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// برچسب رنگی درجه صحت حدیث (صحيح/حسن/ضعيف/موضوع).
///
/// رنگ‌ها از متن حکم عربیِ بازگشتی از درر استخراج می‌شود؛ متن خودِ حکم
/// تغییر نمی‌کند تا کاربر بتواند عین عبارت محدث را بخواند.
class HadithDegreeChip extends StatelessWidget {
  final String? degree;

  const HadithDegreeChip({super.key, this.degree});

  static Color colorFor(BuildContext context, String? degree) {
    final d = (degree ?? '').trim();
    if (d.contains('موضوع') || d.contains('مصنوع') || d.contains('كذب')) {
      return Colors.grey;
    }
    if (d.contains('ضعي') || d.contains('ضعیف') || d.contains('weak')) {
      return Colors.red;
    }
    if (d.contains('حسن') || d.contains('good')) {
      return Colors.orange;
    }
    if (d.contains('صحي') || d.contains('صحیح') || d.contains('ثابت')) {
      return Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSuccess
          : AppTheme.lightSuccess;
    }
    return TimeThemeKit.of(context).palette.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final text = (degree ?? '').trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final color = colorFor(context, text);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
