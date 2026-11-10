import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final image = img.decodeImage(File('test/features/tools/inheritance/presentation/golden_share.png').readAsBytesSync())!;
  for (final (y, x) in [(0, 400), (1, 400), (2, 400), (10, 400), (20, 400), (49, 400), (200, 400), (513, 400), (514, 400), (515, 400)]) {
    final p = image.getPixel(x, y);
    stdout.writeln('y=$y x=$x -> r=${p.r} g=${p.g} b=${p.b}');
  }
  // row 0 profile: how many px are the beige color vs card bg across x
  for (final y in [0, 1, 514]) {
    var beige = 0, cream = 0, other = 0;
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      if ((r - 227).abs() <= 6 && (g - 214).abs() <= 6 && (b - 190).abs() <= 10) {
        beige++;
      } else if ((r - 253).abs() <= 4 &&
          (g - 246).abs() <= 4 &&
          (b - 236).abs() <= 4) {
        cream++;
      } else {
        other++;
      }
    }
    stdout.writeln('row y=$y: beige=$beige cream=$cream other=$other');
  }
}