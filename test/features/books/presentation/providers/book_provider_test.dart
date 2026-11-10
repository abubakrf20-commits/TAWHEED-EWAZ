import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/books/data/daos/book_dao.dart';
import 'package:tawheeed/features/books/data/daos/book_bookmark_dao.dart';
import 'package:tawheeed/features/books/presentation/providers/book_provider.dart';
import '../../../../core/database/mock_daos.dart';

BookTableData makeBook({
  required String id,
  String title = 'Title',
  String author = 'Author',
  String category = 'General',
  bool isFavorite = false,
  int pageCount = 0,
  int currentPage = 0,
}) {
  return BookTableData(
    id: id,
    title: title,
    author: author,
    category: category,
    filePath: '',
    fileSize: 0,
    pageCount: pageCount,
    dateAdded: DateTime.now(),
    currentPage: currentPage,
    isFavorite: isFavorite,
    readProgress: 0.0,
    language: 'fa',
    tags: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late MockBookDao mockDao;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDao = MockBookDao();
    container = ProviderContainer(overrides: [
      bookDaoProvider.overrideWithValue(mockDao),
      bookBookmarkDaoProvider.overrideWithValue(MockBookBookmarkDao()),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  test('build returns books from assets when DAO is empty', () async {
    final books = await container.read(bookProvider.future);
    expect(books.length, greaterThan(0));
    // Books should be sorted by title alphabetically
    for (int i = 0; i < books.length - 1; i++) {
      expect(
          books[i].title.compareTo(books[i + 1].title), lessThanOrEqualTo(0));
    }
  });

  test('build returns books sorted by title', () async {
    await mockDao.upsertBook(makeBook(
        id: '2', title: 'Beta', author: 'A', category: 'فقه', pageCount: 100));
    await mockDao.upsertBook(makeBook(
        id: '1',
        title: 'Alpha',
        author: 'B',
        category: 'تفسیر',
        pageCount: 200));
    final books = await container.read(bookProvider.future);
    expect(books.length, equals(2));
    expect(books[0].title, equals('Alpha'));
    expect(books[1].title, equals('Beta'));
  });

  test('byCategory filters books by category', () async {
    await mockDao.upsertBook(makeBook(id: '1', title: 'A', category: 'فقه'));
    await mockDao.upsertBook(makeBook(id: '2', title: 'B', category: 'تفسیر'));
    await container.read(bookProvider.future);
    final provider = container.read(bookProvider.notifier);
    expect(provider.byCategory('فقه').length, equals(1));
    expect(provider.byCategory('تفسیر').length, equals(1));
    expect(provider.byCategory('unknown'), isEmpty);
  });

  test('categories returns unique sorted category list', () async {
    await mockDao.upsertBook(makeBook(id: '1', title: 'A', category: 'فقه'));
    await mockDao.upsertBook(makeBook(id: '2', title: 'B', category: 'تفسیر'));
    await mockDao.upsertBook(makeBook(id: '3', title: 'C', category: 'فقه'));
    await container.read(bookProvider.future);
    final provider = container.read(bookProvider.notifier);
    expect(provider.categories, equals(['تفسیر', 'فقه']));
  });

  test('search returns matching books', () async {
    await mockDao.upsertBook(
        makeBook(id: '1', title: 'فقه اسلام', author: 'محمد', category: 'فقه'));
    await mockDao.upsertBook(makeBook(
        id: '2', title: 'تفسیر قرآن', author: 'علی', category: 'تفسیر'));
    await container.read(bookProvider.future);
    final provider = container.read(bookProvider.notifier);
    expect(provider.search('فقه').length, equals(1));
    expect(provider.search('محمد').length, equals(1));
    expect(provider.search('xyz'), isEmpty);
  });

  test('toggleFavorite flips isFavorite in DAO', () async {
    await mockDao.upsertBook(makeBook(id: '1', title: 'Test'));
    await container.read(bookProvider.future);
    final provider = container.read(bookProvider.notifier);
    await provider.toggleFavorite('1');
    final book = await mockDao.getBook('1');
    expect(book!.isFavorite, isTrue);
    await provider.toggleFavorite('1');
    final updated = await mockDao.getBook('1');
    expect(updated!.isFavorite, isFalse);
  });

  test('updateProgress updates current page and read progress', () async {
    await mockDao.upsertBook(makeBook(id: '1', title: 'Test', pageCount: 100));
    await container.read(bookProvider.future);
    final provider = container.read(bookProvider.notifier);
    await provider.updateProgress('1', 25);
    final book = await mockDao.getBook('1');
    expect(book!.currentPage, equals(25));
    expect(book.readProgress, equals(0.25));
    expect(book.lastRead, isNotNull);
  });

  test('updateProgress does nothing when pageCount is 0', () async {
    await mockDao.upsertBook(makeBook(id: '1', title: 'Test'));
    await container.read(bookProvider.future);
    final provider = container.read(bookProvider.notifier);
    await provider.updateProgress('1', 10);
    final book = await mockDao.getBook('1');
    expect(book!.currentPage, equals(0));
  });

  test('deleteBook removes book from DAO', () async {
    await mockDao.upsertBook(makeBook(id: '1', title: 'Test'));
    await container.read(bookProvider.future);
    final provider = container.read(bookProvider.notifier);
    await provider.deleteBook('1');
    final books = await container.read(bookProvider.future);
    expect(books, isEmpty);
  });

  test('getById returns book by id', () async {
    await mockDao.upsertBook(makeBook(id: '1', title: 'Test'));
    await container.read(bookProvider.future);
    final provider = container.read(bookProvider.notifier);
    final book = provider.getById('1');
    expect(book, isNotNull);
    expect(book!.title, equals('Test'));
    expect(provider.getById('nonexistent'), isNull);
  });
}
