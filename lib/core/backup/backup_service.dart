import 'dart:io';

class BackupService {
  final String baseDir; // Windows: %APPDATA%\ApexCfgEditor\backups
  BackupService({required this.baseDir});

  String _dirFor(String path) {
    // apex_paths 产出 / 分隔路径，而 Windows 本地路径用 \：统一按两种
    // 分隔符切，只取文件名做备份目录名（按 Platform.pathSeparator 切在
    // Windows 上会把整串路径当目录名，备份/保存全挂）。
    final name = path.split(RegExp(r'[/\\]')).last;
    return '$baseDir/$name';
  }

  /// 字节级复制当前文件内容（规格 §7：备份 = 字节级复制），
  /// 不做任何解码/重编码——GBK 等非 UTF-8 内容原样保存。
  void backupBeforeSave(String path, List<int> currentBytes) {
    final dir = Directory(_dirFor(path))..createSync(recursive: true);
    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
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

  Future<void> restore(String targetPath, String backupPath) async {
    final tmp = '$targetPath.tmp';
    File(tmp).writeAsBytesSync(File(backupPath).readAsBytesSync(), flush: true);
    File(tmp).renameSync(targetPath); // 原子替换，与 CfgFileIo.write 同模式
  }
}
