import 'dart:io';

import 'package:apex_cfg_editor/core/parser/cfg_document.dart';
import 'package:apex_cfg_editor/core/parser/videoconfig_parser.dart';
import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';
import 'package:apex_cfg_editor/ui/widgets/text_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

// 核心测试用真实 EditBloc + 真实解析器 + 真实 CodeField，不用 mock
// （防抖契约与解析选择都必须走真实链路）。FileBloc 也用真实实现，
// kind 由临时文件路径（非 videoconfig.txt 结尾 → autoexec）驱动。
const _src = '"setting.fps_max" "0"\n"setting.r_full" "1"\n';

EditBloc _realEditBloc({String src = _src}) {
  final bloc = EditBloc();
  bloc.add(DocumentOpened(
      doc: VideoconfigParser().parse(src), baseline: src));
  return bloc;
}

FileBloc _realFileBloc(EditBloc edit) => FileBloc(
      editBloc: edit,
      saveImpl: (_, _, _) async {},
      listBackupsImpl: (_) => const [],
      restoreImpl: (_, _) async {},
    );

Widget _host(Widget child, {FileBloc? fileBloc}) => MaterialApp(
      // 查找替换栏的文案走 AppLocalizations：host 需要挂 delegates。
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: fileBloc == null
          ? Scaffold(body: child)
          : BlocProvider<FileBloc>.value(
              value: fileBloc,
              child: Scaffold(body: child),
            ),
    );

