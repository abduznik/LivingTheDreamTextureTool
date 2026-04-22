import 'dart:io' as io;
import 'package:path/path.dart' as p;
import '../models/ugc_texture_entry.dart';

class BackupService {
  static Future<String> backupEntry(UgcTextureEntry entry) async {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}';
    final backupDirName = 'backup_$timestamp';
    final backupPath = p.join(entry.directory, 'backups', backupDirName);

    final dir = io.Directory(backupPath);
    await dir.create(recursive: true);

    await _copyIfExist(entry.ugctexPath, p.join(backupPath, p.basename(entry.ugctexPath)));
    if (entry.thumbPath != null) {
      await _copyIfExist(entry.thumbPath!, p.join(backupPath, p.basename(entry.thumbPath!)));
    }
    if (entry.canvasPath != null) {
      await _copyIfExist(entry.canvasPath!, p.join(backupPath, p.basename(entry.canvasPath!)));
    }

    return backupPath;
  }

  static Future<void> _copyIfExist(String src, String dst) async {
    final file = io.File(src);
    if (await file.exists()) {
      await file.copy(dst);
    }
  }
}
