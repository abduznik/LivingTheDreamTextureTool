import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/services/settings_service.dart';
import 'src/services/log_service.dart';
import 'src/providers/app_providers.dart';
import 'src/ui/views/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await LogService.init();
  final settingsService = await SettingsService.init();

  runApp(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWithValue(settingsService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal Texture Toolkit',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          const HomeView(),
        ],
      ),
    );
  }
}
