import 'dart:convert';
import 'dart:io';

/// 应用级轻量设置持久化（settings.json，单层 JSON）。读写失败一律静默
/// 跳过：记住上次路径属于体验增强，任何 IO 问题都不应影响打开/保存主流程。
///
/// 现有字段：
/// - `lastOpenDir`（规格 R7）：文件选择器的初始目录。
/// - `customInstallDir`（探测 v2）：用户手动指定的 Apex 安装目录；
///   探测结果为空或用户明确指定时参与候选合并。
/// - `themeMode`（酸性风格 v2）：亮/暗主题模式，值为小写枚举名
///   （'system' / 'light' / 'dark'）；原始字符串存取，枚举映射在
///   UI 层（theme_mode_scope.dart），本类保持纯 Dart 可测。
/// - `locale`：界面语言模式，值为 'system' / 'zh' / 'en'；非法值由
///   调用方回退到跟随系统，本类只负责原始字符串持久化。
class SettingsStore {
  static const int defaultBackupLimit = 20;
  static const int minBackupLimit = 1;
  static const int maxBackupLimit = 100;

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

  static String? themeModeRawFromJson(String contents) =>
      _stringFieldFromJson(contents, 'themeMode');

  static String? localeRawFromJson(String contents) =>
      _stringFieldFromJson(contents, 'locale');

  dynamic _readValue(String key) {
    try {
      final f = File(settingsPath);
      if (!f.existsSync()) return null;
      final data = jsonDecode(f.readAsStringSync());
      return data is Map<String, dynamic> ? data[key] : null;
    } catch (_) {
      return null;
    }
  }

  String? _readField(String key) {
    final value = _readValue(key);
    return value is String && value.isNotEmpty ? value : null;
  }

  /// 合并写入：保留文件里已有且合法的其它字段，避免多字段互相覆盖。
  void _writeField(String key, Object? value) {
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

  void writeCustomInstallDir(String dir) =>
      _writeField('customInstallDir', dir);

  /// 主题模式（酸性风格 v2）：原始字符串（'light' / 'dark' / 'system'），
  /// 非法值由调用方映射为 null → 回退默认暗色。
  String? readThemeModeRaw() => _readField('themeMode');

  void writeThemeModeRaw(String value) => _writeField('themeMode', value);

  /// 界面语言模式：原始字符串（'system' / 'zh' / 'en'）。
  String? readLocaleRaw() => _readField('locale');

  void writeLocaleRaw(String value) => _writeField('locale', value);

  String? readLastOpenFile() => _readField('lastOpenFile');

  void writeLastOpenFile(String path) => _writeField('lastOpenFile', path);

  bool _readBool(String key, {required bool fallback}) {
    final value = _readValue(key);
    return value is bool ? value : fallback;
  }

  int _readInt(
    String key, {
    required int fallback,
    required int min,
    required int max,
  }) {
    final value = _readValue(key);
    if (value is! int) return fallback;
    return value.clamp(min, max);
  }

  bool readAutoDetectOnStartup() =>
      _readBool('autoDetectOnStartup', fallback: true);

  void writeAutoDetectOnStartup(bool value) =>
      _writeField('autoDetectOnStartup', value);

  String readPreferredOpenKind() {
    final value = _readField('preferredOpenKind');
    return value == 'autoexec' || value == 'videoconfig' ? value! : 'settings';
  }

  void writePreferredOpenKind(String value) =>
      _writeField('preferredOpenKind', value);

  bool readReopenLastFile() => _readBool('reopenLastFile', fallback: false);

  void writeReopenLastFile(bool value) => _writeField('reopenLastFile', value);

  bool readAutoCreateMissingTemplate() =>
      _readBool('autoCreateMissingTemplate', fallback: false);

  void writeAutoCreateMissingTemplate(bool value) =>
      _writeField('autoCreateMissingTemplate', value);

  bool readBackupEnabled() => _readBool('backupEnabled', fallback: true);

  void writeBackupEnabled(bool value) => _writeField('backupEnabled', value);

  int readBackupLimit() => _readInt(
    'backupLimit',
    fallback: defaultBackupLimit,
    min: minBackupLimit,
    max: maxBackupLimit,
  );

  void writeBackupLimit(int value) =>
      _writeField('backupLimit', value.clamp(minBackupLimit, maxBackupLimit));

  String? readBackupDir() => _readField('backupDir');

  void writeBackupDir(String dir) => _writeField('backupDir', dir);

  /// 只删除应用设置文件，不触碰配置文件或备份。
  void reset() {
    try {
      final file = File(settingsPath);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // 静默：恢复默认失败不影响编辑器继续运行。
    }
  }
}
