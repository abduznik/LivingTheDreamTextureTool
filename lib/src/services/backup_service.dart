import 'dart:io' as io;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/vrs_texture_entry.dart';
import 'log_service.dart';

class BackupService {
  static Future<String> backupEntry(VrsTextureEntry entry) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final parentDir = entry.directory;
    String backupPath = p.join(parentDir, 'UTT_Backups', '${entry.stem}_$timestamp');
    bool isTempFallback = false;
    
    try {
      final dir = io.Directory(backupPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      if (io.Platform.isMacOS && e is io.PathAccessException) {
        LogService.log('Primary backup location failed, falling back to temp: $e');
        final tempDir = await getTemporaryDirectory();
        backupPath = p.join(tempDir.path, 'UTT_Backups', '${entry.stem}_$timestamp');
        isTempFallback = true;
        final dir = io.Directory(backupPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } else {
        rethrow;
      }
    }

    await _copyIfExist(entry.vrsPath, p.join(backupPath, p.basename(entry.vrsPath)));
    if (entry.thumbPath != null) {
      await _copyIfExist(entry.thumbPath!, p.join(backupPath, p.basename(entry.thumbPath!)));
    }
    if (entry.canvasPath != null) {
      await _copyIfExist(entry.canvasPath!, p.join(backupPath, p.basename(entry.canvasPath!)));
    }

    return isTempFallback ? 'TEMP_FALLBACK:$backupPath' : backupPath;
  }

  static Future<void> _copyIfExist(String src, String dest) async {
    final absSrc = p.absolute(src);
    final absDest = p.absolute(dest);
    final file = io.File(absSrc);
    if (await file.exists()) {
      await file.copy(absDest);
    }
  }
}
