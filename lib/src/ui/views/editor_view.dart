import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/vrs_texture_entry.dart';
import '../../providers/app_providers.dart';
import '../../services/backup_service.dart';
import '../../services/texture_processor.dart';
import '../../services/directory_processor.dart';
import '../utils/image_editor_helper.dart';

class EditorView extends ConsumerStatefulWidget {
  const EditorView({super.key});

  @override
  ConsumerState<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends ConsumerState<EditorView> {
  VrsTextureEntry? _selectedEntry;
  bool _isProcessing = false;
  String _status = '';

  Future<void> _refreshFolder() async {
    final path = ref.read(selectedPathProvider);
    if (path == null) return;
    
    final newEntries = DirectoryProcessor.scanFolder(path);
    final currentEntries = ref.read(vrsEntriesProvider).value ?? [];
    
    // Check if any new entries were found that are not in current list
    final addedEntries = newEntries.where((ne) => !currentEntries.any((ce) => ce.vrsPath == ne.vrsPath)).toList();
    
    if (addedEntries.isEmpty) return;

    // This is a bit of a hack to update the list if it was already loaded
    final updatedList = List<VrsTextureEntry>.from(currentEntries)..addAll(addedEntries);
    // Note: In a real app, we'd probably want to refresh the provider properly
    // but for this simple tool we just invalidate it.
    ref.read(vrsEntriesProvider.notifier).refresh();
  }

  Future<void> _loadPreview(VrsTextureEntry entry) async {
    setState(() {
      _selectedEntry = entry;
      _status = 'Loading preview...';
    });

    try {
      final decoded = await TextureProcessor.decodeFile(entry.vrsPath);
      if (mounted && _selectedEntry == entry) {
        setState(() {
          _status = 'Ready: ${entry.stem}';
        });
      }
    } catch (e) {
      if (mounted && _selectedEntry == entry) {
        setState(() => _status = 'Error loading preview: $e');
      }
    }
  }

  Future<void> _importTexture() async {
    if (_selectedEntry == null) return;

    // 1. Get image from clipboard or file? 
    // For now, let's assume we use an image editor helper that returns bytes.
    final decoded = await TextureProcessor.decodeFile(_selectedEntry!.vrsPath);
    final editedBytes = await openCropEditor(context, decoded.toUint8List());

    if (editedBytes == null) return;

    // Show confirmation for thumb regeneration if it has one
    bool regenerateThumb = _selectedEntry!.hasThumb;
    if (_selectedEntry!.hasThumb) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Regenerate Thumbnail?'),
          content: const Text('This texture has a thumbnail. Should it be updated too?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
          ],
        ),
      );
      regenerateThumb = choice ?? false;
    }

    setState(() => _isProcessing = true);
    try {
      setState(() => _status = 'Backing up original...');
      final backupDir = await BackupService.backupEntry(_selectedEntry!);

      setState(() => _status = 'Processing texture...');

      final tempDir = io.Directory.systemTemp;
      final tempFile = io.File('${tempDir.path}/edited_import.png');
      await tempFile.writeAsBytes(editedBytes);

      await TextureProcessor.importPng(
        pngPath: tempFile.path,
        destStem: '${_selectedEntry!.directory}/${_selectedEntry!.stem}',
        writeThumb: regenerateThumb,
        writeCanvas: _selectedEntry!.hasCanvas,
        originalVrsPath: _selectedEntry!.vrsPath,
      );

      setState(() => _status = 'Success! Backup in $backupDir');
      ref.invalidate(vrsEntriesProvider);
      _loadPreview(_selectedEntry!);
    } catch (e) {
      setState(() => _status = 'Import error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(vrsEntriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Texture Editor'),
        backgroundColor: Colors.black45,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(vrsEntriesProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () {
              ref.read(selectedPathProvider.notifier).setPath(null);
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          SizedBox(
            width: 300,
            child: entriesAsync.when(
              data: (entries) => ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    title: Text(entry.displayName, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(entry.hasCanvas ? 'Has Canvas' : 'No Canvas', style: const TextStyle(color: Colors.white70)),
                    selected: _selectedEntry == entry,
                    selectedTileColor: Colors.blue.withOpacity(0.2),
                    onTap: () {
                      _loadPreview(entry);
                    },
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
          // Main Preview
          Expanded(
            child: Container(
              color: Colors.black26,
              child: Column(
                children: [
                  Expanded(
                    child: _selectedEntry == null
                        ? const Center(child: Text('Select a texture to edit', style: TextStyle(color: Colors.white54)))
                        : FutureBuilder(
                            future: TextureProcessor.decodeFile(_selectedEntry!.vrsPath),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return Center(child: Text('Error: ${snapshot.error}'));
                              }
                              return Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      Image.memory(
                                        snapshot.data!.toUint8List(),
                                        filterQuality: FilterQuality.none,
                                      ),
                                      const SizedBox(height: 16),
                                      if (_selectedEntry!.hasThumb) ...[
                                        const Text('Thumbnail Preview:', style: TextStyle(color: Colors.white70)),
                                        FutureBuilder(
                                          future: TextureProcessor.decodeFile(_selectedEntry!.thumbPath!),
                                          builder: (context, thumbSnap) {
                                            if (!thumbSnap.hasData) return const SizedBox();
                                            return Image.memory(thumbSnap.data!.toUint8List());
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black45,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _status,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        if (_selectedEntry != null)
                          ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _importTexture,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Import New PNG'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
