import 'dart:io';

import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../core/io/cfg_file_io.dart';
import '../core/paths/install_locator.dart';
import '../core/paths/windows_registry.dart';
import '../core/settings/settings_store.dart';
import '../core/templates/autoexec_template.dart';
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
import 'widgets/title_bar.dart';

/// FileState.warning（i18n 键名）→ UI 文案映射。
String warningText(BuildContext context, String key) {
  final l = AppLocalizations.of(context)!;
  return switch (key) {
    'fileBadEncoding' => l.fileBadEncoding,
    'fileOpenFailed' => l.fileOpenFailed,
    'fileSaveFailed' => l.fileSaveFailed,
    'fileRestoreFailed' => l.fileRestoreFailed,
    'fileBadBytesDirty' => l.fileBadBytesDirty,
    _ => key,
  };
}

/// 探测后的界面状态（决定空态横幅内容；打开文件成功后横幅自动隐藏）。
enum _DetectPhase {
  /// 未探测 / 已有文件打开 / videoconfig 优先打开成功。
  idle,

  /// 探测全空：提示手动选择或指定 Apex 目录。
  notFound,

  /// 找到安装但 autoexec.cfg 缺失：提供创建模板入口。
  autoexecMissing,
}

/// 主界面三区布局：顶栏（文件名/模式切换/保存/还原）+
/// 编辑区（flex 6）+ 底部区（高 220，内含知识卡 280 宽 + 行级 diff）。
/// 三个 bloc 均由外部注入（测试接缝）。
///
/// 本屏同时承担装配期行为：启动自动探测（探测引擎 v2，见
/// [InstallLocator]）、「打开文件」手动选择（[pickFile]）、指定 Apex 目录
/// （探测 v2 的 customInstallDir 回写）、创建 autoexec.cfg 模板、还原
/// 对话框接线和退出保护（PopScope + window_manager WindowListener，
/// 均经 [ExitGuard] 决策）。
class EditorScreen extends StatefulWidget {
  final EditBloc editBloc;
  final DiffBloc diffBloc;
  final FileBloc fileBloc;

  /// 启动自动探测开关（initState 后帧执行）；默认开，测试可关。
  final bool autoDetect;

  /// 自动探测的 home 根目录。null → 真实环境变量（macOS 开发期
  /// USERPROFILE 通常为 null → 文档根落空，注册表走空实现，绝不去
  /// 探测真实盘）。
  final String? homeDirOverride;

  /// 「打开文件」选择器。null → file_picker（.cfg/.txt）；测试注入。
  final Future<String?> Function()? pickFile;

  /// 「指定 Apex 目录」选择器。null → file_picker 目录选择；测试注入。
  final Future<String?> Function()? pickDirectory;

  /// 探测引擎 v2。null → 生产装配（Windows 真实注册表 + C-F 盘符枚举，
  /// 非 Windows 注册表走空实现）。
  final InstallLocator? locator;

  /// 上次打开路径存储（规格 R7）：选择器以 lastOpenDir 作为
  /// initialDirectory 打开；探测 v2 读写 customInstallDir。
  /// null → 不带初始目录、不读写记忆路径。
  final SettingsStore? settings;

