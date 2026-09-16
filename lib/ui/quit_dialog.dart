import 'package:fluent_ui/fluent_ui.dart';

import '../l10n/app_localizations.dart';
import 'exit_guard.dart';

/// Fluent 退出保护三选对话框。
Future<QuitChoice?> showQuitDialog(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return showDialog<QuitChoice>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ContentDialog(
      title: Text(l.quitDialogTitle),
      content: Text(l.quitDialogBody),
      actions: [
        Button(
          onPressed: () => Navigator.of(dialogContext).pop(QuitChoice.cancel),
          child: Text(l.cancel),
        ),
        Button(
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
