import 'dart:io';

import 'package:apex_cfg_editor/core/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('app_settings_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('new settings have stable defaults', () {
    final store = SettingsStore(settingsPath: '${tmp.path}/settings.json');

    expect(store.readAutoDetectOnStartup(), isTrue);
    expect(store.readPreferredOpenKind(), 'videoconfig');
    expect(store.readReopenLastFile(), isFalse);
    expect(store.readAutoCreateMissingTemplate(), isFalse);
    expect(store.readBackupEnabled(), isTrue);
    expect(store.readBackupLimit(), SettingsStore.defaultBackupLimit);
    expect(store.readBackupDir(), isNull);
    expect(store.readLastOpenFile(), isNull);
  });

  test('new settings roundtrip without clobbering existing fields', () {
    final store = SettingsStore(settingsPath: '${tmp.path}/settings.json');

    store.writeThemeModeRaw('dark');
    store.writeAutoDetectOnStartup(false);
    store.writePreferredOpenKind('autoexec');
    store.writeReopenLastFile(true);
    store.writeAutoCreateMissingTemplate(true);
    store.writeBackupEnabled(false);
    store.writeBackupLimit(7);
    store.writeBackupDir('${tmp.path}/custom-backups');
    store.writeLastOpenFile('${tmp.path}/autoexec.cfg');

    expect(store.readAutoDetectOnStartup(), isFalse);
    expect(store.readPreferredOpenKind(), 'autoexec');
    expect(store.readReopenLastFile(), isTrue);
    expect(store.readAutoCreateMissingTemplate(), isTrue);
    expect(store.readBackupEnabled(), isFalse);
    expect(store.readBackupLimit(), 7);
    expect(store.readBackupDir(), '${tmp.path}/custom-backups');
    expect(store.readLastOpenFile(), '${tmp.path}/autoexec.cfg');
    expect(store.readThemeModeRaw(), 'dark');
  });

  test('backup limit is clamped to a safe range', () {
    final store = SettingsStore(settingsPath: '${tmp.path}/settings.json');

    store.writeBackupLimit(0);
    expect(store.readBackupLimit(), 1);
    store.writeBackupLimit(999);
    expect(store.readBackupLimit(), 100);
  });

  test('reset removes only settings.json', () {
    final configDir = Directory('${tmp.path}/config')..createSync();
    final settings = File('${configDir.path}/settings.json')
      ..writeAsStringSync('{"themeMode":"light"}');
    final apexConfig = File('${configDir.path}/videoconfig.txt')
      ..writeAsStringSync('"setting.fps_max" "144"\n');
    final backup = File('${tmp.path}/backups/videoconfig.txt/old.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('old\n');

    SettingsStore(settingsPath: settings.path).reset();

    expect(settings.existsSync(), isFalse);
    expect(apexConfig.existsSync(), isTrue);
    expect(backup.existsSync(), isTrue);
  });
}
