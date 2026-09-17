import 'dart:io';

import '../io/cfg_file_io.dart';

class ConfigDiagnosticsResult {
  final String configDir;
  final bool configDirExists;
  final bool configDirWritable;
  final CfgEncoding? encoding;
  final bool hasBadBytes;
  final DateTime? latestBackupTime;

  const ConfigDiagnosticsResult({
    required this.configDir,
    required this.configDirExists,
    required this.configDirWritable,
    required this.encoding,
    required this.hasBadBytes,
    required this.latestBackupTime,
  });
}

/// 对配置目录、当前打开文件和备份目录做只读诊断。
class ConfigDiagnosticsService {
  final String configDir;
  final String backupDir;
  final String? openFilePath;

  const ConfigDiagnosticsService({
    required this.configDir,
    required this.backupDir,
    required this.openFilePath,
  });

  ConfigDiagnosticsResult run() {
    final directory = Directory(configDir);
    final exists = configDir.isNotEmpty && directory.existsSync();
    return ConfigDiagnosticsResult(
      configDir: configDir,
      configDirExists: exists,
      configDirWritable: exists && _canWrite(directory),
      encoding: _encoding(),
      hasBadBytes: _hasBadBytes(),
      latestBackupTime: _latestBackupTime(),
    );
  }

  bool _canWrite(Directory directory) {
    final probe = File('${directory.path}/.apex-cfg-editor-write-test');
    try {
      probe.writeAsBytesSync(const <int>[], flush: true);
      probe.deleteSync();
      return true;
    } catch (_) {
      try {
        if (probe.existsSync()) probe.deleteSync();
      } catch (_) {}
      return false;
    }
  }

  CfgEncoding? _encoding() {
    final path = openFilePath;
    if (path == null) return null;
    try {
      return CfgFileIo.read(path).encoding;
    } catch (_) {
      return null;
    }
  }

  bool _hasBadBytes() {
    final path = openFilePath;
    if (path == null) return false;
    try {
      return CfgFileIo.read(path).hasBadBytes;
    } catch (_) {
      return false;
    }
  }

  DateTime? _latestBackupTime() {
    final root = Directory(backupDir);
    if (!root.existsSync()) return null;
    DateTime? latest;
    for (final entity in root.listSync(recursive: true).whereType<File>()) {
      if (!entity.path.endsWith('.cfg')) continue;
      try {
        final modified = entity.statSync().modified;
        if (latest == null || modified.isAfter(latest)) latest = modified;
      } catch (_) {}
    }
    return latest;
  }
}
