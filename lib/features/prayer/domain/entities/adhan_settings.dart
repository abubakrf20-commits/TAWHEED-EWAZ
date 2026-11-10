class AdhanSettings {
  final String sound;
  final double volume;
  final bool enabledForFajr;
  final bool enabledForDhuhr;
  final bool enabledForAsr;
  final bool enabledForMaghrib;
  final bool enabledForIsha;
  final String? customPath;

  const AdhanSettings({
    this.sound = 'kamel',
    this.volume = 1.0,
    this.enabledForFajr = true,
    this.enabledForDhuhr = true,
    this.enabledForAsr = true,
    this.enabledForMaghrib = true,
    this.enabledForIsha = true,
    this.customPath,
  });

  AdhanSettings copyWith({
    String? sound,
    double? volume,
    bool? enabledForFajr,
    bool? enabledForDhuhr,
    bool? enabledForAsr,
    bool? enabledForMaghrib,
    bool? enabledForIsha,
    String? customPath,
  }) {
    return AdhanSettings(
      sound: sound ?? this.sound,
      volume: volume ?? this.volume,
      enabledForFajr: enabledForFajr ?? this.enabledForFajr,
      enabledForDhuhr: enabledForDhuhr ?? this.enabledForDhuhr,
      enabledForAsr: enabledForAsr ?? this.enabledForAsr,
      enabledForMaghrib: enabledForMaghrib ?? this.enabledForMaghrib,
      enabledForIsha: enabledForIsha ?? this.enabledForIsha,
      customPath: customPath ?? this.customPath,
    );
  }
}
