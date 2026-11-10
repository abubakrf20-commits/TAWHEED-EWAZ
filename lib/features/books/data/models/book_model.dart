class BookModel {
  String id;
  String title;
  String author;
  String category;
  String filePath;
  int fileSize;
  int pageCount;
  DateTime dateAdded;
  DateTime? lastRead;
  int currentPage;
  bool isFavorite;
  double readProgress;
  String language;
  List<String> tags;
  DateTime? startedAt;
  DateTime? completedAt;

  BookModel({
    required this.id,
    required this.title,
    this.author = '',
    this.category = '',
    this.filePath = '',
    this.fileSize = 0,
    this.pageCount = 0,
    DateTime? dateAdded,
    this.lastRead,
    this.currentPage = 0,
    this.isFavorite = false,
    this.readProgress = 0.0,
    this.language = 'fa',
    List<String>? tags,
    this.startedAt,
    this.completedAt,
  })  : dateAdded = dateAdded ?? DateTime.now(),
        tags = tags ?? [];

  bool get isCompleted => completedAt != null || readProgress >= 1.0;

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      category: json['category'] ?? '',
      filePath: json['filePath'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      pageCount: json['pages'] ?? json['pageCount'] ?? 0,
      dateAdded: json['dateAdded'] != null
          ? DateTime.parse(json['dateAdded'])
          : DateTime.now(),
      lastRead:
          json['lastRead'] != null ? DateTime.parse(json['lastRead']) : null,
      currentPage: json['currentPage'] ?? 0,
      isFavorite: json['isFavorite'] ?? false,
      readProgress: (json['readProgress'] ?? 0.0).toDouble(),
      language: json['language'] ?? 'fa',
      tags: List<String>.from(json['tags'] ?? []),
      startedAt:
          json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'category': category,
        'filePath': filePath,
        'fileSize': fileSize,
        'pageCount': pageCount,
        'dateAdded': dateAdded.toIso8601String(),
        'lastRead': lastRead?.toIso8601String(),
        'currentPage': currentPage,
        'isFavorite': isFavorite,
        'readProgress': readProgress,
        'language': language,
        'tags': tags,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };
}

class BookBookmark {
  int bookId;
  int page;
  String? note;
  DateTime createdAt;

  BookBookmark({
    required this.bookId,
    required this.page,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class BookIndexEntry {
  final int id;
  final String title;
  final String author;
  final String category;
  final String? coverUrl;

  BookIndexEntry(
      {required this.id,
      required this.title,
      this.author = '',
      this.category = '',
      this.coverUrl});

  factory BookIndexEntry.fromJson(Map<String, dynamic> json) {
    return BookIndexEntry(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      category: json['category'] ?? '',
      coverUrl: json['coverUrl'],
    );
  }
}

class BookTocEntry {
  final int id;
  final String title;
  final int page;

  BookTocEntry({required this.id, required this.title, this.page = 0});

  factory BookTocEntry.fromJson(Map<String, dynamic> json) {
    return BookTocEntry(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      page: json['page'] ?? 0,
    );
  }
}

class BookContentEntry {
  final int id;
  final String text;
  final int page;

  BookContentEntry({required this.id, required this.text, this.page = 0});

  factory BookContentEntry.fromJson(Map<String, dynamic> json) {
    return BookContentEntry(
      id: json['id'] ?? 0,
      text: json['text'] ?? json['content'] ?? '',
      page: json['page'] ?? 0,
    );
  }
}
