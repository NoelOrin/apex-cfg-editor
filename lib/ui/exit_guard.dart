import 'dart:async';

import '../state/edit_bloc.dart';
import '../state/file_bloc.dart';

/// 退出对话框三选。
enum QuitChoice { save, discard, cancel }

/// FileBloc 保存失败告警键（FileState.warning），此处用于识别失败。
const _saveFailedWarning = 'fileSaveFailed';

/// 退出保护决策逻辑：把「是否脏 + 用户三选」映射为是否允许退出，
/// 并处理「保存并退出」的落盘等待与失败中止。
///
/// 不依赖 window_manager / BuildContext：askUser 与 destroy 均注入，
/// 纯 Dart 可测（widget 测试不强求跑 window_manager）。
class ExitGuard {
  final EditBloc editBloc;
  final FileBloc fileBloc;

  /// 询问用户；对话框被关闭（无选择）时返回 null，视为取消。
  final Future<QuitChoice?> Function() askUser;

  /// 真正的关窗动作。生产 = windowManager.destroy()。
  final Future<void> Function() destroy;

  /// 「保存后退出」等待落盘的超时上限。
  final Duration saveTimeout;

  static const _defaultSaveTimeout = Duration(seconds: 5);

  ExitGuard({
    required this.editBloc,
    required this.fileBloc,
    required this.askUser,
    required this.destroy,
    this.saveTimeout = _defaultSaveTimeout,
  });

  /// 执行一次退出请求：不脏直接销毁窗口；脏则先询问三选。
  /// 返回 true 表示窗口已（或即将被调用方）销毁；false 表示退出被中止
  ///（用户取消 / 保存失败 / 保存超时），窗口保持打开。
  Future<bool> confirmExit() async {
    if (!editBloc.state.dirty) {
      await destroy(); // 干净文档：直接退出，不打扰
      return true;
    }
    final choice = await askUser();
    switch (choice) {
      case QuitChoice.save:
        return _saveThenDestroy();
      case QuitChoice.discard:
        await destroy();
        return true;
      case QuitChoice.cancel:
      case null:
        return false;
    }
  }

  /// 「保存并退出」：SaveRequested 后同时监听两个终态——
  /// EditBloc 下一次 dirty == false（成功）或 FileBloc 出现
  /// fileSaveFailed 告警（失败）。成功才 destroy；失败/超时一律中止退出
  ///（宁可让用户手动重试，不可静默丢数据）。
  Future<bool> _saveThenDestroy() async {
    fileBloc.add(SaveRequested());
    // catchError 吞掉落选方后续的错误（如 bloc 关闭时广播流的 StateError），
    // 其结果本就不被使用。
    final saved = editBloc.stream
        .firstWhere((s) => !s.dirty)
        .then<bool>((_) => true)
        .catchError((Object _) => false);
    final failed = fileBloc.stream
        .firstWhere((s) => s.warning == _saveFailedWarning)
        .then<bool>((_) => false)
        .catchError((Object _) => false);
    final savedOk = await Future.any<bool>([saved, failed])
        .timeout(saveTimeout, onTimeout: () => false);
    if (!savedOk) return false; // 失败/超时：中止退出，窗口保持
    await destroy();
    return true;
  }
}
