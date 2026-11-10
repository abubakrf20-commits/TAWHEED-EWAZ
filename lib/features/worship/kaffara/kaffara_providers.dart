/// Riverpod wiring for «کفاره و فدیه» (now part of «عبادات و مناسک»).
///
/// The rules are loaded from `assets/data/kaffara_rules.json` — reviewed,
/// four-madhhab fiqh content. Nothing here authors a ruling; the providers
/// only surface the asset and remember which category / school the screen is
/// showing.
library;

import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:tawheeed/features/settings/domain/entities/app_settings_options.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/worship/kaffara/kaffara_debug_store.dart';
import 'package:tawheeed/features/worship/kaffara/kaffara_models.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

final kaffaraRulesProvider = FutureProvider<List<KaffaraRule>>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/data/kaffara_rules.json');
    return parseKaffaraRules(raw);
  } catch (e) {
    AppLogger.warning('KaffaraRules', 'bundle read failed: $e');
    return const [];
  }
});

/// Which category chip is selected.
final kaffaraCategoryProvider =
    StateProvider<KaffaraCategory>((ref) => KaffaraCategory.fidyaFast);

/// The school the rule is read in.
///
/// The app has no general madhhab setting; the nearest one is the Asr madhhab
/// (`AsrMethod`). Hanafi is offered because the setting exists, so it makes a
/// sensible default when the user follows the Hanafi Asr time. The screen lets
/// the user override any of the four schools freely.
final kaffaraMadhhabProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider).value;
  return settings?.asrMethod == AsrMethod.hanafi ? 'hanafi' : 'shafi';
});

final kaffaraDebugProvider = FutureProvider<bool>((ref) => KaffaraDebugStore.load());

/// Persists the debug (draft-preview) toggle.
final kaffaraDebugSetterProvider = Provider<void Function(bool)>((
  ref,
) {
  return (bool value) {
    unawaited(KaffaraDebugStore.save(value));
    ref.invalidate(kaffaraDebugProvider);
  };
});
