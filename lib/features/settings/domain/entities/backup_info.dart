class BackupInfo {
  final String version;
  final DateTime date;
  final String app;

  const BackupInfo({
    required this.version,
    required this.date,
    required this.app,
  });

  BackupInfo copyWith({
    String? version,
    DateTime? date,
    String? app,
  }) {
    return BackupInfo(
      version: version ?? this.version,
      date: date ?? this.date,
      app: app ?? this.app,
    );
  }
}
