import 'package:flutter/widgets.dart';
import 'package:tawheeed/core/constants/month_display.dart';

/// Repaints its dependents when the user flips «روش عرضه ماه».
///
/// `DateConstants.persianMonths` is a static getter, so reading it does not
/// subscribe anything to the change; a screen that must repaint on the flip
/// calls [MonthDisplayScope.of] in its build.
class MonthDisplayScope extends InheritedNotifier<ValueNotifier<MonthDisplay>> {
  MonthDisplayScope({super.key, required super.child})
    : super(notifier: monthDisplayNotifier);

  static MonthDisplay of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MonthDisplayScope>()
          ?.notifier
          ?.value ??
      monthDisplayNotifier.value;
}
