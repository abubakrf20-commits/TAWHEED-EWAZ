import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/section_colors.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// TopicHues are the canonical copies of the fixed topic colors that legacy
/// SectionColors still serves to un-migrated screens. Pin them equal so the
/// two tables cannot drift while phase 1 migrates call sites.
void main() {
  test('TopicHues mirror SectionColors value-for-value', () {
    expect(TopicHues.qibla, SectionColors.qibla);
    expect(TopicHues.purification, SectionColors.purification);
    expect(TopicHues.prayer, SectionColors.prayer);
    expect(TopicHues.fasting, SectionColors.fasting);
    expect(TopicHues.zakat, SectionColors.zakat);
    expect(TopicHues.khatm, SectionColors.khatm);
    expect(TopicHues.dua, SectionColors.dua);
    expect(TopicHues.duas, SectionColors.duas);
    expect(TopicHues.worshipChecklist, SectionColors.worshipChecklist);
    expect(TopicHues.hajjUmrah, SectionColors.hajjUmrah);
    expect(TopicHues.inheritance, SectionColors.inheritance);
    expect(TopicHues.ruqyah, SectionColors.ruqyah);
    expect(TopicHues.hadithBooks, SectionColors.hadithBooks);
    expect(TopicHues.dorarHadith, SectionColors.dorarHadith);
    expect(TopicHues.ketabkhaneh, SectionColors.ketabkhaneh);
    expect(TopicHues.sciences, SectionColors.sciences);
    expect(TopicHues.study, SectionColors.study);
    expect(TopicHues.tasks, SectionColors.tasks);
    expect(TopicHues.expenses, SectionColors.expenses);
    expect(TopicHues.worshipNotes, SectionColors.worshipNotes);
    expect(TopicHues.reminders, SectionColors.reminders);
    expect(TopicHues.period, SectionColors.period);
    expect(TopicHues.calculator, SectionColors.calculator);
    expect(TopicHues.hifz, SectionColors.hifz);
    expect(TopicHues.pomodoro, SectionColors.pomodoro);
    expect(TopicHues.dangi, SectionColors.dangi);
    expect(TopicHues.hadeethEnc, SectionColors.hadeethEnc);
    expect(TopicHues.moon, SectionColors.moon);
    expect(TopicHues.qafAi, SectionColors.qafAi);
    expect(TopicHues.riyad, SectionColors.riyad);
    expect(TopicHues.taraghib, SectionColors.taraghib);

    // معالم السنه النبویه has no SectionColors copy on purpose: the legacy
    // table only carries colours the router asks for through
    // `SectionColors.of`, and this book is reached from the More registry and
    // from its own screens — which read TopicHues.maalim directly.
    expect(TopicHues.maalim, const Color(0xFFB8860B));
    expect(TopicHues.fatwa, SectionColors.fatwa);
    expect(TopicHues.yaqeen, SectionColors.yaqeen);
    expect(TopicHues.audioLibrary, SectionColors.audioLibrary);
    expect(TopicHues.anasheed, SectionColors.anasheed);
    expect(TopicHues.lectures, SectionColors.lectures);
    expect(TopicHues.misc, SectionColors.misc);
    expect(TopicHues.goals, SectionColors.goals);
    // «دفتر مالی» got its own purple on 2026-11-07 and reads this slot, so the
    // legacy grouping indigo in SectionColors (which no screen reads any more)
    // is no longer the value to mirror.
    expect(TopicHues.personalTools, const Color(0xFF5E35B1));
    expect(TopicHues.personalInfo, SectionColors.personalInfo);
    expect(TopicHues.personalProfile, SectionColors.personalProfile);
    expect(TopicHues.personalDocs, SectionColors.personalDocs);
    expect(TopicHues.personalCredentials, SectionColors.personalCredentials);
    expect(TopicHues.personalAssets, SectionColors.personalAssets);
    expect(TopicHues.personalInsurance, SectionColors.personalInsurance);
    expect(TopicHues.personalEmergency, SectionColors.personalEmergency);
    expect(TopicHues.personalExpiry, SectionColors.personalExpiry);
    expect(TopicHues.kidsHabits, SectionColors.kidsHabits);
    // «دفتر مربی قرآن» moved to عبادات with its own violet on 2026-11-07;
    // SectionColors' lake green stays with the unused legacy copy.
    expect(TopicHues.teacherLedger, const Color(0xFF7C4DFF));
    expect(TopicHues.shopLedger, SectionColors.shopLedger);
    // maliLedger/debtLedger stay in SectionColors only: the ledger pages take
    // their identity from ToolIdentity, and the More tile from TopicHues.
  });

  test('TopicHues.app is the warm-brown app identity (More tiles)', () {
    // تنظیمات + دربارهٔ برنامه — the classic palette's secondary. Deliberately
    // NOT mirrored in SectionColors: those two pages take the theme accent,
    // not a section identity. The value is pinned so the two More tiles and
    // the day palette can never quietly split.
    expect(TopicHues.app, const Color(0xFF6D5A4A));
  });
}
