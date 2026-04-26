import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import '../../providers/app_providers.dart';
import '../../services/log_service.dart';
import 'editor_view.dart';
import 'settings_view.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  Future<void> _pickDirectory(BuildContext context, WidgetRef ref) async {
    try {
      String? result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Resource Directory',
      );
      if (result != null) {
        await ref.read(selectedPathProvider.notifier).setPath(result);
      }
    } on PlatformException catch (e) {
      LogService.log('macOS Security/Picker Block: $e');
      if (context.mounted && io.Platform.isMacOS) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('macOS Security Blocked Picker'),
            content: const Text(
                'macOS security prevented the file picker from opening. This often happens if the app is running from a read-only disk image.\n\nPlease move the UTT app to your Applications folder and try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      LogService.log('Picker error: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPath = ref.watch(selectedPathProvider);

    if (selectedPath != null) {
      return const EditorView();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Universal Texture Toolkit'),
        backgroundColor: Colors.black45,
        elevation: 0,
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
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('logo.png', width: 120, height: 120),
              const SizedBox(height: 24),
              Text(
                'Welcome to UTT',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Universal Texture Toolkit is a professional utility for bit-manipulation and hardware-accelerated texture processing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              const Text(
                'To get started, please select your resource directory containing .ugctex.zs and .canvas.zs files.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _pickDirectory(context, ref),
                icon: const Icon(Icons.folder_open),
                label: const Text('Set Resource Directory'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
