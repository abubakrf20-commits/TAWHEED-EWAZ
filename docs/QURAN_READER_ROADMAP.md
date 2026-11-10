# Quran reader roadmap — tajweed, colour and recitation follow

User request (2026-11-07): «در بخش قرآن تجوید و رنگ و اسکرول اتوماتیک آیات مصحف بدون
ترجمه اضافه شود… مثل امکانات quran.ws، اما حرفه‌ای».

This file is the plan and the record. It lists what the reader can do today, what
landed in this wave, and what each later wave needs — including the waves that must
**not** be built yet because their data is not verified.

## Where the reader stands

Three reading surfaces, deliberately separate (the page pipeline is protected by
AGENTS.md; nothing here changes its justification/banner geometry):

| surface | file | today |
| --- | --- | --- |
| QCF4 page mushaf | `mushaf/qcf4/qcf4_page_viewer.dart` | 604 real mushaf pages, per-word glyph fonts, ayah band + recitation ink, page-turn effects, paper palette |
| scrollable text mode («مصحف بدون ترجمه/با ترجمه») | `mushaf/quran_text_reader_screen.dart` | verse cards, Persian translation toggle, font scale, tajweed colours over the uthmani-hafs edition |
| reader chrome | `mushaf/quran_reader_*.dart` | reciter picker, translations/tafsir, bookmarks, search, share-as-image, player, landscape lock |

Recitation already exists for the page mushaf: `QuranAudioController` plays the
**per-ayah** files (exact verse, no seeking guesswork), advances verse by verse and
turns the page as the reciter moves (`MushafNavPolicy`), respecting the reader's own
drag.

## Wave 1 — landed (2026-11-07, `quran_text_reader_screen.dart`)

The gap the user hit: the no-translation text mode had tajweed but **no recitation and
no scrolling at all** — reading along with a reciter meant going back to the page mode.

- **One session, not two.** The mushaf passes its own `QuranAudioController` into the
  text screen, so the reciter, the position and the lock-screen card never fork. The
  screen talks to a small `QuranTextAudio` interface (implemented by the controller),
  which is also the test seam: widget tests drive a fake transport.
- **Auto-scroll («دنبال‌کردن تلاوت»).** The list is a `ScrollablePositionedList` — index
  addressed, because verse cards are variable-height and a pixel estimate would land on
  the wrong ayah. When the session reports a new verse, the list scrolls to it with a
  quarter-screen lead-in. Ticks that do not change the verse do not rebuild anything.
- **Active-ayah mark.** The recited card gets an accent wash composited **under** the
  ink (never over it) plus a heavier border, so contrast is unchanged.
- **Transport bar.** Play/pause (starting this surah when the session is idle or on
  another surah), previous/next verse, the «در حال تلاوت · آیهٔ N» label, and the
  auto-scroll switch. It sits at the bottom, not in the app bar: five actions beside a
  title do not fit 320 dp. Tapping any verse recites from it.
- **Tajweed legend.** A «راهنمای رنگ‌های تجوید» chip appears while colours are on and
  opens the seven rule families. `TajweedService.topics` is the single source for both
  the legend and the colours (`topicColor` reads the same table), so a colour can never
  reach the page without a row that explains it — pinned by
  `tajweed_service_test.dart`.
- Preferences: `quran_text_mode_tajweed`, `quran_text_mode_translation`,
  `quran_text_mode_font`, `quran_text_mode_follow` (new, default on).

## Wave 2 — tajweed inside the PAGE mushaf (needs verified per-word data)

The page mushaf draws pre-shaped **glyph codes** per word from page-specific QCF4 fonts
(`Qcf4Word.char` in the private-use area). There is no letter-level handle to paint, so
"colour the ghunnah" cannot be done by drawing a rule over a glyph.

Two honest routes, in order of preference:

1. **Per-word mapping from the certified corpus.** For each ayah, take
   `TajweedService.editionText(surah, ayah)`, split on whitespace, and line the tokens up
   with the page's `Qcf4Word.text` sequence. If a token is covered by one rule family at
   ≥ ~80 % of its code points, colour that glyph in the family colour; mixed words stay
   ink. Requires a **verification harness**: for all 6,236 ayahs assert the token counts
   match and no token is coloured where the span corpus disagrees. Ship only at 100 %
   alignment — a mis-coloured glyph is the one defect this project must never ship.
2. **A tajweed-edition page set.** Only if a licensed, page-accurate coloured dataset
   (not a heuristic) can be bundled. This is a data/licence decision, not a coding one,
   and it grows the APK.

Do not ship (1) before the harness is green; a heuristic that paints 95 % of words
correctly is worse than plain ink for recitation practice.

## Wave 3 — study aids over the text mode

- **Word-by-word meaning** on tap/long-press in the text mode (the sheet already exists
  for the page mushaf: `quran_word_meaning_sheet.dart`) — reuse it, do not fork it.
- **Tafsir under the ayah** as an optional inline block (currently a separate sheet), so
  a reader can study without leaving the flow.
- **Verse bookmark / last-read marker** shared with the page mushaf's bookmark store.
- **Search inside the surah** with the current ayah highlighted (`quran_search_*`).

## Wave 4 — recitation options the page mushaf already implies

- **Repeat range** (ayah A→B, N times) is implemented in the controller for the page
  view; surface it in the text mode's bar so both surfaces agree.
- **Word-level highlight** while reciting in the text mode, using
  `QuranAudioController.currentWords` timings (word timings are available for the
  translation engine; recitation may need the timing service).
- **Translation audio** in the text mode (the controller exists:
  `quran_translation_audio_controller.dart`).

## Wave 5 — the quran.ws-style extras (evaluate before building)

| idea | verdict |
| --- | --- |
| PDF export of a page/surah | low value inside the app; share-as-image already covers the need |
| Font family switching (QCF4 vs text) | already two surfaces; a third axis invites bugs |
| Khatm plan tied to the reader | track it in the existing khatm feature, not the reader |
| Listening library (per reciter/surah/juz) | worth a wave of its own, fed by `mp3quran_service.dart` |

## Acceptance checks used for wave 1

- `flutter test test/features/quran/mushaf/quran_text_reader_screen_test.dart` — 7 green
  (translation toggle, font sheet, idle-session play, running session bar, follow switch
  persistence, tap-to-recite).
- `flutter test test/features/quran/services/tajweed_service_test.dart` — 6 green,
  including the legend/colour single-source test.
- `flutter analyze lib/features/quran` — 0 issues.
- No Android device is attached: this is widget-test proof, not an on-device pass. The
  auto-scroll animation and the bar's look still need a phone.
