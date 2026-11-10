import 'package:flutter/material.dart';

/// Fixed spec colors for the settings kit that have no palette equivalent.
/// Everything else (chip fill/ink, slider tracks, stepper pill, segmented
/// container, switch OFF track, section bars) reads the CURRENT theme's
/// [AppPalette] — see settings_components.dart. Light-mode truths, like
/// [HomeColors]: consts below coincide with existing tokens — always reuse
/// the existing one (noted per constant) and add here only what has no
/// equivalent.
abstract final class SettingsTokens {
  /// Value-chip fill — semantic amber, not a theme accent (WarningCard light
  /// face keeps it).
  static const Color chipFill = Color(0xFFFFF1D2);

  /// Search-flash highlight tint fill.
  static const Color selectedTint = Color(0xFFFFF6DA);

  /// Switch ON track (== HomeColors.done — duplicated here so core never
  /// imports the home feature for it). The OFF track is the palette outline.
  static const Color switchOn = Color(0xFF2E8B3D);
}
