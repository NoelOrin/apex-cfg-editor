import 'dart:io';

import 'package:apex_cfg_editor/core/backup/backup_service.dart';
import 'package:apex_cfg_editor/core/io/cfg_file_io.dart';
import 'package:apex_cfg_editor/knowledge/kb_service.dart';
import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/state/diff_bloc.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';
import 'package:apex_cfg_editor/ui/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // window_manager 初始化容错：macOS 开发期 / 测试环境没有原生窗口通道，
  // 失败时应用照常运行，退出保护退化为 PopScope 守护。
  try {
    await windowManager.ensureInitialized();
  } catch (_) {
    // 无窗口通道：忽略。
  }
  final kb = await KbService.fromAssets();
  runApp(ApexCfgEditorApp(kb: kb));
}

/// 生产备份根目录：`%APPDATA%\ApexCfgEditor\backups`；
/// APPDATA 缺失（macOS 开发期）兜底系统临时目录。
String defaultBackupBase() {
  final appData = Platform.environment['APPDATA'];
  return '${appData ?? Directory.systemTemp.path}/ApexCfgEditor/backups';
}

/// saveImpl 装配（FileBloc 契约：`Future<void> Function(path, text, enc)`）：
/// 先把磁盘上的旧内容写入备份，再按打开时探测到的编码写盘。
/// 顺序不可颠倒——写盘完成后旧内容即丢失。
Future<void> backupThenWrite(
  BackupService backups,
  String path,
  String text,
  CfgEncoding enc,
) async {
  backups.backupBeforeSave(path, File(path).readAsStringSync());
  CfgFileIo.write(path, text, enc);
}

/// 应用壳：持有三个 bloc 的生命周期并完成真实装配。
class ApexCfgEditorApp extends StatefulWidget {
  /// 知识库。生产由 main() 从 assets 加载；测试注入（空表 / 临时数据）。
  final KbService kb;

  /// 备份根目录。null → [defaultBackupBase]；测试注入临时目录。
  final String? backupBaseDir;

  /// 是否启动自动探测 Apex 配置路径（EditorScreen 内执行）。
  /// 测试关掉以隔离宿主环境。
  final bool autoDetect;

  const ApexCfgEditorApp({
    super.key,
    required this.kb,
    this.backupBaseDir,
    this.autoDetect = true,
  });

  @override
  State<ApexCfgEditorApp> createState() => _ApexCfgEditorAppState();
}

class _ApexCfgEditorAppState extends State<ApexCfgEditorApp> {
  late final EditBloc editBloc;
  late final DiffBloc diffBloc;
  late final FileBloc fileBloc;

  @override
  void initState() {
    super.initState();
    // 装配顺序约束（任务 7 账本）：DiffBloc 构造时只订阅 editStream、
    // 不读当前状态——三个 bloc 必须全部就绪后才允许发起 OpenRequested
    // （EditorScreen initState 的自动探测发生在本方法之后），否则首个
    // 文档状态漏进 diff。EditorScreen 内所有 OpenRequested 都晚于本方法。
    editBloc = EditBloc();
    diffBloc = DiffBloc(editStream: editBloc.stream);
    final backups =
        BackupService(baseDir: widget.backupBaseDir ?? defaultBackupBase());
    fileBloc = FileBloc(
      editBloc: editBloc,
      saveImpl: (path, text, enc) => backupThenWrite(backups, path, text, enc),
      listBackupsImpl: backups.listBackups,
      restoreImpl: backups.restore,
    );
  }

  @override
  void dispose() {
    fileBloc.close();
    diffBloc.close();
    editBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE2483D), // Apex 红
          brightness: Brightness.dark,
        ),
        fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
      ),
      home: RepositoryProvider<KbService>.value(
        value: widget.kb,
        child: EditorScreen(
          editBloc: editBloc,
          diffBloc: diffBloc,
          fileBloc: fileBloc,
          autoDetect: widget.autoDetect,
        ),
      ),
    );
  }
}
