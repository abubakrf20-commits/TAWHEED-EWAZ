import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/hifz/domain/hifz_helpers.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// A selected Quran range with its computed page count.
typedef HifzRange = ({
  int sFrom,
  int aFrom,
  int sTo,
  int aTo,
  int pages,
});

/// Picks a Quran range (سوره:آیه از → تا) with a live page count.
///
/// Reports changes through [onChanged] so the parent can keep the
/// selected values and the computed page count.
class HifzRangePicker extends StatefulWidget {
  const HifzRangePicker({
    super.key,
    this.initialSurahFrom = 1,
    this.initialAyahFrom = 1,
    this.initialSurahTo = 1,
    this.initialAyahTo = 5,
    this.helperText,
    this.onChanged,
  });

  final int initialSurahFrom;
  final int initialAyahFrom;
  final int initialSurahTo;
  final int initialAyahTo;
  final String? helperText;

  /// Called whenever any part of the range changes.
  final void Function(HifzRange range)? onChanged;

  @override
  State<HifzRangePicker> createState() => _HifzRangePickerState();
}

class _HifzRangePickerState extends State<HifzRangePicker> {
  late int _sFrom;
  late int _aFrom;
  late int _sTo;
  late int _aTo;
  late final TextEditingController _aFromCtrl;
  late final TextEditingController _aToCtrl;

  @override
  void initState() {
    super.initState();
    _sFrom = widget.initialSurahFrom;
    _aFrom = widget.initialAyahFrom;
    _sTo = widget.initialSurahTo;
    _aTo = widget.initialAyahTo;
    _aFromCtrl = TextEditingController(text: '$_aFrom');
    _aToCtrl = TextEditingController(text: '$_aTo');
  }

  @override
  void dispose() {
    _aFromCtrl.dispose();
    _aToCtrl.dispose();
    super.dispose();
  }

  void _changed() {
    final pages = pagesForRange(_sFrom, _aFrom, _sTo, _aTo);
    widget.onChanged?.call((
      sFrom: _sFrom,
      aFrom: _aFrom,
      sTo: _sTo,
      aTo: _aTo,
      pages: pages,
    ));
    setState(() {});
  }

  int _parseAyah(TextEditingController ctrl, int fallback) {
    final v = NumberFormat.parse(ctrl.text).toInt();
    return v < 1 ? fallback : v;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final error = isDark ? AppTheme.darkError : AppTheme.lightError;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final info = isDark ? AppTheme.darkInfo : AppTheme.lightInfo;
    final valid = isRangeValid(_sFrom, _aFrom, _sTo, _aTo);
    final pages = pagesForRange(_sFrom, _aFrom, _sTo, _aTo);
    final pFrom = pageForAyah(_sFrom, _aFrom);
    final pTo = pageForAyah(_sTo, _aTo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.helperText != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.helperText!,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _row(context, 'از', _sFrom, _aFromCtrl, (v) {
          _sFrom = v;
          _changed();
        }, (v) {
          _aFrom = v;
          _changed();
        }),
        const SizedBox(height: 8),
        _row(context, 'تا', _sTo, _aToCtrl, (v) {
          _sTo = v;
          _changed();
        }, (v) {
          _aTo = v;
          _changed();
        }),
        const SizedBox(height: 10),
        if (!valid)
          Text(
            'بازه نادرست است — سوره/آیهٔ «از» باید قبل از «تا» باشد.',
            style: TextStyle(color: error, fontSize: AppTheme.scaledFontSize(context, 12)),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book, size: 18, color: success),
                const SizedBox(width: 8),
                Text(
                  '${en(pages)} صفحه  ·  صفحهٔ ${en(pFrom)} تا ${en(pTo)}',
                  style: TextStyle(
                    color: success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    int surah,
    TextEditingController ayahCtrl,
    ValueChanged<int> onSurah,
    ValueChanged<int> onAyah,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: surah,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              border: OutlineInputBorder(),
            ),
            items: [
              for (var i = 1; i <= 114; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${en(i)}. ${surahNameAr(i)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) onSurah(v);
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: TextField(
            controller: ayahCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
            ],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'آیه',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onAyah(_parseAyah(ayahCtrl, 1)),
          ),
        ),
      ],
    );
  }
}
