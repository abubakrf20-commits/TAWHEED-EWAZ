import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The hadeeth_enc colour source.
///
/// The hadith card is painted on the shared cream paper — its background,
/// hairline, divider, chips and inks are byte-identical to
/// `ShareCardPalette`, so it takes them from there rather than repeating them
/// (that duplication is what the share-family extraction removed). What is
/// genuinely this feature's own is the grade ink: the encrypted-hadith API
/// returns the grade as prose («صحيح»، «حسن»، «ضعيف»), not an enum, so the
/// mapping lives here once instead of inside the card's build method.
class HadeethPalette {
  const HadeethPalette._();

  /// The amber of a «حسن» grade chip — the app's gold, as the card has always
  /// drawn it. `TopicHues.zakat` happens to hold the same value, but that is a
  /// section identity, not a grade, so the two are not cross-referenced.
  static const Color gradeHasan = Color(0xFFF9A825);

  /// Ink for a «درجة الحديث» string.
  ///
  /// The API's prose is unnormalised, so both Arabic and Persian spellings are
  /// matched (`صحيح`/«صحیح»); anything unrecognised falls back to the feature's
  /// accent rather than to a colour that claims a grade it does not know.
  static Color grade(String grade) {
    if (grade.contains('صحیح') || grade.contains('صحيح')) {
      return AppTheme.success;
    }
    if (grade.contains('حسن')) {
      return gradeHasan;
    }
    return TopicHues.hadeethEnc;
  }
}
