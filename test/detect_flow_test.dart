import 'dart:io';

import 'package:apex_cfg_editor/core/backup/backup_service.dart';
import 'package:apex_cfg_editor/core/parser/cfg_document.dart';
import 'package:apex_cfg_editor/core/paths/install_locator.dart';
import 'package:apex_cfg_editor/core/settings/settings_store.dart';
import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/state/diff_bloc.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';
import 'package:apex_cfg_editor/ui/editor_screen.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
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
    // 卸载表扫描：带 "keys:" 前缀的单值简化（本文件用 EA 场景）。
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
  localizationsDelegates: [
    fluent.FluentLocalizations.delegate,
    ...AppLocalizations.localizationsDelegates,
  ],
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
    onOpenSucceeded: (dir) {
      store.writeLastOpenDir(dir);
      final install = apexInstallDirFromOpenedDir(dir);
      if (install != null) store.writeCustomInstallDir(install);
    },
  );
  return (file, edit, diff);
}

Map<String, String?> _eaRegistry(String id, String installDir) => {
  'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall|<keys>': id,
  'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\$id|DisplayName':
      'Apex Legends',
  'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\$id|InstallLocation':
      installDir,
};

void main() {
  late Directory tmp;
  late SettingsStore store;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('detect_flow_');
    store = SettingsStore(settingsPath: '${tmp.path}/settings.json');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  InstallLocator locatorWith(Map<String, String?> values) => InstallLocator(
    registry: FakeRegistry(values: values),
    drives: FakeDrives(),
    env: const {},
  );

  /// 编辑器只接受 settings.cfg（操作设置）与 videoconfig.txt（游戏画质）；
  /// 仅含 autoexec.cfg 的安装不应被自动打开，进入「未找到」横幅。
  testWidgets('EA install with only autoexec.cfg is not auto-opened', (
    t,
  ) async {
    final apex = Directory('${tmp.path}/EAApex')..createSync(recursive: true);
    File('${apex.path}/Respawn/Apex/local/autoexec.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('// hi\n');

    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(
      _host(
        EditorScreen(
          editBloc: edit,
          diffBloc: diff,
          fileBloc: file,
          settings: store,
          locator: locatorWith(_eaRegistry('EA1', apex.path)),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(file.state.path, isNull);
    expect(find.text('Apex not found'), findsOneWidget);
  });

  testWidgets('EA install with settings.cfg auto-opens settings.cfg', (
    t,
  ) async {
    final apex = Directory('${tmp.path}/EAApex2')..createSync(recursive: true);
    final settings = File('${apex.path}/Respawn/Apex/local/settings.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('"setting.mouse_sensitivity" "2.5"\n');

    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(
      _host(
        EditorScreen(
          editBloc: edit,
          diffBloc: diff,
          fileBloc: file,
          settings: store,
          locator: locatorWith(_eaRegistry('EA2', apex.path)),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(_norm(file.state.path!), _norm(settings.path));
    expect(file.state.kind, CfgKind.settings);
  });

  testWidgets('preferred videoconfig opens videoconfig.txt over settings.cfg', (
    t,
  ) async {
    final apex = Directory('${tmp.path}/EAApex3')..createSync(recursive: true);
    final settings = File('${apex.path}/Respawn/Apex/local/settings.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('"setting.mouse_sensitivity" "2.5"\n');
    final video = File('${apex.path}/Respawn/Apex/local/videoconfig.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('"setting.fps_max" "144"\n');
    store.writePreferredOpenKind('videoconfig');

    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(
      _host(
        EditorScreen(
          editBloc: edit,
          diffBloc: diff,
          fileBloc: file,
          settings: store,
          locator: locatorWith(_eaRegistry('EA3', apex.path)),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(_norm(file.state.path!), _norm(video.path));
    expect(file.state.kind, CfgKind.videoconfig);
    expect(settings.existsSync(), isTrue);
  });

  testWidgets('nothing found → empty-state hint; specify dir re-probes and '
      'opens settings.cfg', (t) async {
    final apex = Directory('${tmp.path}/CustomApex')
      ..createSync(recursive: true);
    final settings = File('${apex.path}/Respawn/Apex/local/settings.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('"setting.mouse_sensitivity" "2.5"\n');

    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(
      _host(
        EditorScreen(
          editBloc: edit,
          diffBloc: diff,
          fileBloc: file,
          settings: store,
          locator: locatorWith(const {}),
          pickDirectory: () async => apex.path,
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(file.state.path, isNull);
    expect(find.text('Apex not found'), findsOneWidget);
    expect(find.text('Specify Apex directory'), findsOneWidget);

    await t.tap(find.text('Specify Apex directory'));
    await t.pumpAndSettle();

    expect(_norm(file.state.path!), _norm(settings.path));
    expect(_norm(store.readCustomInstallDir()!), _norm(apex.path));
  });

  testWidgets('reopens last file before auto detection when enabled', (
    t,
  ) async {
    final last = File('${tmp.path}/last/settings.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('"setting.mouse_sensitivity" "2.5"\n');
    store.writeReopenLastFile(true);
    store.writeLastOpenFile(last.path);

    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(
      _host(
        EditorScreen(
          editBloc: edit,
          diffBloc: diff,
          fileBloc: file,
          settings: store,
          autoDetect: false,
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(_norm(file.state.path!), _norm(last.path));
    expect(file.state.kind, CfgKind.settings);
  });

  testWidgets('default preference opens settings.cfg from Saved Games', (
    t,
  ) async {
    final home = Directory('${tmp.path}/settings-home')..createSync();
    final settingsFile =
        File('${home.path}/Saved Games/Respawn/Apex/local/settings.cfg')
          ..createSync(recursive: true)
          ..writeAsStringSync('"setting.mouse_sensitivity" "2.5"\n');
    File(
      '${home.path}/Saved Games/Respawn/Apex/local/videoconfig.txt',
    ).writeAsStringSync('"setting.fps_max" "144"\n');

    final locator = InstallLocator(
      registry: FakeRegistry(),
      drives: FakeDrives(),
      env: {'USERPROFILE': home.path},
    );
    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(
      _host(
        EditorScreen(
          editBloc: edit,
          diffBloc: diff,
          fileBloc: file,
          settings: store,
          locator: locator,
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(file.state.kind, CfgKind.settings);
    expect(_norm(file.state.path!), _norm(settingsFile.path));
  });

  testWidgets('FileBloc opens settings.cfg normally', (t) async {
    final settings = File('${tmp.path}/settings.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('"setting.mouse_sensitivity" "2.5"\n');
    final (file, edit, diff) = _wire('${tmp.path}/backups', store);
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    file.add(OpenRequested(settings.path));
    await t.pumpAndSettle();

    expect(file.state.kind, CfgKind.settings);
    expect(file.state.path, settings.path);
    expect(edit.state.doc, isA<CfgDocument>());
  });
}
