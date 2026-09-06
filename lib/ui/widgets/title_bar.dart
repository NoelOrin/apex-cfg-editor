import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/ui/theme/acid_theme.dart';
import 'package:apex_cfg_editor/ui/theme/theme_mode_scope.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

/// 无边框窗口自绘标题栏（酸性风格 v2）。
///
/// 结构（高 44）：左侧斜切酸绿 Logo 块 + 全大写展示字体品牌名；
/// 中部拖拽区（onPanStart 拖动窗口，双击最大化/还原）承载当前文件名；
/// 右侧依次为业务 actions（注入）、亮/暗主题切换、窗口控制
/// （最小化 / 最大化还原 / 关闭）。
///
/// 窗口控制三回调为测试接缝：null 时走 windowManager 默认实现
/// （全部 try/catch，无窗口通道的测试 / macOS 开发期静默忽略）。
/// 关闭按钮由 EditorScreen 注入 ExitGuard 流程；默认实现走
/// `windowManager.close()`——在 setPreventClose(true) 下同样触发
/// onWindowClose 拦截，两条路径都经退出保护。
class TitleBar extends StatefulWidget {
  /// 当前打开文件名（含扩展名）；null / 空时拖拽区只留品牌名。
  final String? fileName;

  /// 业务动作按钮（打开 / 模式切换 / 保存 / 还原），由 EditorScreen 注入。
  final List<Widget> actions;

  /// 最小化。null → windowManager.minimize()。
  final Future<void> Function()? onMinimize;

  /// 最大化 / 还原切换。null → isMaximized ? restore : maximize。
  final Future<void> Function()? onMaximizeOrRestore;

  /// 关闭。null → windowManager.close()。
  final Future<void> Function()? onClose;

  const TitleBar({
    super.key,
    this.fileName,
    this.actions = const [],
    this.onMinimize,
    this.onMaximizeOrRestore,
    this.onClose,
  });

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
  /// 最大化状态（乐观更新 + onWindowMaximize/Unmaximize 事件校准），
  /// 驱动最大化按钮图标在 square / copy 间切换。
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _readMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _readMaximized() async {
    try {
      final m = await windowManager.isMaximized();
      if (mounted) setState(() => _maximized = m);
    } catch (_) {
      // 无窗口通道（测试 / 未初始化平台）：保持默认 false。
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _maximized = false);
  }

  Future<void> _defaultMinimize() async {
    try {
      await windowManager.minimize();
    } catch (_) {}
  }

  Future<void> _defaultMaximizeOrRestore() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.restore();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  Future<void> _defaultClose() async {
    try {
      await windowManager.close();
    } catch (_) {}
  }

  Future<void> _handleMaximizeOrRestore() async {
    await (widget.onMaximizeOrRestore ?? _defaultMaximizeOrRestore)();
    if (mounted) setState(() => _maximized = !_maximized);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = AcidPalette.of(context);
    final divider =
        Theme.of(context).dividerTheme.color ??
        palette.chrome.withValues(alpha: 0.2);
    final themeScope = ThemeModeScope.maybeOf(context);

    Widget windowButton({
      required Key key,
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
      Color? iconColor,
    }) => IconButton(
      key: key,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 16, color: iconColor ?? palette.textMuted),
      tooltip: tooltip,
      onPressed: onPressed,
    );

    return Material(
      color: palette.panel,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: divider)),
        ),
        height: 44,
        child: Row(
          children: [
            const SizedBox(width: 12),
            const _SlantLogo(),
            const SizedBox(width: 10),
            // 品牌名：展示字体 + 全大写 + 紧字距 + 斜体（酸性风格 v2）。
            const Text(
              'APEX CFG EDITOR',
              style: TextStyle(
                fontFamily: kFontDisplay,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 14),
            // 拖拽区：onPanStart 拖动窗口 + 双击最大化/还原。
            // 不用 DragToMoveArea：其内置 onDoubleTap 直接调 windowManager，
            // 不可注入也不经退出守卫语义，自实现以获得一致的测试接缝。
            Expanded(
              child: GestureDetector(
                key: const ValueKey('titlebar.dragArea'),
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _handleMaximizeOrRestore,
                onPanStart: (_) async {
                  try {
                    await windowManager.startDragging();
                  } catch (_) {}
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.fileName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kFontMono,
                      fontSize: 12,
                      color: palette.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            ...widget.actions,
            if (themeScope != null)
              windowButton(
                key: const ValueKey('titlebar.themeToggle'),
                icon: themeScope.mode == ThemeMode.dark
                    ? LucideIcons.sun
                    : LucideIcons.moon,
                tooltip: l.toggleTheme,
                onPressed: () => themeScope.onChanged(
                  themeScope.mode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                ),
              ),
            if (widget.actions.isNotEmpty || themeScope != null)
              VerticalDivider(width: 1, thickness: 1, color: divider),
            windowButton(
              key: const ValueKey('titlebar.minimize'),
              icon: LucideIcons.minus,
              tooltip: l.minimize,
              onPressed: () => (widget.onMinimize ?? _defaultMinimize)(),
            ),
            windowButton(
              key: const ValueKey('titlebar.maximize'),
              icon: _maximized ? LucideIcons.copy : LucideIcons.square,
              tooltip: _maximized ? l.restoreWindow : l.maximize,
              onPressed: _handleMaximizeOrRestore,
            ),
            windowButton(
              key: const ValueKey('titlebar.close'),
              icon: LucideIcons.x,
              tooltip: l.close,
              onPressed: () => (widget.onClose ?? _defaultClose)(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 斜切酸绿 Logo 块：单个平行四边形（斜切方向与品牌斜体一致），克制不发光。
class _SlantLogo extends StatelessWidget {
  const _SlantLogo();

  @override
  Widget build(BuildContext context) {
    final palette = AcidPalette.of(context);
    return CustomPaint(
      size: const Size(26, 18),
      painter: _SlantLogoPainter(color: palette.acid),
    );
  }
}

class _SlantLogoPainter extends CustomPainter {
  final Color color;

  const _SlantLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.28, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.72, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SlantLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
