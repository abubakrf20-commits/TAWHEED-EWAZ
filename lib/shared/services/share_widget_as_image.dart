import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Renders [child] (typically a print/share-friendly card) offscreen at
/// [width] logical pixels, captures it as a high-resolution PNG, saves it to
/// a temp file and opens the system share sheet so the user can send it to
/// group members, print it or save it.
///
/// Two-pass approach (works on any Flutter version):
/// 1. Lay the widget out with an unbounded height (via [OverflowBox]) and
///    measure its natural height.
/// 2. Re-render it in a [RepaintBoundary] sized exactly to that height and
///    capture with [RenderRepaintBoundary.toImage].
Future<void> shareWidgetAsImage(
  BuildContext context, {
  required Widget child,
  required String fileName,
  String? text,
  double width = 900,
  double pixelRatio = 2.0,
}) async {
  final measureKey = GlobalKey();
  final boundaryKey = GlobalKey();
  final overlay = Overlay.of(context, rootOverlay: true);

  // ── Pass 1: measure the natural content height ────────────────────
  late final OverlayEntry measureEntry;
  measureEntry = OverlayEntry(
    builder: (_) => buildShareCaptureScene(
      boundaryKey: measureKey,
      width: width,
      child: child,
    ),
  );
  overlay.insert(measureEntry);
  await WidgetsBinding.instance.endOfFrame;
  final renderBox = measureKey.currentContext?.findRenderObject() as RenderBox?;
  var measuredHeight = renderBox?.size.height;
  measureEntry.remove();

  if (measuredHeight == null || measuredHeight <= 0) {
    // Fallback — the widget could not be measured for any reason.
    measuredHeight = 800;
  }

  // ── Pass 2: render at the measured size and capture ───────────────
  late final OverlayEntry captureEntry;
  captureEntry = OverlayEntry(
    builder: (_) => buildShareCaptureScene(
      boundaryKey: boundaryKey,
      width: width,
      height: measuredHeight,
      child: child,
    ),
  );
  overlay.insert(captureEntry);
  // The [RepaintBoundary] must stay inside the unconstrained [OverflowBox]
  // so it wraps the exact content — wrapping it the other way around makes it
  // hug the screen size and the shared PNG comes out cropped to the display.
  // Two idle frames also let the freshly inserted layer fully rasterize
  // (fonts/glyphs) before the read-back.
  await WidgetsBinding.instance.endOfFrame;
  await WidgetsBinding.instance.endOfFrame;
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  final image =
      boundary == null ? null : await boundary.toImage(pixelRatio: pixelRatio);
  captureEntry.remove();

  if (image == null) {
    throw StateError('رندر تصویر گزارش ناموفق بود');
  }
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('تبدیل تصویر به PNG ناموفق بود');
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName')
    ..writeAsBytesSync(byteData.buffer.asUint8List(), flush: true);

  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'image/png')],
    text: text,
  ));
}

/// The offscreen scene used by both capture passes: an unconstrained
/// [OverflowBox] whose child is a [RepaintBoundary] that exactly wraps the
/// content (so its layer — and therefore the PNG — is the content's own size,
/// never clipped to the device screen). Exposed for tests.
@visibleForTesting
Widget buildShareCaptureScene({
  required Key boundaryKey,
  required double width,
  required Widget child,
  double? height,
}) {
  return OverflowBox(
    minWidth: 0,
    maxWidth: double.infinity,
    minHeight: 0,
    maxHeight: double.infinity,
    child: RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(width: width, height: height, child: child),
    ),
  );
}
