import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/providers/quran_teacher_providers.dart';

/// «تنظیمات دفتر» — the three facts and two rules the teacher settings row has
/// always carried, with no screen writing them until now.
///
/// The names are not decoration: the parent report prints the teacher's name
/// and the mosque, and a report signed by an empty string is worse than one
/// with no signature. The two switches change the numbers the app shows
/// («مرخص از مخرج حذف شود» moves the attendance percentage, and the absence
/// alert is the banner on the student profile), so each one is written the
/// moment it is touched.
Future<void> showTeacherSettingsSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final dao = ref.read(quranTeacherDaoProvider);
  final settings = await dao.settings();
  if (!context.mounted) return;

  final teacherCtrl = TextEditingController(text: settings.teacherName);
  final mosqueCtrl = TextEditingController(text: settings.mosqueName);
  var excusedExcluded = settings.excusedExcluded;
  var absenceAlert = settings.absenceStreakAlert;

  TeacherSettingsRecord withValues() => TeacherSettingsRecord(
        className: settings.className,
        mosqueName: mosqueCtrl.text.trim(),
        teacherName: teacherCtrl.text.trim(),
        excusedExcluded: excusedExcluded,
        absenceStreakAlert: absenceAlert,
        remindersEnabled: settings.remindersEnabled,
        classStartReminder: settings.classStartReminder,
        unrecordedReminder: settings.unrecordedReminder,
        weeklySummary: settings.weeklySummary,
        quietStartMinutes: settings.quietStartMinutes,
        quietEndMinutes: settings.quietEndMinutes,
      );

  Future<bool> save() async {
    final ok = await dao.saveSettings(withValues());
    ref.invalidate(quranTeacherHomeProvider);
    ref.invalidate(quranStudentProfileProvider);
    return ok;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final t = TimeThemeKit.of(sheetContext).palette;
        Widget label(String text) => Padding(
              padding: const EdgeInsets.only(bottom: 4, top: 10),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: t.textSecondary,
                ),
              ),
            );

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تنظیمات دفتر',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  Text(
                    'این نام‌ها در سربرگ گزارش والدین چاپ می‌شوند.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      height: 1.7,
                      color: t.textMuted,
                    ),
                  ),
                  label('نام مربی'),
                  TextField(
                    controller: teacherCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'مثلاً «عبدالله»',
                    ),
                  ),
                  label('نام مسجد یا مرکز'),
                  TextField(
                    controller: mosqueCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'مثلاً «مسجد جامع»',
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Personal2Colors.teacher,
                    title: Text(
                      'مرخص از مخرج حضور حذف شود',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: t.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'یک غیبت مرخص‌شده، حضور را پایین نمی‌آورد.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                        height: 1.6,
                        color: t.textMuted,
                      ),
                    ),
                    value: excusedExcluded,
                    onChanged: (v) async {
                      setSheetState(() => excusedExcluded = v);
                      await save();
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Personal2Colors.teacher,
                    title: Text(
                      'هشدار غیبت‌های متوالی',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: t.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'از سه جلسهٔ متوالی، در پروندهٔ شاگرد یادآوری تماس '
                      'با ولی نشان داده می‌شود.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                        height: 1.6,
                        color: t.textMuted,
                      ),
                    ),
                    value: absenceAlert,
                    onChanged: (v) async {
                      setSheetState(() => absenceAlert = v);
                      await save();
                    },
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Personal2Colors.teacher,
                    ),
                    onPressed: () async {
                      final ok = await save();
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'تنظیمات ذخیره شد.'
                                : 'ذخیرهٔ تنظیمات ممکن نشد.',
                            style:
                                TextStyle(fontFamily: AppTheme.fontFamily),
                          ),
                        ),
                      );
                      if (ok) Navigator.of(sheetContext).pop();
                    },
                    child: const Text('ذخیره'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
