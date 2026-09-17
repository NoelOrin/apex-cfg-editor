import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// 为无边框窗口补齐可拖拽缩放的四边与四角命中区。
///
/// Windows 原生 `WS_THICKFRAME` 在 frameless 模式下可能只剩极窄命中范围；
/// 该组件用 6 logical px 的透明边缘覆盖层调用 `startResizing`，最大化或
/// 全屏时自动禁用。非 Windows 平台不启用边缘手势。
class WindowResizeFrame extends StatefulWidget {
  const WindowResizeFrame({
    super.key,
    required this.child,
    this.resizeEdgeSize = 6,
    @visibleForTesting this.supportedOverride,
  });

  final Widget child;
  final double resizeEdgeSize;
  final bool? supportedOverride;

  @override
  State<WindowResizeFrame> createState() => _WindowResizeFrameState();
}

class _WindowResizeFrameState extends State<WindowResizeFrame>
    with WindowListener {
  bool _maximized = false;
  bool _fullScreen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _readWindowState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _readWindowState() async {
    try {
      final maximized = await windowManager.isMaximized();
      final fullScreen = await windowManager.isFullScreen();
      if (!mounted) return;
      setState(() {
        _maximized = maximized;
        _fullScreen = fullScreen;
      });
    } catch (_) {
      // 测试或无窗口通道环境保持默认状态。
    }
  }

  bool get _platformSupported =>
      widget.supportedOverride ?? (!kIsWeb && Platform.isWindows);

  @override
  Widget build(BuildContext context) {
    final enabled = _platformSupported && !_maximized && !_fullScreen;
    return DragToResizeArea(
      resizeEdgeSize: widget.resizeEdgeSize,
      enableResizeEdges: enabled ? null : const [],
      child: widget.child,
    );
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _maximized = false);
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _fullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _fullScreen = false);
  }
}
