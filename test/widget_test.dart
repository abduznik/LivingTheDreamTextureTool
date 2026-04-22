import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:living_the_dream_toolkit/main.dart';
import 'package:living_the_dream_toolkit/src/services/settings_service.dart';
import 'package:living_the_dream_toolkit/src/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final settingsService = await SettingsService.init();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsServiceProvider.overrideWithValue(settingsService),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that our app starts and shows the title.
    expect(find.text('Livin\' The Dream Toolkit'), findsOneWidget);
  });
}
