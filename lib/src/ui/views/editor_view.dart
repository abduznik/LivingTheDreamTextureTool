import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import '../../providers/app_providers.dart';
import '../../models/ugc_texture_entry.dart';
import '../../services/texture_processor.dart';
import '../../services/backup_service.dart';
import '../utils/image_editor_helper.dart';
import 'settings_view.dart';

class EditorView extends ConsumerStatefulWidget {
  const EditorView({super.key});

  @override
  ConsumerState<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends ConsumerState<EditorView> {
  UgcTextureEntry? _selectedEntry;
  Uint8List? _previewBytes;
  bool _isLoadingPreview = false;
  bool _isProcessing = false;
  String _status = '';

  Future<void> _loadPreview(UgcTextureEntry entry) async {
    setState(() {
      _isLoadingPreview = true;
      _status = 'Decoding ${entry.displayName}...';
      _previewBytes = null;
    });

    try {
      final decoded = await TextureProcessor.decodeFile(entry.ugctexPath);
      final pngBytes = Uint8List.fromList(img.encodePng(decoded));
      if (mounted && _selectedEntry == entry) {
        setState(() {
          _previewBytes = pngBytes;
          _status = '${entry.displayName} (${decoded.width}x${decoded.height})';
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      if (mounted && _selectedEntry == entry) {
        setState(() {
          _status = 'Error: $e';
          _isLoadingPreview = false;
        });
      }
    }
  }

  Future<void> _exportPng() async {
    if (_selectedEntry == null) return;
    
    final result = await FilePicker.saveFile(
      dialogTitle: 'Export PNG',
      fileName: '${_selectedEntry!.stem}.png',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );

    if (result != null) {
      setState(() => _isProcessing = true);
      try {
        final decoded = await TextureProcessor.decodeFile(_selectedEntry!.ugctexPath);
        final png = img.encodePng(decoded);
        await io.File(result).writeAsBytes(png);
        setState(() => _status = 'Exported to $result');
      } catch (e) {
        setState(() => _status = 'Export error: $e');
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _importPng() async {
    if (_selectedEntry == null) return;

    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import PNG',
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      final pngPath = result.files.single.path!;
      final imageBytes = await io.File(pngPath).readAsBytes();

      if (!mounted) return;

      final editedBytes = await openCropEditor(context, imageBytes);

      if (editedBytes != null) {
        await _processImport(editedBytes);
      }
    }
  }

  Future<void> _processImport(Uint8List editedBytes) async {
    if (_selectedEntry == null) return;

    bool regenerateThumb = false;
    if (_selectedEntry!.hasThumb) {
      if (!mounted) return;
      regenerateThumb = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Regenerate Thumbnail?'),
              content: const Text('Would you like to regenerate the thumbnail from the imported PNG?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
              ],
            ),
          ) ??
          false;
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
        originalUgctexPath: _selectedEntry!.ugctexPath,
      );

      setState(() => _status = 'Success! Backup in $backupDir');
      ref.invalidate(ugcEntriesProvider);
      _loadPreview(_selectedEntry!);
    } catch (e) {
      setState(() => _status = 'Import error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(ugcEntriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Texture Editor'),
        backgroundColor: Colors.black.withAlpha(128),
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
      body: Row(
        children: [
          // Sidebar: File list with opacity darken
          Container(
            width: 300,
            color: Colors.black.withAlpha(154),
            child: entriesAsync.when(
              data: (entries) => ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    title: Text(entry.displayName),
                    selected: _selectedEntry == entry,
                    selectedTileColor: Colors.blue.withAlpha(51),
                    onTap: () {
                      setState(() => _selectedEntry = entry);
                      _loadPreview(entry);
                    },
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.white24),
          // Main content: Preview and Actions
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: _isLoadingPreview
                        ? const CircularProgressIndicator()
                        : _previewBytes != null
                            ? Image.memory(_previewBytes!)
                            : const Text('Select a texture to preview'),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  color: Colors.black.withAlpha(179),
                  child: Column(
                    children: [
                      Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 60, minWidth: 180),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                textStyle: const TextStyle(fontSize: 18),
                              ),
                              icon: const Icon(Icons.download, size: 28),
                              label: const Text('Export PNG'),
                              onPressed: _selectedEntry == null || _isProcessing ? null : _exportPng,
                            ),
                          ),
                          const SizedBox(width: 24),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 60, minWidth: 180),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                textStyle: const TextStyle(fontSize: 18),
                              ),
                              icon: const Icon(Icons.upload, size: 28),
                              label: const Text('Import PNG'),
                              onPressed: _selectedEntry == null || _isProcessing ? null : _importPng,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
