import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// ═══════════════════════════════════════════════════════════════
/// ReportRenderer — one place that turns a report into a shareable file.
///
/// Two outputs, both required by the tools:
///  • **PNG** of an on-screen widget tree, through
///    `RepaintBoundary.toImage` at `pixelRatio <= 2` (the brief's cap — a
///    larger ratio costs memory on an A13-class phone for no legibility gain
///    at A5 scale);
///  • **PDF**, single- or multi-page, in **A4 or A5**, RTL Persian text in
///    Vazirmatn, with the app's footer brand strip («توحید» + logo).
///
/// The PDF reuses `pdf_report_util.dart` (fonts, logo, branded header/footer)
/// rather than re-deriving them, and reuses [ShareService] constants for the
/// brand strings so the exported image and the exported PDF cannot drift.
///
/// Every path deletes its temp file after the share sheet closes: these are
/// reports that contain children's names, and a temp cache that outlives the
/// share is a privacy leak the brief explicitly forbids.
/// ═══════════════════════════════════════════════════════════════

/// Page geometry offered to the report builder.
enum ReportPageSize {
  a4('A4'),
  a5('A5');

  const ReportPageSize(this.label);
  final String label;

  PdfPageFormat get format =>
      this == ReportPageSize.a5 ? PdfPageFormat.a5 : PdfPageFormat.a4;
}

class ReportRenderer {
  ReportRenderer._();

  /// Rasterizes the subtree behind [boundaryKey] to PNG bytes.
  ///
  /// The boundary must be mounted and laid out. Returns null instead of
  /// throwing when it has been disposed mid-capture, so callers can fall back
  /// to sharing text.
  static Future<Uint8List?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = 2,
  }) async {
    // The brief's cap is 2: anything above it multiplies the bitmap by the
    // square of the ratio, and these reports are already tall.
    final ratio = pixelRatio.clamp(1.0, 2.0);
    try {
      final context = boundaryKey.currentContext;
      if (context == null) return null;
      final object = context.findRenderObject();
      if (object is! RenderRepaintBoundary) return null;
      if (!object.hasSize || object.size.isEmpty) return null;

      final image = await object.toImage(pixelRatio: ratio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = data?.buffer.asUint8List();
        if (bytes == null || bytes.isEmpty) return null;
        return bytes;
      } finally {
        image.dispose();
      }
    } catch (e) {
      AppLogger.warning('ReportRenderer', 'png capture failed: $e');
      return null;
    }
  }

  /// Writes [bytes] to a temp file, opens the system share sheet, then deletes
  /// the file. Returns false when the share could not be offered.
  static Future<bool> shareImage(
    Uint8List bytes, {
    required String fileName,
    String? text,
    String? subject,
  }) async {
    File? file;
    try {
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
        subject: subject,
      ));
      return true;
    } catch (e) {
      AppLogger.warning('ReportRenderer', 'image share failed: $e');
      return false;
    } finally {
      await _deleteQuietly(file);
    }
  }

  /// Builds a branded PDF.
  ///
  /// [body] is the report content as `pdf` widgets, already in reading order.
  /// [pageSize] picks A4/A5; [multiPage] chooses `MultiPage` (flowing text,
  /// the usual case) over a single fixed `Page` (a card-like one-pager).
  static Future<Uint8List> buildPdf({
    required String title,
    required String subtitle,
    required Color accent,
    required List<pw.Widget> body,
    ReportPageSize pageSize = ReportPageSize.a4,
    bool multiPage = true,
  }) async {
    final regular = await pdfVazirFont(bold: false);
    final bold = await pdfVazirFont(bold: true);
    final logo = await pdfLogoBytes();
    final accentPdf = PdfColor.fromInt(accent.toARGB32());

    final doc = pw.Document(
      title: title,
      author: ShareService.signatureName,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    final margin = pageSize == ReportPageSize.a5
        ? const pw.EdgeInsets.fromLTRB(20, 18, 20, 26)
        : const pw.EdgeInsets.fromLTRB(32, 28, 32, 40);

    // Header/footer are private to pdf_report_util; the shared builder only
    // offers A4 MultiPage. Rebuilding the two small bands here keeps the A5
    // path possible without widening that util's contract for every caller.
    if (multiPage) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: pageSize.format,
          margin: margin,
          header: (ctx) => _header(title, accentPdf, logo, pageSize),
          footer: (ctx) => _footer(ctx.pageNumber, bold, pageSize),
          build: (ctx) => [
            pw.SizedBox(height: 6),
            if (subtitle.isNotEmpty) ...[
              _subtitleBand(subtitle, pageSize),
              pw.SizedBox(height: 10),
            ],
            ...body,
          ],
        ),
      );
    } else {
      doc.addPage(
        pw.Page(
          pageFormat: pageSize.format,
          margin: margin,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(title, accentPdf, logo, pageSize),
              pw.SizedBox(height: 8),
              if (subtitle.isNotEmpty) ...[
                _subtitleBand(subtitle, pageSize),
                pw.SizedBox(height: 8),
              ],
              ...body,
            ],
          ),
        ),
      );
    }

    return doc.save();
  }

  /// Shares a built PDF and deletes the temp copy afterwards.
  static Future<bool> sharePdf(
    Uint8List bytes, {
    required String fileName,
    String? subject,
  }) async {
    File? file;
    try {
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: subject,
      ));
      return true;
    } catch (e) {
      AppLogger.warning('ReportRenderer', 'pdf share failed: $e');
      return false;
    } finally {
      await _deleteQuietly(file);
    }
  }

  // ── PDF furniture ────────────────────────────────────────────────────

  static pw.Widget _header(
    String title,
    PdfColor accent,
    Uint8List logo,
    ReportPageSize size,
  ) {
    final titleSize = size == ReportPageSize.a5 ? 12.0 : 14.0;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFDF6EC),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.ClipOval(
            child: pw.Image(
              pw.MemoryImage(logo),
              width: 26,
              height: 26,
              fit: pw.BoxFit.cover,
            ),
          ),
          pw.Text(
            title,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              fontSize: titleSize,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF263238),
            ),
          ),
          pw.Container(
            width: 4,
            height: 20,
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _subtitleBand(String subtitle, ReportPageSize size) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFDF6EC),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        subtitle,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          fontSize: size == ReportPageSize.a5 ? 9 : 11,
          color: const PdfColor.fromInt(0xFF78909C),
        ),
      ),
    );
  }

  static pw.Widget _footer(int page, pw.Font bold, ReportPageSize size) {
    final fontSize = size == ReportPageSize.a5 ? 7.0 : 8.0;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          // The brand strip the brief requires on every exported report.
          ShareService.signatureName,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(font: bold, fontSize: fontSize, color: _inkMuted),
        ),
        pw.Text(
          'صفحه ${enDigits(page)}',
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(fontSize: fontSize, color: _inkMuted),
        ),
      ],
    );
  }

  static const PdfColor _inkMuted = PdfColor.fromInt(0xFF78909C);

  static Future<void> _deleteQuietly(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A file left in the temp dir is reclaimed by the OS; failing to delete
      // must not turn a successful share into an error dialog.
    }
  }
}
