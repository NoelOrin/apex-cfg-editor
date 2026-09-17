import 'package:apex_cfg_editor/core/parser/cfg_document.dart';
import 'package:apex_cfg_editor/core/parser/videoconfig_parser.dart';
import 'package:apex_cfg_editor/knowledge/kb_service.dart';
import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';
import 'package:apex_cfg_editor/ui/widgets/kv_table_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

// 核心测试用真实 EditBloc + 真实解析器，不用 mock（避免 mock 漂移）。
const _src = '"setting.fps_max" "0"\n"setting.r_full" "1"\n';

EditBloc _realEditBloc({String src = _src}) {
  final bloc = EditBloc();
  bloc.add(DocumentOpened(doc: VideoconfigParser().parse(src), baseline: src));
  return bloc;
}

FileBloc _realFileBloc(EditBloc edit) => FileBloc(
  editBloc: edit,
  saveImpl: (_, _, _) async {},
  listBackupsImpl: (_) => const [],
  restoreImpl: (_, _) async {},
);

Widget _host(Widget child, {KbService? kb}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: [
    fluent.FluentLocalizations.delegate,
    ...AppLocalizations.localizationsDelegates,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: kb == null
      ? Scaffold(body: child)
      : RepositoryProvider<KbService>.value(
          value: kb,
          child: Scaffold(body: child),
        ),
);

void main() {
  testWidgets('shows empty-state hint when no document is open', (t) async {
    final edit = EditBloc();
    addTearDown(edit.close);
    final file = _realFileBloc(edit);
    addTearDown(file.close);

    await t.pumpWidget(_host(KvTableView(editBloc: edit, fileBloc: file)));
    await t.pumpAndSettle();

    expect(find.text('Open a cfg file to start editing'), findsOneWidget);
    expect(find.byType(fluent.TextBox), findsNothing);
  });

  testWidgets('text edit drives serialize and dirty through real EditBloc', (
    t,
  ) async {
    final edit = _realEditBloc();
    addTearDown(edit.close);
    final file = _realFileBloc(edit);
    addTearDown(file.close);

    await t.pumpWidget(_host(KvTableView(editBloc: edit, fileBloc: file)));
    await t.pumpAndSettle();

    await t.enterText(find.byType(fluent.TextBox).first, '144');
    await t.pumpAndSettle();

    expect(edit.state.dirty, isTrue);
    expect(
      edit.state.doc!.serialize(),
      '"setting.fps_max" "144"\n"setting.r_full" "1"\n',
    );
  });

  testWidgets('second edit after rebuild keeps fields in sync (no garbling)', (
    t,
  ) async {
    final edit = _realEditBloc();
    addTearDown(edit.close);
    final file = _realFileBloc(edit);
    addTearDown(file.close);

    await t.pumpWidget(_host(KvTableView(editBloc: edit, fileBloc: file)));
    await t.pumpAndSettle();

    await t.enterText(find.byType(fluent.TextBox).first, '144');
    await t.pumpAndSettle();
    await t.enterText(find.byType(fluent.TextBox).first, '60');
    await t.pumpAndSettle();

    expect(
      edit.state.doc!.serialize(),
      '"setting.fps_max" "60"\n"setting.r_full" "1"\n',
    );
  });

  testWidgets(
    'kb hit shows localized description and dropdown; select emits value',
    (t) async {
      const kbSrc = '"setting.fps_max" "1"\n"setting.r_full" "1"\n';
      final edit = _realEditBloc(src: kbSrc);
      addTearDown(edit.close);
      final file = _realFileBloc(edit);
      addTearDown(file.close);
      const kb = KbService(
        data: {
          'en': {
            'setting.fps_max': {
              'name': 'FPS Cap',
              'description': 'Frame rate limit',
              'recommended': '0',
              'risk': 'low',
              'values': [
                {'v': '0', 'label': 'Capped'},
                {'v': '1', 'label': 'Uncapped'},
              ],
            },
          },
        },
      );

      await t.pumpWidget(
        _host(
          KvTableView(editBloc: edit, fileBloc: file),
          kb: kb,
        ),
      );
      await t.pumpAndSettle();

      // KB 命中：subtitle 显示 entry.description；行 0 是下拉，行 1 无条目仍是文本框。
      expect(find.text('Frame rate limit'), findsOneWidget);
      expect(find.byType(fluent.ComboBox<String>), findsOneWidget);
      expect(find.byType(fluent.TextBox), findsOneWidget);

      // 下拉当前值 '1' → 按钮显示 label 'Uncapped'；打开菜单选 'Capped'（v='0'）。
      await t.tap(find.text('Uncapped'));
      await t.pumpAndSettle();
      await t.tap(find.text('Capped'));
      await t.pumpAndSettle();

      expect((edit.state.doc!.lines[0] as KeyValueLine).value, '0');
      expect(edit.state.dirty, isTrue);
    },
  );

  testWidgets('unmatched cfg field leaves description blank', (t) async {
    final edit = _realEditBloc();
    addTearDown(edit.close);
    final file = _realFileBloc(edit);
    addTearDown(file.close);
    const kb = KbService(
      data: {
        'en': {
          'setting.fps_max': {
            'name': 'FPS Cap',
            'description': 'Frame rate limit',
            'recommended': '0',
            'risk': 'low',
            'values': [],
          },
        },
      },
    );

    await t.pumpWidget(
      _host(
        KvTableView(editBloc: edit, fileBloc: file),
        kb: kb,
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Frame rate limit'), findsOneWidget);
    expect(find.text('FPS Cap'), findsNothing);
  });

  testWidgets('cfg description follows the selected locale', (t) async {
    final edit = _realEditBloc();
    addTearDown(edit.close);
    final file = _realFileBloc(edit);
    addTearDown(file.close);
    const kb = KbService(
      data: {
        'zh': {
          'setting.fps_max': {
            'name': '帧率上限',
            'description': '限制游戏最大帧率。',
            'recommended': '0',
            'risk': 'low',
            'values': [],
          },
        },
      },
    );

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: [
          fluent.FluentLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepositoryProvider<KbService>.value(
          value: kb,
          child: Scaffold(
            body: KvTableView(editBloc: edit, fileBloc: file),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('限制游戏最大帧率。'), findsOneWidget);
    expect(find.text('Frame rate limit'), findsNothing);
  });

  testWidgets(
    'dropdown carries ValueKey<CfgLine> (symmetric with text field)',
    (t) async {
      const kbSrc = '"setting.fps_max" "1"\n"setting.r_full" "1"\n';
      final edit = _realEditBloc(src: kbSrc);
      addTearDown(edit.close);
      final file = _realFileBloc(edit);
      addTearDown(file.close);
      const kb = KbService(
        data: {
          'en': {
            'setting.fps_max': {
              'name': 'FPS Cap',
              'description': 'Frame rate limit',
              'recommended': '0',
              'risk': 'low',
              'values': [
                {'v': '0', 'label': 'Capped'},
                {'v': '1', 'label': 'Uncapped'},
              ],
            },
          },
        },
      );

      await t.pumpWidget(
        _host(
          KvTableView(editBloc: edit, fileBloc: file),
          kb: kb,
        ),
      );
      await t.pumpAndSettle();

      final dropdown = t.widget<fluent.ComboBox<String>>(
        find.byType(fluent.ComboBox<String>),
      );
      expect(dropdown.key, ValueKey<CfgLine>(edit.state.doc!.lines[0]));
    },
  );

  testWidgets('tapping a row dispatches SelectionChanged and highlights it', (
    t,
  ) async {
    final edit = _realEditBloc();
    addTearDown(edit.close);
    final file = _realFileBloc(edit);
    addTearDown(file.close);

    await t.pumpWidget(_host(KvTableView(editBloc: edit, fileBloc: file)));
    await t.pumpAndSettle();

    await t.tap(find.text('setting.r_full'));
    await t.pumpAndSettle();

    expect(edit.state.selectedIndex, 1);
    final tiles = t
        .widgetList<fluent.ListTile>(find.byType(fluent.ListTile))
        .toList();
    expect(tiles[1].selected, isTrue);
    expect(tiles[0].selected, isFalse);
  });

  testWidgets('non key-value lines render raw text without value editor', (
    t,
  ) async {
    const src = '// framerate cap\n"setting.fps_max" "0"\nraw junk\n';
    final edit = _realEditBloc(src: src);
    addTearDown(edit.close);
    final file = _realFileBloc(edit);
    addTearDown(file.close);

    await t.pumpWidget(_host(KvTableView(editBloc: edit, fileBloc: file)));
    await t.pumpAndSettle();

    expect(find.text('// framerate cap'), findsOneWidget);
    expect(find.text('raw junk'), findsOneWidget);
    // 只有键值行有值控件。
    expect(find.byType(fluent.TextBox), findsOneWidget);
  });
}
