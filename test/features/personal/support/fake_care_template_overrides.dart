import 'package:tawheeed/features/personal/care_engine/care_template_overrides.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';

/// A map-backed store for widget and golden harnesses: the real one opens the
/// database, which a test binding does not have.
class FakeCareTemplateOverrides implements CareTemplateOverrideStore {
  FakeCareTemplateOverrides([Map<String, Map<String, Object?>>? seed])
      : rows = {...?seed};

  final Map<String, Map<String, Object?>> rows;

  @override
  Future<Map<String, Map<String, Object?>>> load() async => rows;

  @override
  Future<bool> save({
    required CareTemplate template,
    int? intervalDays,
    int? intervalKm,
    String? titleFa,
  }) async {
    rows[template.key] = {
      'key': template.key,
      if (titleFa != null) 'titleFa': titleFa,
      if (intervalDays != null) 'intervalDays': intervalDays,
      if (intervalKm != null) 'intervalKm': intervalKm,
    };
    return true;
  }

  @override
  Future<bool> reset(String templateKey) async {
    rows.remove(templateKey);
    return true;
  }
}
