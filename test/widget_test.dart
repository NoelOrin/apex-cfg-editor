import 'dart:io';

import 'package:apex_cfg_editor/core/settings/settings_store.dart';
import 'package:apex_cfg_editor/knowledge/kb_service.dart';
import 'package:apex_cfg_editor/main.dart';
import 'package:apex_cfg_editor/ui/editor_screen.dart';
import 'package:apex_cfg_editor/ui/theme/acid_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 主题切换按钮（自绘标题栏内，ThemeModeScope 由应用壳注入）。
const _themeToggleKey = ValueKey('titlebar.themeToggle');

Future<void> _pumpApp(
  WidgetTester tester,
  String settingsPath, {
  ThemeMode? initialThemeMode,
}) => tester.pumpWidget(
  ApexCfgEditorApp(
    kb: const KbService(data: {}),
    autoDetect: false,
    settingsPath: settingsPath,
    initialThemeMode: initialThemeMode,
  ),
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('apex_cfg_widget_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('app renders the APEX CFG EDITOR brand title (display font)', (
    WidgetTester tester,
  ) async {
    // 装配壳烟测：注入空知识库并关闭自动探测，隔离宿主环境。
    await _pumpApp(tester, '${tmp.path}/settings.json');
    await tester.pump();

    expect(find.text('APEX CFG EDITOR'), findsOneWidget);
  });

  testWidgets('frameless shell draws 1px acid border around window content', (
    tester,
  ) async {
    await _pumpApp(tester, '${tmp.path}/settings.json');
    await tester.pump();

    // 无边框窗口无系统投影：根容器必须有 1px 酸绿描边（当前主题主色）。
    final frame = find.ancestor(
      of: find.byType(EditorScreen),
      matching: find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final border = (w.decoration as BoxDecoration?)?.border;
        return border is Border &&
            border.top.width == 1 &&
            border.top.color == AcidPalette.dark.acid;
      }),
    );
    expect(frame, findsOneWidget);
  });

  testWidgets('theme toggle switches dark to light and persists to settings', (
    tester,
  ) async {
    final settingsPath = '${tmp.path}/settings.json';
    await _pumpApp(tester, settingsPath);
    await tester.pump();

    // 默认暗色（近黑底）。
    expect(
      Theme.of(tester.element(find.byType(EditorScreen))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byKey(_themeToggleKey));
    await tester.pumpAndSettle();

    // 切换到亮色（纸白底）。
    expect(
      Theme.of(tester.element(find.byType(EditorScreen))).brightness,
      Brightness.light,
    );
    expect(
      Theme.of(tester.element(find.byType(EditorScreen))).primaryColor,
      isNot(AcidPalette.dark.acid),
    );
    // 持久化：themeMode=light 已写入 settings.json。
    expect(
      SettingsStore(settingsPath: settingsPath).readThemeModeRaw(),
      'light',
    );
  });

  testWidgets('light theme then toggle back to dark persists dark', (
    tester,
  ) async {
    final settingsPath = '${tmp.path}/settings.json';
    await _pumpApp(tester, settingsPath, initialThemeMode: ThemeMode.light);
    await tester.pump();

    expect(
      Theme.of(tester.element(find.byType(EditorScreen))).brightness,
      Brightness.light,
    );

    await tester.tap(find.byKey(_themeToggleKey));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(EditorScreen))).brightness,
      Brightness.dark,
    );
    expect(
      SettingsStore(settingsPath: settingsPath).readThemeModeRaw(),
      'dark',
    );
  });

  testWidgets('theme mode is restored from settings.json on startup', (
    tester,
  ) async {
    final settingsPath = '${tmp.path}/settings.json';
    SettingsStore(settingsPath: settingsPath).writeThemeModeRaw('light');

    await _pumpApp(tester, settingsPath);
    await tester.pump();

    expect(
      Theme.of(tester.element(find.byType(EditorScreen))).brightness,
      Brightness.light,
    );
  });

  testWidgets('corrupt themeMode value falls back to dark without throwing', (
    tester,
  ) async {
    final settingsPath = '${tmp.path}/settings.json';
    File(settingsPath).writeAsStringSync('{"themeMode": "sepia"}');

    await _pumpApp(tester, settingsPath);
    await tester.pump();

    expect(
      Theme.of(tester.element(find.byType(EditorScreen))).brightness,
      Brightness.dark,
    );
  });
}
