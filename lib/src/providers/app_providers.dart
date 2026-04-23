import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../models/vrs_texture_entry.dart';
import '../services/directory_processor.dart';

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

final vrsEntriesProvider = AsyncNotifierProvider<VrsEntriesNotifier, List<VrsTextureEntry>>(VrsEntriesNotifier.new);

class VrsEntriesNotifier extends AsyncNotifier<List<VrsTextureEntry>> {
  @override
  Future<List<VrsTextureEntry>> build() async {
    final path = ref.watch(selectedPathProvider);
    if (path == null) return [];
    return DirectoryProcessor.scanFolder(path);
  }

  Future<void> refresh() async {
    final path = ref.read(selectedPathProvider);
    if (path == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => DirectoryProcessor.scanFolder(path));
  }
}
