import 'dart:async';
import 'dart:io';

import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:fluent_ui/fluent_ui.dart' hide TitleBar;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../core/io/cfg_file_io.dart';
import '../core/paths/install_locator.dart';
import '../core/paths/windows_registry.dart';
import '../core/settings/settings_store.dart';
import '../core/templates/autoexec_template.dart';
import '../core/update/update_service.dart';
import '../state/diff_bloc.dart';
import '../state/edit_bloc.dart';
import '../state/file_bloc.dart';
import 'backup_dialog.dart';
import 'exit_guard.dart';
import 'quit_dialog.dart';
import 'settings_page.dart';
import 'widgets/kb_card.dart';
import 'widgets/kv_table_view.dart';
import 'widgets/side_by_side_diff.dart';
import 'widgets/text_editor_view.dart';
import 'widgets/title_bar.dart';
import 'theme/acid_theme.dart';

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

void _showErrorInfoBar(BuildContext context, String message) {
  final theme =
      FluentTheme.maybeOf(context) ?? buildFluentTheme(Brightness.dark);
  final locale = Localizations.localeOf(context);
  displayInfoBar(
    context,
    builder: (overlayContext, close) => Localizations.override(
      context: context,
      locale: locale,
      delegates: const [
        AppLocalizations.delegate,
        FluentLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      child: FluentTheme(
        data: theme,
        child: InfoBar.error(title: Text(message), onClose: close),
      ),
    ),
  );
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

/// 主界面三段工作台：窗口栏 + 自适应编辑面板 + 底部知识/变更双栏。
/// 底栏高度随窗口大小时变，编辑模式下的小屏不再被固定 220 高度积压。
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

  /// 更新服务测试接缝；生产默认读取 GitHub Releases。
  final UpdateService? updateService;

  /// 设置页写入设置后通知应用壳刷新运行时依赖（例如备份目录）。
  final VoidCallback? onSettingsChanged;

  /// 设置页确认恢复默认设置后通知应用壳重置主题/语言等内存状态。
  final VoidCallback? onResetSettings;

  /// 应用信息面板展示的备份与日志目录。
  final String? backupDir;
  final String? logDir;

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
    this.updateService,
    this.onSettingsChanged,
    this.onResetSettings,
    this.backupDir,
    this.logDir,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WindowListener {
  BuildContext? _fluentContext;
  bool _textMode = false;
  bool _showSettings = false;

  /// 原生关闭是否被拦截。仅在文档有未保存修改时开启，干净文档直接交给
  /// Windows 处理，避免关窗事件再绕一轮 Dart/平台通道才退出。
  bool _preventClose = true;
  Future<void> _preventCloseSync = Future<void>.value();

  /// 防止 close() 触发的 onWindowClose 再次进入退出流程。
  bool _exiting = false;
  StreamSubscription<EditState>? _dirtyGuardSub;

  late final UpdateService _updateService;

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
    _updateService = widget.updateService ?? UpdateService();
    windowManager.addListener(this);
    _setupWindowGuard();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoDetectAndOpen());
  }

  @override
  void dispose() {
    _dirtyGuardSub?.cancel();
    windowManager.removeListener(this);
    super.dispose();
  }

  /// window_manager 在 macOS 开发期 / 测试环境可能没有原生窗口通道：
  /// 全部调用 try/catch 容错，失败时退出保护退化为 PopScope 守护。
  void _setupWindowGuard() {
    _preventClose = widget.editBloc.state.dirty;
    _queuePreventClose(_preventClose);
    _dirtyGuardSub = widget.editBloc.stream.listen((state) {
      _syncPreventClose(state.dirty);
    });
  }

  Future<void> _destroyWindow() async {
    if (_exiting) return;
    _exiting = true;
    await _preventCloseSync;
    if (_preventClose) {
      _preventClose = false;
      await _setPreventClose(false);
    }
    try {
      // 先隐藏使窗口立刻从桌面消失；close() 走原生 WM_CLOSE，比
      // destroy() 的 PostQuitMessage 更直接。close 失败再强制销毁。
      await windowManager.hide();
      await windowManager.close();
    } catch (_) {
      try {
        await windowManager.destroy();
      } catch (_) {
        // 测试环境无原生窗口通道：忽略；退出决策由 ExitGuard 覆盖测试。
      }
    }
  }

  void _syncPreventClose(bool dirty) {
    if (_preventClose == dirty) return;
    _preventClose = dirty;
    _queuePreventClose(dirty);
  }

  void _queuePreventClose(bool value) {
    _preventCloseSync = _preventCloseSync.then((_) => _setPreventClose(value));
  }

  Future<void> _setPreventClose(bool value) async {
    try {
      await windowManager.setPreventClose(value);
    } catch (_) {
      // 无窗口通道（测试 / 未初始化平台）：PopScope 与 ExitGuard 仍生效。
    }
  }

  ExitGuard get _exitGuard => ExitGuard(
    editBloc: widget.editBloc,
    fileBloc: widget.fileBloc,
    askUser: () => showQuitDialog(_fluentContext ?? context),
    destroy: _destroyWindow,
  );

  @override
  void onWindowClose() async {
    // Windows 关窗（setPreventClose 拦截后的真实退出请求）。
    // confirmExit 内部完成三选决策与 destroy。
    if (!mounted || _exiting) return;
    // 干净文档已关闭原生拦截：本次 WM_CLOSE 可直接走系统默认销毁。
    if (!widget.editBloc.state.dirty && !_preventClose) return;
    await _exitGuard.confirmExit();
  }

  /// 启动自动探测（探测引擎 v2）：videoconfig 优先自动打开，其次所选
  /// 安装的 autoexec.cfg；autoexec 缺失或探测全空时进入对应横幅状态。
  Future<void> _autoDetectAndOpen() async {
    final settings = widget.settings;
    if (settings?.readReopenLastFile() == true) {
      final last = settings?.readLastOpenFile();
      if (last != null && File(last).existsSync()) {
        widget.fileBloc.add(OpenRequested(last));
        return;
      }
    }
    if (!widget.autoDetect || settings?.readAutoDetectOnStartup() == false) {
      return;
    }
    await _applyResults(_runLocator());
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
        customInstallDir:
            customInstallDir ?? widget.settings?.readCustomInstallDir(),
      );

  /// 探测结果落地：文档根（videoconfig）优先自动打开；安装候选多于一个
  /// 时弹选择对话框；所选安装有 autoexec.cfg 就打开，只有目录就进入
  /// 「创建 autoexec.cfg」横幅；全空进入「未找到」横幅。
  Future<void> _applyResults(List<ApexInstall> results) async {
    final configResults = results
        .where((r) => r.videoconfigPath != null || r.settingsPath != null)
        .toList();
    final installs = results
        .where((r) => r.videoconfigPath == null && r.settingsPath == null)
        .toList();

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

    final preferred = widget.settings?.readPreferredOpenKind() ?? 'settings';
    if (preferred == 'autoexec' &&
        chosen != null &&
        chosen.autoexecPath == null &&
        widget.settings?.readAutoCreateMissingTemplate() == true) {
      if (!mounted) return;
      setState(() {
        _activeInstall = chosen;
        _phase = _DetectPhase.autoexecMissing;
      });
      await _createAutoexec();
      return;
    }
    final config = configResults.firstOrNull;
    final openPath = switch (preferred) {
      'autoexec' =>
        chosen?.autoexecPath ?? config?.settingsPath ?? config?.videoconfigPath,
      'videoconfig' =>
        config?.videoconfigPath ?? chosen?.autoexecPath ?? config?.settingsPath,
      _ =>
        config?.settingsPath ?? chosen?.autoexecPath ?? config?.videoconfigPath,
    };
    if (openPath == null &&
        chosen != null &&
        widget.settings?.readAutoCreateMissingTemplate() == true) {
      if (!mounted) return;
      setState(() {
        _activeInstall = chosen;
        _phase = _DetectPhase.autoexecMissing;
      });
      await _createAutoexec();
      return;
    }
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
      context: _fluentContext ?? context,
      builder: (dialogContext) => ContentDialog(
        title: Text(l.chooseInstallTitle),
        content: SizedBox(
          width: 520,
          height: 220,
          child: ListView(
            children: [
              for (final install in installs)
                ListTile(
                  leading: Icon(sourceIcon(install.source)),
                  title: Text(sourceLabel(install.source)),
                  subtitle: Text(
                    install.installDir,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(install),
                ),
            ],
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.cancel),
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
        CfgFileIo.write(file.path, autoexecTemplate, CfgEncoding.utf8);
      }
    } catch (_) {
      if (mounted) {
        _showErrorInfoBar(
          _fluentContext ?? context,
          AppLocalizations.of(context)!.fileSaveFailed,
        );
      }
      return;
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
        _showErrorInfoBar(_fluentContext ?? context, l.filePickerFailed);
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
      if (widget.editBloc.state.dirty) {
        final proceed = await _confirmOpenOverDirty(path);
        if (!proceed || !mounted) return;
      }
      widget.fileBloc.add(OpenRequested(path));
    } catch (_) {
      // file_picker 层异常（测试 / 无窗口环境不可用、插件崩溃等）不再
      // 静默：SnackBar 反馈，用户至少知道点击没有生效，可重试。
      if (!mounted) return;
      _showErrorInfoBar(
        _fluentContext ?? context,
        AppLocalizations.of(context)!.filePickerFailed,
      );
    }
  }

  Future<bool> _confirmOpenOverDirty(String path) async {
    final l = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: _fluentContext ?? context,
      builder: (dialogContext) => ContentDialog(
        title: Text(l.restoreDirtyTitle),
        content: Text(l.restoreDirtyBody),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    return result == true;
  }

  static Future<String?> _pickWithFilePicker(String? initialDirectory) async {
    // file_picker 12.x：单选走静态 FilePicker.pickFile。
    Future<String?> pick(String? dir) async {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['cfg', 'txt'],
        initialDirectory: dir,
      );
      return file?.path;
    }

    final initial =
        initialDirectory != null &&
            initialDirectory.isNotEmpty &&
            Directory(initialDirectory).existsSync()
        ? initialDirectory
        : null;
    try {
      return await pick(initial);
    } catch (_) {
      // 上次路径被移动或删除时，部分 Windows 文件选择器会直接失败；
      // 去掉失效初始目录重试一次，保证「重新选择」始终可恢复。
      if (initial == null) rethrow;
      return pick(null);
    }
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
    final openedState = await opened.timeout(
      _restoreWaitTimeout,
      onTimeout: () => null,
    );
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LayoutBuilder(
            builder: (context, constraints) => InfoBar(
              isLong: constraints.maxWidth < 720,
              title: Text(title),
              content: Text(hint),
              severity: missing
                  ? InfoBarSeverity.warning
                  : InfoBarSeverity.info,
              action: missing
                  ? Button(
                      onPressed: _createAutoexec,
                      child: Text(l.createAutoexec),
                    )
                  : HyperlinkButton(
                      onPressed: _pickApexDir,
                      child: Text(l.specifyApexDir),
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme =
        FluentTheme.maybeOf(context) ?? buildFluentTheme(Brightness.dark);
    return FluentThemeFallback(
      child: Builder(
        builder: (fluentContext) {
          _fluentContext = fluentContext;
          return PopScope(
            // 桌面端没有系统返回栈：canPop 恒 false，统一走 ExitGuard。
            // 原生关闭仅在脏文档时拦截；干净文档由 Windows 直接销毁。
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop || _exiting) return;
              await _exitGuard.confirmExit();
            },
            child: Container(
              color: theme.scaffoldBackgroundColor,
              // 无边框窗口（frameless）：系统标题栏被移除，顶栏为自绘
              // [TitleBar]（品牌 + 拖拽区 + 业务按钮 + 亮/暗切换 + 窗口控制）。
              // 关闭按钮直接走 [ExitGuard] 三选流程；原生关窗仍由
              // setPreventClose → onWindowClose 兜底拦截。
              child: BlocListener<FileBloc, FileState>(
                bloc: widget.fileBloc,
                // warning 常驻状态（如坏字节随文件存续）：仅在出现/变更时提示一次。
                listenWhen: (prev, cur) =>
                    cur.warning != null && prev.warning != cur.warning,
                listener: (context, s) {
                  _showErrorInfoBar(
                    _fluentContext ?? context,
                    warningText(context, s.warning!),
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
                          if (!_showSettings) ...[
                            Tooltip(
                              message: s.path == null
                                  ? l.openFile
                                  : l.reselectFile,
                              child: IconButton(
                                key: const ValueKey('titlebar.openFile'),
                                iconButtonMode: IconButtonMode.small,
                                icon: Icon(
                                  s.path == null
                                      ? LucideIcons.folderOpen
                                      : LucideIcons.fileInput,
                                ),
                                onPressed: _openFileManually,
                              ),
                            ),
                            const _ToolbarDivider(),
                            Tooltip(
                              message: l.save,
                              child: IconButton(
                                icon: const Icon(LucideIcons.save),
                                onPressed: () =>
                                    widget.fileBloc.add(SaveRequested()),
                              ),
                            ),
                            Tooltip(
                              message: l.restore,
                              child: IconButton(
                                icon: const Icon(LucideIcons.history),
                                onPressed: () => showRestoreDialog(
                                  _fluentContext ?? context,
                                  fileBloc: widget.fileBloc,
                                  editBloc: widget.editBloc,
                                  onRestored: _onRestored,
                                ),
                              ),
                            ),
                            const _ToolbarDivider(),
                          ],
                          Tooltip(
                            message: _showSettings ? l.back : l.settings,
                            child: IconButton(
                              key: const ValueKey('titlebar.settings'),
                              icon: Icon(
                                _showSettings
                                    ? LucideIcons.arrowLeft
                                    : LucideIcons.settings2,
                              ),
                              onPressed: () => setState(
                                () => _showSettings = !_showSettings,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showSettings)
                      Expanded(
                        child: SettingsPage(
                          updateService: _updateService,
                          settings: widget.settings,
                          backupDir: widget.backupDir ?? '',
                          logDir: widget.logDir ?? '',
                          openFilePath: widget.fileBloc.state.path,
                          onSettingsChanged: widget.onSettingsChanged,
                          onResetSettings: widget.onResetSettings,
                        ),
                      )
                    else
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final dockHeight = (constraints.maxHeight * 0.31)
                                .clamp(190.0, 276.0);
                            final knowledgeWidth = constraints.maxWidth < 1180
                                ? 260.0
                                : 304.0;

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              child: Column(
                                children: [
                                  // 探测 v2 空态横幅：autoexec 缺失（创建入口）或
                                  // 未找到（指定目录入口）；打开成功后自动隐藏。
                                  _buildDetectBanner(context),
                                  Expanded(
                                    child: Container(
                                      key: const ValueKey('workspace.editor'),
                                      decoration: BoxDecoration(
                                        color: AcidPalette.of(context).panel,
                                        border: Border.all(
                                          color: AcidPalette.of(
                                            context,
                                          ).chrome.withValues(alpha: 0.28),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          _WorkbenchHeader(
                                            editBloc: widget.editBloc,
                                            fileBloc: widget.fileBloc,
                                            textMode: _textMode,
                                            onReselectFile: _openFileManually,
                                            onModeChanged: (next) => setState(
                                              () => _textMode = next,
                                            ),
                                          ),
                                          Container(
                                            height: 1,
                                            color: AcidPalette.of(
                                              context,
                                            ).chrome.withValues(alpha: 0.2),
                                          ),
                                          Expanded(
                                            child: _textMode
                                                ? TextEditorView(
                                                    key: ValueKey<int>(
                                                      _textEpoch,
                                                    ),
                                                    editBloc: widget.editBloc,
                                                  )
                                                : KvTableView(
                                                    editBloc: widget.editBloc,
                                                    fileBloc: widget.fileBloc,
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: dockHeight,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: knowledgeWidth,
                                          child: _DockPanel(
                                            key: const ValueKey(
                                              'workspace.knowledgeBase',
                                            ),
                                            icon: LucideIcons.bookOpen,
                                            title: l.knowledgeBase,
                                            child: KbCard(
                                              editBloc: widget.editBloc,
                                              showEmptyState: true,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _DockPanel(
                                            key: const ValueKey(
                                              'workspace.diffPreview',
                                            ),
                                            icon: LucideIcons.gitCompare,
                                            title: l.diffPreview,
                                            child: SideBySideDiff(
                                              diffBloc: widget.diffBloc,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      color: AcidPalette.of(context).chrome.withValues(alpha: 0.24),
    );
  }
}

class _WorkbenchHeader extends StatelessWidget {
  final EditBloc editBloc;
  final FileBloc fileBloc;
  final bool textMode;
  final VoidCallback onReselectFile;
  final ValueChanged<bool> onModeChanged;

  const _WorkbenchHeader({
    required this.editBloc,
    required this.fileBloc,
    required this.textMode,
    required this.onReselectFile,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = AcidPalette.of(context);
    return BlocBuilder<FileBloc, FileState>(
      bloc: fileBloc,
      buildWhen: (prev, cur) => prev.path != cur.path || prev.kind != cur.kind,
      builder: (context, fileState) {
        final purpose = switch (fileState.kind) {
          CfgKind.videoconfig => l.filePurposeVideoconfig,
          CfgKind.settings => l.filePurposeSettings,
          CfgKind.autoexec => l.filePurposeAutoexec,
          null => null,
        };
        final mode = textMode ? l.modeText : l.modeTable;
        final hasFile = fileState.path != null;
        return SizedBox(
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(width: 3, height: 18, color: palette.acid),
                const SizedBox(width: 9),
                Icon(
                  textMode ? LucideIcons.code2 : LucideIcons.table2,
                  size: 15,
                  color: palette.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    purpose == null ? mode : '$mode · $purpose',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: hasFile ? l.reselectFile : l.openFile,
                  child: Button(
                    key: const ValueKey('workspace.reselectFile'),
                    onPressed: onReselectFile,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasFile
                              ? LucideIcons.fileInput
                              : LucideIcons.folderOpen,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(hasFile ? l.reselectFile : l.openFile),
                      ],
                    ),
                  ),
                ),
                BlocBuilder<EditBloc, EditState>(
                  bloc: editBloc,
                  buildWhen: (prev, cur) => prev.dirty != cur.dirty,
                  builder: (context, state) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 140),
                    child: state.dirty
                        ? Container(
                            key: const ValueKey('workspace.dirty'),
                            margin: const EdgeInsets.only(left: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: palette.danger.withValues(alpha: 0.12),
                              border: Border.all(
                                color: palette.danger.withValues(alpha: 0.42),
                              ),
                            ),
                            child: Text(
                              l.unsavedBadge,
                              style: TextStyle(
                                fontSize: 11,
                                color: palette.danger,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('workspace.clean'),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: palette.bg.withValues(alpha: 0.5),
                    border: Border.all(
                      color: palette.chrome.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: l.modeTable,
                        child: ToggleButton(
                          checked: !textMode,
                          onChanged: (_) => onModeChanged(false),
                          child: const Icon(LucideIcons.table2),
                        ),
                      ),
                      Tooltip(
                        message: l.modeText,
                        child: ToggleButton(
                          checked: textMode,
                          onChanged: (_) => onModeChanged(true),
                          child: const Icon(LucideIcons.code2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DockPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DockPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AcidPalette.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.panel,
        border: Border.all(color: palette.chrome.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: palette.acid),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFontUi,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: palette.chrome.withValues(alpha: 0.2)),
          Expanded(child: child),
        ],
      ),
    );
  }
}
