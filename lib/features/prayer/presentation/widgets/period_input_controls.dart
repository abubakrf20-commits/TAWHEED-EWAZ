part of 'period_widgets.dart';

class PeriodSettingPicker extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final int min, max;
  final ValueChanged<int> onChanged;

  const PeriodSettingPicker(
      {super.key,
      required this.label,
      required this.value,
      required this.unit,
      required this.min,
      required this.max,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final gold = periodAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textMuted)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                button: true,
                enabled: value > min,
                label: '$label — کاهش',
                child: GestureDetector(
                  onTap: value > min ? () => onChanged(value - 1) : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: Icon(Icons.remove,
                        size: 18, color: value > min ? gold : t.textMuted),
                  ),
                ),
              ),
              Flexible(
                  child: Text('$value $unit',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 18),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary))),
              Semantics(
                button: true,
                enabled: value < max,
                label: '$label — افزایش',
                child: GestureDetector(
                  onTap: value < max ? () => onChanged(value + 1) : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: Icon(Icons.add,
                        size: 18, color: value < max ? gold : t.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Owns its controller so the day-actions note field doesn't leak one per open.
class PeriodNotesTextField extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onChanged;
  const PeriodNotesTextField(
      {super.key, required this.initialText, required this.onChanged});

  @override
  State<PeriodNotesTextField> createState() => PeriodNotesTextFieldState();
}

class PeriodNotesTextFieldState extends State<PeriodNotesTextField> {
  late final TextEditingController _controller;
  Timer? _debounce;
  String? _pending;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText)
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: widget.initialText.length),
      );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_pending != null) {
      // آخرین متن تایپ‌شده را قبل از بسته شدن ذخیره کن.
      widget.onChanged(_pending!);
    }
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    _pending = value;
    _debounce?.cancel();
    // نوشتن در دیتابیس به ازای هر کاراکتر باعث لگ تایپ می‌شود؛
    // با تأخیر کوتاه ذخیره کن.
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => widget.onChanged(_pending!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        hintText: 'یادداشت...',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      maxLines: 3,
      onChanged: _handleChanged,
    );
  }
}

class PeriodSymptomSelector extends StatefulWidget {
  final List<String> selectedSymptoms;
  final ValueChanged<List<String>> onChanged;
  const PeriodSymptomSelector(
      {super.key, required this.selectedSymptoms, required this.onChanged});

  @override
  State<PeriodSymptomSelector> createState() => PeriodSymptomSelectorState();
}

class PeriodSymptomSelectorState extends State<PeriodSymptomSelector> {
  static const _allSymptoms = [
    'درد شکم',
    'سردرد',
    'کمر درد',
    'خستگی',
    'نفخ',
    'نوسان خلقی',
    'تهوع',
    'سینه‌درد',
    'جوش صورت',
    'بی‌خوابی',
    'پرخوابی',
    'لکه‌بینی',
    'لخته',
  ];

  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedSymptoms);
  }

  @override
  void didUpdateWidget(PeriodSymptomSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSymptoms != widget.selectedSymptoms) {
      _selected = List.from(widget.selectedSymptoms);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _allSymptoms.map((symptom) {
        final isSelected = _selected.contains(symptom);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selected.remove(symptom);
              } else {
                _selected.add(symptom);
              }
            });
            widget.onChanged(_selected);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? periodAccent.withValues(alpha: 0.16)
                      : periodAccentSoft)
                  : t.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? periodAccent : t.outline,
              ),
            ),
            child: Text(
              symptom,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: isSelected ? periodAccentStrong : t.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// انتخاب شدت خونریزی (کم/متوسط/زیاد) برای نمودار و گزارش.
class PeriodFlowSelector extends StatefulWidget {
  final PeriodFlow? selected;
  final ValueChanged<PeriodFlow?> onChanged;
  const PeriodFlowSelector(
      {super.key, required this.selected, required this.onChanged});

  @override
  State<PeriodFlowSelector> createState() => _PeriodFlowSelectorState();
}

class _PeriodFlowSelectorState extends State<PeriodFlowSelector> {
  PeriodFlow? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: PeriodFlow.values.map((flow) {
        final isSelected = _selected == flow;
        return GestureDetector(
          onTap: () {
            setState(() => _selected = isSelected ? null : flow);
            widget.onChanged(isSelected ? null : flow);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? periodAccentSoft : t.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? periodAccent : t.outline),
            ),
            child: Text(
              periodFlowLabels[flow] ?? '',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: isSelected ? periodAccentStrong : t.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
