import 'dart:convert';
import 'dart:io';

/// 应用级轻量设置持久化（settings.json，单层 JSON）。读写失败一律静默
/// 跳过：记住上次路径属于体验增强，任何 IO 问题都不应影响打开/保存主流程。
class SettingsStore {
  final String settingsPath;

  SettingsStore({required this.settingsPath});

  /// 「读取 lastOpenDir」的纯函数部分：非法/缺失/空值一律返回 null。
  static String? lastOpenDirFromJson(String contents) {
    try {
      final data = jsonDecode(contents);
      if (data is! Map<String, dynamic>) return null;
      final v = data['lastOpenDir'];
      return v is String && v.isNotEmpty ? v : null;
    } catch (_) {
      return null;
    }
  }

  String? readLastOpenDir() {
    try {
      final f = File(settingsPath);
      if (!f.existsSync()) return null;
      return lastOpenDirFromJson(f.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  void writeLastOpenDir(String dir) {
    try {
      final f = File(settingsPath);
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(jsonEncode({'lastOpenDir': dir}), flush: true);
    } catch (_) {
      // 静默：持久化失败不影响主流程。
    }
  }
}
