import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/inheritance/domain/fraction_math.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_palette.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

/// ماشین حساب سهام — السهام في مسائل الفرائض.
///
/// أصل المسألة = ک.م.م مخرج‌های فرض‌ها؛ سهام هر وارث = کسرش × اصل؛ اگر مجموع
/// سهام از اصل بگذرد عول می‌شود (اصل به مجموع تصحیح می‌شود) و اگر کمتر باشد
/// ردّ می‌شود (باقی‌مانده به نسبت سهم‌ها برمی‌گردد). ابزار مستقل همگام با
/// almwareeth.com/tools/almwareeth-faraed.
class InheritanceSharesCalculatorTab extends StatefulWidget {
  const InheritanceSharesCalculatorTab({super.key});

  @override
  State<InheritanceSharesCalculatorTab> createState() =>
      _InheritanceSharesCalculatorTabState();
}

class _InheritanceSharesCalculatorTabState
    extends State<InheritanceSharesCalculatorTab> {
  static const _accentLight =
      InheritancePalette.accent; // بنفش — هماهنگ با تب‌های میراث
  static const _accentDark = InheritancePalette.accentDark;

  final _fractions = TextEditingController();
  final _estate = TextEditingController();

  String? _error;
  SharesCalculationResult? _result;

  Color get _accent => Theme.of(context).brightness == Brightness.dark
      ? _accentDark
      : _accentLight;

  @override
  void dispose() {
    _fractions.dispose();
    _estate.dispose();
    super.dispose();
  }

  String _term((int, int) f) => f.$2 == 1 ? '${f.$1}' : '${f.$1}/${f.$2}';

  String _number(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write('‌');
      out.write(s[i]);
    }
    return out.toString();
  }

  void _calc() {
    setState(() {
      _error = null;
      _result = null;
      final fs = parseFractionInput(_fractions.text);
      if (fs == null || fs.isEmpty) {
        _error = 'فرض‌ها را با فاصله بنویسید — مثال: 1/2 1/6 1/3';
        return;
      }
      double? estate;
      final estateText = _estate.text.trim();
      if (estateText.isNotEmpty) {
        // The field prints «6,000» while it is typed
        // (`LatinGroupingFormatter`), so the grouping is dropped here before
        // the strict integer read — a sign or a fraction still fails.
        final v = int.tryParse(estateText.replaceAll(',', ''));
        if (v == null || v < 0) {
          _error = 'مبلغ ترکه را فقط به عدد (بدون علامت) بنویسید.';
          return;
        }
        estate = v.toDouble();
      }
      final r = calculateShares(fs);
      if (r.totalShares <= 0) {
        _error = 'مجموع سهام صفر شد؛ کسرهای مثبت بنویسید.';
        return;
      }
      _result = SharesCalculationResult(
        asl: r.asl,
        fractions: r.fractions,
        shares: r.shares,
        totalShares: r.totalShares,
        mode: r.mode,
        correctedAsl: r.correctedAsl,
      );
      _resultEstate = estate;
    });
  }

  double? _resultEstate;

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
        _toolCard(),
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
                child: Icon(Icons.pie_chart_outline, size: 20, color: _accent),
              ),
              const SizedBox(width: 10),
              Text(
                'ماشین حساب سهام',
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
            'ابزار تخصصی اهل فرائض برای یافتن اصل مسئله و سهام هر وارث: '
            'اصل مسئله = ک.م.م مخرج‌های فرض‌ها، سهام هر وارث = کسرِ او × اصل. '
            'اگر مجموع سهام از اصل بگذرد «عول» رخ می‌دهد (اصل به مجموع تصحیح '
            'می‌شود) و اگر کمتر باشد «ردّ» (باقی‌مانده به نسبت سهم‌ها برمی‌گردد).',
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
      'به الگوی «ماشین حساب سهام» — سایت مواریث (almwareeth.com) ساخته شده است. '
      'برای تقسیم کامل با در نظر گرفتن حجب، همسر و قرابت‌ها از تب «محاسبه» استفاده کنید.',
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, 11.5),
        color: TimeThemeKit.of(context).palette.textSecondary.withValues(alpha: 0.8),
      ),
      textAlign: TextAlign.center,
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

  Widget _toolCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.pie_chart_outline, 'محاسبهٔ سهام'),
          const SizedBox(height: 8),
          Text(
            'فرض‌ها را با فاصله بنویسید (تا 20 کسر)، مثل مسائل کتاب فرائض. '
            'عدد صحیح مانند 3 را به صورت 3/1 بنویسید. مثال: 1/2 1/6 1/3',
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
            controller: _fractions,
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
              labelText: 'فرض‌ها',
              hintText: '1/2 1/6 1/3',
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
          TextField(
            controller: _estate,
            keyboardType: TextInputType.number,
            inputFormatters: const [LatinGroupingFormatter()],
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'مبلغ ترکه (اختیاری)',
              hintText: 'مثلاً 240000',
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
              onPressed: _calc,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('حساب سهام'),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            _resultPanel(_result!, _resultEstate),
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

  Widget _resultTile(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: TimeThemeKit.of(context).palette.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: FontWeight.w800,
              color: valueColor ?? _accent,
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

  Widget _resultPanel(SharesCalculationResult r, double? estate) {
    final denoms = r.fractions.map((f) => f.$2).join('، ');
    final estateGiven = estate != null && estate > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        _mathLine('اصل مسأله = ک.م.م($denoms) = ${r.asl}', bold: true),
        const SizedBox(height: 10),
        for (var i = 0; i < r.fractions.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _resultTile(
            'فرض ${_term(r.fractions[i])}',
            estateGiven
                ? 'سهام: ${_number(r.shares[i])}   مبلغ: ${_number((estate * r.shares[i] / r.totalShares).round())}'
                : 'سهام: ${_number(r.shares[i])}',
          ),
        ],
        const SizedBox(height: 8),
        _resultTile('مجموع سهام', _number(r.totalShares)),
        const SizedBox(height: 8),
        _resultTile(
          switch (r.mode) {
            'awl' => 'عول',
            'radd' => 'ردّ',
            _ => 'عادی',
          },
          r.mode == 'awl'
              ? 'اصل تصحیح‌شده = ${_number(r.correctedAsl)} (کسر هر سهم: ${_number(r.shares.first)}/${_number(r.correctedAsl)}…)'
              : 'اصل تصحیح‌شده = ${_number(r.correctedAsl)}',
        ),
        const SizedBox(height: 10),
        Text(
          switch (r.mode) {
            'awl' =>
              'عول: مجموع سهام (${_number(r.totalShares)}) از اصل مسأله (${_number(r.asl)}) بیشتر بود؛ '
                  'طبق قاعدهٔ «عول» اصل به ${_number(r.totalShares)} تصحیح شد و هر سهم به همان نسبت کاهش یافت.',
            'radd' =>
              'ردّ: مجموع سهام (${_number(r.totalShares)}) از اصل مسأله (${_number(r.asl)}) کمتر بود؛ '
                  'باقی‌مانده (${_number(r.asl - r.totalShares)}) به نسبت سهم‌ها به فرض‌داران برگردانده شد. '
                  'توجه: اگر همسر (زوج/زوجه) در میان وراث باشد، در ردّ سهم او شامل افزایش نمی‌شود.',
            _ =>
              'مجموع سهام برابر اصل مسأله است؛ تقسیم عادی بدون عول و بدون ردّ.',
          },
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: TimeThemeKit.of(context).palette.textSecondary,
            height: 1.7,
          ),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }
}
