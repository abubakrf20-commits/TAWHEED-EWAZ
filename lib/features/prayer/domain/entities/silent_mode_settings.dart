class SilentModeSettings {
  final bool enabled;
  final int duration;
  final bool beforeIqamah;
  final int beforeIqamahMinutes;

  const SilentModeSettings({
    this.enabled = false,
    this.duration = 10,
    this.beforeIqamah = false,
    this.beforeIqamahMinutes = 15,
  });

  SilentModeSettings copyWith({
    bool? enabled,
    int? duration,
    bool? beforeIqamah,
    int? beforeIqamahMinutes,
  }) {
    return SilentModeSettings(
      enabled: enabled ?? this.enabled,
      duration: duration ?? this.duration,
      beforeIqamah: beforeIqamah ?? this.beforeIqamah,
      beforeIqamahMinutes: beforeIqamahMinutes ?? this.beforeIqamahMinutes,
    );
  }
}
