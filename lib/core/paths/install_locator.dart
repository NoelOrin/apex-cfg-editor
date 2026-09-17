import 'dart:io';

// 探测引擎 v2：统一产出 ApexInstall 列表。配置文件只从 Saved Games
// 读取，游戏目录只保留 EA App 与用户手动记忆目录。
//
// 平台专有访问（注册表、盘符枚举）经由 RegistryReader / DriveLister
// 抽象注入：生产传 win32 实现（windows_registry.dart），测试注入假实现，
// 保证全部探测逻辑在 macOS 上可测。文件系统存在性检查沿用 v1 先例
// （注入根 + existsSync），同样跨平台可测。

/// 注册表蜂巢视图（HKCU / HKLM）。
enum RegistryView { user, machine }

/// 安装来源，决定 [ApexInstall] 在结果列表中的优先级与 UI 展示。
enum InstallSource { videoconfigDoc, steam, eaApp, custom }

/// 注册表读取抽象。生产用 win32 实现；实现必须自吞异常（失败返回
/// null / 空列表），探测是尽力而为，注册表不可读不应让应用崩溃。
abstract class RegistryReader {
  String? readString(RegistryView view, String keyPath, String valueName);

  /// 立即子键名列表（用于卸载表枚举）。键不存在返回空列表。
  List<String> subKeys(RegistryView view, String keyPath);
}

/// 盘符枚举抽象（EA App 常见根目录候选按盘扫描）。
abstract class DriveLister {
  List<String> driveLetters();
}

/// 一个 Apex 安装（或 Saved Games 配置根候选）。
class ApexInstall {
  /// 安装目录（游戏根）；videoconfig 文档候选时为文档根。
  final String installDir;

  final InstallSource source;

  /// videoconfig.txt 完整路径，仅 Saved Games 配置根候选携带。
  final String? videoconfigPath;

  /// settings.cfg 完整路径，仅 Saved Games 配置根候选携带。
  final String? settingsPath;

  /// autoexec 候选目录。存在即算（文件可缺失）；候选目录都不存在时
  /// 为第一个候选（`cfg`）——「可创建」位置。配置根候选为 null。
  final String? autoexecDir;

  /// autoexec.cfg 完整路径，文件存在时才有值。
  final String? autoexecPath;

  const ApexInstall({
    required this.installDir,
    required this.source,
    this.videoconfigPath,
    this.settingsPath,
    this.autoexecDir,
    this.autoexecPath,
  });
}

/// 探测器。注册表 / 盘符 / 环境变量均可注入（测试假实现），文件系统
/// 检查走真实 IO 但只探测注入根推导出的路径。
class InstallLocator {
  final RegistryReader registry;
  final DriveLister drives;

  /// 平台环境变量（USERPROFILE）。测试注入合成环境；
  /// 生产传 [Platform.environment]。
  final Map<String, String?> env;

  InstallLocator({
    required this.registry,
    required this.drives,
    Map<String, String?>? env,
  }) : env = env ?? Platform.environment;

  static const _autoexecDirCandidates = ['cfg', 'global/cfg', 'r2/cfg'];
  static const _videoconfigRelative = 'Respawn/Apex/local/videoconfig.txt';
  static const _settingsRelative = 'Respawn/Apex/local/settings.cfg';
  static const _apexGameRelative = 'steamapps/common/Apex Legends';

  // ---- 候选根收集（平台探测层） ----

  /// 配置文件根：仅 `%USERPROFILE%\Saved Games`。
  List<String> configRoots() {
    final roots = <String>[];
    void add(String? base, String leaf) {
      if (base == null || base.isEmpty) return;
      final r = '${_norm(base)}/$leaf';
      if (!roots.contains(r)) roots.add(r);
    }

    // Apex 配置文件只从系统 Saved Games 目录探测，不再扫描 Documents /
    // OneDrive 等旧路径。
    add(env['USERPROFILE'], 'Saved Games');
    return roots;
  }

  /// EA App 注册表探测：卸载表（HKLM 64/32 位视图 + HKCU）里
  /// DisplayName 含 "Apex"（大小写不敏感）的条目的 InstallLocation。
  List<String> eaRegistryRoots() {
    const uninstallBase =
        r'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall';
    const uninstallBase32 =
        r'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall';
    final roots = <String>[];
    for (final (view, base) in [
      (RegistryView.machine, uninstallBase),
      (RegistryView.machine, uninstallBase32),
      (RegistryView.user, uninstallBase),
    ]) {
      for (final sub in registry.subKeys(view, base)) {
        final name = registry
            .readString(view, '$base\\$sub', 'DisplayName')
            ?.toLowerCase();
        if (name == null || !name.contains('apex')) continue;
        final loc = registry.readString(view, '$base\\$sub', 'InstallLocation');
        if (loc == null || loc.isEmpty) continue;
        final r = _norm(loc);
        if (!roots.any((x) => x.toLowerCase() == r.toLowerCase())) {
          roots.add(r);
        }
      }
    }
    return roots;
  }

