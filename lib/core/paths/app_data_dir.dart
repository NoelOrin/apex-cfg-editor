import 'dart:io';

/// 应用数据目录：Windows 为 `%APPDATA%\ApexCfgEditor`；APPDATA 缺失
/// （macOS 开发期 / 测试环境）兜底系统临时目录。BackupService 备份根
/// 目录与 settings.json 同源推导自这里，保证同机部署位置一致。
String appDataDir() {
  final appData = Platform.environment['APPDATA'];
  return '${appData ?? Directory.systemTemp.path}/ApexCfgEditor';
}
