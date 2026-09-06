import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/ui/theme/acid_theme.dart';
import 'package:apex_cfg_editor/ui/theme/theme_mode_scope.dart';
import 'package:apex_cfg_editor/ui/widgets/title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 窗口控制三键（自绘标题栏）。
const _minimizeKey = ValueKey('titlebar.minimize');
const _maximizeKey = ValueKey('titlebar.maximize');
const _closeKey = ValueKey('titlebar.close');
const _dragAreaKey = ValueKey('titlebar.dragArea');
const _themeToggleKey = ValueKey('titlebar.themeToggle');

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildAcidTheme(Brightness.dark),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('minimize button dispatches onMinimize', (t) async {
    var minimized = 0;
    await t.pumpWidget(_host(TitleBar(onMinimize: () async => minimized++)));

    await t.tap(find.byKey(_minimizeKey));
    await t.pump();

    expect(minimized, 1);
  });

  testWidgets('maximize button dispatches onMaximizeOrRestore and flips icon', (
    t,
  ) async {
    var toggled = 0;
    await t.pumpWidget(
      _host(TitleBar(onMaximizeOrRestore: () async => toggled++)),
    );
    expect(find.byIcon(LucideIcons.square), findsOneWidget);

    await t.tap(find.byKey(_maximizeKey));
    await t.pump();

    expect(toggled, 1);
    // 乐观更新：最大化后图标切换为还原形态。
    expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    expect(find.byIcon(LucideIcons.square), findsNothing);
  });

  testWidgets('double click on drag area dispatches maximize/restore', (
    t,
  ) async {
    var toggled = 0;
    await t.pumpWidget(
      _host(TitleBar(onMaximizeOrRestore: () async => toggled++)),
    );

    await t.tap(find.byKey(_dragAreaKey));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byKey(_dragAreaKey));
    await t.pump();
    expect(toggled, 1);
    // 双击识别器在二次命中后仍挂着一个等待第三次点击的定时器：
    // 推进超过 kDoubleTapTimeout，避免 teardown 的 pending-timer 断言。
    await t.pump(const Duration(milliseconds: 400));
  });

  testWidgets('close button dispatches onClose (ExitGuard seam)', (t) async {
    var closed = 0;
    await t.pumpWidget(_host(TitleBar(onClose: () async => closed++)));

    await t.tap(find.byKey(_closeKey));
    await t.pump();

    expect(closed, 1);
  });

  testWidgets('theme toggle renders only inside ThemeModeScope', (t) async {
    await t.pumpWidget(_host(const TitleBar()));
    expect(find.byKey(_themeToggleKey), findsNothing);

    await t.pumpWidget(
      _host(
        ThemeModeScope(
          mode: ThemeMode.dark,
          onChanged: (_) {},
          child: const TitleBar(),
        ),
      ),
    );
    expect(find.byKey(_themeToggleKey), findsOneWidget);
  });

  testWidgets('theme toggle dispatches opposite mode on scope', (t) async {
    ThemeMode? requested;
    await t.pumpWidget(
      _host(
        ThemeModeScope(
          mode: ThemeMode.dark,
          onChanged: (m) => requested = m,
          child: const TitleBar(),
        ),
      ),
    );

    await t.tap(find.byKey(_themeToggleKey));
    await t.pump();

    expect(requested, ThemeMode.light);
  });

  testWidgets('renders file name in drag area and brand title', (t) async {
    await t.pumpWidget(_host(const TitleBar(fileName: 'videoconfig.txt')));

    expect(find.text('APEX CFG EDITOR'), findsOneWidget);
    expect(find.text('videoconfig.txt'), findsOneWidget);
  });

  testWidgets('window buttons carry localized tooltips (semantics)', (t) async {
    await t.pumpWidget(_host(const TitleBar()));

    expect(find.byTooltip('Minimize'), findsOneWidget);
    expect(find.byTooltip('Maximize'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });
}
