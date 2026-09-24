import 'dart:io';

// 探测引擎 v3：只找配置文件，不扫游戏安装目录。
// 真实位置只有 Saved Games；用户手动指定的是「配置目录」（可指向
// local 本身、Respawn/Apex、或 Saved Games 根）。安装目录下没有
// settings.cfg / videoconfig.txt，注册表 / 盘符 / EA 路径全部移除。

/// 配置来源，决定 [ApexInstall] 在结果列表中的优先级与 UI 展示。
enum InstallSource { savedGames, custom }

/// 一个配置根候选（包含 settings.cfg / videoconfig.txt 的 local 目录）。
class ApexInstall {
  /// 配置目录（即 local 目录本身）。
  final String configDir;

  final InstallSource source;

  /// videoconfig.txt 完整路径，仅文件存在时携带。
  final String? videoconfigPath;

  /// settings.cfg 完整路径，仅文件存在时携带。
  final String? settingsPath;

  const ApexInstall({
    required this.configDir,
    required this.source,
    this.videoconfigPath,
    this.settingsPath,
  });
}

/// 探测器。环境变量可注入（测试合成环境），文件系统检查走真实 IO
/// 但只探测推导出的配置目录。
class InstallLocator {
  /// 平台环境变量（USERPROFILE）。测试注入合成环境；
  /// 生产传 [Platform.environment]。
  final Map<String, String?> env;

  InstallLocator({Map<String, String?>? env})
    : env = env ?? Platform.environment;

  static const _localRelative = 'Respawn/Apex/local';

  /// Saved Games 配置目录：`%USERPROFILE%\Saved Games\Respawn\Apex\local`。
  List<String> savedGamesConfigDirs() {
    final roots = <String>[];
    final home = env['USERPROFILE'];
    if (home == null || home.isEmpty) return roots;
    roots.add('${_norm(home)}/Saved Games/$_localRelative');
    return roots;
  }

  /// 把「配置目录」列表转成 [ApexInstall]：至少存在 settings.cfg 或
  /// videoconfig.txt 才算候选；按归一化路径去重（大小写与分隔符不敏感）。
  /// 用户指定目录 → 可能的 local 配置目录。目录本身是 local、其下有
  /// `Respawn/Apex/local`、或它是 `Respawn/Apex`（补 `local`）均可命中。
  List<String> configDirsFromCustom(String customDir) {
    final custom = _norm(customDir);
    return [
      custom, // 指向 local 本身
      '$custom/$_localRelative', // 指向 Saved Games / 任意包含 Respawn 的根
      '$custom/local', // 指向 Respawn/Apex
    ];
  }

  /// 完整探测：Saved Games 配置目录 + 用户指定配置目录（无条件合并，
  /// 跨来源去重且 Saved Games 优先，不再以「自动探测为空」为门槛）。
  /// 只产出带 settings.cfg / videoconfig.txt 的候选。
  List<ApexInstall> locate({String? customConfigDir}) {
    final seen = <String>{};
    final result = <ApexInstall>[];

    void collect(List<String> dirs, InstallSource source) {
      for (final dir in dirs) {
        final norm = _norm(dir);
        if (!seen.add(norm.toLowerCase())) continue;
        final settingsFile = File('$norm/settings.cfg');
        final videoFile = File('$norm/videoconfig.txt');
        final hasSettings = settingsFile.existsSync();
        final hasVideo = videoFile.existsSync();
        if (!hasSettings && !hasVideo) continue;
        result.add(
          ApexInstall(
            configDir: norm,
            source: source,
            settingsPath: hasSettings ? settingsFile.path : null,
            videoconfigPath: hasVideo ? videoFile.path : null,
          ),
        );
      }
    }

    collect(savedGamesConfigDirs(), InstallSource.savedGames);
    if (customConfigDir != null && customConfigDir.isNotEmpty) {
      collect(configDirsFromCustom(customConfigDir), InstallSource.custom);
    }
    return result;
  }

  /// 归一化：反斜杠 → 正斜杠，去掉尾部分隔符。去重比较另行小写。
  static String _norm(String p) {
    var r = p.replaceAll('\\', '/');
    while (r.length > 1 && r.endsWith('/')) {
      r = r.substring(0, r.length - 1);
    }
    return r;
  }
}


