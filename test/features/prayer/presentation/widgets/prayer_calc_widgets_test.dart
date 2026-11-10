import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/prayer_calc_widgets.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

void main() {
  group('PrayerCalculationDetailsSheet', () {
    testWidgets('renders every row label and value', (tester) async {
      const rows = [
        (label: 'روش محاسبه', value: 'تهران (ایران رسمی)'),
        (label: 'زاویه فجر', value: '17.7 درجه'),
        (label: 'مذهب عصر', value: 'شافعی (سایه یک برابر)'),
      ];
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrayerCalculationDetailsSheet(rows: rows),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('جزئیات محاسبه اوقات شرعی'), findsOneWidget);
      expect(find.text('روش محاسبه'), findsOneWidget);
      expect(find.text('تهران (ایران رسمی)'), findsOneWidget);
      expect(find.text('زاویه فجر'), findsOneWidget);
      expect(find.text('17.7 درجه'), findsOneWidget);
      expect(find.text('مذهب عصر'), findsOneWidget);
    });
  });

  group('showCalculationMethodPicker', () {
    testWidgets(
        'lists methods with their angle descriptions and reports the '
        'selection', (tester) async {
      CalculationMethodOption? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showCalculationMethodPicker(
                    context,
                    selected: CalculationMethodOption.tehran,
                    onSelected: (v) => picked = v,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The selected method and a non-selected one are listed, with angles.
      expect(find.text('تهران (ایران رسمی)'), findsOneWidget);
      expect(
        find.text('زاویه فجر 17.7°، عشاء 14° و مغرب 4.5°'),
        findsOneWidget,
      );
      expect(find.text('رابطه عالم اسلامی'), findsOneWidget);

      // «خودکار» is the app default, so it leads the list (above every
      // explicit method).
      expect(find.text('خودکار — بر اساس کشور'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('خودکار — بر اساس کشور')).dy,
        lessThan(tester.getTopLeft(find.text('رابطه عالم اسلامی')).dy),
      );

      // Picking a method calls onSelected with that option.
      await tester.tap(find.text('رابطه عالم اسلامی'));
      await tester.pumpAndSettle();
      expect(picked, CalculationMethodOption.muslimWorldLeague);
    });
  });

  group('PrayerAngleSlider', () {
    testWidgets('shows the value and fires onChanged', (tester) async {
      double? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrayerAngleSlider(
              label: 'زاویه فجر',
              value: 17.5,
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      );
      expect(find.text('زاویه فجر'), findsOneWidget);
      expect(find.text('17.5°'), findsOneWidget);

      await tester.drag(find.byType(Slider), const Offset(30, 0));
      expect(changed, isNotNull);
    });

    testWidgets('fires onSettled once when the drag ends', (tester) async {
      var settles = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrayerAngleSlider(
              label: 'زاویه فجر',
              value: 17.5,
              onChanged: (v) {},
              onSettled: (v) => settles++,
            ),
          ),
        ),
      );

      await tester.drag(find.byType(Slider), const Offset(30, 0));
      expect(settles, 1);
    });
  });
}
