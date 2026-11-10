import '../entities/zikr_item.dart' hide PrayerPeriod;
import 'package:tawheeed/features/adhkar/domain/entities/prayer_period.dart';

/// Status of a zikr item.
enum ZikrStatus { pending, done, skipped }

/// Abstract interface for azkar data access.
abstract class AzkarRepository {
  /// Initialize the repository (open boxes, load data).
  Future<void> init();

  /// Load all azkar items from the data source.
  Future<List<ZikrItem>> loadAllAzkar();

  /// Get azkar items for a specific prayer period.
  List<ZikrItem> getByPeriod(PrayerPeriod period);

  /// Get the status of a specific zikr item for today.
  ZikrStatus getStatus(String id);

  /// Set the status of a specific zikr item for today.
  Future<void> setStatus(String id, ZikrStatus status);

  /// Set the status of many zikr items for today in a single write.
  Future<void> setStatusBatch(List<String> ids, ZikrStatus status);

  /// Get statistics for a specific prayer period.
  Map<String, int> periodStats(PrayerPeriod period);

  /// Get today's overall statistics.
  Map<String, int> get todayStats;

  /// Reset all progress for today.
  Future<void> resetDay();
}
