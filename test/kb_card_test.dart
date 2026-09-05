import 'package:apex_cfg_editor/core/parser/videoconfig_parser.dart';
import 'package:apex_cfg_editor/knowledge/kb_service.dart';
import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/ui/widgets/kb_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// 核心测试用真实 EditBloc + 真实解析器 + 注入 KbService 数据（不用 mock）。
// 行索引：0 fps_max(low)、1 r_full(high)、2 mat_antialias(medium)、
// 3 注释行、4 未收录键。
const _src = '"setting.fps_max" "0"\n'
    '"setting.r_full" "1"\n'
    '"setting.mat_antialias" "2"\n'
    '// framerate cap\n'
    '"setting.obscure_key" "3"\n';

const _kbData = {
  'en': {
    'setting.fps_max': {
      'name': 'FPS Cap',
      'description': 'Limits the frame rate.',
      'recommended': '0',
      'risk': 'low',
      'values': [],
    },
    'setting.r_full': {
      'name': 'Fullscreen',
      'description': 'Renders the game fullscreen.',
      'recommended': '',
      'risk': 'high',
      'values': [],
    },
    'setting.mat_antialias': {
      'name': 'Antialiasing',
      'description': 'Smooths jagged edges.',
      'recommended': '2',
      'risk': 'medium',
      'values': [],
    },
  },
};

EditBloc _editBloc() {
  final bloc = EditBloc();
  bloc.add(
      DocumentOpened(doc: VideoconfigParser().parse(_src), baseline: _src));
  return bloc;
}

// 显式 seed 主题：测试里可重建同一 ColorScheme 断言图标颜色（红=error）。
ThemeData _theme() => ThemeData(colorSchemeSeed: Colors.blue);

Widget _host(EditBloc edit,
    {bool kb = true, Locale locale = const Locale('en')}) {
  Widget card = const KbCard();
  if (kb) {
    card = RepositoryProvider<KbService>.value(
      value: const KbService(data: _kbData),
      child: card,
    );
  }
  return MaterialApp(
    theme: _theme(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<EditBloc>.value(
      value: edit,
      child: Scaffold(body: card),
    ),
  );
}

void main() {
  testWidgets(
      'kb hit shows name, description and recommended line (low risk: no icon)',
      (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    edit.add(SelectionChanged(0));
    await t.pumpWidget(_host(edit));
    await t.pumpAndSettle();

    expect(find.text('FPS Cap'), findsOneWidget);
    expect(find.text('Limits the frame rate.'), findsOneWidget);
    expect(find.text('Recommended: 0'), findsOneWidget);
    // low → 不额外标注：无警示图标。
    expect(find.byIcon(LucideIcons.alertTriangle), findsNothing);
    // 底部 280 宽区域：文案多行可滚动。
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('undocumented key shows kbNotDocumented fallback (en)',
      (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    edit.add(SelectionChanged(4));
    await t.pumpWidget(_host(edit));
    await t.pumpAndSettle();

    expect(
        find.text('Key not documented yet. You can still edit it.'),
        findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets(
      'high risk entry shows alertTriangle icon in theme error color with semantic label',
      (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    edit.add(SelectionChanged(1));
    await t.pumpWidget(_host(edit));
    await t.pumpAndSettle();

    final icon = t.widget<Icon>(find.byIcon(LucideIcons.alertTriangle));
    expect(icon.semanticLabel, isNotNull);
    expect(icon.color, _theme().colorScheme.error);
    // recommended 为空 → 不显示推荐值行。
    expect(find.textContaining('Recommended'), findsNothing);
  });

  testWidgets('medium risk entry shows neutral (non-red) alert icon',
      (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    edit.add(SelectionChanged(2));
    await t.pumpWidget(_host(edit));
    await t.pumpAndSettle();

    final icon = t.widget<Icon>(find.byIcon(LucideIcons.alertTriangle));
    expect(icon.semanticLabel, isNotNull);
    expect(icon.color, isNot(_theme().colorScheme.error));
  });

  testWidgets('comment line selection hides the card', (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    edit.add(SelectionChanged(3));
    await t.pumpWidget(_host(edit));
    await t.pumpAndSettle();

    expect(find.text('FPS Cap'), findsNothing);
    expect(find.text('Key not documented yet. You can still edit it.'),
        findsNothing);
    expect(find.byIcon(LucideIcons.alertTriangle), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('zh locale shows Chinese fallback text and recommended prefix',
      (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    edit.add(SelectionChanged(4));
    await t.pumpWidget(_host(edit, locale: const Locale('zh')));
    await t.pumpAndSettle();

    expect(find.text('该键尚未收录说明，仍可编辑。'), findsOneWidget);

    // 命中条目的推荐值行同样走 i18n 前缀。
    edit.add(SelectionChanged(0));
    await t.pumpAndSettle();
    expect(find.text('推荐：0'), findsOneWidget);
  });

  testWidgets('no KbService provider hides the card', (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);
    edit.add(SelectionChanged(0));
    await t.pumpWidget(_host(edit, kb: false));
    await t.pumpAndSettle();

    expect(find.text('FPS Cap'), findsNothing);
    expect(find.text('Key not documented yet. You can still edit it.'),
        findsNothing);
  });

  testWidgets('no document open hides the card', (t) async {
    final edit = EditBloc();
    addTearDown(edit.close);
    await t.pumpWidget(_host(edit));
    await t.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsNothing);
  });
}
