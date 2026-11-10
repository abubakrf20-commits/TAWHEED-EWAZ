class DuaFromQuran {
  final String arabic;
  final String persian;
  final String source;

  const DuaFromQuran({
    required this.arabic,
    required this.persian,
    this.source = '',
  });

  /// Stable, reorder-proof identity used to persist favorites. Uses a
  /// deterministic FNV-1a hash of the Arabic text so it survives list
  /// reordering and app restarts — unlike Dart's `String.hashCode`, which is
  /// not guaranteed stable across runs.
  String get stableId {
    var h = 0x811c9dc5;
    for (final c in arabic.runes) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}
