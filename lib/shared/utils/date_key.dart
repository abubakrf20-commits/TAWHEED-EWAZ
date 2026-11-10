/// Single source for the `yyyy-MM-dd` local-date key used by daily counters
/// (tasbih, evaluation, prayer tracker, khatm, reading plans, backups…).
///
/// Phase-2 audit fix: eight features carried byte-identical `_dateKey`
/// copies. A shared helper removes the drift risk (one feature switching to
/// ISO-8601 ordering while another keeps its own format would silently break
/// cross-feature queries like the tasbih daily totals).
String dateKeyOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
