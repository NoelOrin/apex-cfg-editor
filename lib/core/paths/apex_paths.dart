import 'dart:io';

/// 定位 Apex 的 videoconfig.txt 与 autoexec.cfg。
///
/// 可注入 [homeDir] 便于测试；生产传 Platform.environment['USERPROFILE']。
/// 所有文件系统访问都经由注入根推导，保证非 Windows 平台可测；
/// 找不到时返回 null，由 UI 退回手动选择（规格 §9，
/// EA App 安装的玩家同样走此兜底）。
class ApexPathFinder {
  final String homeDir;
  ApexPathFinder({required this.homeDir});

  static const _autoexecRelative =
      'steamapps/common/Apex Legends/global/cfg/autoexec.cfg';

  /// videoconfig.txt 固定位于 Documents/Respawn/Apex/local。
  String? findVideoconfig() {
    final p = '$homeDir/Documents/Respawn/Apex/local/videoconfig.txt';
    return File(p).existsSync() ? p : null;
  }

  /// autoexec.cfg 按库探测：候选 = homeDir 相对推导的 Steam 主库根
  /// + 各 steamapps/libraryfolders.vdf 中解析出的全部 "path" 条目
  /// （vdf 中 Windows 路径的反斜杠转义 `\\` 还原为 `/`），去重后逐个
  /// 探测，命中即返回。
  ///
  /// 取舍：注入模式下无法探测 homeDir 之外的绝对位置（如用户目录在
  /// 非系统盘而 Steam 在 C:\Program Files (x86)\Steam）。生产 Windows
  /// 上由 vdf 兜底——vdf 自身就包含主库及其余全部库的 path，只要任一
  /// 主库根可达即可覆盖所有库；全部落空则返回 null 走手动选择。
  String? findAutoexec() {
    final roots = <String>[
      '$homeDir/Steam',
      '$homeDir/../Program Files (x86)/Steam',
      '$homeDir/../Program Files/Steam',
    ];
    final candidates = <String>[];
    void add(String c) {
      if (!candidates.contains(c)) candidates.add(c);
    }

    for (final root in roots) {
      add(root);
    }
    final pathRegex = RegExp(r'"path"\s+"([^"]+)"');
    for (final root in roots) {
      final vdf = File('$root/steamapps/libraryfolders.vdf');
      if (!vdf.existsSync()) continue;
      // 损坏/非法 UTF-8 的 vdf 跳过（不抛异常），继续探测其余库。
      String content;
      try {
        content = vdf.readAsStringSync();
      } catch (_) {
        continue;
      }
      for (final m in pathRegex.allMatches(content)) {
        add(m.group(1)!.replaceAll('\\\\', '/'));
      }
    }
    for (final lib in candidates) {
      final p = '$lib/$_autoexecRelative';
      if (File(p).existsSync()) return p;
    }
    return null;
  }
}
