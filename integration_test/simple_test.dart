import 'package:arkpulse/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boots the dashboard shell', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.textContaining('ARK_PULSE // WEBDAV_HUB'), findsOneWidget);
    expect(find.textContaining('NO TRACK PLAYING'), findsOneWidget);
  });
}
