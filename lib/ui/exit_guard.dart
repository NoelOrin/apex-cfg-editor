import 'dart:async';

import '../state/edit_bloc.dart';
import '../state/file_bloc.dart';

/// 退出对话框三选。
enum QuitChoice { save, discard, cancel }

/// 退出保护决策逻辑：把「是否脏 + 用户三选」映射为是否允许退出，
/// 并处理「保存并退出」的落盘等待。
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

  /// 「保存后退出」等待落盘的超时上限；超时不阻塞退出。
  static const _saveWaitTimeout = Duration(seconds: 5);

  ExitGuard({
    required this.editBloc,
    required this.fileBloc,
    required this.askUser,
    required this.destroy,
  });

  /// 执行一次退出请求：不脏直接销毁窗口；脏则先询问三选。
  /// 返回 true 表示窗口已（或即将被调用方）销毁；false 表示用户取消，
  /// 窗口保持打开。
  Future<bool> confirmExit() async {
    if (!editBloc.state.dirty) {
      await destroy(); // 干净文档：直接退出，不打扰
      return true;
    }
    final choice = await askUser();
    switch (choice) {
      case QuitChoice.save:
        fileBloc.add(SaveRequested());
        await waitSaved();
        await destroy();
        return true;
      case QuitChoice.discard:
        await destroy();
        return true;
      case QuitChoice.cancel:
      case null:
        return false;
    }
  }

  /// 等待 SaveRequested 处理完毕（EditBloc 下一次 dirty == false）再返回，
  /// 保证 destroy 发生在写盘之后——FileBloc 未暴露事件完成 Future，
  /// 以流等待近似；saveImpl 抛错等异常场景由超时兜底，避免卡死退出流程。
  Future<void> waitSaved() async {
    try {
      await editBloc.stream
          .firstWhere((s) => !s.dirty)
          .timeout(_saveWaitTimeout);
    } on TimeoutException {
      // 保存超时：仍放行退出（放弃未落盘的修改），不无限等待。
    }
  }
}
