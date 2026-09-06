import 'dart:convert';
import 'dart:io';

import 'package:apex_cfg_editor/core/diff/line_diff.dart';
import 'package:apex_cfg_editor/core/io/cfg_file_io.dart';
import 'package:apex_cfg_editor/core/parser/cfg_document.dart';
import 'package:apex_cfg_editor/core/parser/videoconfig_parser.dart';
import 'package:apex_cfg_editor/state/diff_bloc.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';

const _baseline = '"setting.fps_max" "0"\n"setting.r_full" "1"\n';
const _edited = '"setting.fps_max" "144"\n"setting.r_full" "1"\n';

CfgDocument _doc() =>
    VideoconfigParser().parse('"setting.fps_max" "0"\n"setting.r_full" "1"\n');

void main() {
  group('edit bloc', () {
    blocTest<EditBloc, EditState>(
      'edit value → dirty and serialize reflects change',
      build: () => EditBloc(),
      act: (b) {
        b.add(DocumentOpened(doc: _doc(), baseline: '"setting.fps_max" "0"\n"setting.r_full" "1"\n'));
        b.add(LineValueChanged(index: 0, value: '144'));
      },
      expect: () => [
        isA<EditState>().having((s) => s.dirty, 'dirty', false),
        isA<EditState>()
            .having((s) => s.dirty, 'dirty', true)
            .having((s) => s.doc!.serialize(), 'text',
                '"setting.fps_max" "144"\n"setting.r_full" "1"\n'),
      ],
    );

    blocTest<EditBloc, EditState>(
      'edit value then back to original → dirty false (serialize == baseline)',
      build: () => EditBloc(),
      act: (b) {
        b.add(DocumentOpened(doc: _doc(), baseline: _baseline));
        b.add(LineValueChanged(index: 0, value: '144'));
        b.add(LineValueChanged(index: 0, value: '0'));
      },
      expect: () => [
        isA<EditState>().having((s) => s.dirty, 'dirty', false),
        isA<EditState>().having((s) => s.dirty, 'dirty', true),
        isA<EditState>()
            .having((s) => s.dirty, 'dirty', false)
            .having((s) => s.doc!.serialize(), 'text', _baseline),
      ],
    );

    blocTest<EditBloc, EditState>(
      'FullTextChanged equal to baseline → dirty false',
      build: () => EditBloc(),
      act: (b) {
        b.add(DocumentOpened(doc: _doc(), baseline: _baseline));
        b.add(FullTextChanged(VideoconfigParser().parse(_baseline)));
      },
      expect: () => [
        isA<EditState>().having((s) => s.dirty, 'dirty', false),
        isA<EditState>()
            .having((s) => s.dirty, 'dirty', false)
            .having((s) => s.doc!.serialize(), 'text', _baseline),
      ],
    );

    blocTest<EditBloc, EditState>(
      'selection change sets and clears selectedIndex',
      build: () => EditBloc(),
      act: (b) {
        b.add(SelectionChanged(2));
        b.add(SelectionChanged(null));
      },
      expect: () => [
        isA<EditState>().having((s) => s.selectedIndex, 'selectedIndex', 2),
        isA<EditState>().having((s) => s.selectedIndex, 'selectedIndex', null),
      ],
    );

    blocTest<EditBloc, EditState>(
      'full text replace parses to a new dirty doc',
      build: () => EditBloc(),
      act: (b) {
        b.add(DocumentOpened(doc: _doc(), baseline: _baseline));
        b.add(FullTextChanged(VideoconfigParser().parse(_edited)));
      },
      expect: () => [
        isA<EditState>().having((s) => s.dirty, 'dirty', false),
        isA<EditState>()
            .having((s) => s.dirty, 'dirty', true)
            .having((s) => s.doc!.serialize(), 'text', _edited),
      ],
    );

    blocTest<EditBloc, EditState>(
      'save refreshes baseline and clears dirty',
      build: () => EditBloc(),
      act: (b) {
        b.add(DocumentOpened(doc: _doc(), baseline: _baseline));
        b.add(LineValueChanged(index: 0, value: '144'));
        b.add(DocumentSaved(_edited));
      },
      expect: () => [
        isA<EditState>().having((s) => s.dirty, 'dirty', false),
        isA<EditState>().having((s) => s.dirty, 'dirty', true),
        isA<EditState>()
            .having((s) => s.dirty, 'dirty', false)
            .having((s) => s.baseline, 'baseline', _edited),
      ],
    );

    blocTest<EditBloc, EditState>(
      'stale baseline save keeps dirty for interleaved edits',
      build: () => EditBloc(),
      act: (b) {
        b.add(DocumentOpened(doc: _doc(), baseline: _baseline));
        b.add(LineValueChanged(index: 0, value: '144'));
        // 旧 serialize：模拟 saveImpl await 窗口内发生交错编辑后，
        // DocumentSaved 携带的基线已落后于当前 doc。
        b.add(DocumentSaved(_baseline));
      },
      expect: () => [
        isA<EditState>().having((s) => s.dirty, 'dirty', false),
        isA<EditState>().having((s) => s.dirty, 'dirty', true),
        isA<EditState>()
            .having((s) => s.dirty, 'dirty', true)
            .having((s) => s.baseline, 'baseline', _baseline),
      ],
    );
  });

  group('diff bloc', () {
    test('diff bloc derives rows from edit stream', () async {
      final edit = EditBloc();
      final diff = DiffBloc(editStream: edit.stream);
      edit.add(DocumentOpened(
          doc: _doc(), baseline: '"setting.fps_max" "0"\n"setting.r_full" "1"\n'));
      edit.add(LineValueChanged(index: 0, value: '144'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(diff.state.rows.first.type, RowType.modified);
      await diff.close();
      await edit.close();
    });

    test('rows all same after save refreshes baseline', () async {
      final edit = EditBloc();
      final diff = DiffBloc(editStream: edit.stream);
      edit.add(DocumentOpened(doc: _doc(), baseline: _baseline));
      edit.add(LineValueChanged(index: 0, value: '144'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(diff.state.rows.map((r) => r.type),
          [RowType.modified, RowType.same]);
      edit.add(DocumentSaved(_edited));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(diff.state.rows.map((r) => r.type), everyElement(RowType.same));
      expect(diff.state.rows.length, 2);
      await diff.close();
      await edit.close();
    });
  });

  group('file bloc', () {
    late Directory tmp;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('apex_cfg_blocs_');
    });
    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('open parses videoconfig and lists backups', () async {
      final file = File('${tmp.path}/videoconfig.txt')
        ..writeAsStringSync(_baseline);
      final edit = EditBloc();
      final backupsCalls = <String>[];
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, _) async {},
        listBackupsImpl: (p) {
          backupsCalls.add(p);
          return ['videoconfig.txt.bak.1'];
        },
        restoreImpl: (_, _) async {},
      );
      bloc.add(OpenRequested(file.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.path, file.path);
      expect(bloc.state.kind, CfgKind.videoconfig);
      expect(bloc.state.busy, false);
      expect(bloc.state.warning, isNull);
      expect(bloc.state.backups, ['videoconfig.txt.bak.1']);
      expect(backupsCalls, [file.path]);
      expect(edit.state.doc!.serialize(), _baseline);
      expect(edit.state.baseline, _baseline);
      await bloc.close();
      await edit.close();
    });

    test('open falls back to autoexec kind by file name', () async {
      final file = File('${tmp.path}/autoexec.cfg')
        ..writeAsStringSync('fps_max 0\n');
      final edit = EditBloc();
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, _) async {},
        listBackupsImpl: (_) => const [],
        restoreImpl: (_, _) async {},
      );
      bloc.add(OpenRequested(file.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.kind, CfgKind.autoexec);
      expect(edit.state.doc!.lines.first, isA<CvarLine>());
      await bloc.close();
      await edit.close();
    });

    test('save without edits is a no-op without new backups', () async {
      final file = File('${tmp.path}/videoconfig.txt')
        ..writeAsStringSync(_baseline);
      final edit = EditBloc();
      var saveCalls = 0;
      var backupsCalls = 0;
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, _) async => saveCalls++,
        listBackupsImpl: (_) {
          backupsCalls++;
          return const <String>[];
        },
        restoreImpl: (_, _) async {},
      );
      bloc.add(OpenRequested(file.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(backupsCalls, 1);
      bloc.add(SaveRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(saveCalls, 0);
      expect(backupsCalls, 1);
      expect(edit.state.dirty, false);
      await bloc.close();
      await edit.close();
    });

    test('save when edited writes, refreshes baseline and backups', () async {
      final file = File('${tmp.path}/videoconfig.txt')
        ..writeAsStringSync(_baseline);
      final edit = EditBloc();
      final saves = <(String, String, CfgEncoding)>[];
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (p, text, enc) async => saves.add((p, text, enc)),
        listBackupsImpl: (_) => ['videoconfig.txt.bak.2'],
        restoreImpl: (_, _) async {},
      );
      bloc.add(OpenRequested(file.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      edit.add(LineValueChanged(index: 0, value: '144'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.add(SaveRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(saves, [(file.path, _edited, CfgEncoding.utf8)]);
      expect(edit.state.dirty, false);
      expect(edit.state.baseline, _edited);
      expect(bloc.state.backups, ['videoconfig.txt.bak.2']);
      await bloc.close();
      await edit.close();
    });

    test('save keeps gbk encoding detected at save time', () async {
      final file = File('${tmp.path}/videoconfig.txt')
        ..writeAsBytesSync(gbk.encode('// 中文注释\n"setting.fps_max" "0"\n'));
      final edit = EditBloc();
      final encodings = <CfgEncoding>[];
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, enc) async => encodings.add(enc),
        listBackupsImpl: (_) => const [],
        restoreImpl: (_, _) async {},
      );
      bloc.add(OpenRequested(file.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.warning, isNull);
      edit.add(LineValueChanged(index: 1, value: '144'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.add(SaveRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(encodings, [CfgEncoding.gbk]);
      await bloc.close();
      await edit.close();
    });

    test('restore overwrites target and reopens', () async {
      final file = File('${tmp.path}/videoconfig.txt')
        ..writeAsStringSync(_baseline);
      final backup = File('${tmp.path}/videoconfig.txt.bak.1')
        ..writeAsStringSync(_edited);
      final edit = EditBloc();
      final restores = <(String, String)>[];
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, _) async {},
        listBackupsImpl: (_) => [backup.path],
        restoreImpl: (target, b) async {
          restores.add((target, b));
          File(target).writeAsStringSync(File(b).readAsStringSync());
        },
      );
      bloc.add(OpenRequested(file.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      edit.add(LineValueChanged(index: 0, value: '200'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.add(RestoreRequested(backup.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(restores, [(file.path, backup.path)]);
      expect(edit.state.baseline, _edited);
      expect(edit.state.doc!.serialize(), _edited);
      expect(edit.state.dirty, false);
      await bloc.close();
      await edit.close();
    });

    test('restore failure refreshes backup list (stale entries cleared)',
        () async {
      final file = File('${tmp.path}/videoconfig.txt')
        ..writeAsStringSync(_baseline);
      final edit = EditBloc();
      final store = <String>['${tmp.path}/gone.cfg'];
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, _) async {},
        listBackupsImpl: (_) => List.of(store),
        restoreImpl: (_, _) async => throw Exception('backup gone'),
      );
      bloc.add(OpenRequested(file.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.backups, ['${tmp.path}/gone.cfg']);

      // 列表中的备份在还原前失效（被删除）：restoreImpl 抛错。
      store.clear();
      bloc.add(RestoreRequested('${tmp.path}/gone.cfg'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // 失败分支同样重算 backups：失效条目从还原对话框消失。
      expect(bloc.state.warning, 'fileRestoreFailed');
      expect(bloc.state.backups, isEmpty);
      await bloc.close();
      await edit.close();
    });

    test('save after stale baseline is not no-op', () async {
      final file = File('${tmp.path}/videoconfig.txt')
        ..writeAsStringSync(_baseline);
      final edit = EditBloc();
      final saves = <(String, String, CfgEncoding)>[];
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (p, text, enc) async => saves.add((p, text, enc)),
        listBackupsImpl: (_) => const [],
        restoreImpl: (_, _) async {},
      );
      bloc.add(OpenRequested(file.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      edit.add(LineValueChanged(index: 0, value: '144'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      edit.add(DocumentSaved(_baseline)); // 旧 serialize：模拟保存竞态残留
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(edit.state.dirty, true);
      bloc.add(SaveRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(saves, [(file.path, _edited, CfgEncoding.utf8)]);
      expect(edit.state.dirty, false);
      await bloc.close();
      await edit.close();
    });

    test('restore without an open file is a guarded no-op', () async {
      final edit = EditBloc();
      var restoreCalls = 0;
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, _) async {},
        listBackupsImpl: (_) => const [],
        restoreImpl: (_, _) async => restoreCalls++,
      );
      bloc.add(RestoreRequested('${tmp.path}/whatever.cfg'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(restoreCalls, 0);
      expect(bloc.state.path, isNull);
      await bloc.close();
      await edit.close();
    });

    test('restore failure raises warning and bloc stays operable', () async {
      final file = File('${tmp.path}/videoconfig.txt')
        ..writeAsStringSync(_baseline);
      final edit = EditBloc();
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, _) async {},
        listBackupsImpl: (_) => const [],
        restoreImpl: (_, _) async => throw Exception('disk error'),
      );
      bloc.add(OpenRequested(file.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.warning, isNull);

      bloc.add(RestoreRequested('${tmp.path}/missing.cfg'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // 还原失败：告警出现、无异常逃逸，文件未被改写所以不重开。
      expect(bloc.state.warning, 'fileRestoreFailed');
      expect(bloc.state.path, file.path);
      expect(edit.state.baseline, _baseline);
      // bloc 流程未挂起：后续编辑与还原重试照常处理。
      edit.add(LineValueChanged(index: 0, value: '144'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(edit.state.dirty, true);
      await bloc.close();
      await edit.close();
    });

    test('save with dirty edits on bad-byte file is blocked', () async {
      // 0xC3 0x28：UTF-8 严格解码失败，GBK 解码残缺 → U+FFFD 坏字节。
      // 编辑后保存 = 全文重编码，坏字节被固化为 U+FFFD 的 UTF-8 编码
      // （二次损坏）——必须阻止，保住磁盘原始字节。
      final badBytes = <int>[
        0xC3, 0x28, 0x0A,
        ...utf8.encode('"setting.fps_max" "0"\n'),
      ];
      final file = File('${tmp.path}/videoconfig.txt')
        ..writeAsBytesSync(badBytes);
      final edit = EditBloc();
      var saveCalls = 0;
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, _) async => saveCalls++,
        listBackupsImpl: (_) => const [],
        restoreImpl: (_, _) async {},
      );
      bloc.add(OpenRequested(file.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(edit.state.doc, isNotNull);

      edit.add(LineValueChanged(index: 1, value: '144'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.add(SaveRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.warning, 'fileBadBytesDirty');
      expect(saveCalls, 0); // 不写盘（真实装配下也不备份）
      expect(file.readAsBytesSync(), badBytes); // 磁盘字节未变
      expect(edit.state.dirty, true); // 保持脏：处理后可再试
      await bloc.close();
      await edit.close();
    });

    test('open failure resets state and a retry recovers', () async {
      final file = File('${tmp.path}/videoconfig.txt')
        ..writeAsStringSync(_baseline);
      final edit = EditBloc();
      final bloc = FileBloc(
        editBloc: edit,
        saveImpl: (_, _, _) async {},
        listBackupsImpl: (_) => const [],
        restoreImpl: (_, _) async {},
      );
      bloc.add(OpenRequested('${tmp.path}/no_such_file.txt'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.busy, false);
      expect(bloc.state.warning, 'fileOpenFailed');
      expect(bloc.state.path, isNull);
      bloc.add(OpenRequested(file.path));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.path, file.path);
      expect(bloc.state.kind, CfgKind.videoconfig);
      expect(bloc.state.busy, false);
      expect(bloc.state.warning, isNull);
      expect(edit.state.doc!.serialize(), _baseline);
      await bloc.close();
      await edit.close();
    });
  });
}
