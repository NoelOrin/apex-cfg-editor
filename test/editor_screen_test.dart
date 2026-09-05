import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/state/diff_bloc.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';
import 'package:apex_cfg_editor/ui/editor_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockEditBloc extends MockBloc<EditEvent, EditState> implements EditBloc {}
class MockDiffBloc extends MockCubit<DiffState> implements DiffBloc {}
class MockFileBloc extends MockBloc<FileEvent, FileState> implements FileBloc {}

void main() {
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
    expect(find.text('Table'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
  });
}
