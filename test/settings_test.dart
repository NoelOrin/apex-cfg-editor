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
}
