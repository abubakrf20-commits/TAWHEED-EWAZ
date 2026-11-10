import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/providers/quran_teacher_providers.dart';

/// The one student form: add a new name to a class, or edit an existing row.
///
/// It is shared by «مدیریت کلاس‌ها» and «پروندهٔ شاگرد» on purpose — the two had
/// diverged, and only this one carries the two fields the tool already stores
/// and never wrote: the birth year (the profile prints the age) and the
/// teacher's own note about the student.
Future<void> showStudentEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required String classId,
  StudentRecord? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final yearCtrl =
      TextEditingController(text: existing?.birthYear?.toString() ?? '');
  final parentCtrl = TextEditingController(text: existing?.parentName ?? '');
  final phoneCtrl = TextEditingController(text: existing?.parentPhone ?? '');
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  var active = existing?.active ?? true;
  String? error;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final t = TimeThemeKit.of(sheetContext).palette;
        final currentYear = DateTime.now().year;

        Future<void> save() async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) {
            setSheetState(() => error = 'نام شاگرد لازم است.');
            return;
          }
          final yearText = yearCtrl.text.trim();
          final year = int.tryParse(yearText);
          if (yearText.isNotEmpty &&
              (year == null || year < 1300 || year > currentYear)) {
            setSheetState(() => error = 'سال تولد را چهاررقمی و درست بنویسید.');
            return;
          }
          final ok = await ref.read(quranTeacherDaoProvider).saveStudent(
                id: existing?.id ??
                    'stu_${DateTime.now().microsecondsSinceEpoch}',
                classId: classId,
                name: name,
                birthYear: year,
                parentName: parentCtrl.text.trim(),
                parentPhone: phoneCtrl.text.trim(),
                note: noteCtrl.text.trim(),
                active: active,
              );
          if (!sheetContext.mounted) return;
          if (!ok) {
            setSheetState(() => error = 'ذخیرهٔ شاگرد ممکن نشد.');
            return;
          }
          ref.invalidate(quranStudentsProvider(classId));
          ref.invalidate(quranTeacherHomeProvider);
          ref.invalidate(quranClassDayProvider(classId));
          ref.invalidate(quranClassHistoryProvider(classId));
          if (existing != null) {
            ref.invalidate(quranStudentProfileProvider(existing.id));
          }
          Navigator.of(sheetContext).pop();
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null ? 'شاگرد تازه' : 'ویرایش شاگرد',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'نام شاگرد',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: yearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'سال تولد (اختیاری)',
                        helperText:
                            'برای نمایش سن در پرونده؛ تاریخ تولد و جشن برایش '
                            'ساخته نمی‌شود.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: parentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'نام ولی (اختیاری)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'شمارهٔ ولی (دستی)',
                        helperText:
                            'شماره دستی وارد می‌شود؛ دفترچه تلفن خوانده نمی‌شود.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'یادداشت مربی',
                        hintText: 'مثلاً «در حرکات کوتاه باید تمرین کند»',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (existing != null) ...[
                      const SizedBox(height: 4),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Personal2Colors.teacher,
                        title: Text(
                          'در فهرست فعال باشد',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: t.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'با خاموش‌کردن، شاگرد از فهرست روزانه حذف می‌شود ولی '
                          'حضور و درس‌هایش می‌مانند.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10,
                            height: 1.6,
                            color: t.textMuted,
                          ),
                        ),
                        value: active,
                        onChanged: (v) => setSheetState(() => active = v),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        error!,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: DsStatus.danger(sheetContext),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Personal2Colors.teacher,
                      ),
                      onPressed: save,
                      child: const Text('ذخیره'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
