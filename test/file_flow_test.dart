import 'dart:io';

import 'package:apex_cfg_editor/core/backup/backup_service.dart';
import 'package:apex_cfg_editor/core/diff/line_diff.dart';
import 'package:apex_cfg_editor/knowledge/kb_service.dart';
import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/main.dart';
import 'package:apex_cfg_editor/state/diff_bloc.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';
import 'package:apex_cfg_editor/ui/editor_screen.dart';
import 'package:apex_cfg_editor/ui/exit_guard.dart';
import 'package:apex_cfg_editor/ui/widgets/text_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

const _old = '"setting.fps_max" "0"\n"setting.r_full" "1"\n';
const _new = '"setting.fps_max" "144"\n"setting.r_full" "1"\n';

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

/// 与 main.dart 生产装配一致的真实接线：真实 BackupService（临时目录）
/// + backupThenWrite（先备份旧内容再写盘），零 mocktail。
(FileBloc, EditBloc, DiffBloc) _wire(String backupBase) {
  final backups = BackupService(baseDir: backupBase);
  final edit = EditBloc();
  final diff = DiffBloc(editStream: edit.stream);
  final file = FileBloc(
    editBloc: edit,
    saveImpl: (p, t, e) => backupThenWrite(backups, p, t, e),
    listBackupsImpl: backups.listBackups,
    restoreImpl: backups.restore,
  );
  return (file, edit, diff);
}

List<File> _backupFiles(String backupBase, String fileName) => Directory(
      '$backupBase/$fileName',
    )
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.cfg'))
        .toList();

