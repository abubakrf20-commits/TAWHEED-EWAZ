/// Settings-only transfer («انتقال تنظیمات») — a small, human-inspectable JSON
/// document that carries the [AppSettings] preferences so they can move to a
/// new device without running a full backup. Deliberately separate from
/// [AppSettingsDto]'s storage format (that one stores lists as JSON strings and
/// is pinned to the current schema); this envelope is versioned so an older
/// file always imports, and a newer one is never silently misread.
library;

import 'dart:convert';

import 'package:tawheeed/features/settings/data/models/app_settings_model.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

/// The `type` marker that tells this JSON apart from anything else the user
/// might point the importer at (backup JSONs, exported CSVs, …).
const String kSettingsTransferType = 'tawheed_settings_transfer';

/// The current transfer format version. Bump on any field change and make
/// `settingsFromJson` still read v1 (additive, defaulted fields only).
const int kSettingsTransferVersion = 1;

/// Suggested filename for the export sheet.
const String kSettingsTransferFileName = 'tawheed_settings.json';

/// Serializes [settings] into the settings-transfer JSON document.
///
/// The exported payload is exactly what the persisted row holds (via the
/// shared `AppSettingsDto` codec), so export then import never re-maps
/// enums/dates by hand.
String encodeSettingsTransfer(AppSettings settings) {
  return jsonEncode({
    'type': kSettingsTransferType,
    'version': kSettingsTransferVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'settings': AppSettingsDto.fromEntity(settings).toJson(),
  });
}

/// Parses a settings-transfer document, or returns null when [raw] is not one
/// (wrong marker, newer version, or damaged JSON). Unknown individual fields
/// inside `settings` fall back to their factory defaults via the DTO codec, so
/// a file exported by a newer build still imports the fields it knows.
AppSettings? decodeSettingsTransfer(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  if (decoded['type'] != kSettingsTransferType) return null;
  final version = decoded['version'];
  if (version is! int || version < 1 || version > kSettingsTransferVersion) {
    return null;
  }
  final settings = decoded['settings'];
  if (settings is! Map<String, dynamic>) return null;
  try {
    return AppSettingsDto.fromJson(settings).toEntity();
  } on Object {
    return null;
  }
}