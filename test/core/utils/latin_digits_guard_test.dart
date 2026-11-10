import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app's digit standard is Latin, and `main.dart` is why this is a scan
/// rather than a formatting rule: it pins `Locale('fa')`, so every Material
/// date/time dialog renders its dial, its header and its text-input mode with
/// Persian digits on EVERY phone, and Material's own text mode parses with a
/// plain `int.tryParse` — a typed «۲۱:۳۰» is then refused as invalid. `intl`'s
/// `DateFormat`/`formatTimeOfDay` follow the same locale.
///
/// The locale is a product decision and `main.dart` is protected ground, so the
/// only way to keep Latin digits is to never open those dialogs. Every time and
/// date door goes through one of two home-grown surfaces instead:
/// `showLatinTimePicker` (`shared/widgets/latin_time_picker.dart`) folds ۰-۹/٠-٩
/// to ASCII as the user types, and `ShamsiDatePicker` builds its own calendar
/// grid. This test is what stops a third screen from reaching for Material.
void main() {
  const forbidden = <String, String>{
    'showTimePicker(':
        'Material time dial — renders Persian digits under Locale(fa)',
    'showDatePicker(': 'Material date picker — Persian digits in both modes',
    'showDateRangePicker(': 'Material range picker — same locale',
    'formatTimeOfDay(': 'intl time formatter — locale digits',
    'DateFormat(': 'intl date formatter — locale digits',
    'package:intl/': 'intl itself — every formatter in it is locale-aware',
  };

  /// `//` and `/* */` prose may name a forbidden API to explain why it is
  /// forbidden (this file does), so the scan reads code only.
  String stripComments(String source) {
    final out = StringBuffer();
    final lines = source.split('\n');
    var inBlock = false;
    for (final line in lines) {
      if (inBlock) {
        final end = line.indexOf('*/');
        out.writeln(end < 0 ? '' : line.substring(end + 2));
        inBlock = end < 0;
        continue;
      }
      final block = line.indexOf('/*');
      final slash = line.indexOf('//');
      if (block >= 0 && (slash < 0 || block < slash)) {
        final end = line.indexOf('*/', block);
        if (end < 0) {
          inBlock = true;
          out.writeln(line.substring(0, block));
        } else {
          out.writeln('${line.substring(0, block)}${line.substring(end + 2)}');
        }
        continue;
      }
      out.writeln(slash < 0 ? line : line.substring(0, slash));
    }
    return out.toString();
  }

  List<File> libDartFiles() {
    final dir = Directory('lib');
    if (!dir.existsSync()) {
      fail('run the suite from the repository root (lib/ not found)');
    }
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .toList();
  }

  test('no screen opens a Material or intl date/time dialog', () {
    final offenders = <String>[];
    for (final file in libDartFiles()) {
      final path = file.path.replaceAll(r'\', '/');
      final lines = stripComments(file.readAsStringSync()).split('\n');
      for (var i = 0; i < lines.length; i++) {
        for (final entry in forbidden.entries) {
          if (lines[i].contains(entry.key)) {
            offenders.add('$path:${i + 1} ${entry.key} — ${entry.value}');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'these surfaces print Persian digits; route them through '
            'showLatinTimePicker or ShamsiDatePicker instead:\n'
            '${offenders.join('\n')}');
  });

  test('the one time dialog is what every hour picker opens', () {
    final dialog = File('lib/shared/widgets/latin_time_picker.dart');
    expect(dialog.existsSync(), isTrue,
        reason: 'showLatinTimePicker is the app\'s only time-entry dialog');
    final source = dialog.readAsStringSync();
    expect(source, contains('class LatinTimePickerDialog'));
    // Folding happens on the way in, so a Persian keyboard still stores ASCII.
    expect(source, contains('NumberFormat.normalizeDigits'));

    final callers = libDartFiles()
        .where((f) => stripComments(f.readAsStringSync())
            .contains('showLatinTimePicker('))
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toList();
    expect(callers.length, greaterThanOrEqualTo(8),
        reason: 'the converted call sites may not shrink back: $callers');
    expect(callers, contains('lib/shared/widgets/latin_time_picker.dart'));
  });

  test('the two duplicated private time dialogs stay deleted', () {
    expect(
        File('lib/features/khatm/presentation/widgets/khatm/khatm_time_dialog.dart')
            .existsSync(),
        isFalse,
        reason: 'khatm uses showLatinTimePicker — a second dialog drifts');
    final azkar =
        File('lib/features/adhkar/presentation/screens/azkar_tasbih_tab.dart');
    final source = stripComments(azkar.readAsStringSync());
    expect(source, contains('showLatinTimePicker('));
    expect(source, isNot(contains('_showTimeEntryDialog')));
  });

  test('a free-text hour field folds typed Persian digits before storing', () {
    final goals =
        File('lib/features/goals/presentation/screens/goal_editor_screen.dart');
    expect(stripComments(goals.readAsStringSync()),
        contains('inputFormatters: const [LatinDigitFoldFormatter()]'),
        reason:
            'the 24-hour reminder field must not persist a Persian-digit value');
  });

  test('the reminder time reads through the app 12/24 formatter', () {
    final tasks =
        File('lib/features/tasks/presentation/widgets/tasks/tasks_dialog.dart');
    final source = tasks.readAsStringSync();
    expect(source, contains('TimeFormatters.formatTime('));
    expect(source, contains('use12Hour: ref.watch(use12HourProvider)'));
  });

  test('the Jalali dialog still answers for a bounded back-dated pick', () {
    final zakat =
        File('lib/features/tools/zakat/presentation/screens/zakat_screen.dart');
    final source = stripComments(zakat.readAsStringSync());
    expect(source, contains('ShamsiDatePicker.show('));
    expect(source, contains('earliestDate:'));
    expect(source, contains('latestDate:'));
    // The dialog has no helpText of its own; the caller names what it asks.
    expect(source, contains('تاریخ رسیدن به نصاب'));
  });
}
