import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';

/// The home's theme-aware tokens (the 2026-10-17 dark-card report). Light
/// values are the approved mockup hexes the day goldens are pinned to —
/// they must never drift. Dark values replace the three surfaces whose
/// light hex was unreadable ink on the dark card: the «اکنون» row gradient,
/// its time/badge ink, and the faint dashed/ring hairlines.
void main() {
  group('HomeColors theme-aware tokens', () {
    test('light values stay the approved mockup hexes', () {
      expect(HomeColors.nowRowStart(false).toARGB32(), 0xFFFFF6DA);
      expect(HomeColors.nowRowEnd(false).toARGB32(), 0xFFFFFBF0);
      expect(HomeColors.nowRowTime(false).toARGB32(), 0xFF7A5410);
      expect(HomeColors.faintBorder(false).toARGB32(), 0xFFD9C7B3);
      // The rawatib dashed border keeps its 85 % strength through alpha.
      expect(
        HomeColors.faintBorder(false, alpha: 0.85).toARGB32(),
        const Color(0xFFD9C7B3).withValues(alpha: 0.85).toARGB32(),
      );
    });

    test('dark values are the gold wash — never the light hexes', () {
      expect(HomeColors.nowRowStart(true).toARGB32(), 0x29E8C277);
      expect(HomeColors.nowRowEnd(true).toARGB32(), 0x0AE8C277);
      expect(HomeColors.nowRowTime(true), AppPalette.heroGold);
      expect(HomeColors.faintBorder(true).toARGB32(),
          Colors.white.withValues(alpha: 0.25).toARGB32());

      // The reported bug, pinned as a token contract: under dark the open
      // window must not paint the light creams.
      expect(
        HomeColors.nowRowStart(true),
        isNot(HomeColors.nowRowStart(false)),
      );
      expect(HomeColors.nowRowEnd(true), isNot(HomeColors.nowRowEnd(false)));
      expect(HomeColors.nowRowTime(true), isNot(HomeColors.nowRowTime(false)));
    });
  });
}
