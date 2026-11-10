import 'package:flutter/material.dart';

/// FNV-1a 32-bit string hash — deterministic across app launches.
///
/// `String.hashCode` is randomized per Dart isolate (security hardening),
/// so any color derived from it changes every time the app restarts. Tag /
/// label colors must stay the same, hence this explicit hash.
int stableHash(String value) {
  var hash = 0x811C9DC5; // FNV offset basis
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime, 32-bit wrap
  }
  return hash;
}

/// Deterministic palette color for [label] (task tags, folder chips, …).
/// Falls back to grey for an empty palette instead of throwing.
Color stablePaletteColor(String label, List<Color> palette) {
  if (palette.isEmpty) return Colors.grey;
  return palette[stableHash(label) % palette.length];
}
