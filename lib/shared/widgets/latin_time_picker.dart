import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// The app's ONE time-entry dialog — Latin digits, by construction.
///
/// Material's `showTimePicker` cannot be used anywhere: the app pins
/// `Locale('fa')`, so its dial and its text input are formatted with Persian
/// digits, and its text mode parses with a plain `int.tryParse` — a typed
/// «۲۱:۳۰» is refused as «زمان معتبری وارد نکردی». Here the field folds
/// ۰-۹/٠-٩ to ASCII as the user types, so a Persian keyboard still produces
/// Latin digits and a valid time.
Future<TimeOfDay?> showLatinTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  String title = 'ساعت',
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (_) => LatinTimePickerDialog(
      initialTime: initialTime,
      title: title,
    ),
  );
}

/// A StatefulWidget so the two controllers die exactly with the dialog, after
/// its close animation — not with the caller's `await`.
class LatinTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;

  const LatinTimePickerDialog(
      {super.key, required this.initialTime, this.title = 'ساعت'});

  @override
  State<LatinTimePickerDialog> createState() => _LatinTimePickerDialogState();
}

class _LatinTimePickerDialogState extends State<LatinTimePickerDialog> {
  late final TextEditingController _hourCtrl =
      TextEditingController(text: '${widget.initialTime.hour}');
  late final TextEditingController _minuteCtrl =
      TextEditingController(text: '${widget.initialTime.minute}');
  String _hourError = '';
  String _minuteError = '';

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final h = int.tryParse(_hourCtrl.text);
    final m = int.tryParse(_minuteCtrl.text);
    final hourOk = h != null && h >= 0 && h <= 23;
    final minuteOk = m != null && m >= 0 && m <= 59;
    setState(() {
      _hourError = hourOk ? '' : '0 تا 23';
      _minuteError = minuteOk ? '' : '0 تا 59';
    });
    if (hourOk && minuteOk) {
      Navigator.pop(context, TimeOfDay(hour: h, minute: m));
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String error,
  }) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          const _LatinDigitsFormatter(),
          LengthLimitingTextInputFormatter(2),
        ],
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 18),
        ),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          errorText: error.isEmpty ? null : error,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 18),
        ),
      ),
      content: Row(
        children: [
          _field(controller: _hourCtrl, label: 'ساعت', error: _hourError),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              ':',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 26),
                  fontWeight: FontWeight.bold),
            ),
          ),
          _field(controller: _minuteCtrl, label: 'دقیقه', error: _minuteError),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('لغو')),
        FilledButton(onPressed: _submit, child: const Text('تأیید')),
      ],
    );
  }
}

/// Keeps the field digits-only and Latin: every typed ۰-۹/٠-٩ is folded to
/// ASCII before it reaches the field, and anything that is not a digit is
/// dropped. The caret stays at the end (the field holds at most two chars).
class _LatinDigitsFormatter extends TextInputFormatter {
  const _LatinDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = NumberFormat.normalizeDigits(newValue.text)
        .replaceAll(RegExp(r'[^0-9]'), '');
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
