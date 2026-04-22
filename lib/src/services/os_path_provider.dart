import 'dart:io' as io;
import 'package:path/path.dart' as p;

class OSPathProvider {
  static String get homeDir {
    return io.Platform.environment['HOME'] ?? io.Platform.environment['USERPROFILE'] ?? '';
  }

  static String get appData {
    if (io.Platform.isWindows) {
      return io.Platform.environment['APPDATA'] ?? '';
    } else if (io.Platform.isLinux) {
      return p.join(homeDir, '.config');
    } else if (io.Platform.isMacOS) {
      return p.join(homeDir, 'Library', 'Application Support');
    }
    return '';
  }

  static String get localAppData {
    if (io.Platform.isWindows) {
      return io.Platform.environment['LOCALAPPDATA'] ?? '';
    }
    return appData;
  }

  static String get edenBasePath {
    return p.join(appData, 'eden');
  }

  static String get ryujinxBasePath {
    return p.join(appData, 'Ryujinx');
  }

  static String get yuzuBasePath {
    return p.join(appData, 'yuzu');
  }
}
