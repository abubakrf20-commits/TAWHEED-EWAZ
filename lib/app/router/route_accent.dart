import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/time_theme.dart';

/// The ambient light of each pushed page, keyed by route prefix.
///
/// The shell picks its own tab's [SectionHues] colour; this table answers the
/// same question for the ~60 routes that open on top of it, so «زکات» arrives
/// in its gold and «رقیه» in its green instead of inheriting whichever tab the
/// user launched them from. The values are the same `TopicHues` table the
/// tiles, chips and charts already use — one identity source, no new palette.
///
/// Longest prefix wins (`/prayer/period` beats `/prayer`). Unknown routes get
/// `null`, which means "use the phase palette" — the previous behaviour.
const Map<String, Color> _routeHues = <String, Color>{
  // ── Worship ────────────────────────────────────────────────────────────
  '/prayer': TopicHues.prayer,
  '/prayer/settings': TopicHues.prayer,
  '/prayer/map-picker': TopicHues.prayer,
  '/prayer/times-share': TopicHues.prayer,
  '/prayer/battery': TopicHues.prayer,
  '/prayer/period': TopicHues.period,
  '/qibla': TopicHues.qibla,
  '/khatm': TopicHues.khatm,
  '/hifz': TopicHues.hifz,
  '/fasting': TopicHues.fasting,
  '/zakat': TopicHues.zakat,
  '/hajj-umrah': TopicHues.hajjUmrah,
  '/ruqyah': TopicHues.ruqyah,
  '/worship-checklist': TopicHues.worshipChecklist,
  '/reminders': TopicHues.reminders,
  '/notes': TopicHues.worshipNotes,
  '/duas': TopicHues.duas,
  '/dua': TopicHues.dua,
  '/azkar': SectionHues.tasbih,

  // ── Knowledge ─────────────────────────────────────────────────────────
  '/hadith': TopicHues.hadithBooks,
  '/dorar-hadith': TopicHues.dorarHadith,
  '/riyad': TopicHues.riyad,
  '/taraghib': TopicHues.taraghib,
  '/fatwa': TopicHues.fatwa,
  '/hadeeth-enc': TopicHues.hadeethEnc,
  '/books': TopicHues.ketabkhaneh,
  '/sciences': TopicHues.sciences,
  '/study': TopicHues.study,
  '/yaqeen': TopicHues.yaqeen,

  // ── Tools ─────────────────────────────────────────────────────────────
  '/tools/date-converter': SectionHues.calendar,
  '/tools/purification': TopicHues.purification,
  '/tools/inheritance': TopicHues.inheritance,
  '/tools/calculator': TopicHues.calculator,
  '/tools/pomodoro': TopicHues.pomodoro,
  '/tools/dangi': TopicHues.dangi,
  '/tools/moon': TopicHues.moon,
  '/audio-library': TopicHues.audioLibrary,
  '/tasks': TopicHues.tasks,
  '/expenses': TopicHues.expenses,
  '/goals': TopicHues.goals,

  // ── App ───────────────────────────────────────────────────────────────
  '/settings': TopicHues.app,
  '/personal-info': TopicHues.personalInfo,
  '/personal-info/savings': TopicHues.savings,
  '/web': TopicHues.qafAi,
};

/// Longest-prefix lookup, so a nested route can override its parent's hue.
Color? routeAccentFor(String location) {
  Color? best;
  var bestLength = -1;
  for (final entry in _routeHues.entries) {
    final matches = location == entry.key ||
        location.startsWith('${entry.key}/') ||
        location.startsWith('${entry.key}?');
    if (matches && entry.key.length > bestLength) {
      best = entry.value;
      bestLength = entry.key.length;
    }
  }
  return best;
}
