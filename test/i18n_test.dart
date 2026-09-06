import 'package:apex_cfg_editor/core/parser/videoconfig_parser.dart';
import 'package:apex_cfg_editor/knowledge/kb_service.dart';
import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/ui/widgets/kb_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// 任务 16：i18n 收尾审计新增键（知识卡风险警示的辅助文案 riskHigh/risk）
// 的 en/zh 双语断言。行 0 = high 风险，行 1 = medium 风险（图标中性色）。
const _src = '"setting.r_full" "1"\n"setting.mat_antialias" "2"\n';

const _kbData = {
  'en': {
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
      'recommended': '',
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

Future<void> _pump(WidgetTester t, EditBloc edit, Locale locale) async {
  await t.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: RepositoryProvider<KbService>.value(
      value: const KbService(data: _kbData),
      child: BlocProvider<EditBloc>.value(
        value: edit,
        child: const Scaffold(body: KbCard()),
      ),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('risk semantic label localizes to en (high + medium)', (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);

    edit.add(SelectionChanged(0)); // high
    await _pump(t, edit, const Locale('en'));
    expect(t.widget<Icon>(find.byIcon(LucideIcons.alertTriangle)).semanticLabel,
        'High risk');

    edit.add(SelectionChanged(1)); // medium
    await t.pumpAndSettle();
    expect(t.widget<Icon>(find.byIcon(LucideIcons.alertTriangle)).semanticLabel,
        'Risk');
  });

  testWidgets('risk semantic label localizes to zh (high + medium)', (t) async {
    final edit = _editBloc();
    addTearDown(edit.close);

    edit.add(SelectionChanged(0)); // high
    await _pump(t, edit, const Locale('zh'));
    expect(t.widget<Icon>(find.byIcon(LucideIcons.alertTriangle)).semanticLabel,
        '高风险');

    edit.add(SelectionChanged(1)); // medium
    await t.pumpAndSettle();
    expect(t.widget<Icon>(find.byIcon(LucideIcons.alertTriangle)).semanticLabel,
        '风险');
  });
}
