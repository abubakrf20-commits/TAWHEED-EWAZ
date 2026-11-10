import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// بنر شفاف «سرویس ابری در دسترس نیست» برای صفحات متکی به Firestore
/// (ارسال پیشنهاد، پیام‌های مدیریت).
///
/// تا پیش از این، نبودِ Firebase در صفحهٔ پیشنهادها فقط به‌صورت سکوت دیده
/// می‌شد: بخش‌های ابری رندر نمی‌شدند و کاربر نمی‌فهمید چرا. این بنر حالت را
/// صریح می‌کند؛ [detail] توضیح اختصاصی هر صفحه را اضافه می‌کند.
class ServiceUnavailableBanner extends StatelessWidget {
  final String detail;

  const ServiceUnavailableBanner({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: border.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, size: 20, color: border),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'سرویس آنلاین در دسترس نیست',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    height: 1.6,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
