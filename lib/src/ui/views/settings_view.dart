import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/app_providers.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPath = ref.watch(selectedPathProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Resource Directory'),
            subtitle: Text(selectedPath ?? 'None selected'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: () async {
                    String? result = await FilePicker.getDirectoryPath(
                      dialogTitle: 'Select Resource Directory',
                    );
                    if (result != null) {
                      ref.read(selectedPathProvider.notifier).setPath(result);
                    }
                  },
                ),
                if (selectedPath != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      ref.read(selectedPathProvider.notifier).setPath(null);
                    },
                  ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'About UTT',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          const ListTile(
            title: Text('Version'),
            subtitle: Text('0.1.1 (UTT Refactor)'),
          ),
          const ListTile(
            title: Text('Description'),
            subtitle: Text('Universal Texture Toolkit for Tegra-compatible assets.'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }
}
