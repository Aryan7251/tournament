import 'package:flutter_test/flutter_test.dart';
import 'package:tournament_frontend/main.dart';

void main() {
  testWidgets('TournamentApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TournamentApp());
    await tester.pump();

    // Verify that the title brand appears
    expect(find.text('LUCKY'), findsOneWidget);
    expect(find.text('WIN'), findsOneWidget);
  });
}
