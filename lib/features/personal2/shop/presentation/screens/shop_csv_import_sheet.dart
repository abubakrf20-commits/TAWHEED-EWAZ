import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/app_card.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/services/shop_csv.dart';

/// The CSV import flow: pick file → parse in an isolate → PREVIEW with
/// row-level errors and duplicate warnings → confirmed apply in 200-row
/// chunks. Nothing writes before the user sees the preview.
class ShopCsvImportSheet {
  ShopCsvImportSheet._();

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final t = TimeThemeKit.of(context).palette;

    // 1. Pick the file.
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (picked.isEmpty || !context.mounted) return;
    // This file_picker version carries the file via .path (or a stream when
    // the platform caches it) — the same recipe profile_editor_screen uses.
    final src = picked.first.path;
    List<int> bytes;
    if (src != null) {
      bytes = await File(src).readAsBytes();
    } else {
      final tmp = File('${Directory.systemTemp.path}/${picked.first.name}');
      await tmp.openWrite().addStream(picked.first.readAsByteStream());
      bytes = await tmp.readAsBytes();
    }
    if (bytes.isEmpty || !context.mounted) return;
    // BOM tolerated: the exporter does not write one, but Excel round-trips do.
    var content = String.fromCharCodes(bytes);
    if (content.startsWith('﻿')) content = content.substring(1);

    if (!context.mounted) return;

    // 2. Parse off the UI isolate, then show the preview.
    final result = await ShopCsv.runImportParse(content);
    if (!context.mounted) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => SafeArea(
        child: _Preview(result: result),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // 3. Apply: chunked writes; a duplicate-barcode file still imports the
    // rows whose barcodes are unique (the preview warned about the rest).
    final dao = ref.read(shopDaoProvider);
    final written = await ShopCsv.importProducts(dao, result.rows);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        '$written کالا وارد شد'
        '${result.duplicateBarcodes.isEmpty ? '' : '؛ بارکدهای تکراری رد شدند'}.',
        style: TextStyle(fontFamily: AppTheme.fontFamily),
      ),
    ));
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.result});

  final CsvImportResult result;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final okCount = result.rows.length;
    final errorCount = result.errors.length;
    final dupCount = result.duplicateBarcodes.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      children: [
        const SheetHandle(),
        Text(
          'پیش‌نمایش ورود کالا',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _chip(context, '$okCount سالم', const Color(0xFF2E8B3D)),
            const SizedBox(width: 6),
            if (errorCount > 0)
              _chip(context, '$errorCount خطا', const Color(0xFFC9462C)),
            if (dupCount > 0)
              _chip(context, '$dupCount بارکد تکراری', const Color(0xFFD9922B)),
          ],
        ),
        const SizedBox(height: 10),
        if (result.rows.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ردیف‌های سالم (۵ اول)',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: t.textSecondary),
                ),
                const SizedBox(height: 4),
                for (final row in result.rows.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${row.name} · ${row.sellPrice} · '
                      'موجودی ${row.stockMilli ~/ 1000}',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            borderColor: const Color(0xFFC9462C).withValues(alpha: .4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'خطاهای ردیفی',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: const Color(0xFFC9462C)),
                ),
                const SizedBox(height: 4),
                for (final e in result.errors.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'خط ${e.lineNumber}: ${e.message}',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (result.duplicateBarcodes.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            borderColor: const Color(0xFFD9922B).withValues(alpha: .4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بارکدهای تکراری در فایل',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: const Color(0xFFD9922B)),
                ),
                const SizedBox(height: 4),
                for (final b in result.duplicateBarcodes.take(5))
                  Text(b,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily, fontSize: 11)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('انصراف'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7C86),
                ),
                onPressed:
                    okCount == 0 ? null : () => Navigator.of(context).pop(true),
                child: Text(okCount == 0 ? 'چیزی برای وارد کردن نیست' : 'وارد کردن $okCount کالا'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
