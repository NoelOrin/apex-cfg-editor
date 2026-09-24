// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Apex CFG 编辑器';

  @override
  String get modeTable => '表格';

  @override
  String get modeText => '文本';

  @override
  String get save => '保存';

  @override
  String get restore => '还原';

  @override
  String get kbNotDocumented => '该键尚未收录说明，仍可编辑。';

  @override
  String get kbSelectKeyHint => '选择配置项可查看说明与推荐值。';

  @override
  String get knowledgeBase => '知识库';

  @override
  String get diffPreview => '变更对比';

  @override
  String get noFileOpen => '未打开文件';

  @override
  String get unsavedBadge => '未保存';

  @override
  String get emptyDocHint => '打开一个 cfg 文件开始编辑';

  @override
  String get noChanges => '无变更';

  @override
  String kbRecommended(Object value) {
    return '推荐：$value';
  }

  @override
  String get riskHigh => '高风险';

  @override
  String get risk => '风险';

  @override
  String get openFile => '打开文件';

  @override
  String get reselectFile => '重新选择文件';

  @override
  String get fileOpenFailed => '打开文件失败';

  @override
  String get fileTypeUnsupported => '仅支持编辑 settings.cfg 与 videoconfig.txt。';

  @override
  String get filePickerFailed => '打开文件选择器失败';

  @override
  String get fileBadEncoding => '文件包含无法解码的字节，保存可能丢失这些内容';

  @override
  String get fileSaveFailed => '保存文件失败';

  @override
  String get fileChangedOnDisk => '文件已在编辑器外被修改。请重新打开后再保存。';

  @override
  String get fileRestoreFailed => '还原备份失败';

  @override
  String get fileBadBytesDirty =>
      '文件包含无法映射的坏字节，现在保存会全文重编码、造成二次损坏；请先还原备份或手工处理文件。';

  @override
  String get restoreDialogTitle => '从备份还原';

  @override
  String get backupEmpty => '暂无备份。每次保存前都会自动备份。';

  @override
  String get restoreDirtyTitle => '丢弃未保存的修改？';

  @override
  String get restoreDirtyBody => '还原备份将丢失未保存的修改。';

  @override
  String get confirm => '确认';

  @override
  String get quitDialogTitle => '有未保存的修改';

  @override
  String get quitDialogBody => '退出前要保存修改吗？';

  @override
  String get saveAndExit => '保存并退出';

  @override
  String get discardAndExit => '放弃并退出';

  @override
  String get cancel => '取消';

  @override
  String get find => '查找';

  @override
  String get replace => '替换';

  @override
  String get replaceAll => '全部替换';

  @override
  String get findPrev => '上一个';

  @override
  String get findNext => '下一个';

  @override
  String get close => '关闭';

  @override
  String get apexNotFoundTitle => '未找到 Apex';

  @override
  String get apexNotFoundHint =>
      '未检测到 Apex 配置。可手动选择文件，或指定配置目录（Saved Games\\Respawn\\Apex\\local）。';

  @override
  String get specifyApexDir => '指定配置目录';

  @override
  String get chooseInstallTitle => '检测到多个 Apex 安装';

  @override
  String get installSourceSteam => 'Steam';

  @override
  String get installSourceEaApp => 'EA App';

  @override
  String get installSourceCustom => '自定义目录';

  @override
  String get minimize => '最小化';

  @override
  String get maximize => '最大化';

  @override
  String get restoreWindow => '还原窗口';

  @override
  String get toggleTheme => '切换主题';

  @override
  String get navEditor => '编辑器';

  @override
  String get settings => '设置';

  @override
  String get back => '返回';

  @override
  String get interfaceSection => '界面';

  @override
  String get language => '界面语言';

  @override
  String get languageDescription => '选择编辑器界面使用的语言。';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get appInfoSection => '应用信息';

  @override
  String get applicationVersion => '当前版本';

  @override
  String get buildNumber => '构建号';

  @override
  String get repository => 'GitHub 仓库';

  @override
  String get license => '许可证';

  @override
  String get configDirectory => '配置目录';

  @override
  String get backupDirectory => '备份目录';

  @override
  String get logDirectory => '日志目录';

  @override
  String get mitLicense => 'MIT 许可证';

  @override
  String get notAvailable => '不可用';

  @override
  String get openInBrowser => '在浏览器中打开';

  @override
  String get diagnosticsSection => '配置诊断';

  @override
  String get runDiagnostics => '运行诊断';

  @override
  String get diagnosticsNotRun => '尚未运行诊断。';

  @override
  String get configDirectoryExists => '配置目录存在';

  @override
  String get configDirectoryWritable => '配置目录可写';

  @override
  String get encoding => '探测到的编码';

  @override
  String get encodingUtf8 => 'UTF-8';

  @override
  String get encodingGbk => 'GBK';

  @override
  String get encodingUnknown => '未知';

  @override
  String get latestBackup => '最近备份';

  @override
  String get noBackup => '未找到备份';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get fileBehaviorSection => '文件打开行为';

  @override
  String get autoDetectOnStartup => '启动时自动探测 Apex 文件';

  @override
  String get preferredOpenKind => '优先打开文件';

  @override
  String get preferredSettings => 'settings.cfg（操作设置：按键绑定、鼠标/控制器灵敏度等）';

  @override
  String get preferredVideoconfig => 'videoconfig.txt（游戏画质）';

  @override
  String get filePurposeVideoconfig => '游戏画质';

  @override
  String get filePurposeSettings => '操作设置';

  @override
  String get filePurposeAutoexec => '启动命令';

  @override
  String get reopenLastFile => '重新打开上次文件';

  @override
  String get backupSection => '自动备份';

  @override
  String get enableBackups => '保存前创建备份';

  @override
  String get backupLimit => '每个文件的备份数量';

  @override
  String get backupDirectoryInput => '备份目录';

  @override
  String get chooseDirectory => '选择目录';

  @override
  String get openDirectory => '打开目录';

  @override
  String get cleanOldBackups => '清理旧备份';

  @override
  String cleanedBackups(Object count) {
    return '已清理 $count 个旧备份';
  }

  @override
  String get resetSection => '恢复';

  @override
  String get resetSettings => '恢复默认设置';

  @override
  String get resetSettingsTitle => '恢复默认设置？';

  @override
  String get resetSettingsBody => '只会删除应用设置，不会删除配置文件和备份。';

  @override
  String get resetSettingsConfirm => '恢复默认';

  @override
  String get updateSection => '更新';

  @override
  String get currentVersion => '当前版本';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get checkingForUpdates => '正在检查更新...';

  @override
  String get upToDate => '已是最新版本';

  @override
  String newVersionAvailable(Object version) {
    return '发现新版本 $version';
  }

  @override
  String get viewReleaseNotes => '查看发行说明';

  @override
  String get updateCheckFailed => '检查更新失败';

  @override
  String get updateCheckFailedHint => '请检查网络连接后重试。';
}
