import 'dart:io' as io;
import 'package:path/path.dart' as p;
import '../models/vrs_texture_entry.dart';

class BackupService {
  static Future<String> backupEntry(VrsTextureEntry entry) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final parentDir = p.dirname(entry.directory);
    final backupPath = p.join(parentDir, 'UTT_Backups', '${entry.stem}_$timestamp');
    
    final dir = io.Directory(backupPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await _copyIfExist(entry.vrsPath, p.join(backupPath, p.basename(entry.vrsPath)));
    if (entry.thumbPath != null) {
      await _copyIfExist(entry.thumbPath!, p.join(backupPath, p.basename(entry.thumbPath!)));
    }
    if (entry.canvasPath != null) {
      await _copyIfExist(entry.canvasPath!, p.join(backupPath, p.basename(entry.canvasPath!)));
    }

    return backupPath;
  }

  static Future<void> _copyIfExist(String src, String dest) async {
    final file = io.File(src);
    if (await file.exists()) {
      await file.copy(dest);
    }
  }
}
