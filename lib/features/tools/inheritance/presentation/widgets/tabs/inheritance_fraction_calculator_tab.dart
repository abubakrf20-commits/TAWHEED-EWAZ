import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/inheritance/domain/fraction_math.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_palette.dart';

/// حاسبة الكسور — fraction calculator inside the میراث section.
///
/// Rebuilt to mirror the 7 tools of almwareeth.com/tools/fraction-farsi:
/// ک.م.م، جمع، تفریق، ضرب، تقسیم، ساده‌سازی و تبدیل به اعشار — هر کدام با
/// پذیرش چند کسر (تا 20) که با فاصله از هم جدا می‌شوند.
class InheritanceFractionCalculatorTab extends StatefulWidget {
  const InheritanceFractionCalculatorTab({super.key});

  @override
  State<InheritanceFractionCalculatorTab> createState() =>
      _InheritanceFractionCalculatorTabState();
}

class _InheritanceFractionCalculatorTabState
    extends State<InheritanceFractionCalculatorTab> {
  static const _accentLight =
      InheritancePalette.accent; // بنفش — هماهنگ با تب‌های میراث
  static const _accentDark = InheritancePalette.accentDark;

  final _lcm = TextEditingController();
  final _add = TextEditingController();
  final _sub = TextEditingController();
  final _mul = TextEditingController();
  final _div = TextEditingController();
  final _simplify = TextEditingController();
  final _decimal = TextEditingController();

  String? _error;

  // ── Results ─────────────────────────────────────────────────────────
  (List<int>, int)? _lcmOut;
  NFractionOpResult? _addResult;
  NFractionOpResult? _subResult;
  NFractionOpResult? _mulResult;
  NFractionOpResult? _divResult;
  List<(String, FractionSimplifyResult)>? _simplifyResults;
  List<(String, String)>? _decimalResults;

  @override
  void dispose() {
    _lcm.dispose();
    _add.dispose();
    _sub.dispose();
    _mul.dispose();
    _div.dispose();
    _simplify.dispose();
    _decimal.dispose();
    super.dispose();
  }

  Color get _accent => Theme.of(context).brightness == Brightness.dark
      ? _accentDark
      : _accentLight;

  // ── Parsing / actions ────────────────────────────────────────────────

  String _term((int, int) f) => f.$2 == 1 ? '${f.$1}' : '${f.$1}/${f.$2}';

  String _fracText(int n, int d) => d == 1 ? '$n' : '$n/$d';

  void _calcLcm() {
    setState(() {
      _error = null;
      _lcmOut = null;
      final nums = parseIntegerInput(_lcm.text);
      if (nums == null || nums.isEmpty) {
        _error = 'اعداد صحیح را با فاصله بنویسید — مثال: 4 6 8';
        return;
      }
      if (nums.any((n) => n <= 0)) {
        _error = 'اعداد باید مثبت باشند.';
        return;
      }
      _lcmOut = (nums, lcmOfAll(nums));
    });
  }

  void _runOp(
    FractionOp op,
    TextEditingController c,
    void Function(NFractionOpResult?) assign,
  ) {
    setState(() {
      _error = null;
      assign(null);
      final fs = parseFractionInput(c.text);
      if (fs == null || fs.isEmpty) {
        _error = 'کسرها را با فاصله بنویسید — مثال: 1/3 1/2';
        return;
      }
      if ((op == FractionOp.sub || op == FractionOp.div) && fs.length < 2) {
        _error = 'برای «${op.label}» دستکم دو کسر بنویسید.';
        return;
      }
      final r = applyFractions(fs, op);
      if (r == null) {
        _error = 'تقسیم بر صفر مجاز نیست.';
        return;
      }
      assign(r);
    });
  }

  void _calcSimplify() {
    setState(() {
      _error = null;
      _simplifyResults = null;
      final fs = parseFractionInput(_simplify.text);
      if (fs == null || fs.isEmpty) {
        _error = 'کسرها را با فاصله بنویسید — مثال: 8/12 10/4';
        return;
      }
      _simplifyResults = [
        for (final f in fs) (_term(f), simplifyFraction(f.$1, f.$2)),
      ];
    });
  }

  void _calcDecimal() {
    setState(() {
      _error = null;
      _decimalResults = null;
      final fs = parseFractionInput(_decimal.text);
      if (fs == null || fs.isEmpty) {
        _error = 'کسرها را با فاصله بنویسید — مثال: 1/3 3/4';
        return;
      }
      _decimalResults = [
        for (final f in fs) (_term(f), fractionDecimal(f.$1, f.$2)),
      ];
    });
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        _headerCard(),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _errorCard(),
        ],
        const SizedBox(height: 14),
        _toolCard(
          icon: Icons.gps_fixed,
          title: 'ک.م.م — کوچک‌ترین مضرب مشترک',
          subtitle:
              'کوچک‌ترین مضرب مشترک دو یا چند عدد صحیح — برای یافتن اصل مسئلهٔ فرائض.',
          field: _lcm,
          hint: 'بین اعداد فاصله بگذارید — مثال: 4 6 8',
          buttonLabel: 'حساب ک.م.م',
          buttonIcon: Icons.hub_outlined,
          onPressed: _calcLcm,
          results: _lcmOut == null ? null : _lcmPanel(_lcmOut!),
        ),
        const SizedBox(height: 14),
        _toolCard(
          icon: Icons.add,
          title: 'جمع کسرها',
          subtitle:
              'جمع دو یا چند کسر. عدد صحیح مانند 3 را به صورت 3/1 بنویسید.',
          field: _add,
          hint: 'بین کسرها فاصله بگذارید — مثال: 1/3 1/2',
          buttonLabel: 'جمع کن',
          buttonIcon: Icons.functions,
          onPressed: () => _runOp(FractionOp.add, _add, (r) => _addResult = r),
          results: _addResult == null ? null : _opPanel(_addResult!),
        ),
        const SizedBox(height: 14),
        _toolCard(
          icon: Icons.remove,
          title: 'تفریق کسرها',
          subtitle: 'کسر اول از کسرهای بعدی کم می‌شود؛ مثال: 3/4 1/2.',
          field: _sub,
          hint: 'بین کسرها فاصله بگذارید — مثال: 3/4 1/2',
          buttonLabel: 'تفریق کن',
          buttonIcon: Icons.functions,
          onPressed: () => _runOp(FractionOp.sub, _sub, (r) => _subResult = r),
          results: _subResult == null ? null : _opPanel(_subResult!),
        ),
        const SizedBox(height: 14),
        _toolCard(
          icon: Icons.close,
          title: 'ضرب کسرها',
          subtitle: 'ضرب چند کسر در هم؛ مثال: 2/3 3/4.',
          field: _mul,
          hint: 'بین کسرها فاصله بگذارید — مثال: 2/3 3/4',
          buttonLabel: 'ضرب کن',
          buttonIcon: Icons.functions,
          onPressed: () => _runOp(FractionOp.mul, _mul, (r) => _mulResult = r),
          results: _mulResult == null ? null : _opPanel(_mulResult!),
        ),
        const SizedBox(height: 14),
        _toolCard(
          icon: Icons.horizontal_split,
          title: 'تقسیم کسرها',
          subtitle: 'کسر اول بر کسرهای بعدی تقسیم می‌شود؛ مثال: 3/4 1/2.',
          field: _div,
          hint: 'بین کسرها فاصله بگذارید — مثال: 3/4 1/2',
          buttonLabel: 'تقسیم کن',
          buttonIcon: Icons.functions,
          onPressed: () => _runOp(FractionOp.div, _div, (r) => _divResult = r),
          results: _divResult == null ? null : _opPanel(_divResult!),
        ),
        const SizedBox(height: 14),
        _toolCard(
          icon: Icons.compress,
          title: 'ساده‌سازی کسرها',
          subtitle:
              'ساده‌سازی یک یا چند کسر به کوچک‌ترین مخرج با نشان دادن ب.م.م.',
          field: _simplify,
          hint: 'بین کسرها فاصله بگذارید — مثال: 8/12 10/4',
          buttonLabel: 'ساده کن',
          buttonIcon: Icons.auto_fix_high,
          onPressed: _calcSimplify,
          results: _simplifyResults == null
              ? null
              : _simplifyPanel(_simplifyResults!),
        ),
        const SizedBox(height: 14),
        _toolCard(
          icon: Icons.percent,
          title: 'تبدیل کسر به عدد اعشاری',
          subtitle: 'نمایش یک یا چند کسر به صورت اعشاری؛ مثال: 1/3 3/4.',
          field: _decimal,
          hint: 'بین کسرها فاصله بگذارید — مثال: 1/3 3/4',
          buttonLabel: 'به اعشار تبدیل کن',
          buttonIcon: Icons.currency_bitcoin,
          onPressed: _calcDecimal,
          results:
              _decimalResults == null ? null : _decimalPanel(_decimalResults!),
        ),
        const SizedBox(height: 14),
        _footerNote(),
      ],
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.calculate_outlined, size: 20, color: _accent),
              ),
              const SizedBox(width: 10),
              Text(
                'ماشین حساب کسرها',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'هفت ابزار کمکی متخصصان فرائض: ک.م.م، جمع، تفریق، ضرب، تقسیم، '
            'ساده‌سازی و تبدیل به اعشار — هر کدام با وارد کردن تا 20 کسر '
            '(به صورت «1/3 1/2») به فاصله از هم.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              color: TimeThemeKit.of(context).palette.textSecondary,
              height: 1.8,
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }

  Widget _footerNote() {
    return Text(
      'به الگوی «ماشین حساب کسرها» — سایت مواریث '
      '(almwareeth.com) ساخته شده است.',
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, 11.5),
        color: TimeThemeKit.of(context).palette.textSecondary.withValues(alpha: 0.8),
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: FontWeight.w700,
              color: TimeThemeKit.of(context).palette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }

  Widget _toolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required TextEditingController field,
    required String hint,
    required String buttonLabel,
    required IconData buttonIcon,
    required VoidCallback onPressed,
    Widget? results,
  }) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(icon, title),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: TimeThemeKit.of(context).palette.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: field,
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9/\s-]')),
            ],
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: TimeThemeKit.of(context).palette.textSecondary.withValues(alpha: 0.6),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _accent, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onPressed,
              icon: Icon(buttonIcon),
              label: Text(buttonLabel),
            ),
          ),
          if (results != null) ...[
            const SizedBox(height: 14),
            results,
          ],
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: TimeThemeKit.of(context).palette.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: FontWeight.w800,
              color: _accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mathLine(String text, {bool bold = false}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Text(
          text,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 14),
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: bold ? _accent : TimeThemeKit.of(context).palette.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _lcmPanel((List<int>, int) out) {
    final (nums, l) = out;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        _mathLine('ک.م.م(${nums.join('، ')}) = $l', bold: true),
      ],
    );
  }

  Widget _opPanel(NFractionOpResult r) {
    final symbol = switch (r.op) {
      FractionOp.add => '+',
      FractionOp.sub => '−',
      FractionOp.mul => '×',
      FractionOp.div => '÷',
    };
    String terms() {
      if (r.op == FractionOp.sub) {
        return [r.scaledNs.first, for (final s in r.scaledNs.skip(1)) s]
            .asMap()
            .entries
            .map((e) => '${e.value}/${r.commonDen}')
            .join(' − ');
      }
      if (r.op == FractionOp.add) {
        return r.scaledNs.map((s) => '$s/${r.commonDen}').join(' + ');
      }
      return r.inputs.map(_term).join(' $symbol ');
    }

    final raw = _fracText(r.rawN, r.rawD);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.op == FractionOp.add || r.op == FractionOp.sub) ...[
          const SizedBox(height: 6),
          _mathLine(
              'مخرج مشترک = ک.م.م(${r.inputs.map((f) => f.$2).join('، ')}) = ${r.commonDen}'),
          const SizedBox(height: 6),
        ],
        if (r.gcd > 1 || raw != r.simplified)
          _mathLine('${terms()} = $raw = ${r.simplified}  (ب.م.م ${r.gcd})',
              bold: true)
        else
          _mathLine('${terms()} = $raw', bold: true),
        const SizedBox(height: 10),
        _resultTile('کسر ساده‌شده', r.simplified),
        const SizedBox(height: 8),
        _resultTile('عدد مخلوط', r.mixed),
        const SizedBox(height: 8),
        _resultTile('اعشاری', r.decimal),
      ],
    );
  }

  Widget _simplifyPanel(List<(String, FractionSimplifyResult)> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _resultTile(
            rows[i].$1,
            '${rows[i].$2.simplifiedN}/${rows[i].$2.simplifiedD}'
            '  (ب.م.م ${rows[i].$2.gcd})',
          ),
        ],
      ],
    );
  }

  Widget _decimalPanel(List<(String, String)> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _resultTile(rows[i].$1, rows[i].$2),
        ],
      ],
    );
  }
}
