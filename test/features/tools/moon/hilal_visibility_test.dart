import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/astronomy.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/hilal_calendar.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/hilal_visibility.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/moon_position.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/sun_position.dart';
import 'package:tawheeed/features/tools/moon/domain/services/lunar_calculator.dart';

const tehranLat = 35.6892;
const tehranLng = 51.389;

SunsetHilalData _sunset(DateTime date) =>
    HilalVisibility.atSunset(date: date, lat: tehranLat, lng: tehranLng)!;

void main() {
  group('HilalVisibility — وضعیت هلال در غروب (تهران)', () {
    // محاق اسفند ۱۴۰۲: 2024-03-10 ساعت 09:00 UTC
    test('شب محاق — فروتر از حد دانژون', () {
      final d = _sunset(DateTime(2024, 3, 10));
      expect(d.verdict, HilalSightingVerdict.belowDanjon);
      expect(d.arcl, lessThan(7));
      expect(d.ageHoursAtSunset, inInclusiveRange(2, 10));
      expect(d.lagMinutes, greaterThan(0));
    });

    test('غروبِ زودِ ماه — lag منفی و رأی preSunsetMoonset', () {
      // دو روز پیش از محاق ۲۰۲۴-۰۳-۱۰: ماه پیش از خورشید زیر افق میرود؛
      // باگ قبلی علامت را قرینه میکرد و lag مثبت نشان داده میشد.
      final d = _sunset(DateTime(2024, 3, 8));
      expect(d.moonset!.isBefore(d.sunset), isTrue);
      expect(d.lagMinutes, lessThan(0));
      expect(d.verdict, HilalSightingVerdict.preSunsetMoonset);
    });

    test('یک روز پس از محاق — رؤیتپذیرِ بالقوه با پارامترهای سازگار', () {
      final d = _sunset(DateTime(2024, 3, 11));
      expect(d.verdict, isNot(HilalSightingVerdict.belowDanjon));
      expect(d.verdict, isNot(HilalSightingVerdict.preSunsetMoonset));

      expect(d.arcl, inInclusiveRange(7, 25));
      expect(d.ageHoursAtSunset, inInclusiveRange(20, 40));
      expect(d.ageHoursAtBest, inInclusiveRange(20, 40));
      expect(d.crescentWidthArcMin, greaterThan(0));
      expect(d.crescentWidthArcMin, lessThan(1));
      expect(d.illuminationPercent, lessThan(10));
      expect(d.moonDistanceKm, inInclusiveRange(350000, 410000));
      expect(d.lagMinutes, greaterThan(0));
      expect(d.arcvTopocentric, lessThan(d.arcvGeocentric));
      expect(d.danjon.belowLimit, isFalse);
      expect(d.anyPossibility, isTrue);
    });

    test('همارزی پارامترها با فرمولهای مرجع (یالوپ، عوده، بروین)', () {
      final d = _sunset(DateTime(2024, 3, 11));
      final w = d.crescentWidthArcMin;

      final arcvPrime =
          11.8371 - 6.3226 * w + 0.7319 * w * w - 0.1018 * w * w * w;
      final q = (d.arcvGeocentric - arcvPrime) / 10;
      expect(d.yallop.q, closeTo(q, 1e-9));
      expect(d.yallop.arcvPrime, closeTo(arcvPrime, 1e-9));

      final v = d.arcvTopocentric +
          6.3226 * w -
          0.7319 * w * w +
          0.1018 * w * w * w -
          7.1651;
      expect(d.odeh.v, closeTo(v, 1e-9));

      final crit = 12.4023 - 9.4878 * w + 3.9512 * w * w - 0.5632 * w * w * w;
      expect(d.bruin.arcvCritical, closeTo(crit, 1e-9));
      expect(d.bruin.visible, d.arcvGeocentric > crit);
      expect(d.danjon.belowLimit, d.arcl < 7.0);
      expect(d.danjon.limitDeg, 7.0);
    });

    test('طبقهبندی یالوپ و عوده با مرزهای ناحیهای تطبیق دارد', () {
      final d = _sunset(DateTime(2024, 3, 11));

      final q = d.yallop.q;
      final expectedYallop = q >= 0.216
          ? YallopClass.a
          : q >= -0.014
              ? YallopClass.b
              : q >= -0.160
                  ? YallopClass.c
                  : q >= -0.232
                      ? YallopClass.d
                      : q >= -0.293
                          ? YallopClass.e
                          : YallopClass.f;
      expect(d.yallop.cls, expectedYallop);

      final v = d.odeh.v;
      final expectedOdeh = v >= 5.65
          ? OdehClass.a
          : v >= 2
              ? OdehClass.b
              : v >= -0.96
                  ? OdehClass.c
                  : OdehClass.d;
      expect(d.odeh.cls, expectedOdeh);
    });

    test('شباهت هندسی: ARCL، عرض هلال و بهترین زمان با فرمولها', () {
      final d = _sunset(DateTime(2024, 3, 11));

      final mp = Moon.position(Astronomy.julianDay(d.bestTime));
      final sp = Sun.position(Astronomy.julianDay(d.bestTime));
      final cosArcl = math.sin(sp.dec * Astronomy.deg2Rad) *
              math.sin(mp.dec * Astronomy.deg2Rad) +
          math.cos(sp.dec * Astronomy.deg2Rad) *
              math.cos(mp.dec * Astronomy.deg2Rad) *
              math.cos((sp.ra - mp.ra) * Astronomy.deg2Rad);
      final arcl = math.acos(cosArcl.clamp(-1.0, 1.0)) * Astronomy.rad2Deg;
      expect(d.arcl, closeTo(arcl, 0.01));

      final sdDeg = math.asin(1738.1 / d.moonDistanceKm) * Astronomy.rad2Deg;
      expect(d.crescentWidthDeg,
          closeTo(sdDeg * (1 - math.cos(arcl * Astronomy.deg2Rad)), 1e-9));

      // بهترین زمان = غروب + ۴/۹ مکث
      final lag = d.moonset!.difference(d.sunset);
      final expectedLag = Duration(microseconds: (lag.inMicroseconds * 4 ~/ 9));
      final diff = d.bestTime.difference(d.sunset).inMicroseconds;
      expect((diff - expectedLag.inMicroseconds).abs(), lessThanOrEqualTo(60));
    });

    test('اختلاف آزیموت با قرارداد قطبنما یکسان است (ماه − خورشید)', () {
      // چیپ «اختلاف آزیموت» و قطبنمای «اختلاف آزیموت با خورشید» یک کمیت را
      // نشان می‌دهند؛ علامت قرینه، رصدگر را به سمت اشتباه می‌فرستاد.
      final d = _sunset(DateTime(2024, 3, 11));
      var wrapped = (d.moonAzimuth - d.sunAzimuth) % 360;
      if (wrapped > 180) wrapped -= 360;
      if (wrapped < -180) wrapped += 360;
      expect(d.daz, closeTo(wrapped, 1e-9));
      expect(d.daz, inInclusiveRange(-180, 180));
    });

    test('پارالاکس کامل توپومرکزی — مرجع JPL Horizons (۲۰۲۴-۰۳-۱۱ ۱۲:۲۰ UTC)',
        () {
      // مرجع: NASA JPL Horizons، apparent RA/Dec (airless) برای تهران
      // 35.6892N/51.389E — زمینمرکزی 7.25890/2.32693 و توپومرکزی 6.73314/1.75523.
      final jd = Astronomy.julianDay(DateTime.utc(2024, 3, 11, 12, 20));
      final geo = Moon.position(jd);
      expect(geo.ra, closeTo(7.25890, 0.02));
      expect(geo.dec, closeTo(2.32693, 0.02));
      final topo =
          Moon.topocentricEquatorial(jd: jd, lat: 35.6892, lng: 51.389);
      expect(topo.ra, closeTo(6.73314, 0.02));
      expect(topo.dec, closeTo(1.75523, 0.02));
    });

    test(
        'ARCV توپومرکزی اکنون شکست هوا را شامل میشود (بزرگتر از تفاوت پارالاکس)',
        () {
      final d = _sunset(DateTime(2024, 3, 11));
      final parallaxOnly = d.moonAltitudeGeocentric - d.moonParallaxDeg;
      // arcvTopo = (توپو با پارالاکس کامل + شکست) − خورشید؛ تفاوتش با
      // «زمینمرکزی − پارالاکس» باید تقریباً برابر شکست نزدیک ۱۹° باشد (~0.03°)
      expect(d.arcvTopocentric - (parallaxOnly - d.sunAltitude),
          inInclusiveRange(0.01, 0.15));
    });
  });

  group('همارزی سن ماه با LunarCalculator (تأیید Meeus-49 کپی)', () {
    for (final day in [9, 10, 11, 12]) {
      test('age 2024-03-$day — کمتر از ۳۰ دقیقه اختلاف', () {
        final d = _sunset(DateTime(2024, 3, day));
        final viaLunar = LunarCalculator.moonAge(d.bestTime) * 24;
        expect((d.ageHoursAtBest - viaLunar).abs(), lessThan(0.5));
      });
    }
  });

  group('HilalCalendar — پیشبینی ماه قمری (تهران)', () {
    test('رمضان ۱۴۴۵ (ایران: ۲۰۲۴-۰۳-۱۱)', () {
      final months = HilalCalendar.forecast(
        after: DateTime(2024, 3),
        lat: tehranLat,
        lng: tehranLng,
      );
      final first = months.first.startDate;
      expect(first.isAfter(DateTime(2024, 3, 9)), isTrue,
          reason: 'رمضان ۱۴۴۵ نباید زودتر از ۹ مارس شروع شود');
      expect(first.isBefore(DateTime(2024, 3, 14)), isTrue,
          reason: 'رمضان ۱۴۴۵ نباید دیرتر از ۱۳ مارس شروع شود');
      expect(months.first.days, inInclusiveRange(29, 30));
    });

    test('رمضان ۱۴۴۶ (ایران: ۲۰۲۵-۰۳-۰۱)', () {
      final months = HilalCalendar.forecast(
        after: DateTime(2025, 2, 25),
        lat: tehranLat,
        lng: tehranLng,
      );
      final first = months.first.startDate;
      expect(first.isAfter(DateTime(2025, 2, 27)), isTrue,
          reason: 'رمضان ۱۴۴۶ نباید زودتر از ۲۷ فوریه شروع شود');
      expect(first.isBefore(DateTime(2025, 3, 3)), isTrue,
          reason: 'رمضان ۱۴۴۶ نباید دیرتر از ۲ مارس شروع شود');
      expect(months.first.days, inInclusiveRange(29, 30));
    });

    test('ارزیابی ساختار: طول ماهها ۲۹/۳۰ و پیاپی', () {
      for (final basis in HilalMonthBasis.values) {
        final months = HilalCalendar.forecast(
          after: DateTime(2025),
          lat: tehranLat,
          lng: tehranLng,
          basis: basis,
        );
        expect(months.length, 12);
        for (final m in months) {
          expect(m.days, inInclusiveRange(29, 30));
          expect(m.sightingEvening, isNotNull);
        }
        for (var i = 1; i < months.length; i++) {
          expect(months[i].startDate, months[i - 1].endDateExclusive,
              reason: 'باید پیاپی باشند');
        }
        final span = months.last.endDateExclusive
            .difference(months.first.startDate)
            .inDays;
        expect(span, inInclusiveRange(346, 368));
      }
    });

    test('مبنای اقتران: هر ماه نزدیک ۲۹.۵۳ روز', () {
      final months = HilalCalendar.forecast(
        after: DateTime(2025),
        lat: tehranLat,
        lng: tehranLng,
        basis: HilalMonthBasis.conjunction,
      );
      for (final m in months) {
        expect(m.days, inInclusiveRange(29, 30));
        // اقترانِ آغاز ماه: پیش از غروبِ روز اول ولی بعد از غروبِ روز قبل
        final lo = m.startDate.subtract(const Duration(hours: 30));
        final hi = m.startDate.add(const Duration(hours: 24));
        expect(m.conjunctionUtc.isAfter(lo) && m.conjunctionUtc.isBefore(hi),
            isTrue);
        final diff = Duration(
            microseconds:
                m.endDateExclusive.difference(m.conjunctionUtc).inMicroseconds);
        expect((diff - const Duration(days: 29, hours: 12)).abs(),
            lessThan(const Duration(hours: 26)));
      }
    });

    test('forecastAllBases هر چهار مبنا را برمیگرداند', () {
      final all = HilalCalendar.forecastAllBases(
        after: DateTime(2025),
        lat: tehranLat,
        lng: tehranLng,
        count: 6,
      );
      expect(all.length, HilalMonthBasis.values.length);
      for (final list in all.values) {
        expect(list.length, 6);
      }
    });
  });

  group('فاساد LunarCalculator', () {
    test('sunsetHilal و hilalMonths در دسترساند', () {
      final d = LunarCalculator.sunsetHilal(
          DateTime(2024, 3, 11), tehranLat, tehranLng);
      expect(d, isNotNull);
      expect(d!.arcl, greaterThan(7));

      final months = LunarCalculator.hilalMonths(
        after: DateTime(2025),
        lat: tehranLat,
        lng: tehranLng,
        count: 3,
      );
      expect(months.length, 3);

      final all = LunarCalculator.hilalMonthsAllBases(
        after: DateTime(2025),
        lat: tehranLat,
        lng: tehranLng,
        count: 3,
      );
      expect(all.length, 4);
    });
  });
}
