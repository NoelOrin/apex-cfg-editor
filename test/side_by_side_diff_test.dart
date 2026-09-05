import 'package:apex_cfg_editor/core/parser/autoexec_parser.dart';
import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/state/diff_bloc.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/ui/widgets/side_by_side_diff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 高亮色与实现共享同一契约：删除红 / 新增绿（任务 16 前允许的唯一硬编码色）。
const _deleteBg = Color(0x33E2483D);
const _addBg = Color(0x3322C55E);

// 核心测试用真实 EditBloc + DiffBloc + 真实解析器，不用 mock（避免 mock 漂移）。
Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

EditBloc _editBloc() => EditBloc();

DiffBloc _diffBloc(EditBloc edit) {
  final bloc = DiffBloc(editStream: edit.stream);
  return bloc;
}

void main() {
  testWidgets(
      'live edit shows old and new values with delete-red / add-green rows',
      (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    final diff = _diffBloc(edit);
    addTearDown(diff.close);

    edit.add(DocumentOpened(
        doc: AutoexecParser().parse('fps_max 0\n'), baseline: 'fps_max 0\n'));
    await t.pumpWidget(_host(SideBySideDiff(diffBloc: diff)));
    await t.pumpAndSettle();

    // 编辑前：same 行左右各一份旧值，且无红绿高亮。
    expect(find.text('fps_max 0'), findsNWidgets(2));
    final beforeOld = t.widgetList<Container>(find.ancestor(
        of: find.text('fps_max 0'), matching: find.byType(Container)));
    expect(beforeOld.map((c) => c.color), isNot(contains(_deleteBg)));
    expect(beforeOld.map((c) => c.color), isNot(contains(_addBg)));

    edit.add(LineValueChanged(index: 0, value: '144'));
    await t.pumpAndSettle();

    // 编辑后：旧值（左栏）与新值（右栏）同屏。
    expect(find.text('fps_max 0'), findsOneWidget);
    expect(find.text('fps_max 144'), findsOneWidget);

    final oldAncestors = t.widgetList<Container>(find.ancestor(
        of: find.text('fps_max 0'), matching: find.byType(Container)));
    expect(oldAncestors.map((c) => c.color), contains(_deleteBg));
    final newAncestors = t.widgetList<Container>(find.ancestor(
        of: find.text('fps_max 144'), matching: find.byType(Container)));
    expect(newAncestors.map((c) => c.color), contains(_addBg));
  });

  testWidgets('added row appears only in right column, left stays blank',
      (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    final diff = _diffBloc(edit);
    addTearDown(diff.close);

    edit.add(DocumentOpened(
        doc: AutoexecParser().parse('fps_max 0\nfps_mouse 1\n'),
        baseline: 'fps_max 0\n'));
    await t.pumpWidget(_host(SideBySideDiff(diffBloc: diff)));
    await t.pumpAndSettle();

    // 新增文本只在绿色（右栏）单元格里出现一次。
    expect(find.text('fps_mouse 1'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byWidgetPredicate(
                (w) => w is Container && w.color == _addBg),
            matching: find.text('fps_mouse 1')),
        findsOneWidget);
    // 左栏同行为空：行号占位 + 行文本两个空 Text。
    expect(find.text(''), findsNWidgets(2));
    // 行号：same 行左右各 '0'，added 行只有右栏 '1'。
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('removed row appears only in left column, right stays blank',
      (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    final diff = _diffBloc(edit);
    addTearDown(diff.close);

    edit.add(DocumentOpened(
        doc: AutoexecParser().parse('fps_max 0\n'),
        baseline: 'fps_max 0\nfps_mouse 1\n'));
    await t.pumpWidget(_host(SideBySideDiff(diffBloc: diff)));
    await t.pumpAndSettle();

    // 删除文本只在红色（左栏）单元格里出现一次。
    expect(find.text('fps_mouse 1'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byWidgetPredicate(
                (w) => w is Container && w.color == _deleteBg),
            matching: find.text('fps_mouse 1')),
        findsOneWidget);
    // 右栏同行为空：行号占位 + 行文本两个空 Text。
    expect(find.text(''), findsNWidgets(2));
    // 行号：same 行左右各 '0'，removed 行只有左栏 '1'。
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('empty rows show centered no-changes hint', (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    final diff = _diffBloc(edit);
    addTearDown(diff.close);

    await t.pumpWidget(_host(SideBySideDiff(diffBloc: diff)));
    await t.pumpAndSettle();

    expect(find.text('No changes'), findsOneWidget);
    expect(
        find.ancestor(
            of: find.text('No changes'), matching: find.byType(Center)),
        findsOneWidget);
  });

  testWidgets('no-changes hint localizes to zh', (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    final diff = _diffBloc(edit);
    addTearDown(diff.close);

    await t.pumpWidget(_host(SideBySideDiff(diffBloc: diff),
        locale: const Locale('zh')));
    await t.pumpAndSettle();

    expect(find.text('无变更'), findsOneWidget);
  });
}
