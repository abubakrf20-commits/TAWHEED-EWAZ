import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_color_sheets.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/mushaf/quran_kit_row.dart';
import 'package:tawheeed/features/quran/services/mp3quran_service.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// What the reader chose in a [ReciterPickerSheet].
@immutable
class ReciterPick {
  const ReciterPick(this.id, {this.downloadSurah = false});

  /// The reciter's identifier, i.e. [Mp3QuranReciter.identifier].
  final String id;

  /// True when the reader tapped a row's download action rather than the row
  /// itself: «this surah, from this reciter». The caller decides which surah
  /// that is, and does not have to make the reciter the active one.
  final bool downloadSurah;

  @override
  bool operator ==(Object other) =>
      other is ReciterPick &&
      other.id == id &&
      other.downloadSurah == downloadSurah;

  @override
  int get hashCode => Object.hash(id, downloadSurah);

  @override
  String toString() => 'ReciterPick($id, downloadSurah: $downloadSurah)';
}

/// The reader's one reciter picker.
///
/// The player's reciter sheet and the download page's picker were two sheets
/// over the same rows with different chrome — handle, title weight, search,
/// padding — so one list read as two features (report §6.3/§7.2). This is the
/// shared one: the player's sheet geometry and search, the loading / error+retry
/// / no-match states, and — when the caller can download — the per-reciter size
/// line and a download action on every row that is not already selected.
class ReciterPickerSheet extends StatefulWidget {
  const ReciterPickerSheet({
    super.key,
    required this.palette,
    required this.reciters,
    required this.selectedId,
    required this.onSelect,
    this.loading = false,
    this.error,
    this.onRetry,
    this.sizeLabel,
    this.downloadSurahNumber,
  });

  final MushafPalette palette;
  final List<Mp3QuranReciter> reciters;
  final String? selectedId;

  /// Called with the reader's choice. The sheet never pops itself: the caller
  /// owns the route, because what happens next (a pref write, a reader switch,
  /// a download, a confirmation dialog) differs per caller.
  final ValueChanged<ReciterPick> onSelect;

  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  /// Per-reciter size line, e.g. «~۲۳۷ مگابایت». Only the download page has a
  /// figure to put here, so it is a callback rather than a fixed string.
  final String? Function(Mp3QuranReciter reciter)? sizeLabel;

  /// When non-null, every row that is not the selected one grows a download
  /// action for that surah, reporting back with [ReciterPick.downloadSurah].
  final int? downloadSurahNumber;

  @override
  State<ReciterPickerSheet> createState() => _ReciterPickerSheetState();
}

class _ReciterPickerSheetState extends State<ReciterPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final query = _query.trim();
    final filtered = query.isEmpty
        ? widget.reciters
        : widget.reciters.where((r) => r.name.contains(query)).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shared sheet geometry (spec): 38x4 handle.
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: palette.surfaceText.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'انتخاب قاری',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: palette.surfaceText,
                ),
              ),
            ),
            if (!widget.loading && widget.reciters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: palette.surfaceText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'جستجوی قاری…',
                    hintStyle: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: palette.surfaceMuted,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: palette.accent.withValues(alpha: 0.06),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: palette.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: palette.accent),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            Flexible(
              child: widget.loading
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: palette.accent),
                    )
                  : widget.error != null && widget.reciters.isEmpty
                      ? _ErrorState(palette: palette, onRetry: widget.onRetry)
                      : filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'قاری‌ای با این نام پیدا نشد.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  color: palette.surfaceMuted,
                                ),
                              ),
                            )
                          : MushafSheetScrollable(
                              builder: (context, physics) => ListView.builder(
                                shrinkWrap: true,
                                physics: physics,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) =>
                                    _row(filtered[index]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Mp3QuranReciter reciter) {
    final palette = widget.palette;
    final selected = reciter.identifier == widget.selectedId;
    final size = widget.sizeLabel?.call(reciter);
    final surah = widget.downloadSurahNumber;
    return QuranKitRow(
      palette: palette,
      icon: Icons.record_voice_over_rounded,
      title: reciter.name,
      // The surah count is real data about the recording; the size line is only
      // there where the caller can actually estimate one (report §7.2).
      subtitle: size == null
          ? '${reciter.surahCount} سوره'
          : '${reciter.surahCount} سوره • $size',
      selected: selected,
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: palette.accent, size: 20)
          : surah == null
              ? null
              : _SurahDownloadAction(
                  palette: palette,
                  tooltip:
                      'دانلود سورهٔ ${NumberFormat.normalizeDigits('$surah')} از این قاری',
                  onTap: () => widget.onSelect(
                      ReciterPick(reciter.identifier, downloadSurah: true)),
                ),
      onTap: () => widget.onSelect(ReciterPick(reciter.identifier)),
    );
  }
}

/// The download action on a reciter row: a bare glyph with a tooltip, kept off
/// the row's own tap target so choosing a reciter and fetching a surah from one
/// are two different taps.
class _SurahDownloadAction extends StatelessWidget {
  const _SurahDownloadAction({
    required this.palette,
    required this.tooltip,
    required this.onTap,
  });

  final MushafPalette palette;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.download_for_offline_outlined,
            size: 20,
            color: palette.accent,
          ),
        ),
      ),
    );
  }
}

/// Loading failed and there is nothing cached to fall back on.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.palette, this.onRetry});

  final MushafPalette palette;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      // The sheet sits on paper, so the panel is inked from the mushaf palette
      // rather than the ambient time theme.
      child: FailureView(
        id: 'quran_reciters',
        title: 'لیست قاریان دریافت نشد',
        detail: 'فهرست قاریان از سرور می‌آید و برای دریافتش به اینترنت نیاز است.',
        onRetry: onRetry,
        layout: FailureLayout.page,
        icon: Icons.cloud_off_rounded,
        ink: FailureInk(
          title: palette.surfaceText,
          detail: palette.surfaceMuted,
          danger: palette.accent,
        ),
      ),
    );
  }
}
