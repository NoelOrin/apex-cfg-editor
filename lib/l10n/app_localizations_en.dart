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
  String get kbSelectKeyHint =>
      'Select a setting to view its description and recommendation.';

  @override
  String get knowledgeBase => 'Knowledge base';

  @override
  String get diffPreview => 'Changes';

  @override
  String get noFileOpen => 'No file open';

  @override
  String get unsavedBadge => 'Unsaved';

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
  String get reselectFile => 'Reselect file';

  @override
  String get fileOpenFailed => 'Failed to open file';

  @override
  String get fileTypeUnsupported =>
      'Only settings.cfg and videoconfig.txt can be edited.';

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

  @override
  String get settings => 'Settings';

  @override
  String get back => 'Back';

  @override
  String get interfaceSection => 'Interface';

  @override
  String get language => 'Language';

  @override
  String get languageDescription =>
      'Choose the language used by the editor interface.';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get appInfoSection => 'Application';

  @override
  String get applicationVersion => 'Version';

  @override
  String get buildNumber => 'Build';

  @override
  String get repository => 'GitHub repository';

  @override
  String get license => 'License';

  @override
  String get configDirectory => 'Configuration directory';

  @override
  String get backupDirectory => 'Backup directory';

  @override
  String get logDirectory => 'Log directory';

  @override
  String get mitLicense => 'MIT License';

  @override
  String get notAvailable => 'Not available';

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get diagnosticsSection => 'Diagnostics';

  @override
  String get runDiagnostics => 'Run diagnostics';

  @override
  String get diagnosticsNotRun => 'Diagnostics have not been run yet.';

  @override
  String get configDirectoryExists => 'Configuration directory exists';

  @override
  String get configDirectoryWritable => 'Configuration directory is writable';

  @override
  String get encoding => 'Detected encoding';

  @override
  String get encodingUtf8 => 'UTF-8';

  @override
  String get encodingGbk => 'GBK';

  @override
  String get encodingUnknown => 'Unknown';

  @override
  String get latestBackup => 'Latest backup';

  @override
  String get noBackup => 'No backup found';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get fileBehaviorSection => 'File opening';

  @override
  String get autoDetectOnStartup => 'Detect Apex files on startup';

  @override
  String get preferredOpenKind => 'Preferred file';

  @override
  String get preferredSettings =>
      'settings.cfg (controls: binds, mouse/controller sensitivity)';

  @override
  String get preferredVideoconfig => 'videoconfig.txt (graphics)';

  @override
  String get filePurposeVideoconfig => 'Graphics';

  @override
  String get filePurposeSettings => 'Controls';

  @override
  String get filePurposeAutoexec => 'Startup commands';

  @override
  String get reopenLastFile => 'Reopen the last file';

  @override
  String get backupSection => 'Automatic backups';

  @override
  String get enableBackups => 'Create a backup before saving';

  @override
  String get backupLimit => 'Backups per file';

  @override
  String get backupDirectoryInput => 'Backup directory';

  @override
  String get chooseDirectory => 'Choose directory';

  @override
  String get openDirectory => 'Open directory';

  @override
  String get cleanOldBackups => 'Clean old backups';

  @override
  String cleanedBackups(Object count) {
    return 'Removed $count old backups';
  }

  @override
  String get resetSection => 'Reset';

  @override
  String get resetSettings => 'Restore default settings';

  @override
  String get resetSettingsTitle => 'Restore default settings?';

  @override
  String get resetSettingsBody =>
      'Only application settings will be removed. Configuration files and backups will not be deleted.';

  @override
  String get resetSettingsConfirm => 'Restore defaults';

  @override
  String get updateSection => 'Updates';

  @override
  String get currentVersion => 'Current version';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkingForUpdates => 'Checking for updates...';

  @override
  String get upToDate => 'You\'re up to date';

  @override
  String newVersionAvailable(Object version) {
    return 'New version available: $version';
  }

  @override
  String get viewReleaseNotes => 'View release notes';

  @override
  String get updateCheckFailed => 'Update check failed';

  @override
  String get updateCheckFailedHint =>
      'Check your network connection and try again.';
}