void main() {
  testWidgets(
      'typing reparses full text into bloc after 300ms debounce '
      '(videoconfig default when no FileBloc provider)', (t) async {
    final edit = _realEditBloc();
    addTearDown(edit.close);

    // 无 FileBloc provider：EditorScreen 接线如此，可空读取 null → videoconfig。
    await t.pumpWidget(_host(TextEditorView(editBloc: edit)));
    await t.pumpAndSettle();

    // 初始文本来自 Bloc 当前内容；enterText 追加一行。
    await t.enterText(
        find.byType(CodeField), '${_src}fps_max 256\n');
    await t.pump(const Duration(milliseconds: 400)); // 越过 300ms 防抖
    await t.pump(); // 冲刷事件处理微任务

    expect(edit.state.dirty, isTrue);
    expect(edit.state.doc!.serialize(), contains('fps_max 256'));
  });

  testWidgets('debounce holds: bloc untouched before 300ms elapses', (t) async {
    final edit = _realEditBloc();
    addTearDown(edit.close);

    await t.pumpWidget(_host(TextEditorView(editBloc: edit)));
    await t.pumpAndSettle();

    await t.enterText(
        find.byType(CodeField), '${_src}fps_max 256\n');
    await t.pump(const Duration(milliseconds: 100)); // 未到 300ms

    expect(edit.state.dirty, isFalse);
    expect(edit.state.doc!.serialize(), _src);
  });

  testWidgets('no document open: editor shows empty; typing creates doc',
      (t) async {
    final edit = EditBloc();
    addTearDown(edit.close);

    await t.pumpWidget(_host(TextEditorView(editBloc: edit)));
    await t.pumpAndSettle();

    expect(find.byType(CodeField), findsOneWidget);
    await t.enterText(find.byType(CodeField), 'fps_max 256\n');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();

    expect(edit.state.doc!.serialize(), 'fps_max 256\n');
    expect(edit.state.dirty, isTrue);
  });

  testWidgets('FileBloc kind=autoexec parses bind as CvarLine(key=bind)',
      (t) async {
    final edit = EditBloc();
    addTearDown(edit.close);
    final file = _realFileBloc(edit);
    addTearDown(file.close);

    // 真实 FileBloc：临时 autoexec.cfg（非 videoconfig.txt 结尾 → autoexec）。
    final dir = Directory.systemTemp.createTempSync('apex_cfg_editor_te14');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}autoexec.cfg';
    File(path).writeAsStringSync('// my autoexec\n');
    file.add(OpenRequested(path));
    await t.pump(); // 冲刷微任务：DocumentOpened 就绪后再进入文本模式

    await t.pumpWidget(
        _host(TextEditorView(editBloc: edit), fileBloc: file));
    await t.pumpAndSettle();

    // 追加一行 bind。
    await t.enterText(find.byType(CodeField),
        '// my autoexec\nbind "F6" "quit"\n');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();

    final doc = edit.state.doc!;
    final bind = doc.lines.whereType<CvarLine>().toList();
    expect(bind.map((l) => l.key), contains('bind'));
    expect(
      bind.firstWhere((l) => l.key == 'bind').value,
      '"F6" "quit"',
    );
    expect(edit.state.dirty, isTrue);
  });

  group('find & replace bar (spec R4)', () {
    testWidgets('find next selects the match', (t) async {
      final edit = _realEditBloc();
      addTearDown(edit.close);

      await t.pumpWidget(_host(TextEditorView(editBloc: edit)));
      await t.pumpAndSettle();
      // 输入触发 FullTextChanged 后再查找（与规格 R4 用户路径一致）。
      await t.enterText(find.byType(CodeField), '$_src// tuned\n');
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(edit.state.dirty, isTrue);

      await t.tap(find.byTooltip('Find'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('findField')), 'fps_max');
      await t.tap(find.byTooltip('Next'));
      await t.pumpAndSettle();

      final ctrl = t.widget<CodeField>(find.byType(CodeField)).controller;
      // '"setting.' 长 9：首个 fps_max 在 [9, 16)。
      expect(ctrl.selection.baseOffset, 9);
      expect(ctrl.selection.extentOffset, 16);
    });

    testWidgets('find prev goes back; next wraps around at end', (t) async {
      final edit = _realEditBloc(
          src: '"setting.fps_max" "0"\nfps_max 256\n');
      addTearDown(edit.close);

      await t.pumpWidget(_host(TextEditorView(editBloc: edit)));
      await t.pumpAndSettle();

      await t.tap(find.byTooltip('Find'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('findField')), 'fps_max');

      await t.tap(find.byTooltip('Next'));
      await t.pumpAndSettle();
      final ctrl = t.widget<CodeField>(find.byType(CodeField)).controller;
      expect(ctrl.selection.baseOffset, 9); // 第一个匹配

      await t.tap(find.byTooltip('Next'));
      await t.pumpAndSettle();
      expect(ctrl.selection.baseOffset, 22); // 第二个（行首 22 = 9+7 处第二段）

      await t.tap(find.byTooltip('Next'));
      await t.pumpAndSettle();
      expect(ctrl.selection.baseOffset, 9); // 回卷到开头

      await t.tap(find.byTooltip('Previous'));
      await t.pumpAndSettle();
      expect(ctrl.selection.baseOffset, 22); // 向前 = 回卷到末尾
    });

    testWidgets('replace all rewrites text, serialize updates, stays dirty',
        (t) async {
      final edit = _realEditBloc();
      addTearDown(edit.close);

      await t.pumpWidget(_host(TextEditorView(editBloc: edit)));
      await t.pumpAndSettle();
      await t.enterText(find.byType(CodeField), '$_src// fps_max here\n');
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();

      await t.tap(find.byTooltip('Find'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('findField')), 'fps_max');
      await t.enterText(
          find.byKey(const ValueKey('replaceField')), 'r_gamma');
      await t.tap(find.byTooltip('Replace all'));
      await t.pump(const Duration(milliseconds: 400)); // 越过防抖
      await t.pump();

      expect(edit.state.dirty, isTrue);
      expect(edit.state.doc!.serialize(), contains('r_gamma'));
      expect(edit.state.doc!.serialize(), isNot(contains('fps_max')));
      final ctrl = t.widget<CodeField>(find.byType(CodeField)).controller;
      expect(ctrl.text, isNot(contains('fps_max')));
    });
  });
}
