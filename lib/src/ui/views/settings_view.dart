import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as p;
import '../../providers/app_providers.dart';
import '../../services/log_service.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  bool _isPickingPath = false;
  bool _isExportingLog = false;

  @override
  Widget build(BuildContext context) {
    final selectedPath = ref.watch(selectedPathProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black26,
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Resource Directory'),
            subtitle: Text(selectedPath ?? 'None selected'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isPickingPath)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    tooltip: 'Select Directory',
                    onPressed: () async {
                      setState(() => _isPickingPath = true);
                      try {
                        String? result = await FilePicker.getDirectoryPath(
                          dialogTitle: 'Select Resource Directory',
                        );
                        if (result != null) {
                          ref.read(selectedPathProvider.notifier).setPath(result);
                        }
                      } catch (e, stack) {
                        LogService.log('Settings: Folder Picker Error: $e\n$stack');
                      } finally {
                        if (mounted) setState(() => _isPickingPath = false);
                      }
                    },
                  ),
                if (selectedPath != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear Path',
                    onPressed: () {
                      ref.read(selectedPathProvider.notifier).setPath(null);
                    },
                  ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Session Log'),
            subtitle: const Text('Export all debug logs for troubleshooting.'),
            trailing: _isExportingLog
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isExportingLog = true);
                      try {
                        final logs = await LogService.readLogs();
                        final outputPath = await FilePicker.saveFile(
                          dialogTitle: 'Export Session Log',
                          fileName: 'utt_session.log',
                        );
                        if (outputPath != null) {
                          final absoluteOutputPath = p.absolute(outputPath);
                          await io.File(absoluteOutputPath).writeAsString(logs);
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Log exported successfully!')),
                            );
                          }
                        }
                      } catch (e, stack) {
                        LogService.log('Settings: Export Log Error: $e\n$stack');
                      } finally {
                        if (mounted) setState(() => _isExportingLog = false);
                      }
                    },
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Export Log'),
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
