import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dorar_hadith/dorar_hadith.dart';
import 'package:meta/meta.dart';

import '../../domain/entities/dorar_hadith_entity.dart';

/// مدل لایه Data برای یک حدیث بازگشتی از درر.
///
/// [HadithBase] mixin روی هر سه مدل پکیج (Hadith سبک، DetailedHadith و
/// ExplainedHadith) نشسته است، پس یک سازنده کافی است.
@immutable
class DorarHadithModel {
  final String hadithText;
  final String narrator;
  final String mohdith;
  final String book;
  final String numberOrPage;
  final String degree;

  /// شناسه عددی واقعی حدیث در dorar.net؛ در جستجوی سبک (JSON API) موجود نیست.
  final String? hadithId;

  final List<String> similarHadiths;
  final List<String> alternatives;

  const DorarHadithModel({
    required this.hadithText,
    required this.narrator,
    required this.mohdith,
    required this.book,
    required this.numberOrPage,
    required this.degree,
    this.hadithId,
    this.similarHadiths = const [],
    this.alternatives = const [],
  });

  factory DorarHadithModel.fromApi(HadithBase api) {
    String? id;
    var similar = const <String>[];
    var alternatives = const <String>[];
    if (api is DetailedHadith) {
      id = api.hadithId;
      // لینک‌های درر وقتی وجود دارند که حدیث واقعیِ مشابه/بدیل داشته باشد.
      similar = [
        if (api.similarHadithDorar?.isNotEmpty ?? false) api.similarHadithDorar!
      ];
      alternatives = [
        if (api.alternateHadithSahihDorar?.isNotEmpty ?? false)
          api.alternateHadithSahihDorar!,
      ];
    }
    return DorarHadithModel(
      hadithText: api.hadith,
      narrator: api.rawi,
      mohdith: api.mohdith,
      book: api.book,
      numberOrPage: api.numberOrPage,
      degree: api.hukm,
      hadithId: id,
      similarHadiths: similar,
      alternatives: alternatives,
    );
  }

  /// شناسه پایدار: hadithId واقعی، وگرنه بصمت (sha1) متن+منبع.
  ///
  /// جستجوی سبک درر شناسه نمی‌دهد ولی المفضلة به کلیدی تکرارشدنی نیاز دارد؛
  /// hashCode رشته در Dart بین اجراها پایدار نیست، پس sha1.
  String get stableId => hadithId ?? _sha1('$hadithText|$book|$numberOrPage');

  bool get hasRealId => hadithId != null && hadithId!.trim().isNotEmpty;

  static String _sha1(String input) => sha1
      .convert(utf8.encode(input))
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  DorarHadithEntity toEntity({String? explanation}) => DorarHadithEntity(
        id: stableId,
        hadithText: hadithText,
        narrator: narrator.isEmpty ? null : narrator,
        mohdith: mohdith.isEmpty ? null : mohdith,
        book: book.isEmpty ? null : book,
        degree: degree.isEmpty ? null : degree,
        hadithNumber: numberOrPage.isEmpty ? null : numberOrPage,
        explanation: explanation,
        similarHadiths: similarHadiths,
        alternatives: alternatives,
        canViewDetails: hasRealId,
      );
}

/// یک صفحه از نتایج جستجو در سطح Data.
@immutable
class DorarSearchPageModel {
  final List<DorarHadithModel> items;
  final bool hasNextPage;
  final int totalResults;

  const DorarSearchPageModel({
    required this.items,
    this.hasNextPage = false,
    this.totalResults = 0,
  });

  const DorarSearchPageModel.empty()
      : items = const [],
        hasNextPage = false,
        totalResults = 0;

  DorarHadithResultsPage toDomain() => DorarHadithResultsPage(
        items: items.map((m) => m.toEntity()).toList(),
        hasNextPage: hasNextPage,
        totalResults: totalResults,
      );
}
