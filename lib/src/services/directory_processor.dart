import 'dart:io' as io;
import 'package:path/path.dart' as p;
import '../models/vrs_texture_entry.dart';
import 'log_service.dart';

class DirectoryProcessor {
  static List<VrsTextureEntry> scanFolder(String folderPath) {
    try {
      // Defensive: Ensure we always work with absolute paths for the Sandbox bridge
      final absolutePath = p.absolute(folderPath);
      final rootDir = io.Directory(absolutePath);
      
      if (!rootDir.existsSync()) {
        LogService.log("Directory does not exist: $absolutePath");
        return [];
      }

      const ugctexSuffix = '.ugctex.zs';
      const thumbSuffix = '_Thumb_ugctex.zs';
      const canvasSuffix = '.canvas.zs';

      final List<io.File> allFiles = [];

      void scan(io.Directory dir) {
        for (final entity in dir.listSync(recursive: false, followLinks: false)) {
          if (entity is io.Directory) {
            final name = p.basename(entity.path);
            if (name != 'UTT_Backups' && name != 'Backup') {
              scan(entity);
            }
          } else if (entity is io.File) {
            final pathLower = entity.path.toLowerCase();
            if (pathLower.endsWith('.zs')) {
              allFiles.add(entity);
            }
          }
        }
      }

      scan(rootDir);
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
    } on io.PathAccessException catch (e) {
      LogService.log('macOS Sandbox Access Exception: $e');
      // Rethrow so the UI can detect 'Operation not permitted'
      rethrow;
    } catch (e) {
      LogService.log("Scan failed for $folderPath: $e");
      return []; 
    }
  }
}
