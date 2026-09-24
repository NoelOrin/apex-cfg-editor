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
    expect(
      RegExp(r'\d{8}-\d{9}\.cfg$').hasMatch(files.first.split('/').last),
      isTrue,
    );
    expect(File(files.first).readAsBytesSync(), utf8.encode('v1\n'));
  });

  test('same file name under different paths do NOT share backup space', () {
    final a = File('${tmp.path}/a/settings.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('A\n');
    final bTarget = File('${tmp.path}/b/settings.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('B\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(a.path, utf8.encode('A\n'));
    b.backupBeforeSave(bTarget.path, utf8.encode('B\n'));

    final aFiles = b.listBackups(a.path);
    final bFiles = b.listBackups(bTarget.path);
    expect(aFiles, hasLength(1));
    expect(bFiles, hasLength(1));
    expect(File(aFiles.first).readAsBytesSync(), utf8.encode('A\n'));
    expect(File(bFiles.first).readAsBytesSync(), utf8.encode('B\n'));
    // 不同路径 → 不同备份目录。
    expect(
      File(aFiles.first).parent.path,
      isNot(File(bFiles.first).parent.path),
    );
  });

  test('same path with / vs \\ maps to one backup dir', () {
    const forward = 'C:/Users/x/Documents/videoconfig.txt';
    const backward = 'C:\\Users\\x\\Documents\\videoconfig.txt';
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(forward, utf8.encode('v\n'));
    final files = b.listBackups(forward);
    expect(files, hasLength(1));
    expect(b.listBackups(backward), files);
  });

  test('two backups within the same second produce two distinct files', () {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('v\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, utf8.encode('v1\n'));
    b.backupBeforeSave(target.path, utf8.encode('v2\n'));
    final files = b.listBackups(target.path);
    expect(files, hasLength(2));
    expect(files[0], isNot(files[1]));
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

  test('list newest first with distinct hand-written timestamps', () {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('v\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, utf8.encode('v\n'));
    final backupDir = File(b.listBackups(target.path).first).parent;
    File('${backupDir.path}/20260101-000000000.cfg').writeAsStringSync('older\n');
    File('${backupDir.path}/20270101-000000000.cfg').writeAsStringSync('newer\n');
    final l = b.listBackups(target.path);
    expect(l, hasLength(3));
    expect(l.first.endsWith('20270101-000000000.cfg'), isTrue);
    expect(l.last.endsWith('20260101-000000000.cfg'), isTrue);
  });

  test('prunes old backups for one target to the configured limit', () {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('v\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    for (var i = 0; i < 5; i++) {
      b.backupBeforeSave(target.path, utf8.encode('v$i\n'));
    }

    expect(b.pruneBackups(target.path, 2), 3);
    expect(b.listBackups(target.path), hasLength(2));
  });

  test('pruneAll cleans every target and reports latest backup time', () {
    final first = File('${tmp.path}/one/videoconfig.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('v\n');
    final second = File('${tmp.path}/two/videoconfig.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('v\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    for (var i = 0; i < 3; i++) {
      b.backupBeforeSave(first.path, utf8.encode('one$i\n'));
      b.backupBeforeSave(second.path, utf8.encode('two$i\n'));
    }
    final newest = File(b.listBackups(second.path).first);
    newest.setLastModifiedSync(DateTime(2026, 5, 6, 7, 8));

    expect(b.pruneAll(1), 4);
    expect(b.listBackups(first.path), hasLength(1));
    expect(b.listBackups(second.path), hasLength(1));
    expect(b.latestBackupTime(), isNotNull);
  });

  test('migrateFrom copies history into the new base dir', () {
    final target = File('${tmp.path}/Documents/settings.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('v\n');
    final oldBase = '${tmp.path}/old';
    final bOld = BackupService(baseDir: oldBase);
    bOld.backupBeforeSave(target.path, utf8.encode('v1\n'));
    final oldFiles = bOld.listBackups(target.path);
    expect(oldFiles, hasLength(1));

    final bNew = BackupService(baseDir: '${tmp.path}/new');
    bNew.migrateFrom(oldBase);
    final newFiles = bNew.listBackups(target.path);
    expect(newFiles, hasLength(1));
    expect(File(newFiles.first).readAsBytesSync(), utf8.encode('v1\n'));
  });
}
