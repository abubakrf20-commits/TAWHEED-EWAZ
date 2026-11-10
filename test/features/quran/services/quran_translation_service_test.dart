import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/quran/services/quran_translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('selectedId defaults to the bundled Persian translation', () async {
    expect(await QuranTranslationService.selectedId(),
        QuranTranslationService.defaultId);
  });

  test('setSelectedId persists and selectedId reads it back', () async {
    await QuranTranslationService.setSelectedId('my-translation');
    expect(await QuranTranslationService.selectedId(), 'my-translation');
  });

  test('selectedId falls back to default after clearing the key', () async {
    await QuranTranslationService.setSelectedId('temporary');
    SharedPreferences.setMockInitialValues({});
    expect(await QuranTranslationService.selectedId(),
        QuranTranslationService.defaultId);
  });

  test('available() offers every shipped translation', () {
    final list = QuranTranslationService.available();
    expect(list.every((f) => f.isTranslation), isTrue);
    expect(list.map((f) => f.id), containsAll(<String>[
      QuranTranslationService.defaultId,
      'ku_burhan_muhammad_simple',
      'muhammad_saleh_bamoki_simple',
    ]));
  });

  test('a legacy or unknown id resolves to the Persian entry', () async {
    await QuranTranslationService.setSelectedId(
        QuranTranslationService.legacyId);
    expect((await QuranTranslationService.selectedEntry()).id,
        QuranTranslationService.defaultId);

    await QuranTranslationService.setSelectedId('no-such-translation');
    expect((await QuranTranslationService.selectedEntry()).id,
        QuranTranslationService.defaultId);
  });

  test('a known Kurdish id resolves to its own file', () async {
    await QuranTranslationService.setSelectedId('ku_burhan_muhammad_simple');
    final entry = await QuranTranslationService.selectedEntry();
    expect(entry.fileName, 'ku-burhan-muhammad-simple.json');
    expect(entry.lang, 'ku');
  });

  test('setting an empty id stores the default', () async {
    await QuranTranslationService.setSelectedId('');
    expect(await QuranTranslationService.selectedId(),
        QuranTranslationService.defaultId);
  });
}