Widget _host(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('apex_cfg_flow_');
  });
  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  group('file flow with real implementations (temp dir)', () {
    test('open, edit, save: disk updated, one backup with old content, dirty cleared', () async {
      final cfg = File('${tmp.path}/videoconfig.txt')..writeAsStringSync(_old);
      final backupBase = '${tmp.path}/backups';
      final (file, edit, diff) = _wire(backupBase);

      // 装配顺序约束：三个 bloc 全部就绪后才发起 OpenRequested，
      // DiffBloc 订阅 editStream 能收到首个文档状态。
      file.add(OpenRequested(cfg.path));
      await _settle();
      expect(file.state.path, cfg.path);
      expect(diff.state.rows, isNotEmpty);
      expect(edit.state.dirty, false);

      edit.add(LineValueChanged(index: 0, value: '144'));
      await _settle();
      expect(edit.state.dirty, true);

      file.add(SaveRequested());
      await _settle();

      // 磁盘文件内容已更新。
      expect(File(cfg.path).readAsStringSync(), _new);
      // 备份目录出现 1 个备份且内容为旧内容。
      final backups = _backupFiles(backupBase, 'videoconfig.txt');
      expect(backups, hasLength(1));
      expect(backups.single.readAsStringSync(), _old);
      // 编辑状态与还原对话框数据。
      expect(edit.state.dirty, false);
      expect(file.state.backups, hasLength(1));

      await file.close();
      await diff.close();
      await edit.close();
    });

    test('restore requested: disk and edit bloc back to old content', () async {
      final cfg = File('${tmp.path}/videoconfig.txt')..writeAsStringSync(_old);
      final backupBase = '${tmp.path}/backups';
      final (file, edit, diff) = _wire(backupBase);
      file.add(OpenRequested(cfg.path));
      await _settle();
      edit.add(LineValueChanged(index: 0, value: '144'));
      await _settle();
      file.add(SaveRequested());
      await _settle();
      final backupPath = file.state.backups.single;

      // 再次编辑制造脏状态后还原。
      edit.add(LineValueChanged(index: 1, value: '2'));
      await _settle();
      expect(edit.state.dirty, true);

      file.add(RestoreRequested(backupPath));
      await _settle();

      // 磁盘恢复旧内容。
      expect(File(cfg.path).readAsStringSync(), _old);
      // 编辑器重新加载为旧内容：doc / 基线 / dirty 全部复位。
      expect(edit.state.doc!.serialize(), _old);
      expect(edit.state.baseline, _old);
      expect(edit.state.dirty, false);
      expect(file.state.path, cfg.path);
      expect(diff.state.rows.map((r) => r.type), everyElement(RowType.same));

      await file.close();
      await diff.close();
      await edit.close();
    });

    test('KbService.fromAssets loads real assets in test env', () async {
      final kb = await KbService.fromAssets();
      expect(kb.data['en'], isNotEmpty);
      expect(kb.data['zh'], isNotEmpty);
      // 跨域候选：videoconfig 前缀键回退命中 autoexec 表的 fps_max。
      expect(kb.lookup(KbFile.videoconfig, 'setting.fps_max', 'en')?.name,
          'FPS Cap');
      expect(kb.lookup(KbFile.videoconfig, 'setting.gamma', 'zh'), isNotNull);
    });
  });

  group('assembly widgets', () {
    testWidgets('auto-detect opens videoconfig found under injected home dir',
        (t) async {
      final home = '${tmp.path}/home';
      final cfg = File('$home/Documents/Respawn/Apex/local/videoconfig.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync(_old);
      final (file, edit, diff) = _wire('${tmp.path}/backups');
      addTearDown(() async {
        await file.close();
        await diff.close();
        await edit.close();
      });

      await t.pumpWidget(_host(EditorScreen(
        editBloc: edit,
        diffBloc: diff,
        fileBloc: file,
        homeDirOverride: home,
      )));
      await t.pumpAndSettle();

      expect(file.state.path, cfg.path);
      expect(find.text('videoconfig.txt'), findsOneWidget); // AppBar 标题
      expect(find.text('setting.fps_max'), findsOneWidget); // 表格模式渲染内容
    });

    testWidgets('nothing found stays silent; open button picks a file manually',
        (t) async {
      final home = Directory('${tmp.path}/empty_home')..createSync(recursive: true);
      final cfg = File('${tmp.path}/picked/videoconfig.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync(_old);
      final (file, edit, diff) = _wire('${tmp.path}/backups');
      addTearDown(() async {
        await file.close();
        await diff.close();
        await edit.close();
      });

      await t.pumpWidget(_host(EditorScreen(
        editBloc: edit,
        diffBloc: diff,
        fileBloc: file,
        homeDirOverride: home.path,
        pickFile: () async => cfg.path,
      )));
      await t.pumpAndSettle();

      // 静默：无文件打开、无告警。
      expect(file.state.path, isNull);
      expect(file.state.warning, isNull);
      expect(find.text('Open a cfg file to start editing'), findsOneWidget);

      await t.tap(find.byTooltip('Open file'));
      await t.pumpAndSettle();

      expect(file.state.path, cfg.path);
      expect(edit.state.doc!.serialize(), _old);
    });

    testWidgets('restore dialog lists backups; restoring refreshes text mode',
        (t) async {
      final cfg = File('${tmp.path}/videoconfig.txt')..writeAsStringSync(_new);
      final backupBase = '${tmp.path}/backups';
      Directory('$backupBase/videoconfig.txt').createSync(recursive: true);
      File('$backupBase/videoconfig.txt/20260101-000000.cfg')
          .writeAsStringSync(_old);
      final (file, edit, diff) = _wire(backupBase);
      addTearDown(() async {
        await file.close();
        await diff.close();
        await edit.close();
      });

      await t.pumpWidget(_host(EditorScreen(
        editBloc: edit,
        diffBloc: diff,
        fileBloc: file,
        autoDetect: false,
      )));
      file.add(OpenRequested(cfg.path));
      await t.pumpAndSettle();
      expect(file.state.backups, hasLength(1));

      // 切到文本模式：当前内容是 _new（CodeController 只在 initState
      // 初始化一次，直接断言控制器文本最精确）。
      await t.tap(find.text('Text'));
      await t.pumpAndSettle();
      expect(find.byType(TextEditorView), findsOneWidget);
      expect(t.widget<CodeField>(find.byType(CodeField)).controller.text, _new);
      expect(t.widget<TextEditorView>(find.byType(TextEditorView)).key,
          const ValueKey<int>(0));

      // 还原对话框：列出备份（文件名 + 时间戳）。
      await t.tap(find.byTooltip('Restore'));
      await t.pumpAndSettle();
      expect(find.text('Restore from backup'), findsOneWidget);
      expect(find.text('20260101-000000.cfg'), findsOneWidget);
      expect(find.text('2026-01-01 00:00:00'), findsOneWidget);

      // 选择备份 → 对话框关闭 → 磁盘还原 → 编辑器强制刷新回显旧内容。
      await t.tap(find.text('20260101-000000.cfg'));
      await t.pumpAndSettle();
      expect(find.text('Restore from backup'), findsNothing);
      expect(File(cfg.path).readAsStringSync(), _old);
      expect(edit.state.doc!.serialize(), _old);
      expect(edit.state.dirty, false);
      // 还原后刷新约束（任务 14 账本）：epoch key 重建 TextEditorView，
      // 控制器重新以还原后的文档初始化。
      expect(t.widget<TextEditorView>(find.byType(TextEditorView)).key,
          const ValueKey<int>(1));
      expect(t.widget<CodeField>(find.byType(CodeField)).controller.text, _old);
    });

    testWidgets('open failure warning surfaces as snackbar text', (t) async {
      final (file, edit, diff) = _wire('${tmp.path}/backups');
      addTearDown(() async {
        await file.close();
        await diff.close();
        await edit.close();
      });

      await t.pumpWidget(_host(EditorScreen(
        editBloc: edit,
        diffBloc: diff,
        fileBloc: file,
        autoDetect: false,
      )));
      file.add(OpenRequested('${tmp.path}/no_such_file.txt'));
      await t.pumpAndSettle();

      expect(find.text('Failed to open file'), findsOneWidget);
    });

    testWidgets('bad encoding warning surfaces as snackbar text', (t) async {
      // 0xC3 0x28：UTF-8 严格解码失败，GBK 解码也残缺 → U+FFFD 坏字节。
      final cfg = File('${tmp.path}/videoconfig.txt')
        ..writeAsBytesSync(const [0xC3, 0x28, 0x0A]);
      final (file, edit, diff) = _wire('${tmp.path}/backups');
      addTearDown(() async {
        await file.close();
        await diff.close();
        await edit.close();
      });

      await t.pumpWidget(_host(EditorScreen(
        editBloc: edit,
        diffBloc: diff,
        fileBloc: file,
        autoDetect: false,
      )));
      file.add(OpenRequested(cfg.path));
      await t.pumpAndSettle();

      expect(file.state.warning, 'fileBadEncoding');
      expect(find.textContaining('cannot be decoded'), findsOneWidget);
    });
  });

  group('exit guard (pure logic, no window_manager)', () {
    test('clean document exits without asking', () async {
      final cfg = File('${tmp.path}/videoconfig.txt')..writeAsStringSync(_old);
      final (file, edit, diff) = _wire('${tmp.path}/backups');
      file.add(OpenRequested(cfg.path));
      await _settle();

      var asked = 0;
      var destroyed = 0;
      final guard = ExitGuard(
        editBloc: edit,
        fileBloc: file,
        askUser: () async {
          asked++;
          return QuitChoice.cancel;
        },
        destroy: () async => destroyed++,
      );

      expect(await guard.confirmExit(), isTrue);
      expect(asked, 0); // 不脏：不打扰用户
      expect(destroyed, 1);

      await file.close();
      await diff.close();
      await edit.close();
    });

    test('save choice persists to disk then destroys', () async {
      final cfg = File('${tmp.path}/videoconfig.txt')..writeAsStringSync(_old);
      final backupBase = '${tmp.path}/backups';
      final (file, edit, diff) = _wire(backupBase);
      file.add(OpenRequested(cfg.path));
      await _settle();
      edit.add(LineValueChanged(index: 0, value: '144'));
      await _settle();
      expect(edit.state.dirty, true);

      var destroyed = 0;
      String contentAtDestroy = '';
      final guard = ExitGuard(
        editBloc: edit,
        fileBloc: file,
        askUser: () async => QuitChoice.save,
        destroy: () async {
          destroyed++;
          contentAtDestroy = File(cfg.path).readAsStringSync();
        },
      );

      expect(await guard.confirmExit(), isTrue);
      // destroy 在保存落盘之后执行。
      expect(destroyed, 1);
      expect(contentAtDestroy, _new);
      expect(File(cfg.path).readAsStringSync(), _new);
      expect(edit.state.dirty, false);
      // 保存路径走真实装配：备份同样产生。
      expect(_backupFiles(backupBase, 'videoconfig.txt'), hasLength(1));

      await file.close();
      await diff.close();
      await edit.close();
    });

    test('discard choice exits without writing', () async {
      final cfg = File('${tmp.path}/videoconfig.txt')..writeAsStringSync(_old);
      final (file, edit, diff) = _wire('${tmp.path}/backups');
      file.add(OpenRequested(cfg.path));
      await _settle();
      edit.add(LineValueChanged(index: 0, value: '144'));
      await _settle();

      var destroyed = 0;
      final guard = ExitGuard(
        editBloc: edit,
        fileBloc: file,
        askUser: () async => QuitChoice.discard,
        destroy: () async => destroyed++,
      );

      expect(await guard.confirmExit(), isTrue);
      expect(destroyed, 1);
      expect(File(cfg.path).readAsStringSync(), _old); // 未写盘
      expect(edit.state.dirty, true); // 编辑状态原样保留（进程随即退出）

      await file.close();
      await diff.close();
      await edit.close();
    });

    test('cancel or dismissed dialog keeps the window open', () async {
      final cfg = File('${tmp.path}/videoconfig.txt')..writeAsStringSync(_old);
      final (file, edit, diff) = _wire('${tmp.path}/backups');
      file.add(OpenRequested(cfg.path));
      await _settle();
      edit.add(LineValueChanged(index: 0, value: '144'));
      await _settle();

      final guard = ExitGuard(
        editBloc: edit,
        fileBloc: file,
        askUser: () async => QuitChoice.cancel,
        destroy: () async {},
      );
      expect(await guard.confirmExit(), isFalse);

      // 对话框被关闭（返回 null）同样视为取消。
      final guard2 = ExitGuard(
        editBloc: edit,
        fileBloc: file,
        askUser: () async => null,
        destroy: () async {},
      );
      expect(await guard2.confirmExit(), isFalse);

      await file.close();
      await diff.close();
      await edit.close();
    });
  });

  testWidgets('quit dialog offers save/discard/cancel via PopScope path',
      (t) async {
    final cfg = File('${tmp.path}/videoconfig.txt')..writeAsStringSync(_old);
    final (file, edit, diff) = _wire('${tmp.path}/backups');
    addTearDown(() async {
      await file.close();
      await diff.close();
      await edit.close();
    });

    await t.pumpWidget(_host(EditorScreen(
      editBloc: edit,
      diffBloc: diff,
      fileBloc: file,
      autoDetect: false,
    )));
    file.add(OpenRequested(cfg.path));
    await t.pumpAndSettle();

    edit.add(LineValueChanged(index: 0, value: '144'));
    await t.pump();

    // PopScope canPop=false：maybePop 触发退出保护对话框。
    final navigator = t.state<NavigatorState>(find.byType(Navigator));
    navigator.maybePop();
    await t.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Save and exit'), findsOneWidget);
    expect(find.text('Discard and exit'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // 取消 → 对话框关闭、应用仍在。
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsNothing);
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(File(cfg.path).readAsStringSync(), _old); // 未写盘
  });
}
