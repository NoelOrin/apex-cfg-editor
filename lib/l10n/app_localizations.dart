import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Apex CFG Editor'**
  String get appTitle;

  /// No description provided for @modeTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get modeTable;

  /// No description provided for @modeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get modeText;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @kbNotDocumented.
  ///
  /// In en, this message translates to:
  /// **'Key not documented yet. You can still edit it.'**
  String get kbNotDocumented;

  /// No description provided for @kbSelectKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Select a setting to view its description and recommendation.'**
  String get kbSelectKeyHint;

  /// No description provided for @knowledgeBase.
  ///
  /// In en, this message translates to:
  /// **'Knowledge base'**
  String get knowledgeBase;

  /// No description provided for @diffPreview.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get diffPreview;

  /// No description provided for @noFileOpen.
  ///
  /// In en, this message translates to:
  /// **'No file open'**
  String get noFileOpen;

  /// No description provided for @unsavedBadge.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get unsavedBadge;

  /// No description provided for @emptyDocHint.
  ///
  /// In en, this message translates to:
  /// **'Open a cfg file to start editing'**
  String get emptyDocHint;

  /// No description provided for @noChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get noChanges;

  /// No description provided for @kbRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended: {value}'**
  String kbRecommended(Object value);

  /// No description provided for @riskHigh.
  ///
  /// In en, this message translates to:
  /// **'High risk'**
  String get riskHigh;

  /// No description provided for @risk.
  ///
  /// In en, this message translates to:
  /// **'Risk'**
  String get risk;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get openFile;

  /// No description provided for @reselectFile.
  ///
  /// In en, this message translates to:
  /// **'Reselect file'**
  String get reselectFile;

  /// No description provided for @fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get fileOpenFailed;

  /// No description provided for @fileTypeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Only settings.cfg and videoconfig.txt can be edited.'**
  String get fileTypeUnsupported;

  /// No description provided for @filePickerFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open the file picker'**
  String get filePickerFailed;

  /// No description provided for @fileBadEncoding.
  ///
  /// In en, this message translates to:
  /// **'File contains bytes that cannot be decoded; saving may lose them'**
  String get fileBadEncoding;

  /// No description provided for @fileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save file'**
  String get fileSaveFailed;

  /// No description provided for @fileChangedOnDisk.
  ///
  /// In en, this message translates to:
  /// **'File was modified outside the editor. Reopen it before saving.'**
  String get fileChangedOnDisk;

  /// No description provided for @fileRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to restore from backup'**
  String get fileRestoreFailed;

  /// No description provided for @fileBadBytesDirty.
  ///
  /// In en, this message translates to:
  /// **'File contains bytes that cannot be mapped; saving now would re-encode the whole file and make the damage worse. Restore a backup or fix the file manually first.'**
  String get fileBadBytesDirty;

  /// No description provided for @restoreDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreDialogTitle;

  /// No description provided for @backupEmpty.
  ///
  /// In en, this message translates to:
  /// **'No backups yet. A backup is kept before every save.'**
  String get backupEmpty;

  /// No description provided for @restoreDirtyTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get restoreDirtyTitle;

  /// No description provided for @restoreDirtyBody.
  ///
  /// In en, this message translates to:
  /// **'Restoring a backup will lose your unsaved changes.'**
  String get restoreDirtyBody;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @quitDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get quitDialogTitle;

  /// No description provided for @quitDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Save changes before exiting?'**
  String get quitDialogBody;

  /// No description provided for @saveAndExit.
  ///
  /// In en, this message translates to:
  /// **'Save and exit'**
  String get saveAndExit;

  /// No description provided for @discardAndExit.
  ///
  /// In en, this message translates to:
  /// **'Discard and exit'**
  String get discardAndExit;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @find.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get find;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @replaceAll.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get replaceAll;

  /// No description provided for @findPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get findPrev;

  /// No description provided for @findNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get findNext;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @apexNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Apex not found'**
  String get apexNotFoundTitle;

  /// No description provided for @apexNotFoundHint.
  ///
  /// In en, this message translates to:
  /// **'No Apex config was detected. Open a file manually or specify the config directory (Saved Games\\Respawn\\Apex\\local).'**
  String get apexNotFoundHint;

  /// No description provided for @specifyApexDir.
  ///
  /// In en, this message translates to:
  /// **'Specify config directory'**
  String get specifyApexDir;

  /// No description provided for @chooseInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Multiple Apex installations detected'**
  String get chooseInstallTitle;

  /// No description provided for @installSourceSteam.
  ///
  /// In en, this message translates to:
  /// **'Steam'**
  String get installSourceSteam;

  /// No description provided for @installSourceEaApp.
  ///
  /// In en, this message translates to:
  /// **'EA App'**
  String get installSourceEaApp;

  /// No description provided for @installSourceCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom directory'**
  String get installSourceCustom;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @maximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximize;

  /// No description provided for @restoreWindow.
  ///
  /// In en, this message translates to:
  /// **'Restore window'**
  String get restoreWindow;

  /// No description provided for @toggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle theme'**
  String get toggleTheme;

  /// No description provided for @navEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get navEditor;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @interfaceSection.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get interfaceSection;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used by the editor interface.'**
  String get languageDescription;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @appInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get appInfoSection;

  /// No description provided for @applicationVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get applicationVersion;

  /// No description provided for @buildNumber.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get buildNumber;

  /// No description provided for @repository.
  ///
  /// In en, this message translates to:
  /// **'GitHub repository'**
  String get repository;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @configDirectory.
  ///
  /// In en, this message translates to:
  /// **'Configuration directory'**
  String get configDirectory;

  /// No description provided for @backupDirectory.
  ///
  /// In en, this message translates to:
  /// **'Backup directory'**
  String get backupDirectory;

  /// No description provided for @logDirectory.
  ///
  /// In en, this message translates to:
  /// **'Log directory'**
  String get logDirectory;

  /// No description provided for @mitLicense.
  ///
  /// In en, this message translates to:
  /// **'MIT License'**
  String get mitLicense;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openInBrowser;

  /// No description provided for @diagnosticsSection.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsSection;

  /// No description provided for @runDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Run diagnostics'**
  String get runDiagnostics;

  /// No description provided for @diagnosticsNotRun.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics have not been run yet.'**
  String get diagnosticsNotRun;

  /// No description provided for @configDirectoryExists.
  ///
  /// In en, this message translates to:
  /// **'Configuration directory exists'**
  String get configDirectoryExists;

  /// No description provided for @configDirectoryWritable.
  ///
  /// In en, this message translates to:
  /// **'Configuration directory is writable'**
  String get configDirectoryWritable;

  /// No description provided for @encoding.
  ///
  /// In en, this message translates to:
  /// **'Detected encoding'**
  String get encoding;

  /// No description provided for @encodingUtf8.
  ///
  /// In en, this message translates to:
  /// **'UTF-8'**
  String get encodingUtf8;

  /// No description provided for @encodingGbk.
  ///
  /// In en, this message translates to:
  /// **'GBK'**
  String get encodingGbk;

  /// No description provided for @encodingUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get encodingUnknown;

  /// No description provided for @latestBackup.
  ///
  /// In en, this message translates to:
  /// **'Latest backup'**
  String get latestBackup;

  /// No description provided for @noBackup.
  ///
  /// In en, this message translates to:
  /// **'No backup found'**
  String get noBackup;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @fileBehaviorSection.
  ///
  /// In en, this message translates to:
  /// **'File opening'**
  String get fileBehaviorSection;

  /// No description provided for @autoDetectOnStartup.
  ///
  /// In en, this message translates to:
  /// **'Detect Apex files on startup'**
  String get autoDetectOnStartup;

  /// No description provided for @preferredOpenKind.
  ///
  /// In en, this message translates to:
  /// **'Preferred file'**
  String get preferredOpenKind;

  /// No description provided for @preferredSettings.
  ///
  /// In en, this message translates to:
  /// **'settings.cfg (controls: binds, mouse/controller sensitivity)'**
  String get preferredSettings;

  /// No description provided for @preferredVideoconfig.
  ///
  /// In en, this message translates to:
  /// **'videoconfig.txt (graphics)'**
  String get preferredVideoconfig;

  /// No description provided for @filePurposeVideoconfig.
  ///
  /// In en, this message translates to:
  /// **'Graphics'**
  String get filePurposeVideoconfig;

  /// No description provided for @filePurposeSettings.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get filePurposeSettings;

  /// No description provided for @filePurposeAutoexec.
  ///
  /// In en, this message translates to:
  /// **'Startup commands'**
  String get filePurposeAutoexec;

  /// No description provided for @reopenLastFile.
  ///
  /// In en, this message translates to:
  /// **'Reopen the last file'**
  String get reopenLastFile;

  /// No description provided for @backupSection.
  ///
  /// In en, this message translates to:
  /// **'Automatic backups'**
  String get backupSection;

  /// No description provided for @enableBackups.
  ///
  /// In en, this message translates to:
  /// **'Create a backup before saving'**
  String get enableBackups;

  /// No description provided for @backupLimit.
  ///
  /// In en, this message translates to:
  /// **'Backups per file'**
  String get backupLimit;

  /// No description provided for @backupDirectoryInput.
  ///
  /// In en, this message translates to:
  /// **'Backup directory'**
  String get backupDirectoryInput;

  /// No description provided for @chooseDirectory.
  ///
  /// In en, this message translates to:
  /// **'Choose directory'**
  String get chooseDirectory;

  /// No description provided for @openDirectory.
  ///
  /// In en, this message translates to:
  /// **'Open directory'**
  String get openDirectory;

  /// No description provided for @cleanOldBackups.
  ///
  /// In en, this message translates to:
  /// **'Clean old backups'**
  String get cleanOldBackups;

  /// No description provided for @cleanedBackups.
  ///
  /// In en, this message translates to:
  /// **'Removed {count} old backups'**
  String cleanedBackups(Object count);

  /// No description provided for @resetSection.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetSection;

  /// No description provided for @resetSettings.
  ///
  /// In en, this message translates to:
  /// **'Restore default settings'**
  String get resetSettings;

  /// No description provided for @resetSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore default settings?'**
  String get resetSettingsTitle;

  /// No description provided for @resetSettingsBody.
  ///
  /// In en, this message translates to:
  /// **'Only application settings will be removed. Configuration files and backups will not be deleted.'**
  String get resetSettingsBody;

  /// No description provided for @resetSettingsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get resetSettingsConfirm;

  /// No description provided for @updateSection.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updateSection;

  /// No description provided for @currentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get currentVersion;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get checkingForUpdates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get upToDate;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'New version available: {version}'**
  String newVersionAvailable(Object version);

  /// No description provided for @viewReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'View release notes'**
  String get viewReleaseNotes;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get updateCheckFailed;

  /// No description provided for @updateCheckFailedHint.
  ///
  /// In en, this message translates to:
  /// **'Check your network connection and try again.'**
  String get updateCheckFailedHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
