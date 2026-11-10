import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/expenses/domain/expense_categories.dart';
import 'package:tawheeed/features/expenses/presentation/providers/expense_categories_provider.dart';

/// A store whose write always fails, so the rollback can be observed.
///
/// The mock preference backend answers `true` to every `setStringList`, so this
/// is the only way to reach the branch that matters: a chip the reader added must
/// not survive on screen when it did not reach the disk.
class _FailingStore extends ExpenseCategoryStoreNotifier {
  @override
  Future<void> persist(ExpenseCategoryStore store) async {
    throw StateError('disk full');
  }
}

ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// Reads the notifier and waits for its initial (async) prefs read to land.
Future<ExpenseCategoryStoreNotifier> _loaded(
    ProviderContainer container) async {
  container.read(expenseCategoryStoreProvider);
  // The load is kicked off from `build` and is not awaitable from outside, so
  // give the microtask/event queue a turn before asserting on the state.
  await Future<void>.delayed(Duration.zero);
  return container.read(expenseCategoryStoreProvider.notifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts with nothing of its own', () async {
    final container = _container();
    final notifier = await _loaded(container);
    expect(notifier.state.custom, isEmpty);
    expect(notifier.state.hidden, isEmpty);
  });

  test('an added category is in the state and on the disk', () async {
    final container = _container();
    final notifier = await _loaded(container);

    expect(await notifier.addCategory('قهوه'), isTrue);
    expect(notifier.state.custom, ['قهوه']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(kCustomExpenseCategoriesPref), ['قهوه']);
  });

  test('the name is normalised before it is stored', () async {
    final container = _container();
    final notifier = await _loaded(container);

    await notifier.addCategory('  قهوه   تلخ  ');
    expect(notifier.state.custom, ['قهوه تلخ']);
  });

  test('adding a name that already exists changes nothing', () async {
    final container = _container();
    final notifier = await _loaded(container);

    await notifier.addCategory('قهوه');
    await notifier.addCategory('قهوه');
    // Case is irrelevant for Persian here, but a space is not — normalisation
    // happens first, so this is the same entry.
    await notifier.addCategory(' قهوه ');
    expect(notifier.state.custom, ['قهوه']);
  });

  test('re-adding a removed name brings it back out of hidden', () async {
    final container = _container();
    final notifier = await _loaded(container);

    await notifier.addCategory('قهوه');
    await notifier.removeCategory('قهوه');
    expect(notifier.state.hidden, contains('قهوه'));

    await notifier.addCategory('قهوه');
    expect(notifier.state.custom, ['قهوه']);
    // Otherwise the hidden list would keep it out of the picker forever.
    expect(notifier.state.hidden, isNot(contains('قهوه')));
  });

  test('removing a category hides the name and drops the entry', () async {
    final container = _container();
    final notifier = await _loaded(container);

    await notifier.addCategory('قهوه');
    await notifier.addCategory('گل');
    expect(await notifier.removeCategory('قهوه'), isTrue);

    expect(notifier.state.custom, ['گل']);
    expect(notifier.state.hidden, contains('قهوه'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(kHiddenExpenseCategoriesPref), ['قهوه']);
  });

  test('removing something that was never added is a no-op, not a failure',
      () async {
    final container = _container();
    final notifier = await _loaded(container);
    expect(await notifier.removeCategory('قهوه'), isTrue);
    expect(notifier.state.custom, isEmpty);
    expect(notifier.state.hidden, isEmpty);
  });

  test('junk on disk is cleaned on load', () async {
    SharedPreferences.setMockInitialValues({
      kCustomExpenseCategoriesPref: <String>[
        '  قهوه  ', // surrounding space
        'قهوه', // duplicate after normalisation
        'خوراک', // a built-in — never a custom entry
        '', // empty
        '   ', // whitespace only
        'گل',
      ],
      kHiddenExpenseCategoriesPref: <String>[' سفر ', ''],
    });

    final container = _container();
    final notifier = await _loaded(container);

    expect(notifier.state.custom, ['قهوه', 'گل']);
    expect(notifier.state.hidden, {'سفر'});
  });

  test('an over-long name on disk is dropped rather than offered', () async {
    SharedPreferences.setMockInitialValues({
      kCustomExpenseCategoriesPref: <String>[
        'ا' * (kMaxExpenseCategoryLength + 1),
        'قهوه',
      ],
    });

    final container = _container();
    final notifier = await _loaded(container);
    expect(notifier.state.custom, ['قهوه']);
  });

  test('a failed write is rolled back and reported', () async {
    final container = ProviderContainer(
      overrides: [
        expenseCategoryStoreProvider.overrideWith(_FailingStore.new),
      ],
    );
    addTearDown(container.dispose);
    final notifier = await _loaded(container);

    expect(await notifier.addCategory('قهوه'), isFalse);
    // The chip must not survive on screen: the reader would believe they added
    // it and find it gone after the next launch.
    expect(notifier.state.custom, isEmpty);
  });

  test('a failed removal leaves the category in place', () async {
    final container = ProviderContainer(
      overrides: [
        expenseCategoryStoreProvider.overrideWith(_FailingStore.new),
      ],
    );
    addTearDown(container.dispose);
    final notifier = await _loaded(container);
    // Seed the state directly: the write path is the thing under test, and it
    // cannot be used to seed anything.
    notifier.state = const ExpenseCategoryStore(custom: ['قهوه']);

    expect(await notifier.removeCategory('قهوه'), isFalse);
    expect(notifier.state.custom, ['قهوه']);
    expect(notifier.state.hidden, isEmpty);
  });
}
