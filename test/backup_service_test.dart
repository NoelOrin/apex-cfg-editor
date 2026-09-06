import 'dart:convert';
import 'dart:io';
import 'package:apex_cfg_editor/core/backup/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('bk'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('backup before save: timestamped copy stored in app-data dir', () {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('v1\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, utf8.encode('v1\n'));
    final files = b.listBackups(target.path);
    expect(files, hasLength(1));
    expect(RegExp(r'\d{8}-\d{9}\.cfg$').hasMatch(files.first.split('/').last), isTrue);
    // 字节级复制（规格 §7）：备份内容与当前文件字节一致。
    expect(File(files.first).readAsBytesSync(), utf8.encode('v1\n'));
  });

  test('backup dir is file name regardless of path separator style', () {
    // apex_paths 在 Windows 上产出 / 分隔路径，而 Platform.pathSeparator
    // 是 \：旧实现按 \ 切会把整串路径当目录名，备份目录构造崩溃。
    // 备份目录必须只取文件名，与分隔符风格无关（两种写法同一目录）。
    const forward = 'C:/Users/x/Documents/videoconfig.txt';
    const backward = 'C:\\Users\\x\\Documents\\videoconfig.txt';
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(forward, utf8.encode('v\n'));
    final files = b.listBackups(forward);
    expect(files, hasLength(1));
    // 目录名就是文件名（不含盘符/目录段）。
    expect(File(files.first).parent.path,
        '${tmp.path}/appdata/videoconfig.txt');
    expect(File(files.first).readAsBytesSync(), utf8.encode('v\n'));
    // 同一文件的反斜杠写法解析到同一备份目录。
    expect(b.listBackups(backward), files);
  });

  test('two backups within the same second produce two distinct files', () {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)..writeAsStringSync('v\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, utf8.encode('v1\n'));
    b.backupBeforeSave(target.path, utf8.encode('v2\n'));
    final files = b.listBackups(target.path);
    expect(files, hasLength(2)); // 毫秒时间戳：同秒不再覆盖合并
    expect(files[0], isNot(files[1]));
    // 新→旧：第二次备份（v2）排在最前。
    expect(File(files.first).readAsBytesSync(), utf8.encode('v2\n'));
  });

  test('restore writes selected backup content back', () async {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('v1\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, utf8.encode('v1\n'));
    target.writeAsStringSync('v2\n');
    await b.restore(target.path, b.listBackups(target.path).first);
    expect(target.readAsStringSync(), 'v1\n');
  });

  test('list newest first', () {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)..writeAsStringSync('v\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, utf8.encode('v\n'));
    b.backupBeforeSave(target.path, utf8.encode('v\n'));
    final l = b.listBackups(target.path);
    expect(l.first.compareTo(l.last), greaterThanOrEqualTo(0));
  });

  test('list newest first with distinct hand-written timestamps', () {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)..writeAsStringSync('v\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, utf8.encode('v\n'));
    final backupDir = File(b.listBackups(target.path).first).parent;
    File('${backupDir.path}/20260101-000000.cfg').writeAsStringSync('older\n');
    File('${backupDir.path}/20270101-000000.cfg').writeAsStringSync('newer\n');
    final l = b.listBackups(target.path);
    expect(l, hasLength(3)); // 3 个独立文件，排除同秒合并干扰
    expect(l.first.endsWith('20270101-000000.cfg'), isTrue); // 新→旧
    expect(l.last.endsWith('20260101-000000.cfg'), isTrue);
  });
}
