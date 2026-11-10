/// Helpers for presenting Persian text on devices/fonts whose Arabic shaping
/// is limited. The app's default font (Calibri) forms compound Persian words
/// poorly when they rely on the نیم‌فاصله (ZWNJ, U+200C) mid-word — e.g.
/// «خوش‌اخلاق‌ترین» can render with letters stuck together.
///
/// [spacedZwnj] rewrites each نیم‌فاصله to a regular space so the two parts of
/// the compound are shaped and drawn as separate words that always render
/// correctly. It is only meant for *display*, never for stored canonical text.
library;

/// Replaces every نیم‌فاصله (ZWNJ, U+200C) with a regular space so that Persian
/// compound words render as separate, correctly-shaped words even when the
/// active font has weak Arabic joining.
String spacedZwnj(String input) => input.replaceAll('\u200C', ' ');
