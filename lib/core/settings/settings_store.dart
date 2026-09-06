import 'dart:convert';
import 'dart:io';

/// 应用级轻量设置持久化（settings.json，单层 JSON）。读写失败一律静默
/// 跳过：记住上次路径属于体验增强，任何 IO 问题都不应影响打开/保存主流程。
///
/// 现有字段：
/// - `lastOpenDir`（规格 R7）：文件选择器的初始目录。
/// - `customInstallDir`（探测 v2）：用户手动指定的 Apex 安装目录；
///   探测结果为空或用户明确指定时参与候选合并。
class SettingsStore {
  final String settingsPath;

  SettingsStore({required this.settingsPath});

  /// 「读取字符串字段」的纯函数部分：非法/缺失/空值一律返回 null。
  static String? _stringFieldFromJson(String contents, String key) {
    try {
      final data = jsonDecode(contents);
      if (data is! Map<String, dynamic>) return null;
      final v = data[key];
      return v is String && v.isNotEmpty ? v : null;
    } catch (_) {
      return null;
    }
  }

  static String? lastOpenDirFromJson(String contents) =>
      _stringFieldFromJson(contents, 'lastOpenDir');

  static String? customInstallDirFromJson(String contents) =>
      _stringFieldFromJson(contents, 'customInstallDir');

  String? _readField(String key) {
    try {
      final f = File(settingsPath);
      if (!f.existsSync()) return null;
      return _stringFieldFromJson(f.readAsStringSync(), key);
    } catch (_) {
      return null;
    }
  }

  /// 合并写入：保留文件里已有且合法的其它字段，避免多字段互相覆盖。
  void _writeField(String key, String value) {
    try {
      final f = File(settingsPath);
      Map<String, dynamic> merged = {};
      try {
        if (f.existsSync()) {
          final existing = jsonDecode(f.readAsStringSync());
          if (existing is Map<String, dynamic>) merged = existing;
        }
      } catch (_) {
        // 已有文件损坏：以本次写入为准，不抛异常。
      }
      merged[key] = value;
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(jsonEncode(merged), flush: true);
    } catch (_) {
      // 静默：持久化失败不影响主流程。
    }
  }

  String? readLastOpenDir() => _readField('lastOpenDir');

  void writeLastOpenDir(String dir) => _writeField('lastOpenDir', dir);

  String? readCustomInstallDir() => _readField('customInstallDir');

  void writeCustomInstallDir(String dir) => _writeField('customInstallDir', dir);
}
