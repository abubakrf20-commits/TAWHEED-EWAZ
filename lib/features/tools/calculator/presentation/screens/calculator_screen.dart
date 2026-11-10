import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/calculator/data/calculator_engine.dart';
import 'package:tawheeed/features/tools/calculator/data/calculator_history.dart';
import 'package:tawheeed/features/tools/calculator/data/daos/calculator_dao.dart';
import 'package:tawheeed/features/tools/calculator/presentation/widgets/history_sheet.dart';
import 'package:tawheeed/features/tools/calculator/presentation/widgets/calculator_tool_panels.dart';
import 'package:tawheeed/features/tools/calculator/presentation/widgets/unit_converter_view.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

const Color _calcAccent = TopicHues.calculator;

class CalcStep {
  final String expression;
  final String result;
  CalcStep(this.expression, this.result);
}

enum _CalcMode { standard, scientific, percent, discount, age, unit, qardHasan }

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  static const String _modePrefsKey = 'calculator_mode_v1';
  static const Set<String> _sciFuncWrapKeys = {
    'sin',
    'cos',
    'tan',
    'ln',
    'log',
    '√'
  };
  static const Set<String> _memoryKeys = {'MC', 'MR', 'M+', 'M−', 'MS'};

  double? _memory;

  String _currentInput = '';
  String _displayExpression = '';
  String _result = '0';
  bool _isNewCalculation = true;
  _CalcMode _mode = _CalcMode.standard;
  final List<CalcStep> _steps = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPersistedMode();
    // One-time migration of the pre-Drift history (dead until invoked).
    unawaited(_dao.migrateFromLegacyIfNeeded());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  CalculatorDao get _dao => ref.read(calculatorDaoProvider);

  /// Restores the last used tool mode (standard/درصد/تخفیف/…).
  Future<void> _loadPersistedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_modePrefsKey);
      if (saved == null) return;
      for (final m in _CalcMode.values) {
        if (m.name == saved) {
          if (mounted) setState(() => _mode = m);
          return;
        }
      }
    } catch (_) {
      AppLogger.warning('calculator_screen', 'operation failed');
    }
  }

  Future<void> _saveMode(_CalcMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modePrefsKey, mode.name);
    } catch (_) {
      AppLogger.warning('calculator_screen', 'operation failed');
    }
  }

  void _onModeChanged(_CalcMode m) {
    setState(() => _mode = m);
    unawaited(_saveMode(m));
  }

  void _onButtonPressed(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (value == 'C') {
        _currentInput = '';
        _displayExpression = '';
        _result = '0';
        _steps.clear();
        _isNewCalculation = true;
      } else if (value == '⌫') {
        if (_currentInput.isNotEmpty) {
          _currentInput = _currentInput.substring(0, _currentInput.length - 1);
        }
      } else if (value == '=') {
        _calculate();
      } else if (value == '+/-') {
        if (_currentInput.startsWith('-')) {
          _currentInput = _currentInput.substring(1);
        } else if (_currentInput.isNotEmpty && _currentInput != '0') {
          _currentInput = '-$_currentInput';
        }
      } else if (value == '%') {
        if (_currentInput.isNotEmpty) {
          final num = double.tryParse(_currentInput);
          if (num != null) {
            _currentInput = (num / 100).toString();
          }
        }
      } else if (value == '(') {
        _currentInput += '(';
      } else if (value == ')') {
        _currentInput += ')';
      } else if (['+', '−', '×', '÷', '^', 'xʸ'].contains(value)) {
        if (_currentInput.isNotEmpty || _result != '0') {
          if (_isNewCalculation &&
              _result != '0' &&
              double.tryParse(_result) != null) {
            _currentInput = _result;
            _isNewCalculation = false;
          }
          String op = value;
          if (op == '−') op = '-';
          if (op == '×') op = '*';
          if (op == '÷') op = '/';
          if (op == 'xʸ') op = '^';
          _currentInput += op;
        }
      } else if (value == '.') {
        if (_isNewCalculation) {
          _currentInput = '0';
          _isNewCalculation = false;
        }
        if (!_currentInput.contains('.') || _isOperatorAtEnd()) {
          _currentInput += '.';
        }
      } else if (value == '00') {
        _currentInput += '00';
      } else if (_memoryKeys.contains(value)) {
        _handleMemory(value);
      } else if (_sciFuncWrapKeys.contains(value)) {
        final operand = _wrapTarget();
        if (operand != null) {
          final fn = value == '√' ? 'sqrt' : value;
          _currentInput = '$fn($operand)';
          _isNewCalculation = false;
        }
      } else if (value == 'x²') {
        final operand = _wrapTarget();
        if (operand != null) {
          _currentInput = '($operand)^2';
          _isNewCalculation = false;
        }
      } else if (value == 'x!') {
        final operand = _wrapTarget();
        if (operand != null) {
          _currentInput = '($operand)!';
          _isNewCalculation = false;
        }
      } else if (value == '1/x') {
        final operand = _wrapTarget();
        if (operand != null) {
          _currentInput = '1/($operand)';
          _isNewCalculation = false;
        }
      } else if (value == 'π' || value == 'e') {
        if (_isNewCalculation) {
          _currentInput = '';
          _isNewCalculation = false;
        }
        final canAppend = _currentInput.isEmpty ||
            _isOperatorAtEnd() ||
            _currentInput.endsWith('(');
        if (canAppend) _currentInput += value;
      } else {
        if (_isNewCalculation) {
          _currentInput = '';
          _isNewCalculation = false;
        }
        _currentInput += value;
      }
    });
  }

  List<List<String>> get _keypadRows {
    const memoryRow = ['MC', 'MR', 'M+', 'M−', 'MS'];
    const common = [
      ['C', '⌫', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '−'],
      ['1', '2', '3', '+'],
      ['(', '0', ')', '.'],
      ['='],
    ];
    if (_mode != _CalcMode.scientific) {
      return [memoryRow, ...common];
    }
    return [
      memoryRow,
      const ['sin', 'cos', 'tan', '√'],
      const ['x²', 'xʸ', 'x!', '1/x'],
      const ['π', 'e', '(', ')'],
      ...common,
    ];
  }

  Widget _buildKeypad({
    required Color accentColor,
    required Color textColor,
    required Color cardColor,
  }) {
    final rows = _keypadRows;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          _CalculatorRow(
            buttons: rows[i],
            onPressed: _onButtonPressed,
            accentColor: accentColor,
            textColor: textColor,
            cardColor: cardColor,
          ),
          if (i < rows.length - 1) const SizedBox(height: 6),
        ],
        const SizedBox(height: 8),
      ],
    );
    if (_mode != _CalcMode.scientific) return column;
    return Expanded(
      flex: 4,
      child: SingleChildScrollView(
        reverse: true,
        child: column,
      ),
    );
  }

  /// Blue-grey stays raw on light surfaces; dark mode needs a lightened
  /// variant for contrast — derived from the section accent, never restated.
  Color get _accentColor => Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(_calcAccent, Colors.white, 0.35) ?? _calcAccent
      : _calcAccent;

  void _showHistory() {
    // Held in a variable so the retry can replace the future and rebuild just
    // this sheet. The old failure row had no retry at all: the only way out of
    // a failed read was to close the sheet and open it again.
    var future = _dao.getHistory();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) =>
            FutureBuilder<List<CalculationRecord>>(
          future: future,
          builder: (context, snapshot) {
            // Distinguish loading and failure from an empty history, so the
            // «no history» message never flashes while the query is in flight
            // and a DB error is not silently shown as «empty».
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: FailureView(
                  id: 'calculator_history',
                  title: 'تاریخچهٔ محاسبه‌ها باز نشد',
                  detail:
                      'محاسبه‌های قبلی پاک نشده‌اند؛ فقط این فهرست خوانده نشد.',
                  onRetry: () =>
                      setSheetState(() => future = _dao.getHistory()),
                  error: snapshot.error,
                ),
              );
            }
            final history = snapshot.data ?? [];
            return HistorySheet(
              history: history,
              accentColor: _accentColor,
              onClear: () {
                Navigator.pop(context);
                _dao.clearHistory();
              },
              onSelect: (record) {
                Navigator.pop(context);
                setState(() {
                  var expr = record.expression
                      .replaceAll('×', '*')
                      .replaceAll('÷', '/')
                      .replaceAll('−', '-');
                  // Records saved before the tape-prefix fix carry the running
                  // total in front («0 11×5»). Keypad input never contains a
                  // space, so «digits space» at the start is always that
                  // prefix — drop it so recall evaluates what was shown.
                  final tape = RegExp(r'^-?\d+(?:\.\d+)? (?=.*[*+/\^])')
                      .firstMatch(expr);
                  if (tape != null) expr = expr.substring(tape.end);
                  _currentInput = expr;
                  _isNewCalculation = true;
                });
              },
              onDeleteItem: (record) {
                Navigator.pop(context);
                final id = record.id;
                if (id != null) _dao.removeRecord(id);
              },
            );
          },
        ),
      ),
    );
  }

  bool _isOperatorAtEnd() {
    if (_currentInput.isEmpty) return true;
    final last = _currentInput[_currentInput.length - 1];
    return last == '+' ||
        last == '-' ||
        last == '*' ||
        last == '/' ||
        last == '^';
  }

  /// The numeric value currently shown (typed number or last result).
  double? _currentValue() {
    final text = _currentInput.isNotEmpty ? _currentInput : _result;
    return double.tryParse(text);
  }

  /// The operand a unary science key acts on: the whole current expression
  /// when it ends on a value, otherwise the last computed result.
  String? _wrapTarget() {
    if (_currentInput.isNotEmpty) {
      if (_isOperatorAtEnd()) return null;
      return _currentInput;
    }
    if (!_isNewCalculation) return null;
    final r = double.tryParse(_result);
    return (r != null && r != 0) ? _result : null;
  }

  void _handleMemory(String key) {
    if (key == 'MC') {
      _memory = null;
      return;
    }
    if (key == 'MR') {
      final m = _memory;
      if (m != null) {
        _currentInput = CalculatorEngine.formatResult(m);
        _isNewCalculation = true;
      }
      return;
    }
    final v = _currentValue();
    if (v == null) return;
    if (key == 'M+') {
      _memory = (_memory ?? 0) + v;
    } else if (key == 'M−') {
      _memory = (_memory ?? 0) - v;
    } else if (key == 'MS') {
      _memory = v;
    }
  }

  void _calculate() {
    if (_currentInput.isEmpty) return;

    final result = CalculatorEngine.evaluate(_currentInput);
    if (result != null) {
      final formattedResult = CalculatorEngine.formatResult(result);
      final displayExpr = _currentInput
          .replaceAll('*', '×')
          .replaceAll('/', '÷')
          .replaceAll('-', '−');

      final lastStep = _steps.isNotEmpty ? _steps.last.result : '0';
      _steps.add(CalcStep('$lastStep $displayExpr', formattedResult));
      if (_steps.length > 30) {
        _steps.removeRange(0, _steps.length - 30);
      }
      _result = formattedResult;
      _displayExpression =
          _steps.map((s) => '${s.expression} = ${s.result}').join('\n');
      _currentInput = '';
      _isNewCalculation = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });

      _dao.addRecord(CalculationRecord(
        // The TAPE line («1105 ×3») is display-only: storing it here meant a
        // recalled record evaluated the stale running total as part of the
        // new expression — «1105*3» instead of «×3» chained onto it.
        expression: displayExpr,
        result: formattedResult,
        timestamp: DateTime.now(),
        isScientific: _mode == _CalcMode.scientific,
      ));
    } else {
      _result = 'خطا: عبارت نامعتبر';
      _isNewCalculation = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;
    final cardColor = t.card;
    final accentColor = _accentColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'ماشین حساب',
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            tooltip: 'تاریخچه',
            onPressed: _showHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              const SizedBox(height: 4),
              _ModeSwitcher(
                mode: _mode,
                accent: accentColor,
                onChanged: _onModeChanged,
              ),
              const SizedBox(height: 8),
              if (_mode != _CalcMode.standard && _mode != _CalcMode.scientific)
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: switch (_mode) {
                        _CalcMode.percent => PercentPanel(accent: accentColor),
                        _CalcMode.discount =>
                          DiscountPanel(accent: accentColor),
                        _CalcMode.age => AgePanel(accent: accentColor),
                        _CalcMode.qardHasan =>
                          QardHasanPanel(accent: accentColor),
                        _ => const UnitConverterView(),
                      },
                    ),
                  ),
                )
              else ...[
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    width: double.infinity,
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_memory != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'M',
                                  key: const ValueKey('memory_indicator'),
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 13),
                                  ),
                                ),
                              ),
                            ),
                          if (_displayExpression.isNotEmpty)
                            Expanded(
                              child: Scrollbar(
                                controller: _scrollController,
                                child: ListView(
                                  controller: _scrollController,
                                  children: _steps
                                      .map((step) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 4),
                                            child: Text(
                                              '${step.expression} = '
                                              '${NumberFormat.groupDigits(step.result)}',
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                fontSize:
                                                    AppTheme.scaledFontSize(
                                                        context, 14),
                                                color: mutedColor,
                                                fontFamily: AppTheme.fontFamily,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Text(
                            key: const ValueKey('calc_display'),
                            // Grouped for READING only: `_result` and
                            // `_currentInput` stay ungrouped, so the stored
                            // history and `double.tryParse` of the expression
                            // keep working. An expression is not a bare
                            // number, so groupDigits passes it through.
                            NumberFormat.groupDigits(_currentInput.isEmpty
                                ? _result
                                : _currentInput),
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 32),
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              fontFamily: AppTheme.fontFamily,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildKeypad(
                  accentColor: accentColor,
                  textColor: textColor,
                  cardColor: cardColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({
    required this.mode,
    required this.accent,
    required this.onChanged,
  });

  final _CalcMode mode;
  final Color accent;
  final ValueChanged<_CalcMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = TimeThemeKit.of(context).palette.textMuted;
    const entries = [
      (_CalcMode.standard, Icons.calculate_outlined, 'معمولی'),
      (_CalcMode.scientific, Icons.science_outlined, 'علمی'),
      (_CalcMode.percent, Icons.percent, 'درصد'),
      (_CalcMode.discount, Icons.sell_outlined, 'تخفیف'),
      (_CalcMode.age, Icons.cake_outlined, 'سن'),
      (_CalcMode.unit, Icons.swap_horiz, 'واحد'),
      (_CalcMode.qardHasan, Icons.request_quote_outlined, 'قسط قرض الحسنه'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final (m, icon, label) = entries[i];
          final selected = m == mode;
          return GestureDetector(
            onTap: () => onChanged(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: isDark ? 0.35 : 0.16)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03)),
                borderRadius: BorderRadius.circular(20),
                border: selected
                    ? Border.all(color: accent.withValues(alpha: 0.6))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: selected ? accent : mutedColor),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? accent : mutedColor,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalculatorRow extends StatelessWidget {
  final List<String> buttons;
  final Function(String) onPressed;
  final Color accentColor, textColor, cardColor;

  const _CalculatorRow({
    required this.buttons,
    required this.onPressed,
    required this.accentColor,
    required this.textColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: buttons.map((btn) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _CalcButton(
              label: btn,
              type: _getButtonType(btn),
              onTap: () => onPressed(btn),
              accentColor: accentColor,
              textColor: textColor,
              cardColor: cardColor,
            ),
          ),
        );
      }).toList(),
    );
  }

  ButtonType _getButtonType(String btn) {
    if (btn == 'C' ||
        btn == '⌫' ||
        btn == 'MC' ||
        btn == 'MR' ||
        btn == 'M+' ||
        btn == 'M−' ||
        btn == 'MS') {
      return ButtonType.function;
    }
    if (btn == '=') return ButtonType.equals;
    if ([
      ..._CalculatorScreenState._memoryKeys,
      '+',
      '−',
      '×',
      '÷',
      '%',
      '(',
      ')',
      '^',
      'xʸ',
      'sin',
      'cos',
      'tan',
      'ln',
      'log',
      '√',
      'x²',
      'x!',
      '1/x',
      'π',
      'e'
    ].contains(btn)) {
      return ButtonType.operator;
    }
    return ButtonType.number;
  }
}

enum ButtonType { number, operator, function, equals }

class _CalcButton extends StatefulWidget {
  final String label;
  final ButtonType type;
  final VoidCallback onTap;
  final Color accentColor, textColor, cardColor;

  const _CalcButton({
    required this.label,
    required this.type,
    required this.onTap,
    required this.accentColor,
    required this.textColor,
    required this.cardColor,
  });

  @override
  State<_CalcButton> createState() => _CalcButtonState();
}

class _CalcButtonState extends State<_CalcButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = _getBackgroundColor(isDark);
    final foregroundColor = _getForegroundColor(isDark);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 46,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(
                widget.type == ButtonType.equals ? 14 : 10),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: _getFontSize(),
                fontWeight: FontWeight.w600,
                color: foregroundColor,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getFontSize() {
    switch (widget.type) {
      case ButtonType.equals:
        return 22;
      case ButtonType.operator:
        return 20;
      case ButtonType.function:
        return 18;
      default:
        return 20;
    }
  }

  Color _getBackgroundColor(bool isDark) {
    switch (widget.type) {
      case ButtonType.number:
        return isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04);
      case ButtonType.operator:
        return widget.accentColor.withValues(alpha: 0.15);
      case ButtonType.function:
        return widget.accentColor.withValues(alpha: isDark ? 0.18 : 0.10);
      case ButtonType.equals:
        return Color.lerp(_calcAccent, Colors.black, 0.3) ?? _calcAccent;
    }
  }

  Color _getForegroundColor(bool isDark) {
    switch (widget.type) {
      case ButtonType.equals:
        return Colors.white;
      case ButtonType.operator:
        return widget.accentColor;
      case ButtonType.function:
        return widget.accentColor;
      default:
        return isDark ? Colors.white : Colors.black87;
    }
  }
}
