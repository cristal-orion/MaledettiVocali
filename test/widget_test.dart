import 'package:flutter_test/flutter_test.dart';
import 'package:maledetti_vocali/main.dart';

void main() {
  testWidgets('la schermata iniziale invita a condividere un vocale',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Condividi un vocale'), findsOneWidget);
    expect(find.text('Attiva modalità batch'), findsOneWidget);
  });
}
