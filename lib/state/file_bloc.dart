import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/io/cfg_file_io.dart';
import '../core/parser/autoexec_parser.dart';
import '../core/parser/videoconfig_parser.dart';
import 'edit_bloc.dart';

enum CfgKind { videoconfig, autoexec }

sealed class FileEvent {}

class OpenRequested extends FileEvent {
  final String path;
  OpenRequested(this.path);
}

class SaveRequested extends FileEvent {}

class RestoreRequested extends FileEvent {
  final String backupPath;
  RestoreRequested(this.backupPath);
}

class FileState {
  final String? path;
  final CfgKind? kind;
  final bool busy;
  final String? warning; // i18n 键名，UI 层翻译
  final List<String> backups; // 还原对话框数据
  const FileState({
    this.path,
    this.kind,
    this.busy = false,
    this.warning,
    this.backups = const [],
  });

  // `warning` 用闭包传参，以区分「未传」与「显式置 null」。
  FileState copyWith({
    String? path,
    CfgKind? kind,
    bool? busy,
    String? Function()? warning,
    List<String>? backups,
  }) =>
      FileState(
          path: path ?? this.path,
          kind: kind ?? this.kind,
          busy: busy ?? this.busy,
          warning: warning != null ? warning() : this.warning,
          backups: backups ?? this.backups);
}

/// IO 编排：真实读写由任务 8/9 服务注入（saveImpl/listBackupsImpl/restoreImpl
/// 为装配接缝），本 Bloc 只负责事件 → IO → EditBloc 状态的编排。
class FileBloc extends Bloc<FileEvent, FileState> {
  final EditBloc editBloc;
  final Future<void> Function(String path, String text, CfgEncoding enc)
      saveImpl;
  final List<String> Function(String path) listBackupsImpl;
  final Future<void> Function(String target, String backup) restoreImpl;

  FileBloc({
    required this.editBloc,
    required this.saveImpl,
    required this.listBackupsImpl,
    required this.restoreImpl,
  }) : super(const FileState()) {
    on<OpenRequested>((e, em) async {
      em(state.copyWith(busy: true, warning: () => null));
      try {
        final data = CfgFileIo.read(e.path);
        final kind = e.path.endsWith('videoconfig.txt')
            ? CfgKind.videoconfig
            : CfgKind.autoexec;
        final doc = kind == CfgKind.videoconfig
            ? VideoconfigParser().parse(data.text)
            : AutoexecParser().parse(data.text);
        editBloc.add(DocumentOpened(doc: doc, baseline: data.text));
        em(FileState(
            path: e.path,
            kind: kind,
            busy: false,
            warning: data.hasBadBytes ? 'fileBadEncoding' : null,
            backups: listBackupsImpl(e.path)));
      } catch (_) {
        // 打开失败回到无文件状态：busy 复位 + 告警，避免 UI 死锁。
        em(const FileState(busy: false, warning: 'fileOpenFailed'));
      }
    });
    on<SaveRequested>((e, em) async {
      final doc = editBloc.state.doc;
      final path = state.path;
      if (doc == null || path == null) return;
      final st = editBloc.state;
      if (!st.dirty) return; // 未编辑：不产生新备份
      // 先清告警：重试保存失败时（warning 值不变）UI 的 listenWhen 仍能
      // 重新触发提示；fileBadEncoding 属于打开期一次性提示，可安全清除。
      em(state.copyWith(warning: () => null));
      try {
        final cur = File(path).readAsBytesSync();
        await saveImpl(path, doc.serialize(), CfgFileIo.readBytes(cur).encoding);
      } catch (_) {
        // 保存失败：不派发 DocumentSaved（dirty 保持 true，重试不被
        // !dirty no-op 吞掉），置告警由 ExitGuard/UI 中止退出或提示。
        em(state.copyWith(warning: () => 'fileSaveFailed'));
        return;
      }
      editBloc.add(DocumentSaved(doc.serialize()));
      em(state.copyWith(backups: listBackupsImpl(path)));
    });
    on<RestoreRequested>((e, em) async {
      await restoreImpl(state.path!, e.backupPath);
      add(OpenRequested(state.path!));
    });
  }
}
