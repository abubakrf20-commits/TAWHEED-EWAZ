import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/hadeeth_palette.dart';

/// A source-level lock on the app's **share surfaces**.
///
/// These files are the app's published artifact: whatever they paint leaves the
/// phone as a PNG and is read in a chat app, out of theme and out of context. A
/// hard-coded hex or a hard-coded size in one of them is therefore a shipped
/// regression, not a local style choice — and it is invisible to every golden,
/// because a rebuilt card renders fine and a hex that still matches its palette
/// entry produces an identical picture *until* someone edits the palette.
///
/// So this scans the SOURCE (like `test/core/theme/type_scale_guard_test.dart`)
/// and requires every share surface to paint only from a palette/token module:
/// zero `Color(0x…)` and zero raw `fontSize:`.
///
/// Scope: a file whose *job* is sharing — `*_share_screen.dart` and
/// `*_share_card.dart`. Screens that merely *offer* a share button (`qibla_screen`,
/// `ruqyah_screen`, `khatm_stats_screen`, …) are not listed: they are ordinary
/// screens that happen to export, and they are held by the global ratchet in
/// `tools/design_consistency.py` instead. The list below is asserted against the
/// files on disk, so a new share card cannot be added without joining it.
///
/// The 2026-10-23 redesign (user-approved proposals ۱۳–۲۱) also deleted two
/// things that had each already come back once, and neither is visible to a
/// golden — an emoji in a card heading and a colourless `Divider` that inherits
/// the app theme instead of the card's palette. Both are locked below.
///
/// The footer mark is the third locked rule, in the other direction: the
/// Tawheed logo belongs on every export, but only through the kit
/// ([ShareCardLogo], fed by [ShareService.logoAsset]). A surface that loads
/// `logo2.png` itself is a finding, because then ten cards carry ten chances
/// to draw a different mark — the reason proposal ۱۷ removed it in the first
/// place, and the reason it came back in one place only (2026-10-25).
void main() {
  // ── the lock ──────────────────────────────────────────────────────────────
  const shareSurfaces = <String>[
    'lib/features/adhkar/duas/presentation/screens/dua_share_screen.dart',
    'lib/features/adhkar/presentation/screens/adhkar_share_screen.dart',
    'lib/features/dua_from_quran/presentation/screens/dua_from_quran_share_screen.dart',
    'lib/features/hadeeth_enc/presentation/screens/hadeeth_enc_share_screen.dart',
    'lib/features/hadeeth_enc/presentation/widgets/hadeeth_share_card.dart',
    'lib/features/prayer/presentation/screens/prayer_times_share_screen.dart',
    'lib/features/quran/mushaf/quran_ayah_share_screen.dart',
    'lib/features/quran/mushaf/quran_tafsir_share_screen.dart',
    'lib/features/tools/dongi/presentation/widgets/dangi_settlement_share_card.dart',
    'lib/features/tools/inheritance/presentation/widgets/inheritance_share_card.dart',
  ];

  /// The shared frame every surface above renders through. It is not a
  /// `_share_*` file by name, so it cannot appear in the discovery list — but a
  /// regression here lands on all ten exports at once, so it is held to the
  /// same rules.
  const shareKit = <String>[
    'lib/core/design_system/components/share_card_shell.dart',
  ];

  /// The two names that make a file a share surface.
  const surfaceNames = <String>['_share_screen.dart', '_share_card.dart'];

  /// `tools/design_consistency.py`'s own definition of a raw colour.
  final rawColor = RegExp(r'Color\(0x');

  /// Its own definition of a raw size: a whole or decimal literal right after
  /// `fontSize:`. `fontSize: AppTheme.scaledFontSize(context, 14)` does not
  /// match, which is exactly the point.
  final rawSize = RegExp(r'fontSize:\s*\d');

  test('every share surface on disk is in the locked list', () {
    final found = <String>[
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File)
          if (entity.path.replaceAll(r'\', '/').endsWith('.dart'))
            if (surfaceNames.any(
              (name) => entity.path.replaceAll(r'\', '/').endsWith(name),
            ))
              entity.path.replaceAll(r'\', '/'),
    ]..sort();

    expect(
      found,
      equals(List<String>.of(shareSurfaces)..sort()),
      reason: 'A share surface was added, renamed or deleted. Add it to '
          '`shareSurfaces` — and give it a palette before you do, because this '
          'lock is what keeps the exported images on one source.',
    );
  });

  for (final path in [...shareSurfaces, ...shareKit]) {
    test('$path paints from the palette only', () {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing');

      final code = _withoutComments(file.readAsStringSync());

      final colors = <String>[];
      final sizes = <String>[];
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Comments are not painted (the type-scale guard skips them too).
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('*') ||
            trimmed.startsWith('/*')) {
          continue;
        }
        if (rawColor.hasMatch(lines[i])) colors.add('$path:${i + 1}');
        if (rawSize.hasMatch(lines[i])) sizes.add('$path:${i + 1}');
      }

      expect(
        colors,
        isEmpty,
        reason: 'A share surface must not carry a raw colour — it is exported '
            'as an image and read outside the app. Name it in the feature '
            'palette (`ShareCardPalette` for the cream family) instead:\n'
            '${colors.join('\n')}',
      );
      expect(
        sizes,
        isEmpty,
        reason: 'A share surface must not carry a raw size — the exported card '
            'follows the reader\'s «اندازه فونت», so use '
            '`AppTheme.scaledFontSize(context, step)`:\n${sizes.join('\n')}',
      );

      final emoji = _emojiFindings(code);
      expect(
        emoji,
        isEmpty,
        reason:
            'A share surface must not paint an emoji — the header art is an '
            '`IconData` on a `DuotoneIconTile` (proposal ۱۴). An emoji in the '
            'chat message a screen builds is text the recipient reads, not ink '
            'on the card, and stays allowed:\n${_where(path, code, emoji)}',
      );

      final dividers = _colourlessDividers(code);
      expect(
        dividers,
        isEmpty,
        reason: 'A bare `Divider` paints the app theme\'s grey on the cream '
            'paper. Use `ShareCardDivider`, or pass '
            '`color: ShareCardColors.of(context).divider`:\n'
            '${_where(path, code, dividers)}',
      );

      final logos = _logoFindings(code);
      expect(
        logos,
        isEmpty,
        reason: 'A share surface must not load the footer mark itself: every '
            'card draws it through `ShareCardLogo` (which reads '
            '`ShareService.logoAsset`), so the ten exports cannot print ten '
            'different marks:\n${_where(path, code, logos)}',
      );
    });
  }

  // ── the signature row the ten exports depend on ───────────────────────────
  // The user's 2026-10-25 report was that the mark vanished from every export
  // and a bare «—» took its place; the follow-up the same day was that the mark
  // was too big and stood ABOVE the line instead of beside it. This pins the
  // composition at its single source: one row paints `ShareCardLogo` beside the
  // dash-free signature, the footer composes that row, and the asset name is
  // declared once, in the brand service.
  test('the kit footer prints the mark beside a dash-free signature', () {
    final shell = _withoutComments(
      File('lib/core/design_system/components/share_card_shell.dart')
          .readAsStringSync(),
    );

    String classBody(String header) {
      final start = shell.indexOf(header);
      expect(start, greaterThan(-1), reason: '$header is missing');
      final next = RegExp(r'\nclass ').firstMatch(shell.substring(start + 1));
      return next == null
          ? shell.substring(start)
          : shell.substring(start, start + 1 + next.start);
    }

    final signature = classBody('class ShareCardSignature');
    expect(signature, contains('ShareCardLogo('),
        reason: 'the signature row must print the app mark');
    expect(signature, contains('Row('),
        reason: 'the mark and the line share one row, never a column');
    expect(signature, contains('ShareService.signatureLine(section)'),
        reason: 'the footer line is the dash-free signature');
    expect(signature, isNot(contains('ShareService.appLine')),
        reason: 'the em dash belongs to text shares only, not to the card');

    final footer = classBody('class ShareCardFooter');
    expect(footer, contains('ShareCardSignature(section: section)'),
        reason: 'the footer must compose the shared signature row');
    expect(footer, contains('ShareCardDivider('),
        reason: 'the hairline opens the footer, above the signature row');

    final service =
        File('lib/shared/services/share_service.dart').readAsStringSync();
    expect(service, contains("logoAsset = 'assets/logo2.png'"),
        reason: 'the mark is named once, in ShareService.logoAsset');
  });

  // ── the grade ink the lock made single-source ─────────────────────────────
  group('HadeethPalette.grade', () {
    test('maps the API\'s prose, in both spellings, and never guesses', () {
      expect(HadeethPalette.grade('صحيح'), AppTheme.success);
      expect(HadeethPalette.grade('صحیح'), AppTheme.success);
      expect(HadeethPalette.grade('حسن'), HadeethPalette.gradeHasan);
      // An unknown grade must not claim a grade's colour.
      expect(HadeethPalette.grade('ضعيف'), isNot(HadeethPalette.gradeHasan));
    });
  });

  // ── the scanners themselves ───────────────────────────────────────────────
  // A guard that stops biting is worse than no guard, so each scanner is
  // driven against a snippet shaped like the regression it exists to catch.
  group('the locked regressions are actually caught', () {
    const emoji = '\u{1F54C}';

    test('an emoji painted in a header is a finding', () {
      expect(_emojiFindings("Text('$emoji دعا')"), hasLength(1));
      expect(
        _emojiFindings("ShareCardHeader(title: '$emoji دعا', icon: i)"),
        hasLength(1),
      );
      expect(
        _emojiFindings("ShareCardLabel(label: '$emoji دعا', icon: i)"),
        hasLength(1),
      );
    });

    test('an emoji in the chat message stays text, not ink', () {
      expect(_emojiFindings("..writeln('$emoji دعا')"), isEmpty);
    });

    test('a Divider must hand the palette its ink', () {
      expect(_colourlessDividers('const Divider(height: 1),'), hasLength(1));
      expect(
        _colourlessDividers('Divider(height: max(1, 2)),'),
        hasLength(1),
        reason: 'the colour may sit after a nested call',
      );
      expect(_colourlessDividers('VerticalDivider(width: 1),'), hasLength(1));
      expect(
        _colourlessDividers('Divider(height: 1, color: c.divider),'),
        isEmpty,
      );
      expect(_colourlessDividers('const ShareCardDivider(),'), isEmpty);
    });

    test('a surface that loads the mark itself is a finding', () {
      expect(_logoFindings("Image.asset('assets/logo2.png')"), hasLength(1));
      expect(_logoFindings("Image(image: AssetImage('assets/logo2.png'))"),
          hasLength(1));
      // The kit's own call is clean: the path lives in `ShareService`.
      expect(_logoFindings('const ShareCardLogo(),'), isEmpty);
      expect(_logoFindings("Text('برنامه توحید')"), isEmpty);
    });

    test('comments are not painted', () {
      // The scanners read already-stripped code, so the comment must leave
      // through `_withoutComments` exactly as it does for a real file.
      expect(_emojiFindings(_withoutComments('// $emoji در کامنت')), isEmpty);
      expect(
        _colourlessDividers(_withoutComments('// Divider(height: 1)')),
        isEmpty,
      );
      expect(
          _logoFindings(_withoutComments('/* assets/logo2.png */')), isEmpty);
      expect(_lineOf('a\nb\nc', 4), 3);
    });
  });
}

/// Blanks `//` and `/* … */` comments while keeping every newline and offset,
/// so a finding still maps to the line a reader sees. String literals are
/// stepped over whole: a `//` inside a literal is not a comment.
String _withoutComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    final pair = i + 1 < source.length ? source.substring(i, i + 2) : '';
    if (pair == '//') {
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (pair == '/*') {
      // Block comments nest in Dart.
      var depth = 0;
      while (i < source.length) {
        if (source.startsWith('/*', i)) {
          depth++;
          i += 2;
          out.write('  ');
        } else if (source.startsWith('*/', i)) {
          depth--;
          i += 2;
          out.write('  ');
          if (depth == 0) break;
        } else {
          out.write(source[i] == '\n' ? '\n' : ' ');
          i++;
        }
      }
      continue;
    }
    if (ch == "'" || ch == '"') {
      final close = source.startsWith('$ch$ch$ch', i) ? '$ch$ch$ch' : ch;
      out.write(close);
      i += close.length;
      while (i < source.length) {
        if (source[i] == r'\' && i + 1 < source.length) {
          out.write(source.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (source.startsWith(close, i)) {
          out.write(close);
          i += close.length;
          break;
        }
        out.write(source[i]);
        i++;
      }
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}

int _lineOf(String code, int offset) =>
    '\n'.allMatches(code.substring(0, offset)).length + 1;

String _where(String path, String code, Iterable<int> offsets) =>
    offsets.map((offset) => '$path:${_lineOf(code, offset)}').join('\n');

/// The emoji blocks, plus the variation selector that makes `⚠️` one glyph.
bool _isEmoji(int rune) =>
    (rune >= 0x1F000 && rune <= 0x1FAFF) ||
    (rune >= 0x2600 && rune <= 0x27BF) ||
    (rune >= 0x2B00 && rune <= 0x2BFF) ||
    rune == 0xFE0F;

/// The argument positions that become ink on the card.
final RegExp _inkArgument =
    RegExp(r'(?:\bText\s*\(|\b(?:title|subtitle|label)\s*:)\s*$');

/// The last quote before the emoji opens its literal (a share header is one
/// line of text, never a quote inside a quote); what precedes that quote says
/// whether the literal is painted.
bool _isPaintedEmoji(String code, int offset) {
  final window = code.substring(offset < 2000 ? 0 : offset - 2000, offset);
  final quote = window.lastIndexOf(RegExp('[\'"]'));
  if (quote < 0) return false;
  return _inkArgument.hasMatch(window.substring(0, quote));
}

List<int> _emojiFindings(String code) {
  final found = <int>[];
  var offset = 0;
  for (final rune in code.runes) {
    if (_isEmoji(rune) && _isPaintedEmoji(code, offset)) found.add(offset);
    offset += rune > 0xFFFF ? 2 : 1;
  }
  return found;
}

/// `ShareCardDivider(` never matches: there is no word boundary inside it.
final RegExp _dividerCall = RegExp(r'\b(?:Vertical)?Divider\s*\(');

List<int> _colourlessDividers(String code) {
  final found = <int>[];
  for (final match in _dividerCall.allMatches(code)) {
    var depth = 0;
    var end = match.end - 1;
    for (; end < code.length; end++) {
      final ch = code[end];
      if (ch == '(') depth++;
      if (ch == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    if (!code.substring(match.start, end).contains('color:')) {
      found.add(match.start);
    }
  }
  return found;
}

List<int> _logoFindings(String code) => [
      for (final match in RegExp(r'logo2').allMatches(code)) match.start,
    ];
