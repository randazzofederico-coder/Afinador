import 'package:flutter_test/flutter_test.dart';
import 'package:afinador/main.dart';

void main() {
  testWidgets('AfinadorApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AfinadorApp());

    // Verify that the app starts.
    expect(find.byType(AfinadorApp), findsOneWidget);
  });
}
