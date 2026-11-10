class NumberFormat {
  NumberFormat._();

  /// The ONE thousands separator the app prints and accepts.
  ///
  /// Latin digits are the product standard, and `intl` is banned in `lib`
  /// (see `test/core/utils/latin_digits_guard_test.dart`), so grouping is
  /// done here instead of by a locale-aware formatter.
  static const String thousandsSeparator = ',';

  /// Format number with comma separators: 4200000 → "4,200,000"
  ///
  /// A fractional amount keeps up to two decimals and its separators —
  /// `1234.5` → "1,234.5". The old fallback ran `toStringAsFixed(0)`, which
  /// both rounded the fraction away and dropped the grouping, so the same
  /// screen printed "12,346" for one row and "12346" for the row beside it.
  static String formatPlain(double value) {
    if (!value.isFinite) return '0';
    if (value.abs() >= 1e15) return value.toStringAsFixed(0);
    if (value == value.roundToDouble()) {
      final v = value.toInt();
      final isNeg = v < 0;
      return '${isNeg ? '-' : ''}${groupRun(v.abs().toString())}';
    }
    var fixed = value.toStringAsFixed(2);
    if (fixed.endsWith('0')) fixed = fixed.substring(0, fixed.length - 1);
    return groupDigits(fixed);
  }

  /// Groups a written number: "10000000" → "10,000,000".
  ///
  /// Forgiving by design, because it runs on text the user typed: Persian and
  /// Arabic-Indic digits are folded first and an existing separator is dropped,
  /// so feeding the output back through it is stable. Only the INTEGER run is
  /// grouped — a fraction ("1234.5678" → "1,234.5678") keeps its digits — and a
  /// leading minus is preserved. Anything that is not a bare number (an empty
  /// field, half-typed "12.", a word) comes back folded but otherwise untouched,
  /// so this can never mangle what it does not understand.
  static String groupDigits(String text) {
    final stripped = normalizeDigits(text).replaceAll(thousandsSeparator, '');
    final match = RegExp(r'^(-?)(\d+)(\.\d*)?$').firstMatch(stripped);
    if (match == null) return stripped;
    final intPart = match.group(2)!;
    if (intPart.length < 4) return stripped;
    return '${match.group(1)}${groupRun(intPart)}${match.group(3) ?? ''}';
  }

  /// Pads a run of ASCII digits out to groups of three from the right.
  /// The caller has already validated that [digits] holds only 0-9.
  static String groupRun(String digits) {
    if (digits.length < 4) return digits;
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(thousandsSeparator);
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// Format with Toman suffix
  static String formatToman(double value) {
    return '${formatPlain(value)} تومان';
  }

  /// Money with an explicit unit: "4,200,000 تومان" / "1,500 دلار".
  ///
  /// The single place that glues a number to a currency word, so a screen that
  /// lets the user choose the unit never has to concatenate one itself. An
  /// empty [unit] degrades to the bare number (the PDF layout's case).
  static String formatMoney(double value, String unit) {
    if (unit.isEmpty) return formatPlain(value);
    return '${formatPlain(value)} $unit';
  }

  /// Format with Gram suffix
  static String formatGram(double value) {
    if (value == value.roundToDouble()) {
      return '${grouped(value.toInt())} گرم';
    }
    return '${groupDigits(value.toStringAsFixed(1))} گرم';
  }

  /// Parse input string, normalizing Persian/Arabic digits (۰-۹, ٠-٩) and
  /// grouping/decimal separators (٬ , ٫) before parsing.
  static double parse(String text) {
    var s = text.trim();
    if (s.isEmpty) return 0;
    s = s.replaceAll('٬', ',').replaceAll('٫', '.');
    s = s.replaceAll(',', '');
    s = normalizeDigits(s);
    return double.tryParse(s) ?? 0;
  }

  /// Convert Persian (۰-۹) and Arabic-Indic (٠-٩) digits embedded in [text]
  /// to Latin (0-9), leaving all other characters untouched.
  static String normalizeDigits(String text) {
    var s = text;
    s = s.replaceAllMapped(
        RegExp(r'[۰-۹]'), (m) => '${m.group(0)!.codeUnitAt(0) - 0x06F0}');
    s = s.replaceAllMapped(
        RegExp(r'[٠-٩]'), (m) => '${m.group(0)!.codeUnitAt(0) - 0x0660}');
    return s;
  }

  /// Convert any Latin (0-9), Persian (۰-۹) or Arabic-Indic (٠-٩) digits
  /// embedded in [text] to Latin (0-9) for display — the product standard.
  /// Other characters pass through untouched (Persian-digit input from
  /// keypads still renders identically).
  static String toLatin(String text) => normalizeDigits(text);

  /// [toLatin] for numeric values — the common display case
  /// (counters, progress, dates).
  ///
  /// Deliberately UNGROUPED: this is what prints a year, a page, a verse and
  /// an age, and «۱,۴۰۱» is not a date — a four-digit year is every year this
  /// app shows. A quantity a person can grow large (money, an amount, a target)
  /// goes through [grouped] instead; do not group here.
  static String en(int value) => '$value';

  /// The grouped form of any number: 10000000 → "10,000,000", 1234.5 →
  /// "1,234.5".
  ///
  /// The display answer to «وقتی شماره می‌نویسم فاصله هزاری داشته باشد» for
  /// every quantity the app stores, without touching the [en] paths that
  /// print dates and indices. Integral doubles lose their ".0" first, so a
  /// value read back from a REAL column still prints as a plain count.
  static String grouped(num value) {
    if (value is int) return groupRun('$value');
    final d = value.toDouble();
    if (d.isNaN || d.isInfinite || d.abs() >= 1e15) return '$value';
    return groupDigits(d == d.roundToDouble() ? '${d.toInt()}' : '$d');
  }

  /// The ONE fraction formatter: "124 از 604".
  ///
  /// Each NUMBER is isolated, never the phrase. Isolating the whole
  /// "124 از 604" gives the run an LTR base, so in an RTL paragraph it lays
  /// out as 124 → از → 604 left-to-right; a Persian reading right-to-left
  /// then sees "604 از 124" — the reversed counters this formatter exists to
  /// prevent (measured with TextPainter, 2026-10-19). With the numbers
  /// isolated individually the phrase keeps the paragraph's own direction
  /// (124 at the right in RTL, at the left in LTR) and each digit run still
  /// cannot fuse with an adjacent RTL digit.
  ///
  /// Negative operands clamp to 0: a counter is never negative in Persian UI.
  static String fraction(int done, int total) => '${ltrIsolated(
          NumberFormat.en(done.clamp(0, 1 << 62)))} از ${ltrIsolated(
          NumberFormat.en(total.clamp(0, 1 << 62)))}';

  /// Signed integer with an explicit plus / TRUE MINUS (U+2212),
  /// LTR-isolated: "+2", "−5", "0".
  ///
  /// The bidi trap this closes: a bare "+0"/"-5" inside a Persian sentence
  /// is reordered by the bidi algorithm and reads as "0+"/"5-". The ASCII
  /// hyphen-minus is replaced by U+2212 so the sign is unambiguous, and the
  /// isolate keeps the run glued together in both RTL and LTR paragraphs.
  static String formatSigned(int value) {
    if (value == 0) return ltrIsolated('0');
    final sign = value > 0 ? '+' : '−';
    return ltrIsolated('$sign${value.abs()}');
  }

  /// Degrees, LTR-isolated: `formatDegrees(18)` → "18°".
  ///
  /// Integral values drop the ".0" (`18.0` → "18°"); the degree sign stays
  /// inside the isolate so "18°" can never mirror into "°18" in RTL text.
  static String formatDegrees(num value) {
    final digits =
        value is int || value == value.roundToDouble() ? '${value.round()}' : '$value';
    return ltrIsolated('$digits°');
  }

  /// Minutes with the Persian unit OUTSIDE the isolate: "5 دقیقه".
  ///
  /// The unit is a Persian word and must stay in the RTL run — only the
  /// number itself is isolated.
  static String formatMinutes(int value) => '${ltrIsolated('$value')} دقیقه';

  /// Human-readable byte size, LTR-isolated: "330.2MB", "0KB".
  ///
  /// Same rounding the account page's cloud-backup list uses, so one size
  /// never reads differently on two screens.
  static String formatBytes(int bytes) {
    final String value;
    final String unit;
    if (bytes <= 0) {
      value = '0';
      unit = 'KB';
    } else if (bytes < 1048576) {
      value = (bytes / 1024).toStringAsFixed(0);
      unit = 'KB';
    } else if (bytes < 1073741824) {
      value = (bytes / 1048576).toStringAsFixed(1);
      unit = 'MB';
    } else {
      value = (bytes / 1073741824).toStringAsFixed(1);
      unit = 'GB';
    }
    // The number is grouped BEFORE the unit is glued on: a downloaded Quran
    // bundle passes 1,000 MB, and «1024.0MB» is exactly the un-grouped figure
    // the app no longer prints anywhere.
    return ltrIsolated('${groupDigits(value)}$unit');
  }

  /// Wraps [text] in a Unicode left-to-right isolate (U+2066 … U+2069):
  /// invisible marks that stop surrounding RTL text from reordering a
  /// digit run. The single place that knows the isolate characters.
  /// Written as escapes, not literal marks, so the source stays diffable.
  static String ltrIsolated(String text) => '\u2066$text\u2069';
}
