/// The pilgrimage calendar: which day of Dhu al-Hijjah a date is, and which
/// step of the guide that day belongs to.
///
/// The guide is a book: six ordered steps. During the five days they cover it
/// should be a companion — «امروز، همین» at the top. The mapping lives here,
/// away from the widget, because it is the one part that can be wrong in a way
/// that matters (a traveller sent to the wrong rite), so it is unit-tested.
library;

/// Hijri month of the pilgrimage.
const int kDhulHijjah = 12;

/// Steps of `HajjData.hajjSteps` keyed by the Hijri day of Dhu al-Hijjah.
///
///  * 8 — یوم الترویه: احرام و حرکت به منی (step 1)
///  * 9 — یوم عرفه: وقوف در عرفه (step 2)
///  * 10 — یوم النحر: رمی، قربانی، حلق، طواف زیارت (step 4 — Muzdalifah, step
///    3, is the *night* between 9 and 10, so it is offered as [nightStep])
///  * 11, 12 — ایام تشریق: بیتوته و رمی (step 5)
///  * 13 — نفر و طواف وداع (step 6)
const Map<int, int> _dayToStep = {
  8: 1,
  9: 2,
  10: 4,
  11: 5,
  12: 5,
  13: 6,
};

/// The step of the guide that [day] of Dhu al-Hijjah belongs to, or null when
/// the date is outside the pilgrimage.
int? hajjStepForHijri(int month, int day) {
  if (month != kDhulHijjah) return null;
  return _dayToStep[day];
}

/// The rite that belongs to the coming night, when it differs from the day's.
///
/// Only one case: the night of 9 Dhu al-Hijjah is spent in Muzdalifah (step 3)
/// while the day itself is Arafah (step 2). A traveller opening the guide
/// after sunset on the day of Arafah needs the night's step, not the day's.
int? hajjNightStepForHijri(int month, int day) {
  if (month != kDhulHijjah) return null;
  return day == 9 ? 3 : null;
}

/// Persian name of a Dhu al-Hijjah day, for the trip banner.
String hajjDayLabel(int day) => switch (day) {
      8 => 'یوم الترویه',
      9 => 'یوم عرفه',
      10 => 'یوم النحر',
      11 || 12 || 13 => 'ایام تشریق',
      _ => '',
    };
