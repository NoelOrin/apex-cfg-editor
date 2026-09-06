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

  @override
  String get emptyDocHint => 'Open a cfg file to start editing';

  @override
  String get noChanges => 'No changes';

  @override
  String kbRecommended(Object value) {
    return 'Recommended: $value';
  }

  @override
  String get riskHigh => 'High risk';

  @override
  String get risk => 'Risk';

  @override
  String get openFile => 'Open file';

  @override
  String get fileOpenFailed => 'Failed to open file';

  @override
  String get filePickerFailed => 'Failed to open the file picker';

  @override
  String get fileBadEncoding =>
      'File contains bytes that cannot be decoded; saving may lose them';

  @override
  String get fileSaveFailed => 'Failed to save file';

  @override
  String get fileRestoreFailed => 'Failed to restore from backup';

  @override
  String get fileBadBytesDirty =>
      'File contains bytes that cannot be mapped; saving now would re-encode the whole file and make the damage worse. Restore a backup or fix the file manually first.';

  @override
  String get restoreDialogTitle => 'Restore from backup';

  @override
  String get backupEmpty =>
      'No backups yet. A backup is kept before every save.';

  @override
  String get restoreDirtyTitle => 'Discard unsaved changes?';

  @override
  String get restoreDirtyBody =>
      'Restoring a backup will lose your unsaved changes.';

  @override
  String get confirm => 'Confirm';

  @override
  String get quitDialogTitle => 'Unsaved changes';

  @override
  String get quitDialogBody => 'Save changes before exiting?';

  @override
  String get saveAndExit => 'Save and exit';

  @override
  String get discardAndExit => 'Discard and exit';

  @override
  String get cancel => 'Cancel';

  @override
  String get find => 'Find';

  @override
  String get replace => 'Replace';

  @override
  String get replaceAll => 'Replace all';

  @override
  String get findPrev => 'Previous';

  @override
  String get findNext => 'Next';

  @override
  String get close => 'Close';

  @override
  String get createAutoexec => 'Create autoexec.cfg';

  @override
  String get autoexecMissingTitle =>
      'Apex install found, but autoexec.cfg is missing';

  @override
  String get autoexecMissingHint =>
      'Create a commented template to start configuring; it changes nothing until you edit it.';

  @override
  String get apexNotFoundTitle => 'Apex not found';

  @override
  String get apexNotFoundHint =>
      'No Apex installation was detected. Open a file manually or specify your Apex install directory.';

  @override
  String get specifyApexDir => 'Specify Apex directory';

  @override
  String get chooseInstallTitle => 'Multiple Apex installations detected';

  @override
  String get installSourceSteam => 'Steam';

  @override
  String get installSourceEaApp => 'EA App';

  @override
  String get installSourceCustom => 'Custom directory';

  @override
  String get minimize => 'Minimize';

  @override
  String get maximize => 'Maximize';

  @override
  String get restoreWindow => 'Restore window';

  @override
  String get toggleTheme => 'Toggle theme';
}
