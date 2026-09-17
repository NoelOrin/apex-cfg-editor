import 'dart:convert';
import 'dart:io';

import 'package:apex_cfg_editor/core/diagnostics/config_diagnostics.dart';
import 'package:apex_cfg_editor/core/io/cfg_file_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('diagnostics_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('reports config directory, encoding and latest backup', () {
    final configDir = Directory('${tmp.path}/config')..createSync();
    final backupDir = Directory('${tmp.path}/backups/videoconfig.txt')
      ..createSync(recursive: true);
    final oldBackup = File('${backupDir.path}/old.cfg')
      ..writeAsStringSync('old\n');
    final newBackup = File('${backupDir.path}/new.cfg')
      ..writeAsStringSync('new\n');
    oldBackup.setLastModifiedSync(DateTime(2026, 1, 1));
    newBackup.setLastModifiedSync(DateTime(2026, 2, 2, 3, 4));
    final openFile = File('${tmp.path}/videoconfig.txt')
      ..writeAsBytesSync(utf8.encode('"setting.fps_max" "144"\n'));

    final result = ConfigDiagnosticsService(
      configDir: configDir.path,
      backupDir: '${tmp.path}/backups',
      openFilePath: openFile.path,
    ).run();

    expect(result.configDirExists, isTrue);
    expect(result.configDirWritable, isTrue);
    expect(result.encoding, CfgEncoding.utf8);
    expect(result.hasBadBytes, isFalse);
    expect(result.latestBackupTime, DateTime(2026, 2, 2, 3, 4));
  });

  test('reports GBK detection and missing paths without throwing', () {
    final result = ConfigDiagnosticsService(
      configDir: '${tmp.path}/missing',
      backupDir: '${tmp.path}/missing-backups',
      openFilePath: null,
    ).run();

    expect(result.configDirExists, isFalse);
    expect(result.configDirWritable, isFalse);
    expect(result.encoding, isNull);
    expect(result.latestBackupTime, isNull);
  });
}
