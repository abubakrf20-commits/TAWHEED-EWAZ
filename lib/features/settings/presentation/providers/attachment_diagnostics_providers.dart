import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';
import 'package:tawheeed/features/personal_info/services/attachment_dead_refs_scanner.dart';

/// Builds a scanner bound to the live «اطلاعات من» repository.
final attachmentDeadRefsScannerProvider =
    Provider<AttachmentDeadRefsScanner>((ref) {
  return AttachmentDeadRefsScanner(
    repository: ref.read(personalInfoRepositoryProvider),
  );
});
