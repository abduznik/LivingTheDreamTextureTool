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
  Future<img.Image>? _previewFuture;
  bool _isAuthorized = false;
  bool _isLinuxPortalReady = true;

  @override
  void initState() {
    super.initState();
    if (io.Platform.isLinux) {
      _checkLinuxPortal();
    }
  }

  Future<void> _checkLinuxPortal() async {
    try {
      final result = await io.Process.run('which', ['xdg-desktop-portal']);
      if (mounted) {
        setState(() => _isLinuxPortalReady = result.exitCode == 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLinuxPortalReady = false);
      }
    }
  }

  Future<void> _updatePermissionStatus() async {
    if (_selectedEntry == null) return;
    final isWritable = await TextureProcessor.checkDirectoryWritable(_selectedEntry!.directory);
    if (mounted) {
      setState(() => _isAuthorized = isWritable);
    }
  }

  Future<void> _authorizeFolder() async {
    if (_selectedEntry == null) return;

    // This triggers the native macOS "Open" dialog. 
    // When the user selects the folder, the Sandbox is 'punched through'.
    String? selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Authorize UTT to access this folder',
      initialDirectory: _selectedEntry!.directory,
    );
    
    if (selectedDirectory != null) {
      if (mounted) {
        setState(() => _status = 'Folder Authorized!');
      }
      await _updatePermissionStatus();
      // Retry the import immediately
      await _importTexture();
    }
  }

  void _showPermissionDialog({String? reason}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('macOS Permission Required'),
        content: Text(reason ?? 'To overwrite textures, macOS requires you to manually authorize the game folder. Please select the folder containing your .zs files in the next window.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _authorizeFolder();
            }, 
            child: const Text('Authorize Folder'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPreview(VrsTextureEntry entry) async {
    setState(() {
      _selectedEntry = entry;
      _status = 'Loading preview...';
      _previewFuture = TextureProcessor.decodeFile(entry.vrsPath);
    });

    await _updatePermissionStatus();

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
      // Linux/Fedora fix: Explicitly handle the picker result to avoid passing null to the cropper
      result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
    } on PlatformException catch (e) {
      debugPrint('UTT_DEBUG: Linux/macOS PlatformException: $e');
      if (io.Platform.isLinux) {
        if (mounted) {
          _showLinuxPortalDialog();
        }
        setState(() => _status = 'Portal Error: System picker failed.');
      } else {
        setState(() => _status = 'Picker Error: $e');
      }
      return;
    } catch (e) {
      debugPrint('UTT_DEBUG: FilePicker error: $e');
      setState(() => _status = 'Picker Error: $e');
      return;
    }

    if (result == null || result.files.single.path == null) {
      debugPrint('UTT_DEBUG: Picker returned null or was cancelled.');
      setState(() => _status = 'Import cancelled.');
      return;
    }

    // 2. Open Cropper
    final newImageBytes = await io.File(result.files.single.path!).readAsBytes();
    
    if (!mounted) return;
    final editedBytes = await openCropEditor(context, newImageBytes);

    if (editedBytes == null) {
      setState(() => _status = 'Cropping cancelled.');
      return;
    }

    // Show confirmation for thumb regeneration if it has one
    bool regenerateThumb = _selectedEntry!.hasThumb;
    if (_selectedEntry!.hasThumb) {
      if (!mounted) return;
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

    if (!mounted) return;
    // 3. Permission Override Check
    setState(() {
      _isProcessing = true;
      _status = 'Overwriting hardware texture...';
    });

    try {
      setState(() => _status = 'Backing up original...');
      var backupResult = await BackupService.backupEntry(_selectedEntry!);
      
      String backupStatus = 'Backup in $backupResult';
      if (backupResult.startsWith('TEMP_FALLBACK:')) {
        final actualPath = backupResult.replaceFirst('TEMP_FALLBACK:', '');
        backupStatus = 'Notice: Backup saved to system temp due to folder restrictions.';
        debugPrint('UTT_DEBUG: Backup saved to temp: $actualPath');
      }

      setState(() => _status = 'Processing texture...');

      final tempDir = io.Directory.systemTemp;
      final tempFile = io.File(p.join(tempDir.path, 'edited_import_${DateTime.now().millisecondsSinceEpoch}.png'));
      await tempFile.writeAsBytes(editedBytes);

      await TextureProcessor.importPng(
        pngPath: tempFile.path,
        destStem: p.join(_selectedEntry!.directory, _selectedEntry!.stem),
        writeThumb: regenerateThumb,
        writeCanvas: _selectedEntry!.hasCanvas,
        originalVrsPath: _selectedEntry!.vrsPath,
      );

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (!mounted) return;
      setState(() => _status = 'Successfully imported! $backupStatus');
      await _updatePermissionStatus();
      ref.invalidate(vrsEntriesProvider);
      _loadPreview(_selectedEntry!);
    } catch (e) {
      debugPrint('UTT_DEBUG: Import error: $e');
      if (io.Platform.isMacOS && (e.toString().contains('Permission denied') || e is io.PathAccessException)) {
        if (mounted) {
          _showPermissionDialog(reason: 'macOS requires one-time authorization to write to this folder. Please select the folder again to unlock it.');
        }
      }
      if (!mounted) return;
      setState(() => _status = 'Permission Error: Ensure UTT has folder access.');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showLinuxPortalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Linux System Picker failed'),
        content: const Text('The system file picker (portal) failed to open. This is common on some Fedora or KDE installations.\n\nPlease ensure "xdg-desktop-portal" and "xdg-desktop-portal-kde" (or -gnome) are installed.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildLinuxSystemChip() {
    if (!io.Platform.isLinux) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isLinuxPortalReady ? Colors.blue.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isLinuxPortalReady ? Colors.blue : Colors.orange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isLinuxPortalReady ? Icons.bolt : Icons.error_outline,
            color: _isLinuxPortalReady ? Colors.blue : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isLinuxPortalReady ? 'SYSTEM READY' : 'PORTAL MISSING',
            style: TextStyle(
              color: _isLinuxPortalReady ? Colors.blue : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionChip() {
    // Hide completely if not on macOS OR if no entry is selected yet
    if (!io.Platform.isMacOS || _selectedEntry == null) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: _isAuthorized ? null : _authorizeFolder,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isAuthorized ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _isAuthorized ? Colors.green : Colors.red),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isAuthorized ? Icons.check_circle : Icons.warning,
              color: _isAuthorized ? Colors.green : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _isAuthorized ? 'AUTHORIZED' : 'AUTHORIZE HERE',
              style: TextStyle(
                color: _isAuthorized ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
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
                    selectedTileColor: Colors.blue.withValues(alpha: 0.2),
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
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black45,
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                _status,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (io.Platform.isMacOS) ...[
                                const SizedBox(width: 8),
                                _buildPermissionChip(),
                              ],
                              if (io.Platform.isLinux) ...[
                                const SizedBox(width: 8),
                                _buildLinuxSystemChip(),
                              ],
                            ],
                          ),
                        ),
                        if (_selectedEntry != null) ...[
                          FutureBuilder(
                            future: TextureProcessor.decodeFile(_selectedEntry!.vrsPath),
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
