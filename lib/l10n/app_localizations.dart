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

  /// No description provided for @fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get fileOpenFailed;

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
