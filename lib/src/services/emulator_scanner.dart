import 'dart:io' as io;
import 'package:path/path.dart' as p;
import '../models/emulator_path.dart';
import '../models/ugc_texture_entry.dart';
import 'os_path_provider.dart';

class EmulatorScanner {
  static const String gameId = '010051F0207B2000';

  Future<List<EmulatorPath>> scan() async {
    final List<EmulatorPath> results = [];

    // Eden
    await _scanEmulator(
      name: 'Eden',
      basePath: p.join(OSPathProvider.edenBasePath, 'nand', 'user', 'save', '0000000000000000'),
      results: results,
    );

    // Ryujinx
    await _scanEmulator(
      name: 'Ryujinx',
      basePath: p.join(OSPathProvider.ryujinxBasePath, 'bis', 'user', 'save'),
      results: results,
    );

    // Yuzu
    await _scanEmulator(
      name: 'Yuzu',
      basePath: p.join(OSPathProvider.yuzuBasePath, 'nand', 'user', 'save', '0000000000000000'),
      results: results,
    );

    return results;
  }

  Future<void> _scanEmulator({
    required String name,
    required String basePath,
    required List<EmulatorPath> results,
  }) async {
    final dir = io.Directory(basePath);
    if (!await dir.exists()) return;

    try {
      final userDirs = dir.listSync().whereType<io.Directory>();
      for (final userDir in userDirs) {
        final userId = p.basename(userDir.path);
        
        // Check for gameId folder
        final gameDir = io.Directory(p.join(userDir.path, gameId));
        if (!await gameDir.exists()) continue;

        // Check for UGC or Ugc or ugc
        final candidates = ['UGC', 'Ugc', 'ugc'];
        for (final c in candidates) {
          final ugcPath = p.join(gameDir.path, c);
          final ugcDir = io.Directory(ugcPath);
          if (await ugcDir.exists()) {
            results.add(EmulatorPath(
              emulatorName: name,
              path: ugcDir.path,
              userId: userId,
            ));
            break;
          }
        }
      }
    } catch (e) {
      // Ignore directory access errors
    }
  }

  static List<UgcTextureEntry> scanFolder(String folderPath) {
    final dir = io.Directory(folderPath);
    if (!dir.existsSync()) return [];

    const ugctexSuffix = '.ugctex.zs';
    const thumbSuffix = '_Thumb_ugctex.zs';
    const canvasSuffix = '.canvas.zs';

    final allFiles = dir
        .listSync()
        .whereType<io.File>()
        .where((f) => f.path.toLowerCase().endsWith('.zs'))
        .toList();

    final mainFiles = allFiles
        .where((f) => f.path.toLowerCase().endsWith(ugctexSuffix) &&
                      !f.path.toLowerCase().contains('_thumb'))
        .toList();

    final filesByLowerName = {
      for (var f in allFiles) p.basename(f.path).toLowerCase(): f.path
    };

    final entries = <UgcTextureEntry>[];
    for (final mainFile in mainFiles) {
      final fileName = p.basename(mainFile.path);
      final stem = fileName.substring(0, fileName.length - ugctexSuffix.length);

      final thumbName = (stem + thumbSuffix).toLowerCase();
      final canvasName = (stem + canvasSuffix).toLowerCase();

      entries.add(UgcTextureEntry(
        stem: stem,
        ugctexPath: mainFile.path,
        thumbPath: filesByLowerName[thumbName],
        canvasPath: filesByLowerName[canvasName],
        directory: folderPath,
      ));
    }

    entries.sort((a, b) => a.stem.toLowerCase().compareTo(b.stem.toLowerCase()));
    return entries;
  }
}
