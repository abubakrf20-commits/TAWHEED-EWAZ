import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/maalim/services/maalim_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/inline_footnotes.dart';

// ═══════════════════════════════════════════════════════════════
//  مقدمه‌ها و خاتمهٔ معالم السنه النبویه — مقدمه‌ی مترجم، مقدمه‌ی مؤلف،
//  درآمدِ کتاب و خاتمه. این‌ها حدیث نیستند، پس در فهرست باب‌ها نمی‌آیند؛
//  از ردیف «مقدمه‌ها»/«خاتمه» همان صفحه خوانده می‌شوند و پانوشتِ هر بند
//  زیرِ خودش می‌آید — همان رندری که ریاض و ترغیب دارند.
// ═══════════════════════════════════════════════════════════════

class MaalimMatterScreen extends StatefulWidget {
  const MaalimMatterScreen({
    super.key,
    required this.sections,
    required this.title,
    this.service,
  });

  /// The `matter_sections` rows the فهرست already loaded.
  final List<Map<String, dynamic>> sections;

  /// «مقدمه‌های معالم السنه النبویه» or «خاتمهٔ معالم السنه النبویه».
  final String title;

  /// Test seam: the caller's service, so a widget test can drive a fake
  /// database without the download flow.
  @visibleForTesting
  final MaalimService? service;

  @override
  State<MaalimMatterScreen> createState() => _MaalimMatterScreenState();
}

class _MaalimMatterScreenState extends State<MaalimMatterScreen> {
  late final MaalimService _service = widget.service ?? MaalimService();

  /// section id → (its paragraphs, notes keyed by the line they mark)
  final Map<int, List<Map<String, dynamic>>> _paragraphs = {};
  final Map<int, Map<int, List<Map<String, dynamic>>>> _notes = {};

  /// The thrown object, not its text: the panel renders it in debug builds
  /// only, so a reader never meets a table name where an explanation belongs.
  Object? _error;

  static const _accent = TopicHues.maalim;

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
      for (final section in widget.sections) {
        final id = (section['id'] as num).toInt();
        final paragraphs = await _service.matterParagraphs(id);
        final notes = <int, List<Map<String, dynamic>>>{};
        for (final note in await _service.footnotesOfSection(id)) {
          final line = (note['source_para'] as num?)?.toInt();
          if (line == null) continue;
          (notes[line] ??= []).add(note);
        }
        if (!mounted) return;
        setState(() {
          _paragraphs[id] = paragraphs;
          _notes[id] = notes;
        });
      }
    } catch (e) {
      AppLogger.warning('maalim_matter_screen', 'error: $e');
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: widget.title,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return FailureView(
        id: 'maalim_matter_load',
        title: 'متن مقدمه باز نشد',
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
    if (text.isEmpty) return const SizedBox.shrink();
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
