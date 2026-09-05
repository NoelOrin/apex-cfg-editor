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
    b.backupBeforeSave(target.path, 'v1\n');
    final files = b.listBackups(target.path);
    expect(files, hasLength(1));
    expect(RegExp(r'\d{8}-\d{6}\.cfg$').hasMatch(files.first.split('/').last), isTrue);
  });

  test('restore writes selected backup content back', () async {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('v1\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, 'v1\n');
    target.writeAsStringSync('v2\n');
    await b.restore(target.path, b.listBackups(target.path).first);
    expect(target.readAsStringSync(), 'v1\n');
  });

  test('list newest first', () {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)..writeAsStringSync('v\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, 'v\n');
    b.backupBeforeSave(target.path, 'v\n');
    final l = b.listBackups(target.path);
    expect(l.first.compareTo(l.last), greaterThanOrEqualTo(0));
  });
}
