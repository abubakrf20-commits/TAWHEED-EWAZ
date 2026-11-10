import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/khatm/data/daos/khatm_dao.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/features/khatm/domain/repositories/khatm_repository.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

final khatmRepositoryProvider = Provider<KhatmRepository>((ref) {
  return KhatmRepositoryImpl(ref.read(khatmDaoProvider));
});

class KhatmRepositoryImpl implements KhatmRepository {
  final KhatmDao _dao;
  KhatmRepositoryImpl(this._dao);

  List<bool> _decodePages(String? stored) {
    if (stored == null || stored.isEmpty) return List.filled(604, false);
    try {
      final bytes = base64.decode(stored);
      final bits = <bool>[];
      for (int i = 0; i < 604; i++) {
        final byteIndex = i ~/ 8;
        final bitIndex = i % 8;
        if (byteIndex < bytes.length) {
          bits.add((bytes[byteIndex] & (1 << bitIndex)) != 0);
        } else {
          bits.add(false);
        }
      }
      return bits;
    } catch (_) {
      AppLogger.warning('khatm_repository_impl', 'operation failed');
      return List.filled(604, false);
    }
  }

  String _encodePages(List<bool> pages) {
    final bytes = Uint8List((pages.length + 7) ~/ 8);
    for (int i = 0; i < pages.length; i++) {
      if (pages[i]) {
        final byteIndex = i ~/ 8;
        final bitIndex = i % 8;
        bytes[byteIndex] |= (1 << bitIndex);
      }
    }
    return base64.encode(bytes);
  }

  Map<String, int> _decodeDailyRead(String? stored) {
    if (stored == null || stored.isEmpty) return {};
    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      AppLogger.warning('khatm_repository_impl', 'operation failed');
      return {};
    }
  }

  KhatmModel _toModel(KhatmTableData row) {
    return KhatmModel(
      id: row.id,
      title: row.title,
      startDate: row.startDate,
      endDate: row.endDate,
      targetDays: row.targetDays,
      pagesRead: _decodePages(row.pagesRead),
      dailyRead: _decodeDailyRead(row.dailyRead),
      isCompleted: row.isCompleted,
      participantNames: row.participantNames.isEmpty
          ? []
          : (jsonDecode(row.participantNames) as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      participantAssignedJuzs: row.participantAssignedJuzs.isEmpty
          ? []
          : (jsonDecode(row.participantAssignedJuzs) as List<dynamic>)
              .map((e) => e as int)
              .toList(),
    );
  }

  KhatmTableData _toRow(KhatmModel m) {
    return KhatmTableData(
      id: m.id,
      title: m.title,
      startDate: m.startDate,
      endDate: m.endDate,
      targetDays: m.targetDays,
      pagesRead: _encodePages(m.pagesRead),
      dailyRead: jsonEncode(m.dailyRead),
      isCompleted: m.isCompleted,
      participantNames: jsonEncode(m.participantNames),
      participantAssignedJuzs: jsonEncode(m.participantAssignedJuzs),
    );
  }

  @override
  Future<List<KhatmModel>> getAllKhatms() async {
    final all = await _dao.getAllKhatms();
    return all.map(_toModel).toList();
  }

  @override
  Future<KhatmModel?> getKhatm(String id) async {
    final row = await _dao.getKhatm(id);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> upsertKhatm(KhatmModel khatm) => _dao.upsertKhatm(_toRow(khatm));

  @override
  Future<void> deleteKhatm(String id) => _dao.deleteKhatm(id);
}
