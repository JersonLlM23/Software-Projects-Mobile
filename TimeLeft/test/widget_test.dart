// Widget test para la aplicación TimeLeft.

import 'package:flutter_test/flutter_test.dart';
import 'package:timeleft/main.dart';

void main() {
  testWidgets('Smoke test de TimeLeftApp', (WidgetTester tester) async {
    // Renderizar la aplicación TimeLeftApp
    await tester.pumpWidget(const TimeLeftApp());

    // Verificar que el título TimeLeft esté presente en la interfaz
    expect(find.text('TimeLeft'), findsOneWidget);
    expect(find.text('¿Cuánto tiempo te queda?'), findsOneWidget);
  });
}
