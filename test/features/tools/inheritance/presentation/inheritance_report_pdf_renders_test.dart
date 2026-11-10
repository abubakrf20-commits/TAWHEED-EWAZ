import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/inheritance_report_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildInheritanceReportPdf renders modern PDF', () async {
    final result =
        getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
      estate: 45000000,
      wife: 1,
      son: 2,
      daughter: 1,
    ));
    final data = await buildInheritanceReportPdf(
      result: result,
      estate: 45000000.0,
      namedProblem: 'مسألهٔ مشهور',
    );
    expect(data, isA<Uint8List>());
    expect(data.length, greaterThan(0));
  });
}
