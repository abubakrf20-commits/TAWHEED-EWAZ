import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';

abstract class KhatmRepository {
  Future<List<KhatmModel>> getAllKhatms();
  Future<KhatmModel?> getKhatm(String id);
  Future<void> upsertKhatm(KhatmModel khatm);
  Future<void> deleteKhatm(String id);
}
