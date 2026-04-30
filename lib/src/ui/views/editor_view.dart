import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../models/vrs_texture_entry.dart';
import '../../providers/app_providers.dart';
import '../../services/backup_service.dart';
import '../../services/texture_processor.dart';
import '../../services/log_service.dart';
import '../utils/image_editor_helper.dart';
import 'settings_view.dart';

class EditorView extends ConsumerStatefulWidget {
  const EditorView({super.key});

  @override
  ConsumerState<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends ConsumerState<EditorView> {
  VrsTextureEntry? _selectedEntry;
  bool _isProcessing = false;
  String _status = '';
  Future<img.Image>? _previewFuture;
  bool _isAccessDenied = false;

  @override
  void initState() {
    super.initState();
    if (io.Platform.isMacOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkInitialAccess();
      });
    }
  }

  Future<void> _checkInitialAccess() async {
    final path = ref.read(selectedPathProvider);
    if (path != null) {
      try {
        final absolutePath = p.absolute(path);
        final dir = io.Directory(absolutePath);
        dir.listSync();
        if (mounted) setState(() => _isAccessDenied = false);
      } catch (e) {
        if (e is io.PathAccessException || e.toString().contains('Operation not permitted')) {
          LogService.log('Sandbox Check: Access Denied for $path');
          if (mounted) setState(() => _isAccessDenied = true);
        }
      }
    }
  }

  Future<void> _authorizeFolder() async {
    final savedPath = ref.read(selectedPathProvider);
    if (savedPath == null) return;

    String? selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Authorize Folder Access',
      initialDirectory: savedPath,
    );

    if (selectedDirectory != null) {
      LogService.log('Folder Authorized: $selectedDirectory');
      if (mounted) {
        setState(() {
          _status = 'Folder Authorized!';
          _isAccessDenied = false;
        });
      }
      ref.read(vrsEntriesProvider.notifier).refresh();
    }
  }

  Future<void> _loadPreview(VrsTextureEntry entry) async {
    setState(() {
      _selectedEntry = entry;
      _status = 'Loading preview...';
      _previewFuture = TextureProcessor.decodeFile(entry.vrsPath);
    });

    try {
      await _previewFuture;
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

    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp', 'tga', 'tiff'],
        allowMultiple: false,
        withReadStream: false,
      );
    } catch (e) {
      LogService.log('FilePicker error: $e');
      setState(() => _status = 'Picker Error: Please install a file manager to browse files.');
      return;
    }

    if (result == null || result.files.single.path == null) {
      setState(() => _status = 'Import cancelled.');
      return;
    }

    final absolutePickedPath = p.absolute(result.files.single.path!);
    final newImageBytes = await io.File(absolutePickedPath).readAsBytes();
    if (!mounted) return;
    final editedBytes = await openCropEditor(context, newImageBytes);

    if (editedBytes == null) {
      setState(() => _status = 'Cropping cancelled.');
      return;
    }

    bool regenerateThumb = _selectedEntry!.hasThumb;
    if (_selectedEntry!.hasThumb) {
      if (!mounted) return;
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Regenerate Thumbnail?'),
          content: const Text('Do you want to regenerate the thumbnail from the new image?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
          ],
        ),
      );
      regenerateThumb = choice ?? false;
    }

    setState(() => _isProcessing = true);
    setState(() => _status = 'Backing up original...');
    await BackupService.backupEntry(_selectedEntry!);
    setState(() => _status = 'Importing...');

    try {
      final absoluteDestStem = p.join(_selectedEntry!.directory, _selectedEntry!.stem);
      LogService.log('Starting import to: $absoluteDestStem');
      
      await TextureProcessor.importImage(
        imageBytes: editedBytes,
        destStem: absoluteDestStem,
        writeThumb: regenerateThumb,
        writeCanvas: _selectedEntry!.hasCanvas,
        originalVrsPath: _selectedEntry!.vrsPath,
      );

      if (!mounted) return;
      setState(() => _status = 'Successfully imported!');
      ref.invalidate(vrsEntriesProvider);
      _loadPreview(_selectedEntry!);
    } catch (e) {
      LogService.log('Import error: $e');
      if (!mounted) return;
      setState(() => _status = 'Error: Ensure UTT has folder access.');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(vrsEntriesProvider);

    ref.listen(vrsEntriesProvider, (previous, next) {
      if (next is AsyncError) {
        final errorStr = next.error.toString();
        if (errorStr.contains('Operation not permitted') || errorStr.contains('Security Access')) {
          if (!_isAccessDenied) {
            setState(() => _isAccessDenied = true);
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Texture Editor'),
        backgroundColor: Colors.black45,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh List',
            onPressed: () => ref.read(vrsEntriesProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
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
                    selectedTileColor: Colors.blue.withValues(alpha: 0.2),
                    onTap: () {
                      _loadPreview(entry);
                    },
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, color: Colors.orange, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Access Restricted',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _authorizeFolder,
                        child: const Text('Unlock Folder Access'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black26,
              child: _isAccessDenied 
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_open, color: Colors.orange, size: 64),
                        const SizedBox(height: 24),
                        const Text(
                          'Authorize Ryujinx Folder Access',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'macOS requires one-time permission to access the selected directory.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _authorizeFolder,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Unlock Access'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                children: [
                  Expanded(
                    child: _selectedEntry == null
                        ? const Center(child: Text('Select a texture to edit', style: TextStyle(color: Colors.white54)))
                        : FutureBuilder<img.Image>(
                            future: _previewFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return Center(child: Text('Error: ${snapshot.error}'));
                              }
                              if (!snapshot.hasData) {
                                return const Center(child: Text('No data'));
                              }
                              return Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      Image.memory(
                                        Uint8List.fromList(img.encodePng(snapshot.data!)),
                                        filterQuality: FilterQuality.none,
                                      ),
                                      const SizedBox(height: 16),
                                      if (_selectedEntry!.hasThumb) ...[
                                        const Text('Thumbnail Preview:', style: TextStyle(color: Colors.white70)),
                                        FutureBuilder(
                                          future: TextureProcessor.decodeFile(_selectedEntry!.thumbPath!),
                                          builder: (context, thumbSnap) {
                                            if (!thumbSnap.hasData) return const SizedBox();
                                            return Image.memory(
                                              Uint8List.fromList(img.encodePng(thumbSnap.data!)),
                                            );
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black45,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _status.isEmpty ? 'Waiting for selection...' : _status,
                            style: const TextStyle(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_selectedEntry != null) ...[
                          FutureBuilder<img.Image>(
                            future: _previewFuture,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              return ElevatedButton.icon(
                                onPressed: () => TextureProcessor.exportToPng(snapshot.data!, _selectedEntry!.vrsPath),
                                icon: const Icon(Icons.download),
                                label: const Text('Export PNG'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade800,
                                  foregroundColor: Colors.white,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _importTexture,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Import Image'),
                          ),
                        ],
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
