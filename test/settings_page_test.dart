import 'dart:async';
import 'dart:io';

import 'package:apex_cfg_editor/core/update/update_service.dart';
import 'package:apex_cfg_editor/core/settings/settings_store.dart';
import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/ui/settings_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpPage(
  WidgetTester tester,
  UpdateService service, {
  Future<void> Function(Uri url)? openUrl,
  SettingsStore? settings,
  String backupDir = '',
  String logDir = '',
  String? openFilePath,
  VoidCallback? onResetSettings,
}) async {
  await tester.pumpWidget(
    FluentApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsPage(
        updateService: service,
        openUrl: openUrl,
        settings: settings,
        backupDir: backupDir,
        logDir: logDir,
        openFilePath: openFilePath,
        onResetSettings: onResetSettings,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _scrollIntoView(WidgetTester tester, Finder target) async {
  final viewport = tester.binding.renderViews.first.size.height;
  for (var i = 0; i < 8; i++) {
    final rect = tester.getRect(target);
    if (rect.top >= 0 && rect.bottom <= viewport) return;
    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
      900,
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('renders settings and current version', (tester) async {
    await _pumpPage(
      tester,
      UpdateService(
        currentVersion: '1.0.0',
        fetchJson: (_) async =>
            '{"tag_name":"1.0.0","html_url":"https://github.com/NoelOrin/apex-cfg-editor/releases/tag/1.0.0"}',
      ),
    );

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
  });

  testWidgets('shows checking state and then latest state', (tester) async {
    final pending = Completer<String>();
    await _pumpPage(
      tester,
      UpdateService(currentVersion: '1.0.0', fetchJson: (_) => pending.future),
    );

    await tester.tap(find.text('检查更新'));
    await tester.pump();
    expect(find.text('正在检查更新...'), findsOneWidget);

    pending.complete(
      '{"tag_name":"1.0.0","html_url":"https://github.com/NoelOrin/apex-cfg-editor/releases/tag/1.0.0"}',
    );
    await tester.pumpAndSettle();

    expect(find.text('已是最新版本'), findsOneWidget);
  });

  testWidgets('shows available update and opens its release page', (
    tester,
  ) async {
    Uri? opened;
    await _pumpPage(
      tester,
      UpdateService(
        currentVersion: '1.0.0',
        fetchJson: (_) async =>
            '{"tag_name":"1.1.0","html_url":"https://github.com/NoelOrin/apex-cfg-editor/releases/tag/v1.1.0"}',
      ),
      openUrl: (url) async => opened = url,
    );

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 v1.1.0'), findsOneWidget);
    await tester.tap(find.text('查看发行说明'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(opened?.toString(), contains('/releases/tag/v1.1.0'));
  });

  testWidgets('shows a recoverable error when checking fails', (tester) async {
    await _pumpPage(
      tester,
      UpdateService(
        currentVersion: '1.0.0',
        fetchJson: (_) async => throw StateError('offline'),
      ),
    );

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('检查更新失败'), findsOneWidget);
  });

  testWidgets('renders application, behavior, backup and diagnostics sections', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('apex_settings_page_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final settings = SettingsStore(settingsPath: '${tmp.path}/settings.json');
    await _pumpPage(
      tester,
      UpdateService(
        currentVersion: '1.0.0',
        fetchJson: (_) async =>
            '{"tag_name":"1.0.0","html_url":"https://github.com/NoelOrin/apex-cfg-editor/releases/tag/1.0.0"}',
      ),
      settings: settings,
      backupDir: '/tmp/backups',
      logDir: '/tmp/logs',
    );

    expect(find.text('应用信息'), findsOneWidget);
    expect(find.text('文件打开行为'), findsOneWidget);
    expect(find.text('自动备份'), findsOneWidget);
    expect(find.text('配置诊断'), findsOneWidget);
    expect(find.text('恢复'), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('构建号'), findsOneWidget);
    final settingsChoice = find.text('settings.cfg（操作设置）');
    await _scrollIntoView(tester, settingsChoice);
    expect(settingsChoice, findsOneWidget);
    expect(find.text('videoconfig.txt（游戏画质）'), findsOneWidget);
  });

  testWidgets('backup setting writes to SettingsStore', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('apex_settings_page_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final settings = SettingsStore(settingsPath: '${tmp.path}/settings.json');
    await _pumpPage(
      tester,
      UpdateService(
        currentVersion: '1.0.0',
        fetchJson: (_) async =>
            '{"tag_name":"1.0.0","html_url":"https://github.com/NoelOrin/apex-cfg-editor/releases/tag/1.0.0"}',
      ),
      settings: settings,
    );

    final backupToggle = find.text('保存前创建备份');
    await _scrollIntoView(tester, backupToggle);
    await tester.tap(backupToggle);
    await tester.pumpAndSettle();
    expect(settings.readBackupEnabled(), isFalse);
  });

  testWidgets('reset requires confirmation and removes only settings', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('apex_settings_reset_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final path = '${tmp.path}/settings.json';
    final settings = SettingsStore(settingsPath: path);
    settings.writeThemeModeRaw('light');
    var resetCallback = false;
    await _pumpPage(
      tester,
      UpdateService(
        currentVersion: '1.0.0',
        fetchJson: (_) async =>
            '{"tag_name":"1.0.0","html_url":"https://github.com/NoelOrin/apex-cfg-editor/releases/tag/1.0.0"}',
      ),
      settings: settings,
      onResetSettings: () => resetCallback = true,
    );

    final resetButton = find.text('恢复默认设置');
    await _scrollIntoView(tester, resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();
    expect(find.text('恢复默认设置？'), findsOneWidget);
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();

    expect(resetCallback, isTrue);
    expect(File(path).existsSync(), isFalse);
  });
}
