import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LogService {
  static io.File? _logFile;

  static Future<void> init() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _logFile = io.File(p.join(tempDir.path, 'utt_session.log'));
      // Clear previous session log
      if (await _logFile!.exists()) {
        await _logFile!.delete();
      }
      await _logFile!.create();
      log('UTT_DEBUG: Logger initialized at ${_logFile!.path}');
    } catch (e) {
      debugPrint('UTT_DEBUG: Failed to initialize log file: $e');
    }
  }

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final formattedMessage = '[$timestamp] $message';
    
    // Print to console
    debugPrint(formattedMessage);

    // Append to file
    if (_logFile != null) {
      try {
        _logFile!.writeAsStringSync('$formattedMessage\n', mode: io.FileMode.append, flush: true);
      } catch (e) {
        // Fallback if file write fails
      }
    }
  }

  static String get logPath => _logFile?.path ?? '';
  
  static Future<String> readLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      return await _logFile!.readAsString();
    }
    return 'No logs available.';
  }
}
