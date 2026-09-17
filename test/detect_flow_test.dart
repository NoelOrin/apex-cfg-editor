import 'dart:io';

import 'package:apex_cfg_editor/core/backup/backup_service.dart';
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
    // 与 main.dart 生产装配一致：打开成功回写 customInstallDir。
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

  testWidgets('EA install with autoexec.cfg auto-opens the file', (t) async {
    final apex = Directory('${tmp.path}/EAApex')..createSync(recursive: true);
    final autoexec = File('${apex.path}/global/cfg/autoexec.cfg')
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

    expect(_norm(file.state.path!), _norm(autoexec.path));
    // 打开成功回写 customInstallDir（main.dart 装配语义）。
    expect(_norm(store.readCustomInstallDir()!), _norm(apex.path));
  });

  testWidgets('autoexec missing → create button writes template and opens', (
    t,
  ) async {
    final apex = Directory('${tmp.path}/EAApex2')..createSync(recursive: true);
    Directory('${apex.path}/cfg').createSync(recursive: true);

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

  testWidgets('autoexec missing and cfg dir absent → template still created', (
    t,
  ) async {
    // 安装目录存在但完全没有 cfg 子目录：用第一个候选位置可创建。
    final apex = Directory('${tmp.path}/EAApex3')..createSync(recursive: true);

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

    await t.tap(find.text('Create autoexec.cfg'));
    await t.pumpAndSettle();

    expect(_norm(file.state.path!), _norm('${apex.path}/cfg/autoexec.cfg'));
  });

  testWidgets('two installs → chooser dialog; picking one opens its autoexec', (
    t,
  ) async {
    final eaApexA = '${tmp.path}/EAApexA';
    final eaApexB = '${tmp.path}/EAApexB';
    for (final apex in [eaApexA, eaApexB]) {
      Directory('$apex/global/cfg').createSync(recursive: true);
      File('$apex/global/cfg/autoexec.cfg').writeAsStringSync('// $apex\n');
    }

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
          locator: locatorWith({
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall|<keys>':
                'EA1|EA2',
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\EA1|DisplayName':
                'Apex Legends',
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\EA1|InstallLocation':
                eaApexA,
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\EA2|DisplayName':
                'Apex Legends',
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\EA2|InstallLocation':
                eaApexB,
          }),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Multiple Apex installations detected'), findsOneWidget);
    expect(find.text('EA App'), findsNWidgets(2));

    await t.tap(find.text(eaApexB));
    await t.pumpAndSettle();

    expect(_norm(file.state.path!), _norm('$eaApexB/global/cfg/autoexec.cfg'));
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

    expect(_norm(file.state.path!), _norm(autoexec.path));
    expect(_norm(store.readCustomInstallDir()!), _norm(apex.path));
  });

  testWidgets('reopens last file before auto detection when enabled', (
    t,
  ) async {
    final last = File('${tmp.path}/last/autoexec.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('// last\n');
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

  testWidgets('prefers EA autoexec over Saved Games configs when configured', (
    t,
  ) async {
    final home = Directory('${tmp.path}/home')..createSync();
    final local = Directory('${home.path}/Saved Games/Respawn/Apex/local')
      ..createSync(recursive: true);
    final settings = File('${local.path}/settings.cfg')
      ..writeAsStringSync('"setting.mouse_sensitivity" "2.5"\n');
    final videoconfig = File('${local.path}/videoconfig.txt')
      ..writeAsStringSync('"setting.fps_max" "144"\n');
    final apex = Directory('${tmp.path}/EAApex5')..createSync(recursive: true);
    final autoexec = File('${apex.path}/global/cfg/autoexec.cfg')
      ..createSync(recursive: true)
      ..writeAsStringSync('// auto\n');
    store.writePreferredOpenKind('autoexec');

    final locator = InstallLocator(
      registry: FakeRegistry(values: _eaRegistry('EA5', apex.path)),
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

    expect(videoconfig.existsSync(), isTrue);
    expect(settings.existsSync(), isTrue);
    expect(_norm(file.state.path!), _norm(autoexec.path));
  });

  testWidgets('auto-creates missing template when configured', (t) async {
    final apex = Directory('${tmp.path}/EAApexAuto')
      ..createSync(recursive: true);
    store.writeAutoCreateMissingTemplate(true);

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
          locator: locatorWith(_eaRegistry('EA6', apex.path)),
        ),
      ),
    );
    await t.pumpAndSettle();

    final created = File('${apex.path}/cfg/autoexec.cfg');
    expect(created.existsSync(), isTrue);
    expect(_norm(file.state.path!), _norm(created.path));
  });
}
