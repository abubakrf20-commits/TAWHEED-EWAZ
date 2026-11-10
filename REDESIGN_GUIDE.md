# Visual Redesign: Complete Card & Surface System

## What Changed (Before → After)

### 1. Hero Card (BEFORE → AFTER)

**BEFORE:**
- Gradient brown background
- 42px bold clock → feels heavy, not elegant
- Three identical tiny DateBadge boxes (11px label, cramped)
- Countdown bar was a SEPARATE gradient card below

**AFTER:**
- Solid walnut surface with warm shadow → layered, not loud
- 56px thin-weight clock → elegant, dominant focal point
- Seconds as superscript → refined detail
- Unified date strip with thin dividers → no more cramped boxes
- Next prayer integrated as inner-surface module → cohesive
- Gold whisper line as separator → restrained, premium

### 2. Date Presentation (BEFORE → AFTER)

**BEFORE:**
```
┌──────┐ ┌──────┐ ┌──────┐
│شمسی  │ │هجری  │ │میلادی │
│13 تیر│ │10محرم│ │2026  │
└──────┘ └──────┘ └──────┘
```
Three identical rounded boxes with white 15% bg. Labels 11px, values 15px.

**AFTER:**
```
شمسی         ·    هجری         ·    میلادی
۱۳ تیر ۱۴۰۵      ۱۰ محرم ۱۴۴۷      2026/07/03
```
Single row. Thin vertical dividers. Labels 11px bold uppercase. Values 13px regular. No boxes, just clean typography.

### 3. Card System (BEFORE → AFTER)

**BEFORE:**
- Every card: same `Theme.of(context).cardColor` + border + shadow
- No hierarchy between cards
- Section titles: gold vertical bar + generic title
- No inner panels, no layered surfaces

**AFTER:**
- `PremiumCard` component: white surface + warm shadow
- `InnerPanel` for recessed areas inside cards
- `GoldBadge` for micro accents
- `PremiumPrayerRow` for structured prayer list items
- Gold accent bar: 3px gradient (not 4px solid)
- Proper spacing rhythm (16px standard)

## New Files Created

| File | Purpose |
|---|---|
| `lib/core/design_system/card_design_system.dart` | Complete token system: colors, typography, spacing, radius, shadows, surfaces |
| `lib/screens/home_widgets/hero_clock_card.dart` | Redesigned hero clock card with integrated next prayer module |
| `lib/widgets/premium_card.dart` | PremiumCard, InnerPanel, GoldBadge, PremiumPrayerRow |

## Files Modified

| File | Changes |
|---|---|
| `lib/screens/home_tab.dart` | Uses HeroClockCard, PremiumCard for Rawatib section |
| `lib/widgets/home_prayer_summary.dart` | Uses PremiumCard and PremiumPrayerRow |

## Design Token Naming

```
Colors:     espresso, walnut, mocha, cocoa, taupe, warmSand
Surfaces:   parchment, linen, cream, shell (light) / deepNight, darkWalnut, darkMocha (dark)
Accent:     goldRich, goldMuted, goldSoft, goldWhisper, goldGhost
Text:       textOnDark, textOnDarkMuted, textOnDarkGhost / textOnLight, textOnLightSecondary

Typography: heroTime(56/w300), heroSeconds(20/w300), heroDayPhase(13/w500)
            dateLabel(11/w700), dateValue(13/w500)
            nextPrayerName(13/w600/gold), nextPrayerTime(22/w700)
            cardSectionTitle(14/w700), cardBody(14/w400), cardValue(22/w700)

Spacing:    space2, 4, 6, 8, 10, 12, 16, 20, 24, 32
Radius:     radiusXS(8), SM(12), MD(16), LG(24), XL(32)
Shadows:    shadowSubtle, shadowMedium, heroShadow
```

## Migration Strategy

1. All new cards use `PremiumCard` instead of raw Container + BoxDecoration
2. All prayer rows use `PremiumPrayerRow` instead of custom row widgets
3. All section titles use gold gradient bar (3px) instead of solid 4px bar
4. Hero card uses `HeroClockCard` instead of `_LocationTimeSection`
5. Date presentation uses unified strip instead of three DateBadge boxes
6. Countdown is integrated inside hero card, not a separate card
7. Old `ClockWidget`, `DateBadge`, `CountdownBar` are superseded
