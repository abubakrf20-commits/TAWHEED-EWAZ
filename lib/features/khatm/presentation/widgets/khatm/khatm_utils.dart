import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';

/// نسبت صفحات خوانده‌شده در یک جزء (0٫0 تا 1٫0).
double juzProgressOf(KhatmModel khatm, int juz) {
  final startPage = (juz - 1) * 20 + 1;
  final endPage = juz == 30 ? 604 : juz * 20;
  var read = 0;
  for (var p = startPage; p <= endPage; p++) {
    if (p > khatm.pagesRead.length) break;
    if (khatm.pagesRead[p - 1]) read++;
  }
  return read / (endPage - startPage + 1);
}

bool isJuzCompletedOf(KhatmModel khatm, int juz) =>
    juzProgressOf(khatm, juz) >= 1.0;
