import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/domain/quran_teacher_logic.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/providers/quran_teacher_providers.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/student_edit_sheet.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/shared/widgets/latin_time_picker.dart';

/// «مدیریت کلاس‌ها» — classes and students CRUD, CSV export and the paste-in
/// student import (one name per line, with a preview).
class ClassManagementScreen extends ConsumerStatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  ConsumerState<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends ConsumerState<ClassManagementScreen> {
  String? _selectedClassId;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final home = ref.watch(quranTeacherHomeProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          accent: Personal2Colors.teacher,
          title: 'مدیریت کلاس‌ها',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'افزودن کلاس',
              icon: const Icon(Icons.add),
              onPressed: () => _editClass(context),
            ),
          ],
        ),
        body: SafeArea(
          child: home.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FailureView(
              id: 'quran_classes_load',
              title: 'کلاس‌ها باز نشدند',
              detail: 'کلاس‌ها و شاگردها پاک نشده‌اند؛ فقط خواندنشان '
                  'ناموفق بود.',
              onRetry: () => ref.invalidate(quranTeacherHomeProvider),
              layout: FailureLayout.page,
              error: e,
            ),
            data: (data) {
              if (data.classes.isEmpty) {
                return AppEmptyState(
                  icon: Icons.groups_rounded,
                  accent: Personal2Colors.teacher,
                  message: 'کلاسی ثبت نشده',
                  subtitle: 'اولین کلاس را بسازید.',
                  actionLabel: 'افزودن کلاس',
                  onAction: () => _editClass(context),
                );
              }
              final selected = data.classes.any((c) => c.id == _selectedClassId)
                  ? _selectedClassId!
                  : data.classes.first.id;
              final klass = data.classes.firstWhere((c) => c.id == selected);

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    DsSpacing.page, 12, DsSpacing.page, 40),
                children: [
                  for (final c in data.classes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: AppCard(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        borderColor: c.id == selected
                            ? Personal2Colors.teacher
                            : null,
                        onTap: () => setState(() => _selectedClassId = c.id),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: t.textPrimary,
                                    ),
                                  ),
                                  if (c.place.isNotEmpty ||
                                      c.startMinutes != null)
                                    Text(
                                      [
                                        if (c.place.isNotEmpty) c.place,
                                        if (c.startMinutes != null)
                                          classTimeLabel(c.startMinutes!),
                                      ].join(' · '),
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 10,
                                        color: t.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'ویرایش',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _editClass(context, existing: c),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SectionHeader(
                    title: 'شاگردان ${klass.name}',
                    accent: Personal2Colors.teacher,
                  ),
                  const SizedBox(height: 6),
                  _students(context, klass),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Personal2Colors.teacher,
                    ),
                    onPressed: () => _editStudent(context, klass),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('افزودن شاگرد'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _importStudents(context, klass),
                          icon: const Icon(Icons.playlist_add_rounded, size: 18),
                          label: const Text('افزودن از متن'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _exportCsv(klass),
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: const Text('CSV'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _students(BuildContext context, ClassGroupRecord klass) {
    final t = TimeThemeKit.of(context).palette;
    final future = ref.watch(quranStudentsProvider(klass.id));
    return future.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => FailureView(
        id: 'quran_class_students_load',
        title: 'شاگردها باز نشدند',
        detail: 'فهرست شاگردان پاک نشده است؛ فقط خواندنش ناموفق بود.',
        onRetry: () => ref.invalidate(quranStudentsProvider(klass.id)),
        error: e,
      ),
      data: (students) => students.isEmpty
          ? AppCard(
              child: Text(
                'هنوز شاگردی ندارد.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: t.textSecondary,
                ),
              ),
            )
          : Column(
              children: [
                for (final student in students)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 12,
                                    color: t.textPrimary,
                                  ),
                                ),
                                if (student.parentPhone.isNotEmpty)
                                  Text(
                                    student.parentPhone,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 10,
                                      color: t.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_outlined, size: 17),
                            onPressed: () =>
                                _editStudent(context, klass, existing: student),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _editClass(
    BuildContext context, {
    ClassGroupRecord? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final placeCtrl = TextEditingController(text: existing?.place ?? '');
    final t = TimeThemeKit.of(context).palette;
    var mask = existing?.weekdaysMask ?? 0x7F;
    // The class start is what «نیم ساعت قبل از کلاس» is measured from — the
    // reminder existed while no screen could set the time it depends on.
    var startMinutes = existing?.startMinutes;
    var durationMin = existing?.durationMin ?? 60;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: t.elevated,
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام کلاس',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: placeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'مکان (اختیاری)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'روزهای جلسه',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: t.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < 7; i++)
                      FilterChip(
                        label: Text(const ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'][i]),
                        selected: (mask & (1 << i)) != 0,
                        onSelected: (v) => setSheetState(() {
                          if (v) {
                            mask |= 1 << i;
                          } else {
                            mask &= ~(1 << i);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // The app pins Locale('fa'), and Material's dial
                          // prints Persian digits and parses them with a plain
                          // int.tryParse — the Latin picker is the only door
                          // (test/core/utils/latin_digits_guard_test.dart).
                          final picked = await showLatinTimePicker(
                            sheetContext,
                            initialTime: startMinutes == null
                                ? const TimeOfDay(hour: 17, minute: 0)
                                : TimeOfDay(
                                    hour: startMinutes! ~/ 60,
                                    minute: startMinutes! % 60,
                                  ),
                          );
                          if (picked == null) return;
                          setSheetState(() {
                            startMinutes = picked.hour * 60 + picked.minute;
                          });
                        },
                        icon: const Icon(Icons.schedule_rounded, size: 16),
                        label: Text(
                          startMinutes == null
                              ? 'ساعت شروع کلاس'
                              : classTimeLabel(startMinutes!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: durationMin,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'مدت جلسه',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 45, child: Text('۴۵ دقیقه')),
                          DropdownMenuItem(value: 60, child: Text('۶۰ دقیقه')),
                          DropdownMenuItem(value: 90, child: Text('۹۰ دقیقه')),
                        ],
                        onChanged: (v) =>
                            setSheetState(() => durationMin = v ?? 60),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Personal2Colors.teacher,
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          await ref.read(quranTeacherDaoProvider).saveClass(
                                id: existing?.id ??
                                    'class_${DateTime.now().microsecondsSinceEpoch}',
                                name: name,
                                place: placeCtrl.text.trim(),
                                weekdaysMask: mask,
                                startMinutes: startMinutes,
                                durationMin: durationMin,
                              );
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                          ref.invalidate(quranTeacherHomeProvider);
                        },
                        child: const Text('ذخیره'),
                      ),
                    ),
                    if (existing != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await ref
                                .read(quranTeacherDaoProvider)
                                .archiveClass(existing.id);
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            ref.invalidate(quranTeacherHomeProvider);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DsStatus.danger(context),
                          ),
                          child: const Text('بایگانی'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The shared student form (also reachable from the profile).
  Future<void> _editStudent(
    BuildContext context,
    ClassGroupRecord klass, {
    StudentRecord? existing,
  }) {
    return showStudentEditSheet(
      context,
      ref,
      classId: klass.id,
      existing: existing,
    );
  }


  /// Paste-in import: one name per line, with a preview and a count.
  Future<void> _importStudents(BuildContext context, ClassGroupRecord klass) async {
    final ctrl = TextEditingController();
    final t = TimeThemeKit.of(context).palette;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final names = ctrl.text
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(sheetContext).size.height * .7,
              decoration: BoxDecoration(
                color: t.elevated,
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  Text(
                    'هر نام در یک خط',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'علی\nمریم\nحسن',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${names.length} نام آماده است',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Personal2Colors.teacher,
                    ),
                    onPressed: names.isEmpty
                        ? null
                        : () async {
                            final dao = ref.read(quranTeacherDaoProvider);
                            final stamp = DateTime.now().microsecondsSinceEpoch;
                            var i = 0;
                            for (final name in names) {
                              await dao.saveStudent(
                                id: 'stu_${stamp}_${i++}',
                                classId: klass.id,
                                name: name,
                              );
                            }
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            ref.invalidate(quranStudentsProvider(klass.id));
                            ref.invalidate(quranTeacherHomeProvider);
                            ref.invalidate(quranClassDayProvider(klass.id));
                          },
                    child: Text('افزودن ${names.length} شاگرد'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportCsv(ClassGroupRecord klass) async {
    final students = await ref.read(quranStudentsProvider(klass.id).future);
    // The roster only: names as the teacher typed them, plus the parent phone
    // they chose to record. No attendance history leaves the device via this
    // action unless the teacher shares the file — and it goes through the
    // system sheet, so nothing is uploaded by the app.
    final buffer = StringBuffer('name,parent_name,parent_phone\n');
    for (final s in students) {
      buffer.writeln(
        '${_csv(s.name)},${_csv(s.parentName)},${_csv(s.parentPhone)}',
      );
    }
    await ShareService.shareText(
      buffer.toString(),
      subject: 'فهرست شاگردان ${klass.name}',
    );
  }

  /// CSV escaping: quote when the value contains a comma, quote or newline.
  static String _csv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
