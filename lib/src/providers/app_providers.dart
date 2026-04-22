import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../models/ugc_texture_entry.dart';
import '../services/emulator_scanner.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) => throw UnimplementedError());

class SelectedPathNotifier extends Notifier<String?> {
  @override
  String? build() {
    final settings = ref.watch(settingsServiceProvider);
    return settings.selectedPath;
  }

  Future<void> setPath(String? path) async {
    state = path;
    final settings = ref.read(settingsServiceProvider);
    await settings.setSelectedPath(path);
  }
}

final selectedPathProvider = NotifierProvider<SelectedPathNotifier, String?>(SelectedPathNotifier.new);

class AutoLoadNotifier extends Notifier<bool> {
  @override
  bool build() {
    final settings = ref.watch(settingsServiceProvider);
    return settings.autoLoad;
  }

  Future<void> setAutoLoad(bool value) async {
    state = value;
    final settings = ref.read(settingsServiceProvider);
    await settings.setAutoLoad(value);
  }
}

final autoLoadProvider = NotifierProvider<AutoLoadNotifier, bool>(AutoLoadNotifier.new);

final ugcEntriesProvider = FutureProvider<List<UgcTextureEntry>>((ref) async {
  final path = ref.watch(selectedPathProvider);
  if (path == null) return [];
  return EmulatorScanner.scanFolder(path);
});
