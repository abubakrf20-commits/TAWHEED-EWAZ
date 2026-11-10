import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/settings/presentation/widgets/widget_palettes.dart';

/// Contract tests over assets/widget_palettes.json — the single source the
/// native widgets, the generator and the settings preview all read.
void main() {
  late Map<String, dynamic> config;
  late List<WidgetPalette> palettes;

  setUpAll(() {
    final raw = File('assets/widget_palettes.json').readAsStringSync();
    config = jsonDecode(raw) as Map<String, dynamic>;
    palettes = WidgetPalettes.parseForTest(raw);
  });

  test('exposes exactly 8 presets with unique ids', () {
    expect(palettes, hasLength(8));
    expect(palettes.map((p) => p.id).toSet(), hasLength(8));
    expect(
      palettes.map((p) => p.id),
      containsAll([
        'brown_gold',
        'night_blue',
        'emerald',
        'dawn_purple',
        'sunset',
        'graphite',
        'cream_light',
      ]),
    );
  });

  test('the two gold-family presets stay distinguishable', () {
    // The picker shows «قهوه‌ای طلایی» beside «روشن کرم»; a redesign must not
    // collapse them onto the same surface, or the swatch stops meaning
    // anything.
    final brown = WidgetPalettes.byId(palettes, 'brown_gold');
    final cream = WidgetPalettes.byId(palettes, 'cream_light');
    expect(brown.bg, isNot(cream.bg));
    expect(brown.light, isFalse);
    expect(cream.light, isTrue);
    expect(WidgetPalettes.byId(palettes, 'brown_gold').id, 'brown_gold');
  });

  test('default palette exists and is not the auto entry', () {
    final id = config['defaultPalette'] as String;
    final def = WidgetPalettes.byId(palettes, id);
    expect(def.id, id);
    expect(def.auto, isFalse);
  });

  test('opacity steps are the four user-facing levels', () {
    expect(WidgetPalettes.opacitySteps(palettes), [1.0, 0.85, 0.7, 0.55]);
  });

  test('every phase is claimed by exactly one preset', () {
    // «خودکار» is a picker chip, not a table row: it resolves through each
    // preset's `autoPhases`. Every phase must therefore be claimed exactly
    // once, or the automatic palette has a hole (two claims would make the
    // winner depend on table order).
    final claims = <String, int>{};
    for (final p in palettes) {
      for (final phase in p.autoPhases) {
        claims[phase] = (claims[phase] ?? 0) + 1;
      }
    }
    for (final phase in WidgetPhase.values) {
      expect(claims[phase.name], 1, reason: 'phase ${phase.name}');
    }
    expect(claims.keys.toSet(), WidgetPhase.values.map((p) => p.name).toSet());
  });

  test('every auto-claimed phase resolves to a real palette', () {
    for (final phase in WidgetPhase.values) {
      final resolved = WidgetPalettes.forPhase(palettes, phase);
      expect(resolved.auto, isFalse, reason: 'phase ${phase.name}');
    }
  });

  test('text on background meets WCAG AA (4.5:1) at full opacity', () {
    for (final p in palettes) {
      if (p.auto) continue;
      final ratio = WidgetPalettes.contrastRatio(p.textColor, p.bgColor);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: '${p.id} text ${p.text} on bg ${p.bg}');
    }
  });

  test('accent on background stays readable (3:1) at full opacity', () {
    for (final p in palettes) {
      if (p.auto) continue;
      final ratio = WidgetPalettes.contrastRatio(p.accentColor, p.bgColor);
      expect(ratio, greaterThanOrEqualTo(3.0),
          reason: '${p.id} accent ${p.accent} on bg ${p.bg}');
    }
  });

  test('text survives the 55% step composited over a dark backdrop (3:1)', () {
    // A widget at 55% opacity lets the wallpaper through; the strict floor
    // here is against the palette's own darkened surface, and the layouts
    // carry a text shadow for the light-wallpaper case (documented in
    // docs/WIDGETS_THEMING_REPORT.md).
    const backdrop = ui.Color(0xFF000000);
    for (final p in palettes) {
      if (p.auto || p.light) continue;
      final washed = WidgetPalettes.composite(p.bgColor, 0.55, backdrop);
      final ratio = WidgetPalettes.contrastRatio(p.textColor, washed);
      expect(ratio, greaterThanOrEqualTo(3.0),
          reason: '${p.id} text on 55% bg over black');
    }
  });

  test('light palette keeps dark text on the 55% step over white', () {
    const backdrop = ui.Color(0xFFFFFFFF);
    final p = WidgetPalettes.byId(palettes, 'cream_light');
    final washed = WidgetPalettes.composite(p.bgColor, 0.55, backdrop);
    expect(WidgetPalettes.contrastRatio(p.textColor, washed),
        greaterThanOrEqualTo(3.0));
  });

  group('legacySelection — old stored colors mapped onto presets', () {
    /// A colour one step off [hex] on the blue channel. Derived from the
    /// palette table rather than hardcoded: the contract is «an exact match
    /// wins, and a near-miss lands on its neighbour», not any one hex value —
    /// pinning a literal is what let this test rot through a redesign.
    String nudge(String hex) {
      final value = int.parse(hex.substring(1), radix: 16);
      final blue = (value & 0xFF);
      final shifted = (blue == 0xFF) ? blue - 1 : blue + 1;
      final next = (value & 0xFFFF00) | shifted;
      return '#${next.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }

    test('exact bg match wins', () {
      final emerald = WidgetPalettes.byId(palettes, 'emerald');
      final (id, step) = WidgetPalettes.legacySelection(palettes, emerald.bg, 1.0);
      expect(id, 'emerald');
      expect(step, 0);
    });

    test('unknown dark bg lands on the nearest dark palette', () {
      final emerald = WidgetPalettes.byId(palettes, 'emerald');
      final (id, _) = WidgetPalettes.legacySelection(palettes, nudge(emerald.bg), 1.0);
      expect(id, 'emerald');
    });

    test('light bg never migrates onto a dark preset', () {
      final (id, _) = WidgetPalettes.legacySelection(palettes, '#FFF8F1', 1.0);
      expect(WidgetPalettes.byId(palettes, id).light, isTrue);
    });

    test('null or unparseable bg falls back to the default palette', () {
      expect(WidgetPalettes.legacySelection(palettes, null, 1.0).$1,
          WidgetPalettes.defaultPaletteId);
      expect(WidgetPalettes.legacySelection(palettes, '004F9', 1.0).$1,
          WidgetPalettes.defaultPaletteId);
    });

    test('legacy opacity snaps to the nearest step', () {
      expect(WidgetPalettes.legacySelection(palettes, null, 0.9).$2, 1);
      expect(WidgetPalettes.legacySelection(palettes, null, 0.5).$2, 3);
      expect(WidgetPalettes.legacySelection(palettes, null, -1).$2, 0);
    });
  });
}
