import 'package:fluent_ui/fluent_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../state/edit_bloc.dart';
import '../state/file_bloc.dart';

/// Fluent 备份还原对话框。
Future<void> showRestoreDialog(
  BuildContext context, {
  required FileBloc fileBloc,
  required EditBloc editBloc,
  required void Function(String backupPath) onRestored,
}) {
  final l = AppLocalizations.of(context)!;
  final backups = fileBloc.state.backups;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: Text(l.restoreDialogTitle),
      content: backups.isEmpty
          ? Text(l.backupEmpty)
          : SizedBox(
              width: 500,
              height: 320,
              child: ListView.builder(
                itemCount: backups.length,
                itemBuilder: (context, i) {
                  final path = backups[i];
                  final name = _fileName(path);
                  final stamp = _formatStamp(name);
                  return ListTile(
                    leading: const Icon(LucideIcons.fileClock),
                    title: Text(name),
                    subtitle: stamp == null ? null : Text(stamp),
                    onPressed: () => _onBackupSelected(
                      dialogContext,
                      backupPath: path,
                      fileBloc: fileBloc,
                      dirty: editBloc.state.dirty,
                      l: l,
                      onRestored: onRestored,
                    ),
                  );
                },
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

void _onBackupSelected(
  BuildContext dialogContext, {
  required String backupPath,
  required FileBloc fileBloc,
  required bool dirty,
  required AppLocalizations l,
  required void Function(String backupPath) onRestored,
}) {
  if (dirty) {
    _confirmDirtyRestore(
      dialogContext,
      backupPath: backupPath,
      fileBloc: fileBloc,
      l: l,
      onRestored: onRestored,
    );
    return;
  }
  _dispatchRestore(dialogContext, backupPath, fileBloc, onRestored);
}

void _confirmDirtyRestore(
  BuildContext dialogContext, {
  required String backupPath,
  required FileBloc fileBloc,
  required AppLocalizations l,
  required void Function(String backupPath) onRestored,
}) {
  showDialog<void>(
    context: dialogContext,
    builder: (confirmContext) => ContentDialog(
      title: Text(l.restoreDirtyTitle),
      content: Text(l.restoreDirtyBody),
      actions: [
        Button(
          onPressed: () => Navigator.of(confirmContext).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(confirmContext).pop();
            _dispatchRestore(dialogContext, backupPath, fileBloc, onRestored);
          },
          child: Text(l.confirm),
        ),
      ],
    ),
  );
}

void _dispatchRestore(
  BuildContext dialogContext,
  String backupPath,
  FileBloc fileBloc,
  void Function(String backupPath) onRestored,
) {
  fileBloc.add(RestoreRequested(backupPath));
  Navigator.of(dialogContext).pop();
  onRestored(backupPath);
}

String _fileName(String path) => path.split('/').last.split('\\').last;

/// 时间戳文件名 `YYYYMMDD-HHMMSSmmm.cfg`（毫秒必有）；兼容旧的无毫秒形态。
final RegExp _stampPattern = RegExp(
  r'^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})(\d{3})?\.cfg$',
);

String? _formatStamp(String name) {
  final m = _stampPattern.firstMatch(name);
  if (m == null) return null;
  final ms = m.group(7);
  final base =
      '${m.group(1)}-${m.group(2)}-${m.group(3)} '
      '${m.group(4)}:${m.group(5)}:${m.group(6)}';
  return ms == null ? base : '$base.$ms';
}
