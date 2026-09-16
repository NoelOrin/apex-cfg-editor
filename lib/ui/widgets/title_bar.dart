import 'package:fluent_ui/fluent_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../theme/acid_theme.dart';
import '../theme/theme_mode_scope.dart';

/// 无边框窗口的 Fluent 标题栏。
///
/// 业务操作仍由 [actions] 注入，窗口控制继续经 window_manager 接缝调用；
/// 视觉控件统一使用 Fluent 的 IconButton、Tooltip 和焦点状态。
class TitleBar extends StatefulWidget {
  final String? fileName;
  final List<Widget> actions;
  final Future<void> Function()? onMinimize;
  final Future<void> Function()? onMaximizeOrRestore;
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
      final value = await windowManager.isMaximized();
      if (mounted) setState(() => _maximized = value);
    } catch (_) {}
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

  Widget _windowButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: key,
        iconButtonMode: IconButtonMode.small,
        icon: Icon(icon, size: 16, color: color),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme =
        FluentTheme.maybeOf(context) ?? buildFluentTheme(Brightness.dark);
    final palette = AcidPalette.of(context);
    final scope = ThemeModeScope.maybeOf(context);
    final effectiveDark = theme.brightness == Brightness.dark;

    return FluentThemeFallback(
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: theme.micaBackgroundColor,
          border: Border(
            bottom: BorderSide(color: palette.chrome.withValues(alpha: 0.22)),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const _SlantLogo(),
            const SizedBox(width: 10),
            Text(
              'APEX CFG EDITOR',
              style: TextStyle(
                fontFamily: kFontDisplay,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                letterSpacing: 1,
                color: palette.text,
              ),
            ),
            const SizedBox(width: 14),
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
            if (scope != null)
              _windowButton(
                key: const ValueKey('titlebar.themeToggle'),
                icon: effectiveDark ? LucideIcons.sun : LucideIcons.moon,
                tooltip: l.toggleTheme,
                color: palette.textMuted,
                onPressed: () {
                  final next =
                      scope.mode == ThemeMode.dark ||
                          (scope.mode == ThemeMode.system && effectiveDark)
                      ? ThemeMode.light
                      : ThemeMode.dark;
                  scope.onChanged(next);
                },
              ),
            if (widget.actions.isNotEmpty || scope != null)
              Container(
                width: 1,
                height: 22,
                color: palette.chrome.withValues(alpha: 0.24),
              ),
            _windowButton(
              key: const ValueKey('titlebar.minimize'),
              icon: LucideIcons.minus,
              tooltip: l.minimize,
              color: palette.textMuted,
              onPressed: () => (widget.onMinimize ?? _defaultMinimize)(),
            ),
            _windowButton(
              key: const ValueKey('titlebar.maximize'),
              icon: _maximized ? LucideIcons.copy : LucideIcons.square,
              tooltip: _maximized ? l.restoreWindow : l.maximize,
              color: palette.textMuted,
              onPressed: _handleMaximizeOrRestore,
            ),
            _windowButton(
              key: const ValueKey('titlebar.close'),
              icon: LucideIcons.x,
              tooltip: l.close,
              color: palette.danger,
              onPressed: () => (widget.onClose ?? _defaultClose)(),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _SlantLogo extends StatelessWidget {
  const _SlantLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 18),
      painter: _SlantLogoPainter(color: AcidPalette.of(context).acid),
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
