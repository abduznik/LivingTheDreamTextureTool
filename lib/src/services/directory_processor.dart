import 'dart:io' as io;
import 'package:path/path.dart' as p;
import '../models/vrs_texture_entry.dart';
import 'log_service.dart';

class DirectoryProcessor {
  static List<VrsTextureEntry> scanFolder(String folderPath) {
    final absolutePath = p.absolute(folderPath);
    final rootDir = io.Directory(absolutePath);
    if (!rootDir.existsSync()) return [];

    const ugctexSuffix = '.ugctex.zs';
    const thumbSuffix = '_Thumb_ugctex.zs';
    const canvasSuffix = '.canvas.zs';

    // Recursive scan to find all .zs files
    final List<io.File> allFiles = [];
    try {
      if (!rootDir.existsSync()) return [];
      
      allFiles.addAll(
        rootDir
            .listSync(recursive: true, followLinks: false)
            .whereType<io.File>()
            .where((f) {
          final pathLower = f.path.toLowerCase();
          return pathLower.endsWith('.zs') &&
              !pathLower.contains('backups') &&
              !pathLower.contains('utt_backups');
        }),
      );
    } on io.PathAccessException catch (e) {
      LogService.log('macOS/Security Access Exception: $e. Folder might be locked.');
      return []; // Return empty instead of hanging
    } catch (e) {
      // Handle potential permission errors during recursive scan
      LogService.log('Error scanning directory $folderPath: $e');
      return [];
    }

    // Group files by their directory to handle multiple texture folders
    final mainFiles = allFiles
        .where((f) => f.path.toLowerCase().endsWith(ugctexSuffix) &&
                      !f.path.toLowerCase().contains('_thumb'))
        .toList();

    final entries = <VrsTextureEntry>[];
    
    for (final mainFile in mainFiles) {
      final directoryPath = p.dirname(mainFile.path);
      final fileName = p.basename(mainFile.path);
      final stem = fileName.substring(0, fileName.length - ugctexSuffix.length);

      final thumbName = (stem + thumbSuffix).toLowerCase();
      final canvasName = (stem + canvasSuffix).toLowerCase();

      // Look for related files in the same directory as the main file
      String? thumbPath;
      String? canvasPath;

      for (final file in allFiles) {
        if (p.dirname(file.path) == directoryPath) {
          final base = p.basename(file.path).toLowerCase();
          if (base == thumbName) thumbPath = file.path;
          if (base == canvasName) canvasPath = file.path;
        }
      }

      entries.add(VrsTextureEntry(
        stem: stem,
        vrsPath: mainFile.path,
        thumbPath: thumbPath,
        canvasPath: canvasPath,
        directory: directoryPath,
      ));
    }

    entries.sort((a, b) => a.stem.toLowerCase().compareTo(b.stem.toLowerCase()));
    return entries;
  }
}
