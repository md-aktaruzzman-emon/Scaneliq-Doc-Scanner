import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaneliq/main.dart';

void main() {
  testWidgets('Scaneliq app renders Home screen with Scan document action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ScaneliqApp()));

    // Verify app title and primary actions are present
    expect(find.text('Scaneliq'), findsOneWidget);
    expect(
      find.text('Scan documents. Keep everything organized.'),
      findsOneWidget,
    );
    expect(find.text('Scan document'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
  });
}
