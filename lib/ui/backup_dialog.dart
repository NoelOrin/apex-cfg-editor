import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state/edit_bloc.dart';
import '../state/file_bloc.dart';

/// 还原对话框：列出当前文件的历史备份（FileState.backups，新→旧），
/// 每项显示备份文件名（时间戳形如 20260101-000000.cfg）及格式化时间。
/// 有未保存修改（[EditBloc] dirty）时选择备份先弹确认——还原会覆盖当前
/// 编辑内容，确认后才派发 RestoreRequested；未 dirty 直接还原并关闭。
///
/// [onRestored] 在还原发起后以所选备份路径回调（还原因 FileBloc 未暴露
/// 完成 Future，由屏幕层等待重开到达后再刷新），供 EditorScreen 做
/// 文本模式强制回显。
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
                    onTap: () => _onBackupSelected(
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
        TextButton(
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

/// dirty 确认框：确认 = 关闭两层对话框并派发还原；取消 = 只关确认框，
/// 留在备份列表（可改选其他备份或放弃）。
void _confirmDirtyRestore(
  BuildContext dialogContext, {
  required String backupPath,
  required FileBloc fileBloc,
  required AppLocalizations l,
  required void Function(String backupPath) onRestored,
}) {
  showDialog<void>(
    context: dialogContext,
    builder: (confirmContext) => AlertDialog(
      title: Text(l.restoreDirtyTitle),
      content: Text(l.restoreDirtyBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(confirmContext).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
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
