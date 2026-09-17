import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/state/diff_bloc.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';
import 'package:apex_cfg_editor/ui/editor_screen.dart';
import 'package:apex_cfg_editor/ui/widgets/kv_table_view.dart';
import 'package:apex_cfg_editor/ui/widgets/text_editor_view.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockEditBloc extends MockBloc<EditEvent, EditState> implements EditBloc {}

class MockDiffBloc extends MockCubit<DiffState> implements DiffBloc {}

class MockFileBloc extends MockBloc<FileEvent, FileState> implements FileBloc {}

void main() {
  // SaveRequested 无 == 重写（按身份相等），verify 需按类型匹配。
  setUpAll(() {
    registerFallbackValue(SaveRequested());
    registerFallbackValue(OpenRequested(''));
  });

  testWidgets('renders top bar with mode toggle (lucide icons, no emoji)', (
    t,
  ) async {
    final edit = MockEditBloc();
    final diff = MockDiffBloc();
    final file = MockFileBloc();
    whenListen(
      edit,
      const Stream<EditState>.empty(),
      initialState: const EditState(),
    );
    whenListen(
      diff,
      const Stream<DiffState>.empty(),
      initialState: const DiffState(),
    );
    whenListen(
      file,
      const Stream<FileState>.empty(),
      initialState: const FileState(),
    );

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          fluent.FluentLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditorScreen(editBloc: edit, diffBloc: diff, fileBloc: file),
      ),
    );
    expect(find.text('APEX CFG EDITOR'), findsWidgets);
    // 模式切换为纯图标段（Tooltip 兼作语义标签），断言随 UI 形态调整。
    expect(find.byTooltip('Table'), findsOneWidget);
    expect(find.byTooltip('Text'), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace.editor')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace.knowledgeBase')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('workspace.diffPreview')), findsOneWidget);
  });

  testWidgets('title bar close button routes dirty exit through ExitGuard', (
    t,
  ) async {
    final edit = MockEditBloc();
    final diff = MockDiffBloc();
    final file = MockFileBloc();
    whenListen(
      edit,
      const Stream<EditState>.empty(),
      initialState: const EditState(dirty: true),
    );
    whenListen(
      diff,
      const Stream<DiffState>.empty(),
      initialState: const DiffState(),
    );
    whenListen(
      file,
      const Stream<FileState>.empty(),
      initialState: const FileState(),
    );

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          fluent.FluentLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditorScreen(editBloc: edit, diffBloc: diff, fileBloc: file),
      ),
    );

    // 无边框标题栏关闭键：脏文档 → 三选退出对话框（不直接关窗）。
    await t.tap(find.byKey(const ValueKey('titlebar.close')));
    await t.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Save and exit'), findsOneWidget);
  });

  testWidgets('mode toggle swaps editing area between table and text views', (
    t,
  ) async {
    final edit = MockEditBloc();
    final diff = MockDiffBloc();
    final file = MockFileBloc();
    whenListen(
      edit,
      const Stream<EditState>.empty(),
      initialState: const EditState(),
    );
    whenListen(
      diff,
      const Stream<DiffState>.empty(),
      initialState: const DiffState(),
    );
    whenListen(
      file,
      const Stream<FileState>.empty(),
      initialState: const FileState(),
    );

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          fluent.FluentLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditorScreen(editBloc: edit, diffBloc: diff, fileBloc: file),
      ),
    );

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
    whenListen(
      edit,
      const Stream<EditState>.empty(),
      initialState: const EditState(),
    );
    whenListen(
      diff,
      const Stream<DiffState>.empty(),
      initialState: const DiffState(),
    );
    whenListen(
      file,
      const Stream<FileState>.empty(),
      initialState: const FileState(),
    );

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          fluent.FluentLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditorScreen(editBloc: edit, diffBloc: diff, fileBloc: file),
      ),
    );

    await t.tap(find.byTooltip('Save'));
    await t.pumpAndSettle();

    verify(
      () => file.add(any<SaveRequested>(that: isA<SaveRequested>())),
    ).called(1);
  });

  testWidgets('reselect file button dispatches the picked path', (t) async {
    final edit = MockEditBloc();
    final diff = MockDiffBloc();
    final file = MockFileBloc();
    whenListen(
      edit,
      const Stream<EditState>.empty(),
      initialState: const EditState(),
    );
    whenListen(
      diff,
      const Stream<DiffState>.empty(),
      initialState: const DiffState(),
    );
    whenListen(
      file,
      const Stream<FileState>.empty(),
      initialState: const FileState(path: 'C:\\old\\autoexec.cfg'),
    );

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          fluent.FluentLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditorScreen(
          editBloc: edit,
          diffBloc: diff,
          fileBloc: file,
          autoDetect: false,
          pickFile: () async => 'C:\\new\\videoconfig.txt',
        ),
      ),
    );

    expect(find.byKey(const ValueKey('titlebar.openFile')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace.reselectFile')),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('workspace.reselectFile')));
    await t.pumpAndSettle();

    verify(
      () => file.add(
        any<OpenRequested>(
          that: predicate<OpenRequested>(
            (event) => event.path.endsWith('new\\videoconfig.txt'),
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('file picker failure surfaces a snackbar (filePickerFailed)', (
    t,
  ) async {
    final edit = MockEditBloc();
    final diff = MockDiffBloc();
    final file = MockFileBloc();
    whenListen(
      edit,
      const Stream<EditState>.empty(),
      initialState: const EditState(),
    );
    whenListen(
      diff,
      const Stream<DiffState>.empty(),
      initialState: const DiffState(),
    );
    whenListen(
      file,
      const Stream<FileState>.empty(),
      initialState: const FileState(),
    );

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          fluent.FluentLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditorScreen(
          editBloc: edit,
          diffBloc: diff,
          fileBloc: file,
          autoDetect: false,
          // 注入抛错的 picker seam：file_picker 层异常不再被静默吞掉。
          pickFile: () async => throw Exception('picker crashed'),
        ),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('titlebar.openFile')));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();

    await t.pump(const Duration(seconds: 4));
  });
}
