import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/riyad/services/riyad_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/inline_footnotes.dart';

// ═══════════════════════════════════════════════════════════════
//  مقدمه‌های جلد نخست — درآمدی بر کتاب، دو زندگینامه و مقدمه‌ی مؤلف.
//  این‌ها حدیث نیستند، پس در فهرست باب‌ها نمی‌آیند؛ از ردیف «مقدمه‌ها»ی
//  همان صفحه خوانده می‌شوند و پانوشت هر بند زیرِ خودش می‌آید.
// ═══════════════════════════════════════════════════════════════

class RiyadIntroScreen extends StatefulWidget {
  const RiyadIntroScreen({
    super.key,
    required this.sections,
    this.service,
  });

  /// The `matter_sections` rows the فهرست already loaded.
  final List<Map<String, dynamic>> sections;

  /// Test seam: the caller's service, so a widget test can drive a fake
  /// database without the download flow.
  @visibleForTesting
  final RiyadService? service;

  @override
  State<RiyadIntroScreen> createState() => _RiyadIntroScreenState();
}

class _RiyadIntroScreenState extends State<RiyadIntroScreen> {
  late final RiyadService _service = widget.service ?? RiyadService();

  /// section id → (its paragraphs, notes keyed by the paragraph they mark)
  final Map<int, List<Map<String, dynamic>>> _paragraphs = {};
  final Map<int, int> _counts = {};
  final Map<int, Map<int, List<Map<String, dynamic>>>> _notes = {};

  /// The thrown object, not its text: the panel renders it in debug builds
  /// only, so a reader never meets a table name where an explanation belongs.
  Object? _error;

  static const _accent = TopicHues.riyad;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // A retry must clear the previous failure before it starts, or the panel
    // stays on screen on top of the loading state it was replaced by.
    if (_error != null) setState(() => _error = null);
    try {
      await _service.ensureReady();
      final counts = await _service.matterParagraphCounts();
      if (!mounted) return;
      setState(() => _counts.addAll(counts));
      for (final section in widget.sections) {
        final id = (section['id'] as num).toInt();
        final paragraphs = await _service.matterParagraphs(id);
        final notes = <int, List<Map<String, dynamic>>>{};
        for (final note in await _service.footnotesOfSection(id)) {
          final order = (note['source_para'] as num?)?.toInt();
          if (order == null) continue;
          (notes[order] ??= []).add(note);
        }
        if (!mounted) return;
        setState(() {
          _paragraphs[id] = paragraphs;
          _notes[id] = notes;
        });
      }
    } catch (e) {
      AppLogger.warning('riyad_intro_screen', 'error: $e');
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'مقدمه‌های ریاض الصالحین'),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return FailureView(
        id: 'riyad_intro_load',
        title: 'مقدمه‌ها باز نشدند',
        detail: 'متن از پایگاه‌دادهٔ خودِ کتاب خوانده می‌شود و جایی نرفته است؛ '
            'این صفحه فقط نتوانست بخواندش.',
        onRetry: _load,
        layout: FailureLayout.page,
        error: _error,
      );
    }
    if (_paragraphs.length < widget.sections.length) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 14, DsSpacing.page, 28),
      children: [
        for (final section in widget.sections)
          ..._buildSection(context, section),
      ],
    );
  }

  List<Widget> _buildSection(
      BuildContext context, Map<String, dynamic> section) {
    final id = (section['id'] as num).toInt();
    final paragraphs = _paragraphs[id] ?? const <Map<String, dynamic>>[];
    final notes = _notes[id] ?? const <int, List<Map<String, dynamic>>>{};
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Text(
          (section['title'] ?? '') as String,
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w800,
              color: _accent),
        ),
      ),
      for (final p in paragraphs)
        _paragraph(
          context,
          ((p['arabic'] ?? '') as String).trim(),
          notes[(p['para_order'] as num?)?.toInt()] ?? const [],
        ),
      const Divider(height: 26, thickness: .6),
    ];
  }

  Widget _paragraph(
      BuildContext context, String text, List<Map<String, dynamic>> notes) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(
            text,
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                height: 1.95),
          ),
          if (notes.isNotEmpty)
            InlineFootnotes(footnotes: notes, accent: _accent),
        ],
      ),
    );
  }
}
