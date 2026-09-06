import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'exit_guard.dart';

/// 退出保护三选对话框（保存/放弃/取消）。返回 null 表示对话框被关闭。
Future<QuitChoice?> showQuitDialog(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return showDialog<QuitChoice>(
    context: context,
    barrierDismissible: false, // 明确三选，避免点空误退出
    builder: (dialogContext) => AlertDialog(
      title: Text(l.quitDialogTitle),
      content: Text(l.quitDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(QuitChoice.cancel),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(QuitChoice.discard),
          child: Text(l.discardAndExit),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(QuitChoice.save),
          child: Text(l.saveAndExit),
        ),
      ],
    ),
  );
}
