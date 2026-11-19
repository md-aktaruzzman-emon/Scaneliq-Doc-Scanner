import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/features/scanner/presentation/scan_session_provider.dart';
import 'package:scaneliq/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Scaneliq app renders Concept A Home dashboard and 3-tab shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsListProvider.overrideWith((ref) async => const []),
          foldersListProvider(null).overrideWith((ref) async => const []),
          latestDraftProvider.overrideWith((ref) async => null),
        ],
        child: const ScaneliqApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Editorial header branding & OCR search bar
    expect(find.text('Scaneliq'), findsOneWidget);
    expect(find.text('Search titles or recognized text…'), findsOneWidget);
    expect(find.text('OCR'), findsOneWidget);

    // Concept A inline scope tabs
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Starred'), findsOneWidget);
    expect(find.text('Folders'), findsWidgets);

    // Right-thumb floating capture cluster
    expect(find.text('Scan'), findsOneWidget);
    expect(find.byTooltip('Import from Gallery'), findsOneWidget);

    // Concept A 3-tab bottom bar
    expect(find.text('Scans'), findsOneWidget);
    expect(find.text('PDF Suite'), findsOneWidget);
  });

  testWidgets('Scaneliq app displays empty vault prompt when no scans exist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsListProvider.overrideWith(
            (ref) async => const <ScannedDocument>[],
          ),
          foldersListProvider(null)
              .overrideWith((ref) async => const <DocumentFolder>[]),
          latestDraftProvider.overrideWith((ref) async => null),
        ],
        child: const ScaneliqApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No scans yet'), findsOneWidget);
    expect(find.text('Scan document'), findsOneWidget);
    expect(find.text('Import from Gallery'), findsOneWidget);
  });
}
