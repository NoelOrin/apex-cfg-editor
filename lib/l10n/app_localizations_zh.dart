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
}
