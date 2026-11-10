import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Confirms removing one downloaded content database from the device.
///
/// Shared by the five book sections and «مدیریت فضا» so the promise — the
/// data really goes away, and a later visit offers the download again — can
/// never be worded differently in two places.
Future<bool> confirmContentDatabaseDelete(
  BuildContext context, {
  required String name,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final t = TimeThemeKit.of(ctx).palette;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'حذف «$name»؟',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(ctx, 16),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'دادهٔ «$name» از این دستگاه حذف می‌شود. برای مطالعهٔ دوباره باید '
          'همین‌جا دوباره دانلودش کنید.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(ctx, 13),
            height: 1.7,
            color: t.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
