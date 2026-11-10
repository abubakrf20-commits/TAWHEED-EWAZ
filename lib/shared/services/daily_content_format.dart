/// Single source of truth for how daily content (آیه روز / حدیث روز) is
/// presented — used by the app screens and the scheduled notifications so
/// both always look exactly the same.
///
/// Format: the Arabic text on its own line, then the translation, then the
/// source — i.e. `text / trans / ref`. The translation is skipped only when it
/// is empty or duplicates the text itself (legacy Persian-only entries).
library;

import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/persian_text.dart';

String dailyContentBody({
  required String text,
  required String ref,
  required String trans,
}) {
  final buffer = StringBuffer(spacedZwnj(text).trim());
  final tail = dailyContentTail(text: text, ref: ref, trans: trans);
  if (tail.isNotEmpty) buffer.write('\n$tail');
  return buffer.toString();
}

/// Everything after the Arabic text: the translation on its own line followed
/// by the source — `trans\nref` when the translation exists AND differs from
/// the text, otherwise just `ref`. Used by both the notification body and the
/// in-app cards so the two always agree.
String dailyContentTail({
  required String text,
  required String ref,
  required String trans,
}) {
  final t = NumberFormat.toLatin(trans.trim());
  final hasTranslation = t.isNotEmpty && t != NumberFormat.toLatin(text.trim());
  if (!hasTranslation) return spacedZwnj(NumberFormat.toLatin(ref.trim()));
  return '${spacedZwnj(t)}\n${spacedZwnj(NumberFormat.toLatin(ref.trim()))}';
}

/// Rich HTML body for the Android daily-content notification (آیه/حدیث/دعا).
/// Rendered via `BigTextStyleInformation(..., html: true)` — the Arabic text is
/// shown big and bold, the translation in a normal line and the source as a
/// smaller italic line at the bottom. Mirrors [dailyContentBody]'s order:
/// text → translation → source.
String dailyNotificationHtml({
  required String text,
  required String ref,
  required String trans,
}) {
  final buffer =
      StringBuffer('<b><big>${_escapeHtml(spacedZwnj(text.trim()))}</big></b>');
  final t = trans.trim();
  if (t.isNotEmpty && t != text.trim()) {
    buffer.write('<br/>${_escapeHtml(spacedZwnj(NumberFormat.toLatin(t)))}');
  }
  if (ref.trim().isNotEmpty) {
    buffer.write(
        '<br/><i><small>${_escapeHtml(spacedZwnj(NumberFormat.toLatin(ref.trim())))}</small></i>');
  }
  return buffer.toString();
}

String _escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
