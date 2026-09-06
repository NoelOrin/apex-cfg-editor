import 'dart:io';

import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../core/paths/apex_paths.dart';
import '../state/diff_bloc.dart';
import '../state/edit_bloc.dart';
import '../state/file_bloc.dart';
import 'backup_dialog.dart';
import 'exit_guard.dart';
import 'quit_dialog.dart';
import 'widgets/kb_card.dart';
import 'widgets/kv_table_view.dart';
import 'widgets/side_by_side_diff.dart';
import 'widgets/text_editor_view.dart';

/// FileState.warning（i18n 键名）→ UI 文案映射。
String warningText(BuildContext context, String key) {
  final l = AppLocalizations.of(context)!;
  return switch (key) {
    'fileBadEncoding' => l.fileBadEncoding,
    'fileOpenFailed' => l.fileOpenFailed,
    'fileSaveFailed' => l.fileSaveFailed,
    _ => key,
  };
}

/// 主界面三区布局：顶栏（文件名/模式切换/保存/还原）+
/// 编辑区（flex 6）+ 底部区（高 220，内含知识卡 280 宽 + 行级 diff）。
/// 三个 bloc 均由外部注入（测试接缝）。
///
/// 本屏同时承担装配期行为：启动自动探测（[homeDirOverride]）、「打开文件」
/// 手动选择（[pickFile]）、还原对话框接线和退出保护
///（PopScope + window_manager WindowListener，均经 [ExitGuard] 决策）。
class EditorScreen extends StatefulWidget {
  final EditBloc editBloc;
  final DiffBloc diffBloc;
  final FileBloc fileBloc;

  /// 启动自动探测开关（initState 后帧执行）；默认开，测试可关。
  final bool autoDetect;

  /// 自动探测的 home 根目录。null → Platform.environment['USERPROFILE']
  /// （macOS 开发期通常为 null → 静默跳过，绝不去探测真实盘）。
  final String? homeDirOverride;

  /// 「打开文件」选择器。null → file_picker（.cfg/.txt）；测试注入。
  final Future<String?> Function()? pickFile;

  const EditorScreen({
    super.key,
    required this.editBloc,
    required this.diffBloc,
    required this.fileBloc,
    this.autoDetect = true,
    this.homeDirOverride,
    this.pickFile,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WindowListener {
  bool _textMode = false;

  /// 还原后递增，作为 TextEditorView 的 key 强制重建子树（见 _onRestored）。
  int _textEpoch = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _setupWindowGuard();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoDetectAndOpen());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  /// window_manager 在 macOS 开发期 / 测试环境可能没有原生窗口通道：
  /// 全部调用 try/catch 容错，失败时退出保护退化为 PopScope 守护。
  Future<void> _setupWindowGuard() async {
    try {
      await windowManager.setPreventClose(true);
    } catch (_) {
      // 无窗口通道（测试 / 未初始化平台）：忽略，PopScope 仍生效。
    }
  }

  Future<void> _destroyWindow() async {
    try {
      await windowManager.destroy();
    } catch (_) {
      // 测试环境无原生通道：忽略（退出决策逻辑已由 ExitGuard 覆盖测试）。
    }
  }

  ExitGuard get _exitGuard => ExitGuard(
        editBloc: widget.editBloc,
        fileBloc: widget.fileBloc,
        askUser: () => showQuitDialog(context),
        destroy: _destroyWindow,
      );

  @override
  void onWindowClose() async {
    // Windows 关窗（setPreventClose 拦截后的真实退出请求）。
    // confirmExit 内部完成三选决策与 destroy。
    if (!mounted) return;
    await _exitGuard.confirmExit();
  }

  /// 启动自动探测：优先 videoconfig，其次 autoexec；home 缺失（macOS
  /// 开发期）或两个目标都不存在时静默，由顶部「打开文件」按钮兜底。
  void _autoDetectAndOpen() {
    if (!widget.autoDetect) return;
    final home = widget.homeDirOverride ?? Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) return;
    final finder = ApexPathFinder(homeDir: home);
    final path = finder.findVideoconfig() ?? finder.findAutoexec();
    if (path != null && widget.fileBloc.state.path == null) {
      widget.fileBloc.add(OpenRequested(path));
    }
  }

  Future<void> _openFileManually() async {
    final pick = widget.pickFile ?? _pickWithFilePicker;
    try {
      final path = await pick();
      if (path == null || !mounted) return; // 用户取消
      widget.fileBloc.add(OpenRequested(path));
    } catch (_) {
      // file_picker 在测试 / 无窗口环境不可用：静默（打开失败另有告警路径）。
    }
  }

  static Future<String?> _pickWithFilePicker() async {
    // file_picker 12.x：单选走静态 FilePicker.pickFile。
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['cfg', 'txt'],
    );
    return file?.path;
  }

  /// 还原完成通知。还原链路 RestoreRequested → (FileBloc) →
  /// OpenRequested → DocumentOpened 是异步事件链，让一拍事件循环跑完；
  /// 随后递增 _textEpoch 重建编辑区子树——文本模式的 TextEditorView
  /// 控制器只在 initState 初始化一次（任务 14 取舍），换 key 重建是
  /// 让还原内容回显的最小手段；表格模式天然跟随 BlocBuilder 无需处理。
  Future<void> _onRestored() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (!mounted) return;
    setState(() => _textEpoch++);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      // 桌面端没有系统返回栈：批准退出 = 销毁窗口（原生关闭已被
      // window_manager 拦截），因此 canPop 恒 false，统一走 ExitGuard
      //（confirmExit 内部完成三选决策与 destroy）。
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _exitGuard.confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: BlocBuilder<FileBloc, FileState>(
            bloc: widget.fileBloc,
            // 无文件时回退到应用标题；有文件时只显示文件名。
            builder: (_, s) => Text(
              s.path?.split('/').last.split('\\').last ?? l.appTitle,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.folderOpen),
              tooltip: l.openFile,
              onPressed: _openFileManually,
            ),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(LucideIcons.table2),
                  label: Text(l.modeTable),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(LucideIcons.code2),
                  label: Text(l.modeText),
                ),
              ],
              selected: {_textMode},
              onSelectionChanged: (v) => setState(() => _textMode = v.first),
            ),
            // IconButton 的 tooltip 同时充当无障碍语义（semanticLabel 不可传）。
            IconButton(
              icon: const Icon(LucideIcons.save),
              tooltip: l.save,
              onPressed: () => widget.fileBloc.add(SaveRequested()),
            ),
            IconButton(
              icon: const Icon(LucideIcons.history),
              tooltip: l.restore,
              onPressed: () => showRestoreDialog(
                context,
                fileBloc: widget.fileBloc,
                onRestored: _onRestored,
              ),
            ),
          ],
        ),
        body: BlocListener<FileBloc, FileState>(
          bloc: widget.fileBloc,
          // warning 常驻状态（如坏字节随文件存续）：仅在出现/变更时提示一次。
          listenWhen: (prev, cur) =>
              cur.warning != null && prev.warning != cur.warning,
          listener: (context, s) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(warningText(context, s.warning!))),
            );
          },
          child: Column(
            children: [
              Expanded(
                flex: 6,
                child: _textMode
                    ? TextEditorView(
                        key: ValueKey<int>(_textEpoch),
                        editBloc: widget.editBloc,
                      )
                    : KvTableView(
                        editBloc: widget.editBloc,
                        fileBloc: widget.fileBloc,
                      ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 220,
                child: Row(
                  children: [
                    const SizedBox(width: 280, child: KbCard()),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: SideBySideDiff(diffBloc: widget.diffBloc),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
