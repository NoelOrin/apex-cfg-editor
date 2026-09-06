import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state/file_bloc.dart';

/// 还原对话框：列出当前文件的历史备份（FileState.backups，新→旧），
/// 每项显示备份文件名（时间戳形如 20260101-000000.cfg）及格式化时间；
/// 选择即派发 RestoreRequested 并关闭对话框。
///
/// [onRestored] 在还原发起后以所选备份路径回调（还原因 FileBloc 未暴露
/// 完成 Future，由屏幕层等待重开到达后再刷新），供 EditorScreen 做
/// 文本模式强制回显。
Future<void> showRestoreDialog(
  BuildContext context, {
  required FileBloc fileBloc,
  required void Function(String backupPath) onRestored,
}) {
  final l = AppLocalizations.of(context)!;
  final backups = fileBloc.state.backups;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.restoreDialogTitle),
      content: backups.isEmpty
          ? Text(l.backupEmpty)
          : SizedBox(
              width: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: backups.length,
                itemBuilder: (context, i) {
                  final path = backups[i];
                  final name = _fileName(path);
                  final stamp = _formatStamp(name);
                  return ListTile(
                    leading: const Icon(LucideIcons.fileClock),
                    title: Text(name),
                    subtitle: stamp == null ? null : Text(stamp),
                    onTap: () {
                      fileBloc.add(RestoreRequested(path));
                      Navigator.of(dialogContext).pop();
                      onRestored(path);
                    },
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l.cancel),
        ),
      ],
    ),
  );
}

String _fileName(String path) => path.split('/').last.split('\\').last;

/// 备份文件名 20260101-000000.cfg → 「2026-01-01 00:00:00」；
/// 非时间戳命名的备份只显示文件名。
final RegExp _stampPattern =
    RegExp(r'^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})\.cfg$');

String? _formatStamp(String name) {
  final m = _stampPattern.firstMatch(name);
  if (m == null) return null;
  return '${m.group(1)}-${m.group(2)}-${m.group(3)} '
      '${m.group(4)}:${m.group(5)}:${m.group(6)}';
}
