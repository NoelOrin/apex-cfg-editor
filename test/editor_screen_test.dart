import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/state/diff_bloc.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';
import 'package:apex_cfg_editor/ui/editor_screen.dart';
import 'package:apex_cfg_editor/ui/widgets/kv_table_view.dart';
import 'package:apex_cfg_editor/ui/widgets/text_editor_view.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockEditBloc extends MockBloc<EditEvent, EditState> implements EditBloc {}
class MockDiffBloc extends MockCubit<DiffState> implements DiffBloc {}
class MockFileBloc extends MockBloc<FileEvent, FileState> implements FileBloc {}

void main() {
  // SaveRequested 无 == 重写（按身份相等），verify 需按类型匹配。
  setUpAll(() => registerFallbackValue(SaveRequested()));

  testWidgets('renders top bar with mode toggle (lucide icons, no emoji)',
      (t) async {
    final edit = MockEditBloc();
    final diff = MockDiffBloc();
    final file = MockFileBloc();
    whenListen(edit, const Stream<EditState>.empty(),
        initialState: const EditState());
    whenListen(diff, const Stream<DiffState>.empty(),
        initialState: const DiffState());
    whenListen(file, const Stream<FileState>.empty(),
        initialState: const FileState());

    await t.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EditorScreen(editBloc: edit, diffBloc: diff, fileBloc: file),
    ));
    expect(find.text('Apex CFG Editor'), findsWidgets);
    // 模式切换为纯图标段（Tooltip 兼作语义标签），断言随 UI 形态调整。
    expect(find.byTooltip('Table'), findsOneWidget);
    expect(find.byTooltip('Text'), findsOneWidget);
  });

  testWidgets('mode toggle swaps editing area between table and text views',
      (t) async {
    final edit = MockEditBloc();
    final diff = MockDiffBloc();
    final file = MockFileBloc();
    whenListen(edit, const Stream<EditState>.empty(),
        initialState: const EditState());
    whenListen(diff, const Stream<DiffState>.empty(),
        initialState: const DiffState());
    whenListen(file, const Stream<FileState>.empty(),
        initialState: const FileState());

    await t.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EditorScreen(editBloc: edit, diffBloc: diff, fileBloc: file),
    ));

    expect(find.byType(KvTableView), findsOneWidget);
    expect(find.byType(TextEditorView), findsNothing);

    await t.tap(find.byTooltip('Text'));
    await t.pumpAndSettle();
    expect(find.byType(TextEditorView), findsOneWidget);
    expect(find.byType(KvTableView), findsNothing);

    await t.tap(find.byTooltip('Table'));
    await t.pumpAndSettle();
    expect(find.byType(KvTableView), findsOneWidget);
    expect(find.byType(TextEditorView), findsNothing);
  });

  testWidgets('save button dispatches SaveRequested to file bloc', (t) async {
    final edit = MockEditBloc();
    final diff = MockDiffBloc();
    final file = MockFileBloc();
    whenListen(edit, const Stream<EditState>.empty(),
        initialState: const EditState());
    whenListen(diff, const Stream<DiffState>.empty(),
        initialState: const DiffState());
    whenListen(file, const Stream<FileState>.empty(),
        initialState: const FileState());

    await t.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EditorScreen(editBloc: edit, diffBloc: diff, fileBloc: file),
    ));

    await t.tap(find.byTooltip('Save'));
    await t.pumpAndSettle();

    verify(() => file.add(any<SaveRequested>(that: isA<SaveRequested>())))
        .called(1);
  });

  testWidgets('file picker failure surfaces a snackbar (filePickerFailed)',
      (t) async {
    final edit = MockEditBloc();
    final diff = MockDiffBloc();
    final file = MockFileBloc();
    whenListen(edit, const Stream<EditState>.empty(),
        initialState: const EditState());
    whenListen(diff, const Stream<DiffState>.empty(),
        initialState: const DiffState());
    whenListen(file, const Stream<FileState>.empty(),
        initialState: const FileState());

    await t.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EditorScreen(
        editBloc: edit,
        diffBloc: diff,
        fileBloc: file,
        autoDetect: false,
        // 注入抛错的 picker seam：file_picker 层异常不再被静默吞掉。
        pickFile: () async => throw Exception('picker crashed'),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Open file'));
    await t.pumpAndSettle();

    expect(find.text('Failed to open the file picker'), findsOneWidget);
  });
}
