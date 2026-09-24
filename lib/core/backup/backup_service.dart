import 'dart:convert';
import 'dart:io';

class BackupService {
  String baseDir; // Windows: %APPDATA%\ApexCfgEditor\backups
  BackupService({required this.baseDir});

  static final _sep = RegExp(r'[/\\]');

  /// 备份目录 = `<文件名>/<路径哈希>`：不同路径的同名文件（两个
  /// settings.cfg）不再共用命名空间；同一路径的 `/` 与 `\` 写法归一化后
  /// 哈希一致。
  String _dirFor(String path) {
    final name = path.split(_sep).last;
    return '$baseDir/$name/${pathKeyOf(path)}';
  }

  /// 目标路径的稳定短键（大小写与分隔符不敏感的 FNV-1a）。
  static String pathKeyOf(String path) {
    final norm = path.replaceAll('\\', '/').toLowerCase();
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(norm)) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// 上一次备份时间戳的毫秒值：保证同一服务实例内时间戳严格递增——
  /// 同毫秒重入（macOS 时钟分辨率下两次连续保存可落同一毫秒）时 +1ms，
  /// 文件名不碰撞且字符串排序仍等价于时间排序。
  int _lastStampMs = -1;

  String _stampFor(DateTime now) {
    var ms = now.millisecondsSinceEpoch;
    if (ms <= _lastStampMs) ms = _lastStampMs + 1;
    _lastStampMs = ms;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}'
        '-${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}'
        '${d.second.toString().padLeft(2, '0')}'
        '${d.millisecond.toString().padLeft(3, '0')}';
  }

  /// 字节级复制当前文件内容（规格 §7：备份 = 字节级复制），
  /// 不做任何解码/重编码——GBK 等非 UTF-8 内容原样保存。
  void backupBeforeSave(String path, List<int> currentBytes) {
    final dir = Directory(_dirFor(path))..createSync(recursive: true);
    final stamp = _stampFor(DateTime.now());
    final tmp = '${dir.path}/.$stamp.tmp';
    File(tmp).writeAsBytesSync(currentBytes, flush: true);
    File(tmp).renameSync('${dir.path}/$stamp.cfg'); // 原子替换；同秒重名即覆盖合并
  }

  List<String> listBackups(String path) {
    final dir = Directory(_dirFor(path));
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.cfg'))
        .map((f) => f.path)
        .toList()
      ..sort((a, b) => b.compareTo(a)); // 新→旧
  }

  /// 删除目标文件的旧备份，保留按文件名排序后的最新 [limit] 个。
  int pruneBackups(String path, int limit) {
    final files = listBackups(path);
    final keep = limit < 1 ? 1 : limit;
    var removed = 0;
    for (final old in files.skip(keep)) {
      try {
        File(old).deleteSync();
        removed++;
      } catch (_) {}
    }
    return removed;
  }

  /// 遍历备份根目录下的每个目标文件目录并执行数量裁剪。
  int pruneAll(int limit) {
    final root = Directory(baseDir);
    if (!root.existsSync()) return 0;
    var removed = 0;
    for (final entity in root.listSync(recursive: true).whereType<File>()) {
      if (!entity.path.endsWith('.cfg')) continue;
      final dir = entity.parent;
      // 只按「时间戳 .cfg 所在目录」裁剪，兼容 `<name>/<hash>/` 两层结构。
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.cfg'))
          .map((f) => f.path)
          .toList()
        ..sort((a, b) => b.compareTo(a));
      for (final old in files.skip(limit < 1 ? 1 : limit)) {
        try {
          File(old).deleteSync();
          removed++;
        } catch (_) {}
      }
    }
    return removed;
  }

  /// 返回所有备份文件中最后修改的时间。
  DateTime? latestBackupTime() {
    final root = Directory(baseDir);
    if (!root.existsSync()) return null;
    DateTime? latest;
    for (final entity in root.listSync(recursive: true).whereType<File>()) {
      if (!entity.path.endsWith('.cfg')) continue;
      try {
        final time = entity.statSync().modified;
        if (latest == null || time.isAfter(latest)) latest = time;
      } catch (_) {}
    }
    return latest;
  }

  Future<void> restore(String targetPath, String backupPath) async {
    final tmp = '$targetPath.tmp';
    File(tmp).writeAsBytesSync(File(backupPath).readAsBytesSync(), flush: true);
    File(tmp).renameSync(targetPath); // 原子替换，与 CfgFileIo.write 同模式
  }

  /// 把 [oldBase] 下的全部备份迁移到当前 [baseDir]（换备份目录时不丢历史）。
  /// 同名备份文件跳过，不覆盖。
  void migrateFrom(String oldBase) {
    if (oldBase.isEmpty || oldBase == baseDir) return;
    final oldRoot = Directory(oldBase);
    if (!oldRoot.existsSync()) return;
    final newRoot = Directory(baseDir)..createSync(recursive: true);
    for (final entity in oldRoot.listSync(recursive: true).whereType<File>()) {
      if (!entity.path.endsWith('.cfg')) continue;
      final rel = entity.path.substring(oldRoot.path.length).replaceAll('\\', '/');
      final target = File('${newRoot.path}$rel');
      if (target.existsSync()) continue;
      target.parent.createSync(recursive: true);
      try {
        entity.copySync(target.path);
      } catch (_) {}
    }
  }
}
