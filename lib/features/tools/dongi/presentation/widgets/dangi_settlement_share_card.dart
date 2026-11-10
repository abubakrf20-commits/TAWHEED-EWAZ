import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_report.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/tools/dongi/presentation/dangi_colors.dart';

/// Paper-style settlement summary, rendered offscreen and shared as an image.
/// Keeps its own light palette so the picture looks good on any chat app.
class DangiSettlementShareCard extends StatelessWidget {
  const DangiSettlementShareCard({
    super.key,
    required this.groupName,
    required this.members,
    required this.transfers,
    required this.total,
  });

  final String groupName;
  final List<DangiMemberModel> members;
  final List<SettlementTransfer> transfers;
  final double total;

  static const Color _paper = DangiSettlementPalette.paper;
  static const Color _ink = DangiSettlementPalette.ink;
  static const Color _muted = DangiSettlementPalette.muted;
  static const Color _accent = TopicHues.dangi;
  static const Color _accentDark = DangiSettlementPalette.accentDark;
  static const Color _green = AppTheme.success;

  String _name(String id) =>
      members.where((m) => m.id == id).firstOrNull?.name ?? id;

  /// First letter of a member name, used for the avatar badge.
  String _initial(String name) =>
      name.isEmpty ? '؟' : String.fromCharCode(name.runes.first);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _paper,
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const SizedBox(height: 22),
          if (members.isNotEmpty) ...[
            _memberChips(context, ),
            const SizedBox(height: 18),
          ],
          if (transfers.isEmpty)
            _settledCard(context, )
          else ...[
            _sectionTitle(context, 'پیشنهاد تسویه'),
            const SizedBox(height: 10),
            for (var i = 0; i < transfers.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _transferRow(context, transfers[i]),
            ],
          ],
          const SizedBox(height: 24),
          const Divider(color: _muted, thickness: 1),
          const SizedBox(height: 12),
          _footer(context, ),
        ],
      ),
    );
  }

  // ── Header band ────────────────────────────────────────────────────
  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_accent, _accentDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.people_alt_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تسویهٔ هزینه‌ها',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTheme.scaledFontSize(context, 21),
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Vazirmatn',
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'گروه: $groupName',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.25), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'مجموع هزینه‌ها',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontFamily: 'Vazirmatn',
                ),
              ),
              const Spacer(),
              Text(
                faMoney(total),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppTheme.scaledFontSize(context, 21),
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Member chips ───────────────────────────────────────────────────
  Widget _memberChips(BuildContext context, ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اعضای گروه (${members.length})',
          style: TextStyle(
            color: _muted,
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: FontWeight.w600,
            fontFamily: 'Vazirmatn',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in members)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _avatar(context, _initial(m.name), _accent),
                    const SizedBox(width: 8),
                    Text(
                      m.name,
                      style: TextStyle(
                        color: _ink,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: _ink,
            fontSize: AppTheme.scaledFontSize(context, 14),
            fontWeight: FontWeight.w700,
            fontFamily: 'Vazirmatn',
          ),
        ),
      ],
    );
  }

  // ── Transfer rows ──────────────────────────────────────────────────
  Widget _transferRow(BuildContext context, SettlementTransfer t) {
    final from = _name(t.fromId);
    final to = _name(t.toId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _avatar(context, _initial(from), _accent),
          const SizedBox(width: 10),
          Text(
            from,
            style: TextStyle(
              color: _ink,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w700,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, color: _accent.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            to,
            style: TextStyle(
              color: _ink,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w600,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              faMoney(t.amount),
              style: TextStyle(
                color: _accentDark,
                fontSize: AppTheme.scaledFontSize(context, 16),
                fontWeight: FontWeight.w800,
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, String initial, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontSize: AppTheme.scaledFontSize(context, 15),
          fontWeight: FontWeight.w800,
          fontFamily: 'Vazirmatn',
        ),
      ),
    );
  }

  // ── All-settled state ──────────────────────────────────────────────
  Widget _settledCard(BuildContext context, ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DangiSettlementPalette.settledBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'همه چیز تسویه است — بدهی‌ای نیست!',
              style: TextStyle(
                color: _ink,
                fontSize: AppTheme.scaledFontSize(context, 15),
                fontWeight: FontWeight.w700,
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────
  Widget _footer(BuildContext context, ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration:
              const BoxDecoration(color: _accent, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            'ت',
            style: TextStyle(
              color: Colors.white,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w800,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'ساخته شده با برنامهٔ توحید',
          style: TextStyle(
            color: _muted,
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontFamily: 'Vazirmatn',
          ),
        ),
      ],
    );
  }
}
