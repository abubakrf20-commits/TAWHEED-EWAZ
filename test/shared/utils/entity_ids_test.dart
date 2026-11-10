import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/utils/entity_ids.dart';

void main() {
  group('newEntityId', () {
    test('is unique across rapid calls', () {
      // The old scheme (epoch + nextInt(999999)) failed this at ~12% for 500
      // ids; a collision silently REPLACEs the row through
      // insertOnConflictUpdate.
      final ids = List.generate(5000, (_) => newEntityId());
      expect(ids.toSet().length, 5000);
    });

    test('starts with the creation timestamp, so ids sort by age', () {
      final before = DateTime.now().microsecondsSinceEpoch;
      final id = newEntityId();
      final after = DateTime.now().microsecondsSinceEpoch;
      final epoch = int.parse(id.split('_').first);
      expect(epoch, inInclusiveRange(before, after));
    });

    test('is three underscore-separated numbers', () {
      expect(newEntityId(), matches(RegExp(r'^\d+_\d+_\d+$')));
    });
  });
}
