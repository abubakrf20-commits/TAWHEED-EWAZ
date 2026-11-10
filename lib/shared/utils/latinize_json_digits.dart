import 'package:tawheeed/shared/utils/number_format.dart';

/// Folds Persian (۰-۹) and Arabic-Indic (٠-٩) digits to Latin inside a decoded
/// JSON payload, recursively.
///
/// The bundled content assets under `assets/content/` are authored with
/// Persian digits, while the app-wide display standard is Latin. Folding once
/// at load time keeps every screen that renders that content consistent,
/// instead of leaving each [Text] call to remember to do it.
///
/// Scripture payloads (the mushaf pages, ruqyah ayah markers) are deliberately
/// NOT passed through here — their Eastern-Arabic numerals are part of the
/// printed Qur'an, not app UI.
dynamic latinizeJsonDigits(dynamic node) {
  if (node is String) return NumberFormat.toLatin(node);
  if (node is Map) {
    // JSON objects always key on String; keeping that type is what lets
    // callers still cast the result to `Map<String, dynamic>`.
    return <String, dynamic>{
      for (final entry in node.entries)
        '${entry.key}': latinizeJsonDigits(entry.value),
    };
  }
  if (node is List) {
    return [for (final item in node) latinizeJsonDigits(item)];
  }
  return node;
}
