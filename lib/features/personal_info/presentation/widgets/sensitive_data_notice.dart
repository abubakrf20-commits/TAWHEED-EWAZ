import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Caution shown at the top of «اطلاعات من»: the vault is encrypted, but it is
/// not the place for banking codes that can be used the moment they leak.
class SensitiveDataNotice extends StatelessWidget {
  const SensitiveDataNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اطلاعات حساس را در این بخش ذخیره نکنید',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'رمز دوم پویا، کد CVV2 و رمزهای یک‌بارمصرف بانکی را اینجا '
                  'نگه ندارید. اطلاعات صندوق با رمز ورود شما رمزنگاری می‌شود، '
                  'اما برای رمزهای بانکی از روش‌های امن بانک استفاده کنید.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    height: 1.5,
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
