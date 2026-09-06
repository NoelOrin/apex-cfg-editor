import 'dart:io';

// 探测引擎 v2：统一产出 ApexInstall 列表（探测引擎 v1 ApexPathFinder 的
// 继任者，覆盖 EA App / OneDrive / 自定义 Steam 库等 v1 扫不到的场景）。
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

/// 一个 Apex 安装（或 videoconfig 文档根候选）。
class ApexInstall {
  /// 安装目录（游戏根）；videoconfig 文档候选时为文档根。
  final String installDir;

  final InstallSource source;

  /// videoconfig.txt 完整路径，仅文档根候选携带。
  final String? videoconfigPath;

  /// autoexec 候选目录。存在即算（文件可缺失）；候选目录都不存在时
  /// 为第一个候选（`cfg`）——「可创建」位置。文档根候选为 null。
  final String? autoexecDir;

  /// autoexec.cfg 完整路径，文件存在时才有值。
  final String? autoexecPath;

  const ApexInstall({
    required this.installDir,
    required this.source,
    this.videoconfigPath,
    this.autoexecDir,
    this.autoexecPath,
  });
}

/// 探测器。注册表 / 盘符 / 环境变量均可注入（测试假实现），文件系统
/// 检查走真实 IO 但只探测注入根推导出的路径。
class InstallLocator {
  final RegistryReader registry;
  final DriveLister drives;

  /// 平台环境变量（USERPROFILE / OneDrive*）。测试注入合成环境；
  /// 生产传 [Platform.environment]。
  final Map<String, String?> env;

  InstallLocator({
    required this.registry,
    required this.drives,
    Map<String, String?>? env,
  }) : env = env ?? Platform.environment;

  static const _autoexecDirCandidates = ['cfg', 'global/cfg', 'r2/cfg'];
  static const _videoconfigRelative = 'Respawn/Apex/local/videoconfig.txt';
  static const _apexGameRelative = 'steamapps/common/Apex Legends';
  static final _vdfPathRegex = RegExp(r'"path"\s+"([^"]+)"');

  // ---- 候选根收集（平台探测层） ----

  /// videoconfig 候选文档根：USERPROFILE\Documents、各 OneDrive 变量的
  /// Documents 与「文档」（OneDrive 中文重定向）。
  List<String> documentRoots() {
    final roots = <String>[];
    void add(String? base, String leaf) {
      if (base == null || base.isEmpty) return;
      final r = '${_norm(base)}/$leaf';
      if (!roots.contains(r)) roots.add(r);
    }

    add(env['USERPROFILE'], 'Documents');
    for (final v in ['OneDrive', 'OneDriveCommercial', 'OneDriveConsumer']) {
      add(env[v], 'Documents');
      add(env[v], '文档');
    }
    return roots;
  }

  /// Steam 根目录：HKCU SteamPath + HKLM WOW6432Node InstallPath。
  List<String> steamRoots() {
    final roots = <String>[];
    final seen = <String>{};
    void add(String? p) {
      if (p == null || p.isEmpty) return;
      final r = _norm(p);
      if (seen.add(r.toLowerCase())) roots.add(r);
    }

    add(
      registry.readString(
        RegistryView.user,
        r'Software\Valve\Steam',
        'SteamPath',
      ),
    );
    add(
      registry.readString(
        RegistryView.machine,
        r'SOFTWARE\WOW6432Node\Valve\Steam',
        'InstallPath',
      ),
    );
    return roots;
  }

  /// Steam 根下的全部库（根自身 + libraryfolders.vdf 的全部 "path"）。
  /// 损坏 vdf 跳过（不抛异常）。
  List<String> steamLibraries(List<String> roots) {
    final libs = <String>[];
    void add(String p) {
      final r = _norm(p);
      if (!libs.any((l) => l.toLowerCase() == r.toLowerCase())) libs.add(r);
    }

    for (final root in roots) {
      add(root);
      final vdf = File('$root/steamapps/libraryfolders.vdf');
      if (!vdf.existsSync()) continue;
      String content;
      try {
        content = vdf.readAsStringSync();
      } catch (_) {
        continue;
      }
      for (final m in _vdfPathRegex.allMatches(content)) {
        add(m.group(1)!.replaceAll('\\\\', '/'));
      }
    }
    return libs;
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

  /// 完整探测：文档根（videoconfig 存在才算）→ Steam（注册表根 → vdf
  /// 库 → 游戏目录）→ EA App（卸载表 + 常见根 + 盘符扫描）→ 用户记忆
  /// 路径（仅当以上全部落空时：先按库根尝试 `customInstallDir` 下的
  /// `steamapps/common/Apex Legends`，命中则不再把该目录本身当安装——
  /// 用户记忆的可能是 Steam 库根；库根落空后再把它本身当游戏根候选）。
  List<ApexInstall> locate({String? customInstallDir}) {
    final installs = <ApexInstall>[];

    // 1. videoconfig 文档根。
    for (final doc in documentRoots()) {
      final vc = '$doc/$_videoconfigRelative';
      if (File(vc).existsSync()) {
        installs.add(
          ApexInstall(
            installDir: doc,
            source: InstallSource.videoconfigDoc,
            videoconfigPath: vc,
          ),
        );
      }
    }

    // 2. Steam。
    final steamInstalls = installsFromInstallDirs(
      steamLibraries(
        steamRoots(),
      ).map((lib) => '$lib/$_apexGameRelative').toList(),
      source: InstallSource.steam,
    );
    installs.addAll(steamInstalls);

    // 3. EA App。
    final eaRoots = [...eaRegistryRoots(), ...eaCommonRoots()];
    installs.addAll(
      installsFromInstallDirs(eaRoots, source: InstallSource.eaApp),
    );

    // 4. 用户记忆路径：常规探测全空时兜底。先按库根（steamapps 下）探测，
    // 命中即不回退到目录本身，避免库根与其内的游戏目录重复计入。
    if (installs.isEmpty && customInstallDir != null) {
      final custom = _norm(customInstallDir);
      final nested = installsFromInstallDirs(
        ['$custom/$_apexGameRelative'],
        source: InstallSource.custom,
      );
      installs.addAll(
        nested.isNotEmpty
            ? nested
            : installsFromInstallDirs(
                [custom],
                source: InstallSource.custom,
              ),
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
/// 或 `steamapps/common/Apex Legends` 树内 → 安装根；videoconfig 的
/// Documents 文档根与其余任意目录都不是安装目录 → null。结果与
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
        return segments
            .sublist(0, segments.length - suffix.length)
            .join('/');
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
