import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/notes/presentation/providers/notes_provider.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/notes/presentation/utils/note_colors.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

/// Notes identity color — warm amber (matches the notes list screen).
const Color _notesAccent = TopicHues.worshipNotes;

class NoteEditorScreen extends ConsumerStatefulWidget {
  final NoteTableData? note;

  /// The word a deep-search hit was opened for. Painted inside the fields
  /// themselves — an editor has no `Text.rich` to put a span in.
  final String highlightQuery;

  const NoteEditorScreen({super.key, this.note, this.highlightQuery = ''});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late _HighlightingController _titleCtrl;
  late _HighlightingController _contentCtrl;
  late int _colorIndex;
  late bool _isPinned;
  final _focusNode = FocusNode();
  final _contentScroll = ScrollController();
  final _contentFieldKey = GlobalKey();
  bool _hasChanges = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = _HighlightingController(
      text: widget.note?.title ?? '',
      highlightQuery: widget.highlightQuery,
    );
    _contentCtrl = _HighlightingController(
      text: widget.note?.content ?? '',
      highlightQuery: widget.highlightQuery,
    );
    _colorIndex = widget.note?.colorIndex ?? 0;
    _isPinned = widget.note?.isPinned ?? false;

    _titleCtrl.addListener(_onChanged);
    _contentCtrl.addListener(_onChanged);
    if (widget.highlightQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealMatch());
    }
  }

  /// Scrolls the body so the matched word starts in view. The field owns its
  /// scrolling, so the offset is measured with a [TextPainter] using the same
  /// style and width the field lays out with (setting the selection instead
  /// would mark the note dirty and pop the unsaved-changes dialog on close).
  void _revealMatch() {
    if (!mounted) return;
    final matches =
        TextHighlight.findMatches(_contentCtrl.text, widget.highlightQuery);
    if (matches.isEmpty || !_contentScroll.hasClients) return;
    final width = _contentFieldKey.currentContext?.size?.width;
    if (width == null) return;
    final style = TextStyle(
      fontSize: AppTheme.scaledFontSize(context, 16),
      height: 1.7,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: _contentCtrl.text.substring(0, matches.first.start),
        style: style,
      ),
      textDirection: TextDirection.rtl,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width - 4);
    final target = painter.height - 48;
    if (target <= 0) return;
    _contentScroll.jumpTo(
      target.clamp(0, _contentScroll.position.maxScrollExtent),
    );
  }

  void _onChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onChanged);
    _contentCtrl.removeListener(_onChanged);
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _contentScroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final service = ref.read(notesProvider.notifier);
    // A note may be saved with no title at all: the list then previews the body
    // instead of a fake «یادداشت» heading.
    if (_isEditing) {
      // Only the two text fields are editable here: folder, tags, color and any
      // voice note already on the note are left exactly as they are.
      await service.editNote(widget.note!.id, title, content);
      if (_isPinned != widget.note!.isPinned) {
        await service.toggleNotePin(widget.note!.id);
      }
    } else {
      await service.addNote(
        title,
        content,
        const [],
        colorIndex: _colorIndex,
        isPinned: _isPinned,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) return true;
    if (!mounted) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغییرات ذخیره شود؟'),
        content: const Text('یادداشت شما ذخیره نشده است.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _save();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final bgColor = NoteColors.getColor(_colorIndex);
    final hasCustomColor = _colorIndex > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: hasCustomColor
            ? Color.lerp(bgColor, t.card, 0.4)
            : null,
        appBar: SectionAppBar(
          title: _isEditing ? 'ویرایش یادداشت' : 'یادداشت جدید',
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'بستن',
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: _isPinned ? _notesAccent : null,
              ),
              onPressed: () => setState(() => _isPinned = !_isPinned),
              tooltip: _isPinned ? 'برداشتن پین' : 'پین کردن',
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
              tooltip: 'ذخیره',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══ Title ═══
              // No box, no divider: the title and the body share one open sheet.
              TextField(
                controller: _titleCtrl,
                focusNode: _focusNode,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 20),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
                decoration: InputDecoration(
                  filled: false,
                  hintText: 'عنوان...',
                  hintStyle: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 20),
                    fontWeight: FontWeight.w700,
                    color: t.textMuted,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                ),
                textDirection: TextDirection.rtl,
              ),
              // ═══ Content ═══
              Expanded(
                child: TextField(
                  key: _contentFieldKey,
                  controller: _contentCtrl,
                  scrollController: _contentScroll,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    height: 1.7,
                    color: t.textPrimary,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    hintText: 'متن یادداشت...',
                    hintStyle: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      color: t.textMuted,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                  ),
                  textDirection: TextDirection.rtl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A field controller that paints a deep-search match in the text it renders.
/// `TextField` builds its own span, so a searched word can only be shaded by
/// overriding [buildTextSpan].
class _HighlightingController extends TextEditingController {
  _HighlightingController({super.text, required this.highlightQuery});

  final String highlightQuery;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final query = highlightQuery.trim();
    if (query.isEmpty ||
        text.isEmpty ||
        // While the IME owns a composing range its underline must win; the
        // highlight returns as soon as the composition commits.
        (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    if (TextHighlight.findMatches(text, query).isEmpty) {
      return TextSpan(style: style, text: text);
    }
    return TextSpan(
      style: style,
      children: TextHighlight.spans(
        text,
        query,
        baseStyle: style,
        highlightStyle:
            TextHighlight.defaultHighlightStyle(context, base: style),
      ),
    );
  }
}
