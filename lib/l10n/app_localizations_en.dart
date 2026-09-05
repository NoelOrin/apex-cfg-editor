// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Apex CFG Editor';

  @override
  String get modeTable => 'Table';

  @override
  String get modeText => 'Text';

  @override
  String get save => 'Save';

  @override
  String get restore => 'Restore';

  @override
  String get kbNotDocumented =>
      'Key not documented yet. You can still edit it.';
}
