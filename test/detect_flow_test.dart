import 'dart:io';

import 'package:apex_cfg_editor/core/backup/backup_service.dart';
import 'package:apex_cfg_editor/core/paths/install_locator.dart';
import 'package:apex_cfg_editor/core/settings/settings_store.dart';
import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/state/diff_bloc.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';
import 'package:apex_cfg_editor/ui/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Windows 上探测引擎用 `\` 拼接（文件系统等价），断言前归一化到 `/`。
String _norm(String p) => p.replaceAll(r'\', '/');

class FakeRegistry implements RegistryReader {
  final Map<String, String?> values;
  FakeRegistry({this.values = const {}});

  @override
  String? readString(RegistryView view, String keyPath, String valueName) =>
      values['${view.name}|$keyPath|$valueName'];

  @override
  List<String> subKeys(RegistryView view, String keyPath) {
    // 卸载表扫描：带 "keys:" 前缀的单值简化（本文件只造 Steam 场景）。
    return values['${view.name}|$keyPath|<keys>']?.split('|').toList() ??
        const [];
  }
}

class FakeDrives implements DriveLister {
  @override
  List<String> driveLetters() => const [];
}

Widget _host(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

(FileBloc, EditBloc, DiffBloc) _wire(String backupBase, SettingsStore store) {
  final backups = BackupService(baseDir: backupBase);
  final edit = EditBloc();
  final diff = DiffBloc(editStream: edit.stream);
  final file = FileBloc(
    editBloc: edit,
    saveImpl: (p, t, e) async {},
    listBackupsImpl: backups.listBackups,
    restoreImpl: backups.restore,
    // 与 main.dart 生产装配一致：打开成功回写 customInstallDir。
    onOpenSucceeded: (dir) {
      store.writeLastOpenDir(dir);
      final install = apexInstallDirFromOpenedDir(dir);
      if (install != null) store.writeCustomInstallDir(install);
    },
  );
  return (file, edit, diff);
}

void main() {
  late Directory tmp;
  late SettingsStore store;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('detect_flow_');
    store = SettingsStore(settingsPath: '${tmp.path}/settings.json');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  InstallLocator locatorWith(Map<String, String?> values) =>
      InstallLocator(
        registry: FakeRegistry(values: values),
        drives: FakeDrives(),
        env: const {},
      );

  testWidgets('steam install with autoexec.cfg auto-opens the file', (t) async {
    final apex =
        Directory('${tmp.path}/Lib/steamapps/common/Apex Legends')
          ..createSync(recursive: true);
    final autoexec =
        File('${apex.path}/global/cfg/autoexec.cfg')
          ..createSync(recursive: true)
          ..writeAsStringSync('// hi\n');
    final steamRoot = '${tmp.path}/Steam';
    Directory('$steamRoot/steamapps').createSync(recursive: true);
    File('$steamRoot/steamapps/libraryfolders.vdf').writeAsStringSync(
        '"libraryfolders"\n{\n  "0" { "path" "${tmp.path}/Lib" }\n}\n');

    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(_host(EditorScreen(
      editBloc: edit,
      diffBloc: diff,
      fileBloc: file,
      settings: store,
      locator: locatorWith({
        'user|Software\\Valve\\Steam|SteamPath': steamRoot,
      }),
    )));
    await t.pumpAndSettle();

    expect(_norm(file.state.path!), _norm(autoexec.path));
    // 打开成功回写 customInstallDir（main.dart 装配语义）。
    expect(_norm(store.readCustomInstallDir()!), _norm(apex.path));
  });

  testWidgets('autoexec missing → create button writes template and opens',
      (t) async {
    final apex =
        Directory('${tmp.path}/Lib2/steamapps/common/Apex Legends')
          ..createSync(recursive: true);
    Directory('${apex.path}/cfg').createSync(recursive: true);
    final steamRoot = '${tmp.path}/Steam2';
    Directory('$steamRoot/steamapps').createSync(recursive: true);
    File('$steamRoot/steamapps/libraryfolders.vdf').writeAsStringSync(
        '"libraryfolders"\n{\n  "0" { "path" "${tmp.path}/Lib2" }\n}\n');

    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(_host(EditorScreen(
      editBloc: edit,
      diffBloc: diff,
      fileBloc: file,
      settings: store,
      locator: locatorWith({
        'user|Software\\Valve\\Steam|SteamPath': steamRoot,
      }),
    )));
    await t.pumpAndSettle();

    expect(file.state.path, isNull);
    expect(find.text('Create autoexec.cfg'), findsOneWidget);

    await t.tap(find.text('Create autoexec.cfg'));
    await t.pumpAndSettle();

    final created = File('${apex.path}/cfg/autoexec.cfg');
    expect(created.existsSync(), isTrue);
    expect(_norm(file.state.path!), _norm(created.path));
    for (final line in created.readAsStringSync().split('\n')) {
      if (line.trim().isEmpty) continue;
      expect(line.trimLeft().startsWith('//'), isTrue, reason: line);
    }
  });

  testWidgets('autoexec missing and cfg dir absent → template still created',
      (t) async {
    // 安装目录存在但完全没有 cfg 子目录：用第一个候选位置可创建。
    Directory('${tmp.path}/Lib3/steamapps/common/Apex Legends')
        .createSync(recursive: true);
    final steamRoot = '${tmp.path}/Steam3';
    Directory('$steamRoot/steamapps').createSync(recursive: true);
    File('$steamRoot/steamapps/libraryfolders.vdf').writeAsStringSync(
        '"libraryfolders"\n{\n  "0" { "path" "${tmp.path}/Lib3" }\n}\n');

    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(_host(EditorScreen(
      editBloc: edit,
      diffBloc: diff,
      fileBloc: file,
      settings: store,
      locator: locatorWith({
        'user|Software\\Valve\\Steam|SteamPath': steamRoot,
      }),
    )));
    await t.pumpAndSettle();

    await t.tap(find.text('Create autoexec.cfg'));
    await t.pumpAndSettle();

    expect(
        _norm(file.state.path!),
        _norm(
            '${tmp.path}/Lib3/steamapps/common/Apex Legends/cfg/autoexec.cfg'));
  });

  testWidgets('two installs → chooser dialog; picking one opens its autoexec',
      (t) async {
    for (final lib in ['LibA', 'LibB']) {
      Directory('${tmp.path}/$lib/steamapps/common/Apex Legends/global/cfg')
          .createSync(recursive: true);
      File('${tmp.path}/$lib/steamapps/common/Apex Legends/global/cfg/autoexec.cfg')
          .writeAsStringSync('// $lib\n');
    }
    final steamRoot = '${tmp.path}/Steam4';
    Directory('$steamRoot/steamapps').createSync(recursive: true);
    File('$steamRoot/steamapps/libraryfolders.vdf').writeAsStringSync(
        '"libraryfolders"\n{\n  "0" { "path" "${tmp.path}/LibA" }\n}\n');
    final eaApex =
        '${tmp.path}/LibB/steamapps/common/Apex Legends';

    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(_host(EditorScreen(
      editBloc: edit,
      diffBloc: diff,
      fileBloc: file,
      settings: store,
      locator: locatorWith({
        'user|Software\\Valve\\Steam|SteamPath': steamRoot,
        // EA App：卸载表 InstallLocation 指向 LibB 的游戏目录。
        'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\EA|DisplayName':
            'Apex Legends',
        'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\EA|InstallLocation':
            eaApex,
        'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall|<keys>':
            'EA',
      }),
    )));
    await t.pumpAndSettle();

    expect(find.text('Multiple Apex installations detected'), findsOneWidget);
    expect(find.text('Steam'), findsOneWidget);
    expect(find.text('EA App'), findsOneWidget);

    await t.tap(find.text('EA App'));
    await t.pumpAndSettle();

    expect(_norm(file.state.path!), _norm('$eaApex/global/cfg/autoexec.cfg'));
  });

  testWidgets('nothing found → empty-state hint; specify dir re-probes and '
      'opens', (t) async {
    final apex = Directory('${tmp.path}/CustomApex')
      ..createSync(recursive: true);
    final autoexec = File('${apex.path}/cfg/autoexec.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('// custom\n');

    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(_host(EditorScreen(
      editBloc: edit,
      diffBloc: diff,
      fileBloc: file,
      settings: store,
      locator: locatorWith(const {}),
      pickDirectory: () async => apex.path,
    )));
    await t.pumpAndSettle();

    expect(file.state.path, isNull);
    expect(find.text('Apex not found'), findsOneWidget);
    expect(find.text('Specify Apex directory'), findsOneWidget);

    await t.tap(find.text('Specify Apex directory'));
    await t.pumpAndSettle();

    expect(_norm(file.state.path!), _norm(autoexec.path));
    expect(_norm(store.readCustomInstallDir()!), _norm(apex.path));
  });
}
