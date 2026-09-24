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

String _norm(String p) => p.replaceAll(r'\', '/');

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
      store.writeCustomInstallDir(dir);
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

  testWidgets('custom config root with only autoexec.cfg is not auto-opened', (
    t,
  ) async {
    final local = Directory('${tmp.path}/CustomLocal')
      ..createSync(recursive: true);
    File('${local.path}/autoexec.cfg')
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
          locator: InstallLocator(env: const {}),
          pickDirectory: () async => local.path,
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(file.state.path, isNull);
    expect(find.text('Apex not found'), findsOneWidget);
    // 找不到可打开配置：不污染 customConfigDir 记忆。
    expect(store.readCustomInstallDir(), isNull);
  });

  testWidgets('Saved Games settings.cfg auto-opens settings.cfg', (t) async {
    final home = Directory('${tmp.path}/home')..createSync();
    final settings = File(
      '${home.path}/Saved Games/Respawn/Apex/local/settings.cfg',
    )
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
          locator: InstallLocator(env: {'USERPROFILE': home.path}),
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
    final home = Directory('${tmp.path}/home')..createSync();
    final settings = File(
      '${home.path}/Saved Games/Respawn/Apex/local/settings.cfg',
    )
      ..createSync(recursive: true)
      ..writeAsStringSync('"setting.mouse_sensitivity" "2.5"\n');
    final video = File(
      '${home.path}/Saved Games/Respawn/Apex/local/videoconfig.txt',
    )
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
          locator: InstallLocator(env: {'USERPROFILE': home.path}),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(_norm(file.state.path!), _norm(video.path));
    expect(file.state.kind, CfgKind.videoconfig);
    expect(settings.existsSync(), isTrue);
  });

  testWidgets('nothing found → empty-state; specify config dir re-probes and '
      'opens settings.cfg', (t) async {
    final local = Directory('${tmp.path}/CustomLocal')
      ..createSync(recursive: true);
    final settings = File('${local.path}/settings.cfg')
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
          locator: InstallLocator(env: const {}),
          pickDirectory: () async => local.path,
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(file.state.path, isNull);
    expect(find.text('Apex not found'), findsOneWidget);
    expect(find.text('Specify config directory'), findsOneWidget);

    await t.tap(find.text('Specify config directory'));
    await t.pumpAndSettle();

    expect(_norm(file.state.path!), _norm(settings.path));
    expect(_norm(store.readCustomInstallDir()!), _norm(local.path));
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

    final locator = InstallLocator(env: {'USERPROFILE': home.path});
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
