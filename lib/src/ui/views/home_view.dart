// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/emulator_scanner.dart';
import '../../models/emulator_path.dart';
import 'editor_view.dart';
import 'settings_view.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialPath();
    });
  }

  Future<void> _checkInitialPath() async {
    final selectedPath = ref.read(selectedPathProvider);
    if (selectedPath != null) {
      // Path already selected, EditorView will be shown via conditional build
      return;
    }

    await _runScan();
  }

  Future<void> _runScan() async {
    setState(() => _isScanning = true);
    try {
      final scanner = EmulatorScanner();
      final results = await scanner.scan();

      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No emulator save folders found automatically.')),
          );
        }
      } else if (results.length == 1) {
        // Even if 1, maybe show dialog or just auto-select? 
        // User said: "if you ever meet 2 of them open a popup".
        // I'll show it even for 1 so they can confirm.
        if (mounted) _showSelectionDialog(results);
      } else {
        if (mounted) _showSelectionDialog(results);
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _showSelectionDialog(List<EmulatorPath> results) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PathSelectionDialog(results: results),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPath = ref.watch(selectedPathProvider);

    if (selectedPath != null) {
      return const EditorView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Livin\' The Dream Toolkit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsView()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _isScanning
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for emulator save files...'),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No folder selected.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _runScan,
                    child: const Text('Scan Again'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsView()),
                      );
                    },
                    child: const Text('Manually select folder in Settings'),
                  ),
                ],
              ),
      ),
    );
  }
}

class PathSelectionDialog extends ConsumerStatefulWidget {
  final List<EmulatorPath> results;

  const PathSelectionDialog({super.key, required this.results});

  @override
  ConsumerState<PathSelectionDialog> createState() => _PathSelectionDialogState();
}

class _PathSelectionDialogState extends ConsumerState<PathSelectionDialog> {
  bool _rememberPath = true;
  EmulatorPath? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.results.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Save Folder'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Multiple save folders were found. Please select which one to use:'),
            const SizedBox(height: 16),
            ...widget.results.map((res) => RadioListTile<EmulatorPath>(
                  title: Text(res.emulatorName),
                  subtitle: Text('User: ${res.userId}\n${res.path}'),
                  isThreeLine: true,
                  value: res,
                  groupValue: _selected,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selected = val);
                    }
                  },
                )),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Remember this for future uses'),
              value: _rememberPath,
              onChanged: (val) => setState(() => _rememberPath = val ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selected != null) {
              ref.read(selectedPathProvider.notifier).setPath(_selected!.path);
              if (_rememberPath) {
                ref.read(autoLoadProvider.notifier).setAutoLoad(true);
              }
              Navigator.pop(context);
            }
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