  /// EA App 常见根目录候选：Program Files 固定路径 + 各盘符根下的
  /// EA Games / Origin Games / 纯目录变体。
  List<String> eaCommonRoots() {
    final roots = <String>['C:/Program Files/EA Games/Apex Legends'];
    roots.add('C:/Program Files/Origin Games/Apex Legends');
    for (final d in drives.driveLetters()) {
      roots.add('$d:/EA Games/Apex Legends');
      roots.add('$d:/Origin Games/Apex Legends');
      roots.add('$d:/Apex Legends');
    }
    return roots;
  }

  // ---- 纯逻辑层（候选根 → 去重安装列表） ----

  /// 把候选安装目录列表转成 [ApexInstall]：目录必须真实存在；对每个
  /// 目录探测 autoexec 候选目录（存在即算，文件可缺失；都不存在时取
  /// 第一个候选作为可创建位置）；按归一化路径去重（大小写与分隔符
  /// 不敏感），保留首次出现的原始写法。
  List<ApexInstall> installsFromInstallDirs(
    List<String> dirs, {
    InstallSource source = InstallSource.custom,
  }) {
    final seen = <String>{};
    final result = <ApexInstall>[];
    for (final dir in dirs) {
      final norm = _norm(dir);
      if (!seen.add(norm.toLowerCase())) continue;
      if (!Directory(norm).existsSync()) continue;
      String? autoexecDir;
      for (final cand in _autoexecDirCandidates) {
        final d = '$norm/$cand';
        if (Directory(d).existsSync()) {
          autoexecDir = d;
          break;
        }
      }
      autoexecDir ??= '$norm/${_autoexecDirCandidates.first}';
      final autoexecFile = File('$autoexecDir/autoexec.cfg');
      result.add(
        ApexInstall(
          installDir: norm,
          source: source,
          autoexecDir: autoexecDir,
          autoexecPath: autoexecFile.existsSync() ? autoexecFile.path : null,
        ),
      );
    }
    return result;
  }

  /// 完整探测：Saved Games 配置根 + EA App 安装目录；两者都为空时
  /// 才回退用户手动记忆的目录。不再扫描 Steam / Documents / OneDrive。
  List<ApexInstall> locate({String? customInstallDir}) {
    final installs = <ApexInstall>[];

    // 1. Saved Games 配置根：settings.cfg（操作设置）与
    // videoconfig.txt（游戏画质）均可命中。
    for (final doc in configRoots()) {
      final vc = '$doc/$_videoconfigRelative';
      final settings = '$doc/$_settingsRelative';
      final hasVideoconfig = File(vc).existsSync();
      final hasSettings = File(settings).existsSync();
      if (!hasVideoconfig && !hasSettings) continue;
      installs.add(
        ApexInstall(
          installDir: doc,
          source: InstallSource.videoconfigDoc,
          videoconfigPath: hasVideoconfig ? vc : null,
          settingsPath: hasSettings ? settings : null,
        ),
      );
    }

    // 2. EA App 安装目录（保留）：用于定位 autoexec.cfg。
    final eaRoots = [...eaRegistryRoots(), ...eaCommonRoots()];
    installs.addAll(
      installsFromInstallDirs(eaRoots, source: InstallSource.eaApp),
    );

    // 3. 用户手动记忆路径：自动探测全空时兜底。
    if (installs.isEmpty && customInstallDir != null) {
      final custom = _norm(customInstallDir);
      final nested = installsFromInstallDirs([
        '$custom/$_apexGameRelative',
      ], source: InstallSource.custom);
      installs.addAll(
        nested.isNotEmpty
            ? nested
            : installsFromInstallDirs([custom], source: InstallSource.custom),
      );
    }
    return installs;
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

/// 从「成功打开的文件所在目录」推导 Apex 安装根（探测 v2 的
/// customInstallDir 回写规则）：autoexec 的 cfg/global/r2 目录父级、
/// 或 `steamapps/common/Apex Legends` 树内 → 安装根；Saved Games
/// 配置根与其余任意目录都不是安装目录 → null。结果与
/// [InstallLocator.locate] 的 customInstallDir 语义对齐（可直接回填）。
String? apexInstallDirFromOpenedDir(String dirPath) {
  final dir = _normPath(dirPath);
  final segments = dir.split('/');

  // <install>/(cfg|global/cfg|r2/cfg) → <install>。长候选优先，
  // 否则 global/cfg 会被 'cfg' 先剥一半。
  for (final cand in const ['global/cfg', 'r2/cfg', 'cfg']) {
    final suffix = cand.split('/');
    if (segments.length > suffix.length) {
      final tail = segments.sublist(segments.length - suffix.length);
      if (tail.join('/').toLowerCase() == cand) {
        return segments.sublist(0, segments.length - suffix.length).join('/');
      }
    }
  }

  // Steam 安装树：根为 .../steamapps/common/Apex Legends（大小写不敏感）。
  for (var i = 0; i < segments.length; i++) {
    if (segments[i].toLowerCase() == 'apex legends') {
      return segments.sublist(0, i + 1).join('/');
    }
  }
  return null;
}

/// 归一化规则与 [InstallLocator._norm] 一致的顶层复用。
String _normPath(String p) {
  var r = p.replaceAll('\\', '/');
  while (r.length > 1 && r.endsWith('/')) {
    r = r.substring(0, r.length - 1);
  }
  return r;
}
