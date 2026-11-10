/// One cloud (Firebase Storage) copy of the backup ZIP under the signed-in
/// user's account. Downstream code shows it in a list and restores on demand.
class CloudBackupItem {
  final String name;
  final int sizeBytes;
  final DateTime updated;

  const CloudBackupItem({
    required this.name,
    required this.sizeBytes,
    required this.updated,
  });
}
