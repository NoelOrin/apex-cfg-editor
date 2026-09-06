import 'dart:io';

import 'package:apex_cfg_editor/core/settings/settings_store.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// 规格 R7：「打开文件」记住上次路径。settings.json 存于应用数据目录
/// （测试注入临时路径），打开成功写入父目录，失败静默跳过。
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('apex_cfg_settings_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('lastOpenDirFromJson (pure)', () {
    test('parses lastOpenDir string payload', () {
      expect(
        SettingsStore.lastOpenDirFromJson(
            '{"lastOpenDir": "C:/Users/x/Documents"}'),
        'C:/Users/x/Documents',
      );
    });

    test('missing/empty/non-string values and invalid json are null', () {
      expect(SettingsStore.lastOpenDirFromJson('{}'), isNull);
      expect(SettingsStore.lastOpenDirFromJson('{"lastOpenDir": ""}'), isNull);
      expect(SettingsStore.lastOpenDirFromJson('{"lastOpenDir": 42}'), isNull);
      expect(SettingsStore.lastOpenDirFromJson('["a"]'), isNull);
      expect(SettingsStore.lastOpenDirFromJson('not json'), isNull);
    });
  });

  group('SettingsStore (temp dir)', () {
    test('missing file reads as null without throwing', () {
      final store = SettingsStore(settingsPath: '${tmp.path}/settings.json');
      expect(store.readLastOpenDir(), isNull);
    });

    test('write creates file, roundtrips and overwrites', () {
      final store =
          SettingsStore(settingsPath: '${tmp.path}/nested/settings.json');
      store.writeLastOpenDir('${tmp.path}/a');
      expect(store.readLastOpenDir(), '${tmp.path}/a');
      store.writeLastOpenDir('${tmp.path}/b');
      expect(store.readLastOpenDir(), '${tmp.path}/b');
    });

    test('corrupt file reads as null without throwing', () {
      File('${tmp.path}/settings.json').writeAsStringSync('{broken');
      final store = SettingsStore(settingsPath: '${tmp.path}/settings.json');
      expect(store.readLastOpenDir(), isNull);
    });

    test('unwritable path write fails silently', () {
      // 父路径是文件：createSync 抛错 → 静默跳过，不抛异常。
      final blocker = File('${tmp.path}/blocker')..writeAsStringSync('x');
      final store =
          SettingsStore(settingsPath: '${blocker.path}/settings.json');
      expect(() => store.writeLastOpenDir('${tmp.path}/a'), returnsNormally);
      expect(store.readLastOpenDir(), isNull);
    });
  });

  group('open flow wiring', () {
    test('successful open writes parent dir into settings.json', () async {
      final cfg = File('${tmp.path}/videoconfig.txt')
        ..writeAsStringSync('"setting.fps_max" "0"\n');
      final settingsPath = '${tmp.path}/settings/settings.json';
      final store = SettingsStore(settingsPath: settingsPath);
      final edit = EditBloc();
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, _) async {},
        listBackupsImpl: (_) => const [],
        restoreImpl: (_, _) async {},
        onOpenSucceeded: store.writeLastOpenDir,
      );

      bloc.add(OpenRequested(cfg.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(File(settingsPath).existsSync(), isTrue);
      expect(store.readLastOpenDir(), tmp.path); // 打开文件的父目录

      await bloc.close();
      await edit.close();
    });

    test('failed open does not touch settings', () async {
      final settingsPath = '${tmp.path}/settings.json';
      final store = SettingsStore(settingsPath: settingsPath);
      final edit = EditBloc();
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, _) async {},
        listBackupsImpl: (_) => const [],
        restoreImpl: (_, _) async {},
        onOpenSucceeded: store.writeLastOpenDir,
      );

      bloc.add(OpenRequested('${tmp.path}/no_such_file.txt'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(File(settingsPath).existsSync(), isFalse);

      await bloc.close();
      await edit.close();
    });
  });

group('customInstallDir (用户记忆的 Apex 安装目录)', () {
  test('roundtrips via json without clobbering lastOpenDir', () {
    final path = '${tmp.path}/settings.json';
    final store = SettingsStore(settingsPath: path);
    expect(store.readCustomInstallDir(), isNull);

    store.writeLastOpenDir('${tmp.path}/docs');
    store.writeCustomInstallDir('D:/Games/Apex Legends');
    expect(store.readCustomInstallDir(), 'D:/Games/Apex Legends');
    // 两个字段互不覆盖：写 customInstallDir 后 lastOpenDir 仍在。
    expect(store.readLastOpenDir(), '${tmp.path}/docs');
    // 反向亦然：再写 lastOpenDir 不丢 customInstallDir。
    store.writeLastOpenDir('${tmp.path}/other');
    expect(store.readCustomInstallDir(), 'D:/Games/Apex Legends');
  });

  test('missing/empty/non-string and invalid json are null', () {
    expect(SettingsStore.customInstallDirFromJson('{}'), isNull);
    expect(
        SettingsStore.customInstallDirFromJson('{"customInstallDir": ""}'),
        isNull);
    expect(
        SettingsStore.customInstallDirFromJson('{"customInstallDir": 42}'),
        isNull);
    expect(SettingsStore.customInstallDirFromJson('not json'), isNull);
  });

  test('missing file reads as null without throwing', () {
    final store = SettingsStore(settingsPath: '${tmp.path}/none.json');
    expect(store.readCustomInstallDir(), isNull);
  });

  test('unwritable path write fails silently', () {
    final blocker = File('${tmp.path}/blocker2')..writeAsStringSync('x');
    final store = SettingsStore(settingsPath: '${blocker.path}/settings.json');
    expect(
        () => store.writeCustomInstallDir('${tmp.path}/a'), returnsNormally);
    expect(store.readCustomInstallDir(), isNull);
  });
});
}
