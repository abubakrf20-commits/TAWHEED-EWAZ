import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Thrown when an on-screen share card cannot be captured. Carries a
/// Persian user-facing [message] so callers can show it directly.
class ShareCaptureException implements Exception {
  final String message;
  const ShareCaptureException(this.message);

  @override
  String toString() => 'ShareCaptureException: $message';
}

/// Single entry point for every share/copy flow in the app.
///
/// Before this service, each share screen hand-rolled the same
/// `RepaintBoundary → PNG → temp file → SharePlus` block (with force-unwraps
/// that crashed when the card was disposed mid-capture) and copy-pasted the
/// channel footer in 4+ places. Screens keep their own card widgets and
/// formatted text; all capture/share/clipboard mechanics live here.
class ShareService {
  ShareService._();

  // ── Brand (single source of truth) ────────────────────────────────────

  static const String channelName = 'کانال تلگرام توحید اوز';
  static const String channelUrl = 'https://t.me/TAWHEED_EWAZ1';

  /// Footer block appended to shared images (`text:` of the image share).
  static String get channelBlock => '$channelName\n$channelUrl';

  /// Footer line appended to formatted share texts.
  static String get channelLine => '$channelName: $channelUrl';

  /// The app's name as it is printed under the logo on an exported card.
  static const String signatureName = 'برنامه توحید';

  /// The mark painted above [signatureLine] on an exported card. Only the
  /// share-card kit may draw it (`ShareCardLogo`), never a surface by hand.
  static const String logoAsset = 'assets/logo2.png';

  /// The signature line printed inside an exported image. It carries no
  /// leading dash because the logo above it already marks the signature.
  static String signatureLine([String? section]) =>
      (section == null || section.isEmpty)
          ? signatureName
          : '$signatureName | $section';

  /// Footer line for share texts (copy / Telegram). The leading dash stays so
  /// the text still separates itself from the content above it.
  static String appLine([String? section]) => '— ${signatureLine(section)}';

  // ── Card capture ──────────────────────────────────────────────────────

  /// Null-safe lookup of an on-screen [RepaintBoundary] card and its size.
  /// Throws [ShareCaptureException] (Persian message, never a crash) when
  /// the card is disposed mid-capture or not laid out yet.
  static ({RenderRepaintBoundary boundary, Size size}) cardBoundary(
      GlobalKey cardKey) {
    final context = cardKey.currentContext;
    if (context == null) {
      throw const ShareCaptureException('کارت ارسال آماده نیست.');
    }
    final renderObject = context.findRenderObject();
    final boundary =
        renderObject is RenderRepaintBoundary ? renderObject : null;
    final box = renderObject is RenderBox ? renderObject : null;
    if (boundary == null || box == null || !box.hasSize) {
      throw const ShareCaptureException('کارت ارسال آماده نیست.');
    }
    final size = box.size;
    if (size.width <= 0 || size.height <= 0) {
      throw const ShareCaptureException('کارت ارسال آماده نیست.');
    }
    return (boundary: boundary, size: size);
  }

  /// Rasterizes [boundary] at [pixelRatio] to PNG bytes.
  static Future<Uint8List> rasterizeCard(
      RenderRepaintBoundary boundary, double pixelRatio) async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null || bytes.isEmpty) {
      throw const ShareCaptureException('تبدیل تصویر به PNG ناموفق بود.');
    }
    return bytes;
  }

  /// Captures the on-screen [RepaintBoundary] behind [cardKey] as PNG bytes.
  ///
  /// The output is scaled so the longest side lands around [targetLongest]
  /// px, clamped to [minRatio]..[maxRatio]. Never force-unwraps: a missing
  /// context (card disposed mid-capture) or a render failure throws
  /// [ShareCaptureException] with a Persian message instead of crashing.
  static Future<Uint8List> captureCard(
    GlobalKey cardKey, {
    double targetLongest = 2400,
    double minRatio = 2.0,
    double maxRatio = 6.0,
  }) async {
    final card = cardBoundary(cardKey);
    final longest =
        card.size.width > card.size.height ? card.size.width : card.size.height;
    final pixelRatio = (targetLongest / longest).clamp(minRatio, maxRatio);
    return rasterizeCard(card.boundary, pixelRatio);
  }

  // ── Share ─────────────────────────────────────────────────────────────

  /// Shares PNG [bytes] through the system sheet. Throws on I/O failure so
  /// callers can fall back to text sharing.
  static Future<void> sharePng(
    Uint8List bytes,
    String fileName, {
    String? text,
    String? subject,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      text: text,
      subject: subject,
    ));
  }

  /// Shares plain [text] through the system sheet.
  static Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  // ── Clipboard + feedback ──────────────────────────────────────────────

  /// Copies [text] and shows a short confirmation. Safe to call without a
  /// mounted check — the [context] must still be valid, as with any snackbar.
  static Future<void> copyText(
    BuildContext context,
    String text, {
    String doneMessage = 'کپی شد',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(doneMessage), duration: const Duration(seconds: 1)),
    );
  }

  /// Standard image-share failure snackbar («ارسال تصویر ممکن نشد…»).
  static void showImageFailure(BuildContext context,
      [String message = 'ارسال تصویر ممکن نشد. متن را ارسال کنید.']) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
