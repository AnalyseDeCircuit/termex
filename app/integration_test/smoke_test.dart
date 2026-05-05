import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termex/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts and shows unlock page', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    // The unlock page should be visible before authentication.
    expect(find.text('Enter master password'), findsOneWidget);
  });
}
