import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';

int bruteForce(int jd) {
  final year = HijriUtils.findHijriYear(jd);
  final month = HijriUtils.hijriMonthFromJd(jd, year);
  if (month == 9) return 0;
  final startYear = month < 9 ? year : year + 1;
  return HijriUtils.hijriToJd(startYear, 9, 1) - jd;
}

void main() {
  test('daysUntilRamadan JD arithmetic matches brute force 2020-2040', () {
    var checked = 0;
    for (var y = 2020; y <= 2040; y++) {
      for (var m = 1; m <= 12; m++) {
        final dim = DateTime(y, m + 1, 0).day;
        for (var d = 1; d <= dim; d++) {
          final jd = HijriUtils.gregToJd(y, m, d);
          final year = HijriUtils.findHijriYear(jd);
          final month = HijriUtils.hijriMonthFromJd(jd, year);
          final actual = month == 9
              ? 0
              : HijriUtils.hijriToJd(month < 9 ? year : year + 1, 9, 1) - jd;
          expect(actual, bruteForce(jd), reason: 'y=$y m=$m d=$d');
          checked++;
        }
      }
    }
    expect(checked, greaterThan(7600));
  });
}
