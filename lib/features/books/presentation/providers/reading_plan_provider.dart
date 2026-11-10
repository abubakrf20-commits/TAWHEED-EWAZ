import 'package:tawheeed/shared/utils/date_key.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

part 'reading_plan_provider.g.dart';

class StudyBook {
  final String id;
  String name;
  int dailyTarget;
  int currentPage;
  int totalPages;
  String partInfo;
  bool isActive;
  DateTime? startedAt;
  DateTime? completedAt;
  String notes;

  StudyBook({
    required this.id,
    required this.name,
    this.dailyTarget = 0,
    this.currentPage = 0,
    this.totalPages = 0,
    this.partInfo = '',
    this.isActive = true,
    this.startedAt,
    this.completedAt,
    this.notes = '',
  });

  bool get isCompleted => totalPages > 0 && currentPage >= totalPages;

  double get progress =>
      totalPages > 0 ? (currentPage / totalPages).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dailyTarget': dailyTarget,
        'currentPage': currentPage,
        'totalPages': totalPages,
        'partInfo': partInfo,
        'isActive': isActive,
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (notes.isNotEmpty) 'notes': notes,
      };

  factory StudyBook.fromJson(Map<String, dynamic> json) => StudyBook(
        id: json['id'] as String,
        name: json['name'] as String,
        dailyTarget: json['dailyTarget'] as int? ?? 0,
        currentPage: json['currentPage'] as int? ?? 0,
        totalPages: json['totalPages'] as int? ?? 0,
        partInfo: json['partInfo'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
        startedAt: json['startedAt'] != null
            ? DateTime.tryParse(json['startedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse(json['completedAt'] as String)
            : null,
        notes: json['notes'] as String? ?? '',
      );
}

class ReadingPlanState {
  final bool enabled;
  final int dailyTarget;
  final int pagesReadToday;
  final TimeOfDay reminderTime;
  final List<StudyBook> books;
  final String? activeBookId;

  ReadingPlanState({
    this.enabled = false,
    this.dailyTarget = 20,
    this.pagesReadToday = 0,
    this.reminderTime = const TimeOfDay(hour: 8, minute: 0),
    this.books = const [],
    this.activeBookId,
  });

  double get progress =>
      dailyTarget > 0 ? (pagesReadToday / dailyTarget).clamp(0.0, 1.0) : 0.0;

  StudyBook? get activeBook => activeBookId != null
      ? books.where((b) => b.id == activeBookId).firstOrNull
      : null;

  ReadingPlanState copyWith({
    bool? enabled,
    int? dailyTarget,
    int? pagesReadToday,
    TimeOfDay? reminderTime,
    List<StudyBook>? books,
    Object? activeBookId = _activeBookIdUnset,
  }) {
    return ReadingPlanState(
      enabled: enabled ?? this.enabled,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      pagesReadToday: pagesReadToday ?? this.pagesReadToday,
      reminderTime: reminderTime ?? this.reminderTime,
      books: books ?? this.books,
      activeBookId: identical(activeBookId, _activeBookIdUnset)
          ? this.activeBookId
          : activeBookId as String?,
    );
  }
}

/// Sentinel to distinguish "not provided" from "set to null" in [copyWith].
const _activeBookIdUnset = Object();

@riverpod
class ReadingPlan extends _$ReadingPlan {
  SharedPreferences? _prefs;
  int _bookIdCounter = 0;
  bool _disposed = false;

  @override
  Future<ReadingPlanState> build() async {
    ref.keepAlive();
    ref.onDispose(() => _disposed = true);
    try {
      _prefs = await SharedPreferences.getInstance();
      final defaults = ReadingPlanState();
      final enabled = _prefs!.getBool('plan_enabled') ?? defaults.enabled;
      final dailyTarget =
          _prefs!.getInt('plan_dailyTarget') ?? defaults.dailyTarget;
      final reminderTime = TimeOfDay(
        hour: _prefs!.getInt('plan_reminderHour') ?? defaults.reminderTime.hour,
        minute: _prefs!.getInt('plan_reminderMinute') ??
            defaults.reminderTime.minute,
      );
      final todayKey = dateKeyOf(DateTime.now());
      final pagesReadToday =
          _prefs!.getInt('plan_progress_$todayKey') ?? defaults.pagesReadToday;
      final activeBookId = _prefs!.getString('plan_activeBookId');
      final books = _loadBooks();
      return ReadingPlanState(
        enabled: enabled,
        dailyTarget: dailyTarget,
        pagesReadToday: pagesReadToday,
        reminderTime: reminderTime,
        books: books,
        activeBookId: activeBookId,
      );
    } catch (e) {
      AppLogger.warning('reading_plan_provider', 'error: $e');
      return ReadingPlanState();
    }
  }

  List<StudyBook> _loadBooks() {
    final saved = _prefs?.getString('plan_study_books');
    if (saved != null && saved.isNotEmpty) {
      try {
        final decoded = jsonDecode(saved);
        if (decoded is! List) return [];
        final books = <StudyBook>[];
        for (final s in decoded) {
          try {
            if (s is Map<String, dynamic>) {
              books.add(StudyBook.fromJson(s));
            }
          } catch (_) {
            // Skip corrupted individual book entries
          }
        }
        return books;
      } catch (_) {
        // Clear corrupted data
        _prefs?.remove('plan_study_books');
        return [];
      }
    }
    return [];
  }

  Future<void> _saveBooks(List<StudyBook> books) async {
    final jsonList = jsonEncode(books.map((b) => b.toJson()).toList());
    await _prefs?.setString('plan_study_books', jsonList);
  }

  void _safeSetState(ReadingPlanState newState) {
    if (!_disposed) {
      state = AsyncData(newState);
    }
  }

  Future<void> setEnabled(bool v) async {
    await _prefs?.setBool('plan_enabled', v);
    _safeSetState(state.requireValue.copyWith(enabled: v));
  }

  Future<void> setDailyTarget(int v) async {
    await _prefs?.setInt('plan_dailyTarget', v);
    _safeSetState(state.requireValue.copyWith(dailyTarget: v));
  }

  Future<void> setReminderTime(TimeOfDay t) async {
    await _prefs?.setInt('plan_reminderHour', t.hour);
    await _prefs?.setInt('plan_reminderMinute', t.minute);
    _safeSetState(state.requireValue.copyWith(reminderTime: t));
  }

  Future<void> addBook(String name,
      {int dailyTarget = 0,
      int totalPages = 0,
      String partInfo = '',
      int currentPage = 0}) async {
    final cur = state.requireValue;
    final book = StudyBook(
      id: 'study_${DateTime.now().millisecondsSinceEpoch}_${_bookIdCounter++}',
      name: name,
      dailyTarget: dailyTarget,
      totalPages: totalPages,
      partInfo: partInfo,
      currentPage: currentPage,
      startedAt: DateTime.now(),
    );
    final books = [...cur.books, book];
    await _saveBooks(books);
    _safeSetState(cur.copyWith(books: books));
  }

  Future<void> removeBook(String id) async {
    final cur = state.requireValue;
    final books = cur.books.where((b) => b.id != id).toList();
    final activeBookId = cur.activeBookId == id ? null : cur.activeBookId;
    await _saveBooks(books);
    _safeSetState(cur.copyWith(books: books, activeBookId: activeBookId));
  }

  Future<void> setActiveBook(String? id) async {
    if (id != null) {
      await _prefs?.setString('plan_activeBookId', id);
    } else {
      await _prefs?.remove('plan_activeBookId');
    }
    _safeSetState(state.requireValue.copyWith(activeBookId: id));
  }

  Future<void> updateBook(String id,
      {String? name,
      int? dailyTarget,
      int? totalPages,
      String? partInfo,
      int? currentPage}) async {
    final cur = state.requireValue;
    final books = cur.books.map((b) {
      if (b.id != id) return b;
      if (name != null) b.name = name;
      if (dailyTarget != null) b.dailyTarget = dailyTarget;
      if (totalPages != null) b.totalPages = totalPages;
      if (partInfo != null) b.partInfo = partInfo;
      if (currentPage != null) b.currentPage = currentPage;
      return b;
    }).toList();
    await _saveBooks(books);
    _safeSetState(cur.copyWith(books: books));
  }

  Future<void> updateBookNotes(String id, String notes) async {
    final cur = state.requireValue;
    final books = cur.books.map((b) {
      if (b.id != id) return b;
      b.notes = notes;
      return b;
    }).toList();
    await _saveBooks(books);
    _safeSetState(cur.copyWith(books: books));
  }

  Future<void> logPages(String bookId, int pages) async {
    final cur = state.requireValue;
    final books = cur.books.map((b) {
      if (b.id != bookId) return b;
      final wasCompleted = b.isCompleted;
      b.currentPage += pages;
      if (b.isCompleted && !wasCompleted) {
        b.completedAt = DateTime.now();
      } else if (!b.isCompleted) {
        b.completedAt = null;
      }
      return b;
    }).toList();
    final todayKey = dateKeyOf(DateTime.now());
    final newPagesRead =
        (cur.pagesReadToday + pages).clamp(0, double.infinity).toInt();
    await _saveBooks(books);
    await _prefs?.setInt('plan_progress_$todayKey', newPagesRead);
    _safeSetState(cur.copyWith(books: books, pagesReadToday: newPagesRead));
  }

  Future<void> resetToday() async {
    final key = dateKeyOf(DateTime.now());
    await _prefs?.setInt('plan_progress_$key', 0);
    _safeSetState(state.requireValue.copyWith(pagesReadToday: 0));
  }
}
