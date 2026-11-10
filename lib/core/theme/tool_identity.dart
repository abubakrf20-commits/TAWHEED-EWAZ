import 'package:flutter/material.dart';

/// Identity colours of the personal tools, in ONE place.
///
/// The tools already carried these hexes in their own style files
/// (`care_widgets.dart`, `finance_style.dart`, `family_faith_style.dart`) while
/// the More page's tiles drew a *different* hue for the same tool — the tile
/// for «صله رحم» was brown while the tool was rose, «کفاره» was dark red on the
/// tile and amber inside. Two palettes for one tool is exactly what a shared
/// token file exists to prevent, so the More tiles and the tool screens now
/// read the same constants.
///
/// These are identity hues, not semantic ones: status colours (good/near/urgent)
/// stay in the theme's success/warning/danger tokens.
class ToolIdentity {
  ToolIdentity._();

  /// «خودرو» — a calm navy; reads as "metal/road" without competing with the
  /// teal the shop already owns.
  static const Color car = Color(0xFF3A5BA0);

  /// «خانه» — deep teal-green, the household counterpart of [car].
  static const Color home = Color(0xFF0F7B6C);

  /// «صله رحم» — deep pink, gentle but distinct from the other tools.
  static const Color relatives = Color(0xFFD81B60);

  /// «کفاره و فدیه» — amber; it is a calculation, not a warning.
  static const Color kaffara = Color(0xFFD9822B);

  /// «قلک» — warm emerald, distinct from the dark teal the shop and hifz own.
  static const Color savings = Color(0xFF4CAF50);

  /// «دفتر مالی» — purple theme: gold for installments, purple for cheques/loans,
  /// pale blue for «سایر», warm brown for the debt ledger.
  static const Color financeInstallment = Color(0xFFC9922F);
  static const Color financeCheque = Color(0xFF7E57C2);
  static const Color financeLoan = Color(0xFF5E35B1);
  static const Color financeOther = Color(0xFF8FB3F5);
  static const Color financeLedger = Color(0xFF5E35B1);
}
