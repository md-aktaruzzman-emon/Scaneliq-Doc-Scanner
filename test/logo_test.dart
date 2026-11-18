import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaneliq/core/widgets/scaneliq_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScaneliqLogo Widget Tests', () {
    testWidgets('renders ScaneliqLogo with default and custom sizes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ScaneliqLogo(size: 32),
                ScaneliqLogo(size: 72),
                ScaneliqLogo(size: 96),
              ],
            ),
          ),
        ),
      );

      final logoWidgets = find.byType(ScaneliqLogo);
      expect(logoWidgets, findsNWidgets(3));

      // Verify that the images load the official master PNG asset
      final imageWidgets = tester.widgetList<Image>(find.byType(Image));
      expect(imageWidgets.length, equals(3));
      for (final img in imageWidgets) {
        final assetImg = img.image as AssetImage;
        expect(assetImg.assetName, equals(ScaneliqLogo.masterAssetPath));
      }
    });

    testWidgets('renders with custom border radius when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ScaneliqLogo(size: 80, borderRadius: 16)),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, equals(BorderRadius.circular(16)));
    });

    testWidgets(
      'applies hairline frame cleanly in both light and dark themes',
      (WidgetTester tester) async {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: const Scaffold(
                body: ScaneliqLogo(size: 48, borderRadius: 12),
              ),
            ),
          );

          expect(find.byType(ScaneliqLogo), findsOneWidget);
          expect(find.byType(DecoratedBox), findsOneWidget);
          final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
          final decoration = box.decoration as BoxDecoration;
          expect(decoration.border, isNotNull);
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