  const EditorScreen({
    super.key,
    required this.editBloc,
    required this.diffBloc,
    required this.fileBloc,
    this.autoDetect = true,
    this.homeDirOverride,
    this.pickFile,
    this.pickDirectory,
    this.locator,
    this.settings,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WindowListener {
  bool _textMode = false;

  _DetectPhase _phase = _DetectPhase.idle;

  /// 用户在多安装选择对话框中选定的安装（创建 autoexec 的目标）。
  ApexInstall? _activeInstall;

  /// 还原后递增，作为 TextEditorView 的 key 强制重建子树（见 _onRestored）。
  int _textEpoch = 0;

  /// 还原刷新等待重开（baseline == 备份内容）的超时上限。
  static const _restoreWaitTimeout = Duration(seconds: 3);

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

  /// 启动自动探测（探测引擎 v2）：videoconfig 优先自动打开，其次所选
  /// 安装的 autoexec.cfg；autoexec 缺失或探测全空时进入对应横幅状态。
  void _autoDetectAndOpen() {
    if (!widget.autoDetect) return;
    _applyResults(_runLocator());
  }

  /// 组装探测器：优先注入（测试），否则生产装配。homeDirOverride 仅测试
  /// 注入，映射为 USERPROFILE 环境变量供文档根推导。
  InstallLocator _buildLocator() {
    if (widget.locator != null) return widget.locator!;
    final home = widget.homeDirOverride;
    return InstallLocator(
      registry: defaultRegistryReader(),
      drives: fixedDriveLister,
      env: (home != null && home.isNotEmpty)
          ? <String, String?>{'USERPROFILE': home}
          : null,
    );
  }

  List<ApexInstall> _runLocator({String? customInstallDir}) =>
      _buildLocator().locate(
        customInstallDir: customInstallDir ??
            widget.settings?.readCustomInstallDir(),
      );

  /// 探测结果落地：文档根（videoconfig）优先自动打开；安装候选多于一个
  /// 时弹选择对话框；所选安装有 autoexec.cfg 就打开，只有目录就进入
  /// 「创建 autoexec.cfg」横幅；全空进入「未找到」横幅。
  Future<void> _applyResults(List<ApexInstall> results) async {
    final docResults =
        results.where((r) => r.videoconfigPath != null).toList();
    final installs = results.where((r) => r.videoconfigPath == null).toList();

    ApexInstall? chosen;
    if (installs.length > 1) {
      if (!mounted) return;
      chosen = await _showInstallChooser(installs);
      if (!mounted) return;
      // 用户取消选择：不再自动处理 autoexec，退回「未找到」横幅
      // （顶栏「打开文件」始终可用）。
    } else if (installs.isNotEmpty) {
      chosen = installs.first;
    }

    final openPath = docResults.isNotEmpty
        ? docResults.first.videoconfigPath
        : chosen?.autoexecPath;
    if (openPath != null && widget.fileBloc.state.path == null) {
      widget.fileBloc.add(OpenRequested(openPath));
    }
    if (!mounted) return;
    setState(() {
      _activeInstall = chosen;
      _phase = openPath != null
          ? _DetectPhase.idle
          : chosen != null
              ? _DetectPhase.autoexecMissing
              : _DetectPhase.notFound;
    });
  }

  /// 多安装选择对话框（Steam + EA App 双装等）。取消返回 null。
  Future<ApexInstall?> _showInstallChooser(List<ApexInstall> installs) {
    final l = AppLocalizations.of(context)!;
    String sourceLabel(InstallSource s) => switch (s) {
          InstallSource.steam => l.installSourceSteam,
          InstallSource.eaApp => l.installSourceEaApp,
          _ => l.installSourceCustom,
        };
    IconData sourceIcon(InstallSource s) => switch (s) {
          InstallSource.steam => LucideIcons.gamepad2,
          InstallSource.eaApp => LucideIcons.appWindow,
          _ => LucideIcons.folder,
        };
    return showDialog<ApexInstall>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l.chooseInstallTitle),
        children: [
          for (final install in installs)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(install),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(sourceIcon(install.source)),
                title: Text(sourceLabel(install.source)),
                subtitle: Text(install.installDir, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l.cancel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 「创建 autoexec.cfg」：写入全注释模板（目录按可创建位置补建）后
  /// 自动打开。模板不改变任何游戏行为。
  Future<void> _createAutoexec() async {
    final dir = _activeInstall?.autoexecDir;
    if (dir == null) return;
    final file = File('$dir/autoexec.cfg');
    try {
      if (!file.existsSync()) {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(autoexecTemplate);
      }
    } catch (_) {
      // 建档失败（权限等）：交由 OpenRequested 的失败告警反馈。
    }
    if (!mounted) return;
    setState(() => _phase = _DetectPhase.idle);
    if (widget.fileBloc.state.path == null) {
      widget.fileBloc.add(OpenRequested(file.path));
    }
  }

  /// 「指定 Apex 目录」：选择目录 → 记入 customInstallDir → 以该目录
  /// 重新探测（locate 内部按 fallback 语义合并候选）。
  Future<void> _pickApexDir() async {
    final l = AppLocalizations.of(context)!;
    String? dir;
    try {
      final pick = widget.pickDirectory;
      dir = pick != null
          ? await pick()
          : await FilePicker.getDirectoryPath(
              initialDirectory: widget.settings?.readLastOpenDir(),
            );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.filePickerFailed)),
        );
      }
      return;
    }
    if (dir == null || dir.isEmpty || !mounted) return; // 用户取消
    widget.settings?.writeCustomInstallDir(dir);
    await _applyResults(_runLocator(customInstallDir: dir));
  }

  Future<void> _openFileManually() async {
    final pick = widget.pickFile;
    try {
      // 规格 R7：失败退回手动选择并记住上次路径——选择器以上次目录打开。
      final path = pick != null
          ? await pick()
          : await _pickWithFilePicker(widget.settings?.readLastOpenDir());
      if (path == null || !mounted) return; // 用户取消
      widget.fileBloc.add(OpenRequested(path));
    } catch (_) {
      // file_picker 层异常（测试 / 无窗口环境不可用、插件崩溃等）不再
      // 静默：SnackBar 反馈，用户至少知道点击没有生效，可重试。
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.filePickerFailed)),
      );
    }
  }

  static Future<String?> _pickWithFilePicker(String? initialDirectory) async {
    // file_picker 12.x：单选走静态 FilePicker.pickFile。
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['cfg', 'txt'],
      initialDirectory: initialDirectory,
    );
    return file?.path;
  }

  /// 还原完成刷新。还原链路 RestoreRequested → restoreImpl →
  /// OpenRequested → DocumentOpened 全异步（慢盘/杀毒扫描下可能明显晚于
  /// 对话框关闭），因此不做延时竞速，而是订阅 EditBloc 流等待「baseline
  /// 等于备份内容」的重开状态到达，到达后才递增 _textEpoch 重建编辑区——
  /// 文本模式的 TextEditorView 控制器只在 initState 初始化一次（任务 14
  /// 取舍），换 key 重建是让还原内容回显的最小手段；表格模式天然跟随
  /// BlocBuilder 无需处理。
  ///
  /// 等待超时（3s）自愈失败 → 强制切回表格模式：文档视图由 BlocBuilder
  /// 跟随最新状态，滞留旧内容的文本编辑器随视图销毁，杜绝用户继续输入
  /// 把刚还原的文档整个回灌覆盖（自愈后切回文本模式即可取到新内容）。
  Future<void> _onRestored(String backupPath) async {
    final String expected;
    try {
      expected = CfgFileIo.read(backupPath).text;
    } catch (_) {
      // 备份在列出后被删除等异常：无从校验，退回表格模式最稳。
      if (!mounted) return;
      setState(() => _textMode = false);
      return;
    }
    final opened = widget.editBloc.stream
        .firstWhere((s) => s.doc != null && s.baseline == expected)
        .then<EditState?>((s) => s)
        .catchError((Object _) => null);
    final openedState =
        await opened.timeout(_restoreWaitTimeout, onTimeout: () => null);
    if (!mounted) return;
    if (openedState == null) {
      setState(() => _textMode = false); // 超时：强制表格模式
      return;
    }
    setState(() => _textEpoch++);
  }

  /// 探测状态横幅（常规样式；酸性视觉重构归属下一轮 UI 波次）。
  Widget _buildDetectBanner(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BlocBuilder<FileBloc, FileState>(
      bloc: widget.fileBloc,
      // 常驻状态按「有无文件」门控，避免每次状态发射都重建横幅。
      buildWhen: (prev, cur) => (prev.path == null) != (cur.path == null),
      builder: (context, s) {
        if (s.path != null || _phase == _DetectPhase.idle) {
          return const SizedBox.shrink();
        }
        final missing = _phase == _DetectPhase.autoexecMissing;
        final title = missing ? l.autoexecMissingTitle : l.apexNotFoundTitle;
        final hint = missing ? l.autoexecMissingHint : l.apexNotFoundHint;
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(missing ? LucideIcons.filePlus2 : LucideIcons.searchX,
                    size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(hint,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                missing
                    ? FilledButton.tonal(
                        onPressed: _createAutoexec,
                        child: Text(l.createAutoexec),
                      )
                    : TextButton(
                        onPressed: _pickApexDir,
                        child: Text(l.specifyApexDir),
                      ),
              ],
            ),
          ),
        );
      },
    );
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
        // 无边框窗口（frameless）：系统标题栏被移除，顶栏为自绘
        // [TitleBar]（品牌 + 拖拽区 + 业务按钮 + 亮/暗切换 + 窗口控制）。
        // 关闭按钮直接走 [ExitGuard] 三选流程；原生关窗仍由
        // setPreventClose → onWindowClose 兜底拦截。
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
              BlocBuilder<FileBloc, FileState>(
                bloc: widget.fileBloc,
                buildWhen: (prev, cur) => prev.path != cur.path,
                builder: (_, s) => TitleBar(
                  fileName: s.path?.split('/').last.split('\\').last,
                  onClose: () => _exitGuard.confirmExit(),
                  actions: [
                    IconButton(
                      icon: const Icon(LucideIcons.folderOpen),
                      tooltip: l.openFile,
                      onPressed: _openFileManually,
                    ),
                    // 模式切换仅用图标（Tooltip 兼作悬停提示与无障碍语义）：
                    // 顶栏 actions 宽度固定 ~300，配合窗口最小尺寸 960x640，
                    // 窄窗口下不再溢出破版（任务 16 UI 打磨）。
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: Tooltip(
                            message: l.modeTable,
                            child: const Icon(LucideIcons.table2),
                          ),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Tooltip(
                            message: l.modeText,
                            child: const Icon(LucideIcons.code2),
                          ),
                        ),
                      ],
                      selected: {_textMode},
                      onSelectionChanged: (v) =>
                          setState(() => _textMode = v.first),
                    ),
                    // IconButton 的 tooltip 同时充当无障碍语义。
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
                        editBloc: widget.editBloc,
                        onRestored: _onRestored,
                      ),
                    ),
                  ],
                ),
              ),
              // 探测 v2 空态横幅：autoexec 缺失（创建入口）或未找到
              // （指定目录入口）；打开文件成功后自动隐藏。
              _buildDetectBanner(context),
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
