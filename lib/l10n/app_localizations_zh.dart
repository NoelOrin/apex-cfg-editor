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
  String get fileOpenFailed => '打开文件失败';

  @override
  String get filePickerFailed => '打开文件选择器失败';

  @override
  String get fileBadEncoding => '文件包含无法解码的字节，保存可能丢失这些内容';

  @override
  String get fileSaveFailed => '保存文件失败';

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
  String get createAutoexec => '创建 autoexec.cfg';

  @override
  String get autoexecMissingTitle => '已找到 Apex 安装目录，但缺少 autoexec.cfg';

  @override
  String get autoexecMissingHint => '可创建一个全注释的模板文件开始配置；在你编辑前不会改变任何游戏行为。';

  @override
  String get apexNotFoundTitle => '未找到 Apex';

  @override
  String get apexNotFoundHint => '未检测到 Apex 安装。可手动选择文件，或指定 Apex 安装目录。';

  @override
  String get specifyApexDir => '指定 Apex 目录';

  @override
  String get chooseInstallTitle => '检测到多个 Apex 安装';

  @override
  String get installSourceSteam => 'Steam';

  @override
  String get installSourceEaApp => 'EA App';

  @override
  String get installSourceCustom => '自定义目录';
}
