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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get commonSearch;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get commonEmpty;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @validatorRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get validatorRequired;

  /// No description provided for @validatorEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get validatorEmail;

  /// No description provided for @validatorMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least {n} characters'**
  String validatorMinLength(int n);

  /// No description provided for @validatorMaxLength.
  ///
  /// In en, this message translates to:
  /// **'At most {n} characters'**
  String validatorMaxLength(int n);

  /// No description provided for @themeSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save theme'**
  String get themeSaveError;

  /// No description provided for @selectNoOptions.
  ///
  /// In en, this message translates to:
  /// **'No options'**
  String get selectNoOptions;

  /// No description provided for @dialogDefaultConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get dialogDefaultConfirm;

  /// No description provided for @dialogDefaultCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialogDefaultCancel;

  /// No description provided for @shortcutsHintTitle.
  ///
  /// In en, this message translates to:
  /// **'Available Shortcuts'**
  String get shortcutsHintTitle;

  /// No description provided for @crossTabSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search across all tabs...'**
  String get crossTabSearchPlaceholder;

  /// No description provided for @crossTabSearchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get crossTabSearchNoMatches;

  /// No description provided for @crossTabSearchMatchesFound.
  ///
  /// In en, this message translates to:
  /// **'{count} match(es) found'**
  String crossTabSearchMatchesFound(int count);

  /// No description provided for @idleLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get idleLockTitle;

  /// No description provided for @idleLockHint.
  ///
  /// In en, this message translates to:
  /// **'You have been idle. Enter your master password to continue.'**
  String get idleLockHint;

  /// No description provided for @pluginsTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get pluginsTitle;

  /// No description provided for @pluginsInstall.
  ///
  /// In en, this message translates to:
  /// **'Install from .zip'**
  String get pluginsInstall;

  /// No description provided for @pluginsDeveloperMode.
  ///
  /// In en, this message translates to:
  /// **'Developer Mode'**
  String get pluginsDeveloperMode;

  /// No description provided for @pluginsPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin Permission Request'**
  String get pluginsPermissionTitle;

  /// No description provided for @pluginsPermissionDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get pluginsPermissionDeny;

  /// No description provided for @pluginsPermissionGrantOnce.
  ///
  /// In en, this message translates to:
  /// **'Grant Once'**
  String get pluginsPermissionGrantOnce;

  /// No description provided for @pluginsPermissionGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get pluginsPermissionGrant;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Termex'**
  String get appName;

  /// No description provided for @appSlogan.
  ///
  /// In en, this message translates to:
  /// **'Open-source AI-powered local SSH client'**
  String get appSlogan;

  /// No description provided for @sidebarServers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get sidebarServers;

  /// No description provided for @sidebarSearch.
  ///
  /// In en, this message translates to:
  /// **'Search servers...'**
  String get sidebarSearch;

  /// No description provided for @sidebarNewConnection.
  ///
  /// In en, this message translates to:
  /// **'New Connection'**
  String get sidebarNewConnection;

  /// No description provided for @sidebarNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get sidebarNewGroup;

  /// No description provided for @sidebarGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get sidebarGroupNameHint;

  /// No description provided for @sidebarGroupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Group name is required'**
  String get sidebarGroupNameRequired;

  /// No description provided for @sidebarQuickConnect.
  ///
  /// In en, this message translates to:
  /// **'Quick Connect'**
  String get sidebarQuickConnect;

  /// No description provided for @sidebarImportConfig.
  ///
  /// In en, this message translates to:
  /// **'Import Config'**
  String get sidebarImportConfig;

  /// No description provided for @sidebarExportConfig.
  ///
  /// In en, this message translates to:
  /// **'Export Config'**
  String get sidebarExportConfig;

  /// Auto-imported from Tauri sidebar.bastionUsedBy
  ///
  /// In en, this message translates to:
  /// **'Used as bastion by {count} connection(s)'**
  String sidebarBastionUsedBy(String count);

  /// No description provided for @sidebarImportSshConfig.
  ///
  /// In en, this message translates to:
  /// **'Import SSH Config'**
  String get sidebarImportSshConfig;

  /// No description provided for @sidebarSnippets.
  ///
  /// In en, this message translates to:
  /// **'Snippets'**
  String get sidebarSnippets;

  /// No description provided for @sidebarRecordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get sidebarRecordings;

  /// No description provided for @sidebarCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get sidebarCloud;

  /// No description provided for @sidebarFilterall.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sidebarFilterall;

  /// No description provided for @sidebarFilterprivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get sidebarFilterprivate;

  /// No description provided for @sidebarFilterteam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get sidebarFilterteam;

  /// No description provided for @sidebarPrivateServers.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get sidebarPrivateServers;

  /// No description provided for @sidebarTeamServers.
  ///
  /// In en, this message translates to:
  /// **'Team Nodes'**
  String get sidebarTeamServers;

  /// No description provided for @sidebarTeamEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Team nodes are synced from your team — they can\'t be created directly.'**
  String get sidebarTeamEmptyHint;

  /// No description provided for @sidebarTeamEmptySync.
  ///
  /// In en, this message translates to:
  /// **'Share a private node first, then run a sync to push it to teammates.'**
  String get sidebarTeamEmptySync;

  /// No description provided for @sidebarGoToPrivate.
  ///
  /// In en, this message translates to:
  /// **'View Private Nodes'**
  String get sidebarGoToPrivate;

  /// No description provided for @terminalNewTab.
  ///
  /// In en, this message translates to:
  /// **'New Tab'**
  String get terminalNewTab;

  /// No description provided for @terminalCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get terminalCloseTab;

  /// No description provided for @terminalDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get terminalDisconnect;

  /// No description provided for @terminalReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get terminalReconnect;

  /// No description provided for @terminalReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get terminalReconnecting;

  /// No description provided for @terminalReconnected.
  ///
  /// In en, this message translates to:
  /// **'Reconnected'**
  String get terminalReconnected;

  /// No description provided for @terminalReconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Reconnect failed'**
  String get terminalReconnectFailed;

  /// Auto-imported from Tauri terminal.reconnectAttempt
  ///
  /// In en, this message translates to:
  /// **'Reconnecting... attempt {attempt}/{max}'**
  String terminalReconnectAttempt(String attempt, String max);

  /// Auto-imported from Tauri terminal.reconnectAttemptFailed
  ///
  /// In en, this message translates to:
  /// **'Attempt {attempt} failed'**
  String terminalReconnectAttemptFailed(String attempt);

  /// Auto-imported from Tauri terminal.reconnectGaveUp
  ///
  /// In en, this message translates to:
  /// **'Reconnect failed after {max} attempts'**
  String terminalReconnectGaveUp(String max);

  /// No description provided for @terminalOpenLocalTerminal.
  ///
  /// In en, this message translates to:
  /// **'Open Local Terminal'**
  String get terminalOpenLocalTerminal;

  /// No description provided for @terminalOpenLocalTerminalError.
  ///
  /// In en, this message translates to:
  /// **'Failed to open terminal'**
  String get terminalOpenLocalTerminalError;

  /// No description provided for @terminalSplitVertical.
  ///
  /// In en, this message translates to:
  /// **'Split Right'**
  String get terminalSplitVertical;

  /// No description provided for @terminalSplitHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Split Down'**
  String get terminalSplitHorizontal;

  /// No description provided for @terminalClosePane.
  ///
  /// In en, this message translates to:
  /// **'Close Pane'**
  String get terminalClosePane;

  /// No description provided for @terminalMaxSplitDepth.
  ///
  /// In en, this message translates to:
  /// **'Maximum split depth reached'**
  String get terminalMaxSplitDepth;

  /// No description provided for @terminalBroadcastOn.
  ///
  /// In en, this message translates to:
  /// **'Broadcast ON'**
  String get terminalBroadcastOn;

  /// No description provided for @terminalBroadcastOff.
  ///
  /// In en, this message translates to:
  /// **'Broadcast'**
  String get terminalBroadcastOff;

  /// No description provided for @terminalBroadcastHintOn.
  ///
  /// In en, this message translates to:
  /// **'Input sent to all panes'**
  String get terminalBroadcastHintOn;

  /// No description provided for @terminalBroadcastToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle pane broadcast'**
  String get terminalBroadcastToggle;

  /// No description provided for @terminalBroadcastHintOff.
  ///
  /// In en, this message translates to:
  /// **'Enable broadcast mode'**
  String get terminalBroadcastHintOff;

  /// Auto-imported from Tauri terminal.paneCount
  ///
  /// In en, this message translates to:
  /// **'{count} panes'**
  String terminalPaneCount(String count);

  /// Auto-imported from Tauri terminal.mouseReportingHint
  ///
  /// In en, this message translates to:
  /// **'Mouse captured by remote app. Hold {key}+drag to select and copy text locally.'**
  String terminalMouseReportingHint(String key);

  /// Auto-imported from Tauri terminal.mouseReportingActive
  ///
  /// In en, this message translates to:
  /// **'Mouse captured · {key}+drag to select'**
  String terminalMouseReportingActive(String key);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get settingsTerminal;

  /// No description provided for @settingsKeybindings.
  ///
  /// In en, this message translates to:
  /// **'Keybindings'**
  String get settingsKeybindings;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsAiConfig.
  ///
  /// In en, this message translates to:
  /// **'AI Config'**
  String get settingsAiConfig;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackup;

  /// No description provided for @settingsHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get settingsHighlights;

  /// No description provided for @settingsProxies.
  ///
  /// In en, this message translates to:
  /// **'Proxies'**
  String get settingsProxies;

  /// No description provided for @settingsMonitor.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get settingsMonitor;

  /// No description provided for @settingsTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get settingsTeam;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @fontsFontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font Family'**
  String get fontsFontFamily;

  /// No description provided for @fontsFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontsFontSize;

  /// No description provided for @fontsUploadFont.
  ///
  /// In en, this message translates to:
  /// **'Upload Font'**
  String get fontsUploadFont;

  /// No description provided for @fontsBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in Fonts'**
  String get fontsBuiltIn;

  /// No description provided for @fontsCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Fonts'**
  String get fontsCustom;

  /// Auto-imported from Tauri fonts.deleteConfirm
  ///
  /// In en, this message translates to:
  /// **'Delete font \"{name}\"?'**
  String fontsDeleteConfirm(String name);

  /// No description provided for @fontsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Font'**
  String get fontsDeleteTitle;

  /// No description provided for @fontsUploaded.
  ///
  /// In en, this message translates to:
  /// **'Font uploaded successfully'**
  String get fontsUploaded;

  /// No description provided for @fontsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Font deleted'**
  String get fontsDeleted;

  /// No description provided for @fontsInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported format. Use .ttf, .otf, .woff, or .woff2'**
  String get fontsInvalidFormat;

  /// No description provided for @fontsUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload font'**
  String get fontsUploadFailed;

  /// No description provided for @tabClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get tabClose;

  /// No description provided for @tabCloseOthers.
  ///
  /// In en, this message translates to:
  /// **'Close Others'**
  String get tabCloseOthers;

  /// No description provided for @tabDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get tabDuplicate;

  /// No description provided for @tabSplitVertical.
  ///
  /// In en, this message translates to:
  /// **'Split Left/Right'**
  String get tabSplitVertical;

  /// No description provided for @tabSplitHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Split Top/Bottom'**
  String get tabSplitHorizontal;

  /// No description provided for @tabRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get tabRename;

  /// No description provided for @tabRenameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter new name'**
  String get tabRenameHint;

  /// No description provided for @tabReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get tabReconnect;

  /// No description provided for @tabReconnectAll.
  ///
  /// In en, this message translates to:
  /// **'Reconnect All'**
  String get tabReconnectAll;

  /// No description provided for @appearanceTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appearanceTheme;

  /// No description provided for @appearanceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get appearanceLanguage;

  /// No description provided for @appearanceFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get appearanceFollowSystem;

  /// No description provided for @appearanceSidebarTransition.
  ///
  /// In en, this message translates to:
  /// **'Sidebar Transition'**
  String get appearanceSidebarTransition;

  /// No description provided for @appearanceTransFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip (3D Door)'**
  String get appearanceTransFlip;

  /// No description provided for @appearanceTransSlide.
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get appearanceTransSlide;

  /// No description provided for @appearanceTransFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get appearanceTransFade;

  /// No description provided for @appearanceTransScale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get appearanceTransScale;

  /// No description provided for @appearanceTransSlideUp.
  ///
  /// In en, this message translates to:
  /// **'Slide Up'**
  String get appearanceTransSlideUp;

  /// No description provided for @appearanceTransNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get appearanceTransNone;

  /// No description provided for @sftpTitle.
  ///
  /// In en, this message translates to:
  /// **'SFTP'**
  String get sftpTitle;

  /// No description provided for @sftpName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sftpName;

  /// No description provided for @sftpSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sftpSize;

  /// No description provided for @sftpPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get sftpPermissions;

  /// No description provided for @sftpModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get sftpModified;

  /// No description provided for @sftpGoUp.
  ///
  /// In en, this message translates to:
  /// **'Go Up'**
  String get sftpGoUp;

  /// No description provided for @sftpRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get sftpRefresh;

  /// No description provided for @sftpNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get sftpNewFolder;

  /// No description provided for @sftpNewFolderPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter folder name'**
  String get sftpNewFolderPrompt;

  /// No description provided for @sftpClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get sftpClose;

  /// No description provided for @sftpDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sftpDelete;

  /// Auto-imported from Tauri sftp.deleteConfirm
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String sftpDeleteConfirm(String name);

  /// No description provided for @sftpDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get sftpDeleted;

  /// No description provided for @sftpRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get sftpRename;

  /// No description provided for @sftpRenamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter new name'**
  String get sftpRenamePrompt;

  /// No description provided for @sftpDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get sftpDownload;

  /// No description provided for @sftpDownloadPrompt.
  ///
  /// In en, this message translates to:
  /// **'Save to local path'**
  String get sftpDownloadPrompt;

  /// No description provided for @sftpDownloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get sftpDownloadStarted;

  /// No description provided for @sftpUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get sftpUpload;

  /// No description provided for @sftpUploadStarted.
  ///
  /// In en, this message translates to:
  /// **'Upload started'**
  String get sftpUploadStarted;

  /// No description provided for @sftpUploadError.
  ///
  /// In en, this message translates to:
  /// **'Upload error'**
  String get sftpUploadError;

  /// No description provided for @sftpTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get sftpTransfers;

  /// No description provided for @sftpFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get sftpFiles;

  /// No description provided for @sftpCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get sftpCompleted;

  /// No description provided for @sftpConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get sftpConnecting;

  /// No description provided for @sftpClearCompleted.
  ///
  /// In en, this message translates to:
  /// **'Clear completed'**
  String get sftpClearCompleted;

  /// No description provided for @sftpNoTransfers.
  ///
  /// In en, this message translates to:
  /// **'No transfers'**
  String get sftpNoTransfers;

  /// No description provided for @sftpConfirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get sftpConfirm;

  /// No description provided for @sftpCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sftpCancel;

  /// No description provided for @sftpEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty directory'**
  String get sftpEmpty;

  /// No description provided for @sftpLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get sftpLocal;

  /// No description provided for @sftpRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get sftpRemote;

  /// No description provided for @sftpOpenSftp.
  ///
  /// In en, this message translates to:
  /// **'Open SFTP'**
  String get sftpOpenSftp;

  /// No description provided for @sftpDropToUpload.
  ///
  /// In en, this message translates to:
  /// **'Drop files to upload'**
  String get sftpDropToUpload;

  /// No description provided for @sftpDropToDownload.
  ///
  /// In en, this message translates to:
  /// **'Drop to download here'**
  String get sftpDropToDownload;

  /// No description provided for @sftpCwdSyncOn.
  ///
  /// In en, this message translates to:
  /// **'Sync ON — following terminal CWD'**
  String get sftpCwdSyncOn;

  /// No description provided for @sftpCwdSyncOff.
  ///
  /// In en, this message translates to:
  /// **'Sync SFTP path with terminal CWD'**
  String get sftpCwdSyncOff;

  /// No description provided for @sftpCloseSplit.
  ///
  /// In en, this message translates to:
  /// **'Close split panel'**
  String get sftpCloseSplit;

  /// No description provided for @sftpNotConnected.
  ///
  /// In en, this message translates to:
  /// **'SFTP not connected'**
  String get sftpNotConnected;

  /// No description provided for @sftpDownloadError.
  ///
  /// In en, this message translates to:
  /// **'Download error'**
  String get sftpDownloadError;

  /// No description provided for @sftpCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared completed transfers'**
  String get sftpCleared;

  /// No description provided for @sftpCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get sftpCopy;

  /// No description provided for @sftpCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get sftpCut;

  /// No description provided for @sftpPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get sftpPaste;

  /// No description provided for @sftpMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get sftpMore;

  /// No description provided for @sftpCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy Path'**
  String get sftpCopyPath;

  /// No description provided for @sftpEditPath.
  ///
  /// In en, this message translates to:
  /// **'Edit Path'**
  String get sftpEditPath;

  /// No description provided for @sftpNewFile.
  ///
  /// In en, this message translates to:
  /// **'New File'**
  String get sftpNewFile;

  /// No description provided for @sftpMkdir.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get sftpMkdir;

  /// No description provided for @sftpSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get sftpSelectAll;

  /// No description provided for @sftpChmod.
  ///
  /// In en, this message translates to:
  /// **'Edit Permissions'**
  String get sftpChmod;

  /// No description provided for @sftpFileInfo.
  ///
  /// In en, this message translates to:
  /// **'File Info'**
  String get sftpFileInfo;

  /// No description provided for @sftpEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get sftpEdit;

  /// No description provided for @sftpType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sftpType;

  /// No description provided for @sftpDirectory.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get sftpDirectory;

  /// No description provided for @sftpFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get sftpFile;

  /// No description provided for @sftpUid.
  ///
  /// In en, this message translates to:
  /// **'UID'**
  String get sftpUid;

  /// No description provided for @sftpGid.
  ///
  /// In en, this message translates to:
  /// **'GID'**
  String get sftpGid;

  /// No description provided for @sftpSymlink.
  ///
  /// In en, this message translates to:
  /// **'Symbolic Link'**
  String get sftpSymlink;

  /// No description provided for @sftpYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get sftpYes;

  /// No description provided for @sftpNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get sftpNo;

  /// No description provided for @sftpChmodFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get sftpChmodFile;

  /// No description provided for @sftpChmodOctal.
  ///
  /// In en, this message translates to:
  /// **'Octal Permissions (e.g., 755)'**
  String get sftpChmodOctal;

  /// No description provided for @sftpChmodExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. 755'**
  String get sftpChmodExample;

  /// No description provided for @sftpChmodHelp.
  ///
  /// In en, this message translates to:
  /// **'Octal notation: read=4, write=2, execute=1. Example: 755 = rwxr-xr-x'**
  String get sftpChmodHelp;

  /// No description provided for @sftpChmodRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter permissions'**
  String get sftpChmodRequired;

  /// No description provided for @sftpChmodInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid octal value (0-7777)'**
  String get sftpChmodInvalid;

  /// No description provided for @sftpPermissionsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Permissions updated'**
  String get sftpPermissionsUpdated;

  /// No description provided for @sftpCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get sftpCopied;

  /// No description provided for @sftpPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied to clipboard'**
  String get sftpPathCopied;

  /// No description provided for @sftpFileCreated.
  ///
  /// In en, this message translates to:
  /// **'File created'**
  String get sftpFileCreated;

  /// No description provided for @sftpFolderCreated.
  ///
  /// In en, this message translates to:
  /// **'Folder created'**
  String get sftpFolderCreated;

  /// No description provided for @sftpNewFilePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter file name'**
  String get sftpNewFilePrompt;

  /// No description provided for @sftpSelectAllTodo.
  ///
  /// In en, this message translates to:
  /// **'Multi-select coming soon'**
  String get sftpSelectAllTodo;

  /// No description provided for @sftpEditTodo.
  ///
  /// In en, this message translates to:
  /// **'File editing coming soon'**
  String get sftpEditTodo;

  /// No description provided for @sftpPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get sftpPreparing;

  /// No description provided for @sftpRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get sftpRemove;

  /// No description provided for @sftpError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get sftpError;

  /// No description provided for @sftpServerTransfer.
  ///
  /// In en, this message translates to:
  /// **'Server transfer started'**
  String get sftpServerTransfer;

  /// Auto-imported from Tauri sftp.transferError
  ///
  /// In en, this message translates to:
  /// **'Transfer failed: {error}'**
  String sftpTransferError(String error);

  /// No description provided for @sftpServerDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Server disconnected'**
  String get sftpServerDisconnected;

  /// No description provided for @sftpDirTransferTodo.
  ///
  /// In en, this message translates to:
  /// **'Directory transfer coming soon'**
  String get sftpDirTransferTodo;

  /// No description provided for @aiPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiPanelTitle;

  /// No description provided for @aiInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Describe what you want to do...'**
  String get aiInputPlaceholder;

  /// No description provided for @aiSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get aiSend;

  /// No description provided for @aiCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get aiCopy;

  /// No description provided for @aiInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert to Terminal'**
  String get aiInsert;

  /// No description provided for @aiCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get aiCopied;

  /// No description provided for @aiEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Describe in natural language, AI will generate the command'**
  String get aiEmptyHint;

  /// No description provided for @aiExplain.
  ///
  /// In en, this message translates to:
  /// **'Explain Command'**
  String get aiExplain;

  /// No description provided for @aiDanger.
  ///
  /// In en, this message translates to:
  /// **'Dangerous Command'**
  String get aiDanger;

  /// Auto-imported from Tauri ai.dangerWarning
  ///
  /// In en, this message translates to:
  /// **'⚠️ This command may be risky: {desc}'**
  String aiDangerWarning(String desc);

  /// Auto-imported from Tauri ai.dangerCritical
  ///
  /// In en, this message translates to:
  /// **'🚫 Critical danger: {desc}'**
  String aiDangerCritical(String desc);

  /// No description provided for @aiConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get aiConfirm;

  /// No description provided for @aiCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get aiCancel;

  /// No description provided for @aiClear.
  ///
  /// In en, this message translates to:
  /// **'Clear Chat'**
  String get aiClear;

  /// No description provided for @aiNoProviderHint.
  ///
  /// In en, this message translates to:
  /// **'No AI provider configured yet. Please set up one first.'**
  String get aiNoProviderHint;

  /// No description provided for @aiNoProviderShort.
  ///
  /// In en, this message translates to:
  /// **'Configure AI first'**
  String get aiNoProviderShort;

  /// No description provided for @aiGoConfig.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get aiGoConfig;

  /// No description provided for @aiSaveAsSnippet.
  ///
  /// In en, this message translates to:
  /// **'Save as Snippet'**
  String get aiSaveAsSnippet;

  /// No description provided for @aiIncludeContext.
  ///
  /// In en, this message translates to:
  /// **'Include terminal context'**
  String get aiIncludeContext;

  /// No description provided for @aiThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get aiThinking;

  /// No description provided for @aiErrorDetected.
  ///
  /// In en, this message translates to:
  /// **'Error Detected'**
  String get aiErrorDetected;

  /// No description provided for @aiAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing error...'**
  String get aiAnalyzing;

  /// No description provided for @aiDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get aiDismiss;

  /// No description provided for @aiCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get aiCommand;

  /// No description provided for @aiRunFix.
  ///
  /// In en, this message translates to:
  /// **'Run fix'**
  String get aiRunFix;

  /// No description provided for @aiRunAll.
  ///
  /// In en, this message translates to:
  /// **'Run All'**
  String get aiRunAll;

  /// No description provided for @aiRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get aiRun;

  /// No description provided for @aiConfirmRun.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Run'**
  String get aiConfirmRun;

  /// No description provided for @aiPlaybook.
  ///
  /// In en, this message translates to:
  /// **'Playbook'**
  String get aiPlaybook;

  /// No description provided for @aiPlaybookGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating steps...'**
  String get aiPlaybookGenerating;

  /// Auto-imported from Tauri ai.playbookReady
  ///
  /// In en, this message translates to:
  /// **'Ready ({count} steps)'**
  String aiPlaybookReady(String count);

  /// No description provided for @aiStepSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get aiStepSuccess;

  /// No description provided for @aiStepFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get aiStepFailed;

  /// No description provided for @aiSummarize.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get aiSummarize;

  /// No description provided for @aiSummarizing.
  ///
  /// In en, this message translates to:
  /// **'Generating summary...'**
  String get aiSummarizing;

  /// No description provided for @aiExportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export as Markdown'**
  String get aiExportMarkdown;

  /// No description provided for @aiDiagnosisTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Diagnosis'**
  String get aiDiagnosisTitle;

  /// No description provided for @aiAlertCpuThreshold.
  ///
  /// In en, this message translates to:
  /// **'CPU alert threshold (%)'**
  String get aiAlertCpuThreshold;

  /// No description provided for @aiAlertMemoryThreshold.
  ///
  /// In en, this message translates to:
  /// **'Memory alert threshold (%)'**
  String get aiAlertMemoryThreshold;

  /// No description provided for @aiAlertDiskThreshold.
  ///
  /// In en, this message translates to:
  /// **'Disk alert threshold (%)'**
  String get aiAlertDiskThreshold;

  /// No description provided for @aiAutoDiagnose.
  ///
  /// In en, this message translates to:
  /// **'Auto-diagnose errors'**
  String get aiAutoDiagnose;

  /// No description provided for @aiAutoDiagnoseHint.
  ///
  /// In en, this message translates to:
  /// **'AI automatically analyzes command errors'**
  String get aiAutoDiagnoseHint;

  /// No description provided for @portForwardTitle.
  ///
  /// In en, this message translates to:
  /// **'Port Forwarding'**
  String get portForwardTitle;

  /// No description provided for @portForwardLocal.
  ///
  /// In en, this message translates to:
  /// **'Local Forward'**
  String get portForwardLocal;

  /// No description provided for @portForwardRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote Forward'**
  String get portForwardRemote;

  /// No description provided for @portForwardDynamic.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Forward'**
  String get portForwardDynamic;

  /// No description provided for @portForwardLocalHost.
  ///
  /// In en, this message translates to:
  /// **'Local Host'**
  String get portForwardLocalHost;

  /// No description provided for @portForwardLocalPort.
  ///
  /// In en, this message translates to:
  /// **'Local Port'**
  String get portForwardLocalPort;

  /// No description provided for @portForwardRemoteHost.
  ///
  /// In en, this message translates to:
  /// **'Remote Host'**
  String get portForwardRemoteHost;

  /// No description provided for @portForwardRemotePort.
  ///
  /// In en, this message translates to:
  /// **'Remote Port'**
  String get portForwardRemotePort;

  /// No description provided for @portForwardAutoStart.
  ///
  /// In en, this message translates to:
  /// **'Auto Start'**
  String get portForwardAutoStart;

  /// No description provided for @portForwardStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get portForwardStart;

  /// No description provided for @portForwardStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get portForwardStop;

  /// No description provided for @portForwardAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Rule'**
  String get portForwardAdd;

  /// No description provided for @portForwardDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get portForwardDelete;

  /// No description provided for @portForwardRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get portForwardRunning;

  /// No description provided for @portForwardStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get portForwardStopped;

  /// No description provided for @configExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Config'**
  String get configExportTitle;

  /// No description provided for @configImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Config'**
  String get configImportTitle;

  /// No description provided for @configPassword.
  ///
  /// In en, this message translates to:
  /// **'Export Password'**
  String get configPassword;

  /// No description provided for @configPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Set a separate export password'**
  String get configPasswordHint;

  /// No description provided for @configFilePath.
  ///
  /// In en, this message translates to:
  /// **'File Path'**
  String get configFilePath;

  /// No description provided for @configOnConflict.
  ///
  /// In en, this message translates to:
  /// **'On Conflict'**
  String get configOnConflict;

  /// No description provided for @configSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip Existing'**
  String get configSkip;

  /// No description provided for @configOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get configOverwrite;

  /// No description provided for @configExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Export successful'**
  String get configExportSuccess;

  /// Auto-imported from Tauri config.importSuccess
  ///
  /// In en, this message translates to:
  /// **'Import complete: {imported} imported, {skipped} skipped'**
  String configImportSuccess(String imported, String skipped);

  /// No description provided for @connectionEditConnection.
  ///
  /// In en, this message translates to:
  /// **'Edit Connection'**
  String get connectionEditConnection;

  /// No description provided for @connectionName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get connectionName;

  /// No description provided for @connectionHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get connectionHost;

  /// No description provided for @connectionPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get connectionPort;

  /// No description provided for @connectionUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get connectionUsername;

  /// No description provided for @connectionPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get connectionPassword;

  /// No description provided for @connectionAuthType.
  ///
  /// In en, this message translates to:
  /// **'Auth Type'**
  String get connectionAuthType;

  /// No description provided for @connectionPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Private Key'**
  String get connectionPrivateKey;

  /// No description provided for @connectionBrowseKey.
  ///
  /// In en, this message translates to:
  /// **'Browse File'**
  String get connectionBrowseKey;

  /// No description provided for @connectionSshAgent.
  ///
  /// In en, this message translates to:
  /// **'SSH Agent'**
  String get connectionSshAgent;

  /// No description provided for @connectionSshAgentInfo.
  ///
  /// In en, this message translates to:
  /// **'Use system SSH Agent (\$SSH_AUTH_SOCK) for authentication. No private key credentials stored in Termex.'**
  String get connectionSshAgentInfo;

  /// No description provided for @connectionGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get connectionGroup;

  /// No description provided for @connectionAuthorizationInfo.
  ///
  /// In en, this message translates to:
  /// **'Authorization'**
  String get connectionAuthorizationInfo;

  /// No description provided for @connectionSshTunnel.
  ///
  /// In en, this message translates to:
  /// **'SSH Tunnel'**
  String get connectionSshTunnel;

  /// No description provided for @connectionBastion.
  ///
  /// In en, this message translates to:
  /// **'Bastion / Jump Host'**
  String get connectionBastion;

  /// No description provided for @connectionBastionHint.
  ///
  /// In en, this message translates to:
  /// **'Bastion servers are managed in the sidebar server list. Any saved server can be used as a bastion.'**
  String get connectionBastionHint;

  /// No description provided for @connectionSelectBastion.
  ///
  /// In en, this message translates to:
  /// **'Search or select bastion server...'**
  String get connectionSelectBastion;

  /// No description provided for @connectionConnectionPath.
  ///
  /// In en, this message translates to:
  /// **'Connection Path'**
  String get connectionConnectionPath;

  /// No description provided for @connectionNoProxyConfigured.
  ///
  /// In en, this message translates to:
  /// **'No bastion configured. Will connect directly to target server.'**
  String get connectionNoProxyConfigured;

  /// No description provided for @connectionRemoveTunnel.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get connectionRemoveTunnel;

  /// No description provided for @connectionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get connectionSave;

  /// No description provided for @connectionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get connectionCancel;

  /// No description provided for @connectionConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectionConnect;

  /// No description provided for @connectionTest.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get connectionTest;

  /// No description provided for @connectionTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection test successful'**
  String get connectionTestSuccess;

  /// No description provided for @connectionProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get connectionProxy;

  /// No description provided for @connectionNetworkProxy.
  ///
  /// In en, this message translates to:
  /// **'Network Proxy'**
  String get connectionNetworkProxy;

  /// No description provided for @connectionNetworkProxyHint.
  ///
  /// In en, this message translates to:
  /// **'Proxies are managed in the sidebar Proxy panel. Switch to the Proxy tab in the sidebar to add or edit proxies.'**
  String get connectionNetworkProxyHint;

  /// No description provided for @connectionProxyNone.
  ///
  /// In en, this message translates to:
  /// **'None (Direct)'**
  String get connectionProxyNone;

  /// No description provided for @connectionProxyName.
  ///
  /// In en, this message translates to:
  /// **'Proxy Name'**
  String get connectionProxyName;

  /// No description provided for @connectionProxyType.
  ///
  /// In en, this message translates to:
  /// **'Proxy Type'**
  String get connectionProxyType;

  /// No description provided for @connectionProxySocks5.
  ///
  /// In en, this message translates to:
  /// **'SOCKS5'**
  String get connectionProxySocks5;

  /// No description provided for @connectionProxySocks4.
  ///
  /// In en, this message translates to:
  /// **'SOCKS4'**
  String get connectionProxySocks4;

  /// No description provided for @connectionProxyHttp.
  ///
  /// In en, this message translates to:
  /// **'HTTP CONNECT'**
  String get connectionProxyHttp;

  /// No description provided for @connectionProxyHost.
  ///
  /// In en, this message translates to:
  /// **'Proxy Host'**
  String get connectionProxyHost;

  /// No description provided for @connectionProxyPort.
  ///
  /// In en, this message translates to:
  /// **'Proxy Port'**
  String get connectionProxyPort;

  /// No description provided for @connectionProxyUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get connectionProxyUsername;

  /// No description provided for @connectionProxyPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get connectionProxyPassword;

  /// No description provided for @connectionProxyAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Proxy'**
  String get connectionProxyAdd;

  /// No description provided for @connectionProxyEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Proxy'**
  String get connectionProxyEdit;

  /// No description provided for @connectionProxyDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Proxy'**
  String get connectionProxyDelete;

  /// Auto-imported from Tauri connection.proxyDeleteConfirm
  ///
  /// In en, this message translates to:
  /// **'Delete proxy \"{name}\"? Servers using it will switch to direct connection.'**
  String connectionProxyDeleteConfirm(String name);

  /// Auto-imported from Tauri connection.proxyUsedBy
  ///
  /// In en, this message translates to:
  /// **'Used by {count} server(s)'**
  String connectionProxyUsedBy(String count);

  /// No description provided for @connectionProxyNoConfig.
  ///
  /// In en, this message translates to:
  /// **'No proxy configured yet.'**
  String get connectionProxyNoConfig;

  /// No description provided for @connectionProxyGoSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings → Proxies to add one.'**
  String get connectionProxyGoSettings;

  /// No description provided for @connectionProxyTestReachable.
  ///
  /// In en, this message translates to:
  /// **'Proxy is reachable'**
  String get connectionProxyTestReachable;

  /// No description provided for @connectionProxyTor.
  ///
  /// In en, this message translates to:
  /// **'Tor'**
  String get connectionProxyTor;

  /// Auto-imported from Tauri connection.proxyTorRunning
  ///
  /// In en, this message translates to:
  /// **'Tor service detected on port {port}'**
  String connectionProxyTorRunning(String port);

  /// No description provided for @connectionProxyTorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Tor service not detected (install and start Tor first)'**
  String get connectionProxyTorNotFound;

  /// No description provided for @connectionProxyTlsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable TLS (HTTPS)'**
  String get connectionProxyTlsEnable;

  /// No description provided for @connectionProxyTlsVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify Certificate'**
  String get connectionProxyTlsVerify;

  /// No description provided for @connectionProxyCaCert.
  ///
  /// In en, this message translates to:
  /// **'CA Certificate path (.pem)'**
  String get connectionProxyCaCert;

  /// No description provided for @connectionProxyClientCert.
  ///
  /// In en, this message translates to:
  /// **'Client Certificate path (.pem/.crt)'**
  String get connectionProxyClientCert;

  /// No description provided for @connectionProxyClientKey.
  ///
  /// In en, this message translates to:
  /// **'Client Key path (.pem/.key)'**
  String get connectionProxyClientKey;

  /// No description provided for @connectionProxyCommand.
  ///
  /// In en, this message translates to:
  /// **'ProxyCommand'**
  String get connectionProxyCommand;

  /// No description provided for @connectionProxyCommandPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. cloudflared access ssh --hostname %h'**
  String get connectionProxyCommandPlaceholder;

  /// No description provided for @connectionProxyCommandHint.
  ///
  /// In en, this message translates to:
  /// **'Variables: %h = hostname, %p = port, %r = username. Executed via sh -c.'**
  String get connectionProxyCommandHint;

  /// No description provided for @connectionSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get connectionSync;

  /// No description provided for @connectionTmuxMode.
  ///
  /// In en, this message translates to:
  /// **'tmux Mode'**
  String get connectionTmuxMode;

  /// No description provided for @connectionTmuxDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled — Normal shell'**
  String get connectionTmuxDisabled;

  /// No description provided for @connectionTmuxAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto — Detect and use if available'**
  String get connectionTmuxAuto;

  /// No description provided for @connectionTmuxAlways.
  ///
  /// In en, this message translates to:
  /// **'Always — Require tmux (error if unavailable)'**
  String get connectionTmuxAlways;

  /// No description provided for @connectionTmuxCloseAction.
  ///
  /// In en, this message translates to:
  /// **'On Tab Close'**
  String get connectionTmuxCloseAction;

  /// No description provided for @connectionTmuxDetach.
  ///
  /// In en, this message translates to:
  /// **'Detach — Keep remote session running'**
  String get connectionTmuxDetach;

  /// No description provided for @connectionTmuxKill.
  ///
  /// In en, this message translates to:
  /// **'Kill — Destroy remote session'**
  String get connectionTmuxKill;

  /// No description provided for @connectionGitSyncEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Git Auto Sync'**
  String get connectionGitSyncEnable;

  /// No description provided for @connectionGitSyncRemotePath.
  ///
  /// In en, this message translates to:
  /// **'Remote Repository Path'**
  String get connectionGitSyncRemotePath;

  /// No description provided for @connectionGitSyncLocalPath.
  ///
  /// In en, this message translates to:
  /// **'Local Repository Path'**
  String get connectionGitSyncLocalPath;

  /// No description provided for @connectionGitSyncMode.
  ///
  /// In en, this message translates to:
  /// **'Sync Mode'**
  String get connectionGitSyncMode;

  /// No description provided for @connectionGitSyncNotify.
  ///
  /// In en, this message translates to:
  /// **'Notify Only — Desktop notification on push'**
  String get connectionGitSyncNotify;

  /// No description provided for @connectionGitSyncAutoPull.
  ///
  /// In en, this message translates to:
  /// **'Auto Pull — Automatically pull to local'**
  String get connectionGitSyncAutoPull;

  /// No description provided for @connectionGitSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Ensure your remote .gitignore excludes .env and sensitive files.'**
  String get connectionGitSyncHint;

  /// No description provided for @connectionForwarding.
  ///
  /// In en, this message translates to:
  /// **'Forwarding'**
  String get connectionForwarding;

  /// No description provided for @connectionForwardAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Forward'**
  String get connectionForwardAdd;

  /// No description provided for @connectionForwardLocal.
  ///
  /// In en, this message translates to:
  /// **'Local Forward'**
  String get connectionForwardLocal;

  /// No description provided for @connectionForwardDynamic.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Forward (SOCKS5)'**
  String get connectionForwardDynamic;

  /// No description provided for @connectionForwardDynamicHint.
  ///
  /// In en, this message translates to:
  /// **'SOCKS5 proxy — all browser traffic routed through remote server'**
  String get connectionForwardDynamicHint;

  /// No description provided for @connectionForwardNone.
  ///
  /// In en, this message translates to:
  /// **'No forwarding rules configured.'**
  String get connectionForwardNone;

  /// No description provided for @contextConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get contextConnect;

  /// No description provided for @contextEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get contextEdit;

  /// No description provided for @contextDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get contextDuplicate;

  /// No description provided for @contextRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get contextRename;

  /// No description provided for @contextRenameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter new name'**
  String get contextRenameHint;

  /// No description provided for @contextNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get contextNameRequired;

  /// No description provided for @contextMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to Group'**
  String get contextMoveTo;

  /// No description provided for @contextUngroup.
  ///
  /// In en, this message translates to:
  /// **'Remove from Group'**
  String get contextUngroup;

  /// No description provided for @contextDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get contextDelete;

  /// Auto-imported from Tauri context.deleteConfirm
  ///
  /// In en, this message translates to:
  /// **'Delete server \"{name}\"?'**
  String contextDeleteConfirm(String name);

  /// No description provided for @contextShareWithTeam.
  ///
  /// In en, this message translates to:
  /// **'Share with Team'**
  String get contextShareWithTeam;

  /// No description provided for @contextMakePrivate.
  ///
  /// In en, this message translates to:
  /// **'Make Private'**
  String get contextMakePrivate;

  /// Auto-imported from Tauri context.deleteGroupConfirm
  ///
  /// In en, this message translates to:
  /// **'Delete group \"{name}\"? Servers in this group will become ungrouped.'**
  String contextDeleteGroupConfirm(String name);

  /// No description provided for @contextNewSubgroup.
  ///
  /// In en, this message translates to:
  /// **'New Subgroup'**
  String get contextNewSubgroup;

  /// No description provided for @securityProtectionMode.
  ///
  /// In en, this message translates to:
  /// **'Credential Protection'**
  String get securityProtectionMode;

  /// Auto-imported from Tauri security.keychainActive
  ///
  /// In en, this message translates to:
  /// **'Using {platform}. All passwords and keys are securely stored in the OS credential manager.'**
  String securityKeychainActive(String platform);

  /// No description provided for @securityKeychainUnavailable.
  ///
  /// In en, this message translates to:
  /// **'OS keychain is not available. Using local encrypted storage.'**
  String get securityKeychainUnavailable;

  /// No description provided for @securityStoredCredentials.
  ///
  /// In en, this message translates to:
  /// **'Protected Credentials'**
  String get securityStoredCredentials;

  /// No description provided for @securityCredentialHint.
  ///
  /// In en, this message translates to:
  /// **'SSH passwords, passphrases, AI API keys'**
  String get securityCredentialHint;

  /// No description provided for @securityHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get securityHowItWorks;

  /// No description provided for @securityHint1.
  ///
  /// In en, this message translates to:
  /// **'Passwords and keys are stored in the OS credential manager, not in termex.db'**
  String get securityHint1;

  /// No description provided for @securityHint2.
  ///
  /// In en, this message translates to:
  /// **'termex.db only stores keychain reference IDs'**
  String get securityHint2;

  /// No description provided for @securityHint3.
  ///
  /// In en, this message translates to:
  /// **'Even if termex.db is leaked, no credentials can be extracted'**
  String get securityHint3;

  /// No description provided for @hostKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Host Key Verification'**
  String get hostKeyTitle;

  /// No description provided for @hostKeyWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'WARNING: HOST KEY HAS CHANGED!'**
  String get hostKeyWarningTitle;

  /// No description provided for @hostKeyWarningDesc.
  ///
  /// In en, this message translates to:
  /// **'The host key for this server has changed. This could indicate a man-in-the-middle attack, or the server may have been reconfigured.'**
  String get hostKeyWarningDesc;

  /// No description provided for @hostKeyHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get hostKeyHost;

  /// No description provided for @hostKeyKeyType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get hostKeyKeyType;

  /// No description provided for @hostKeyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get hostKeyFingerprint;

  /// No description provided for @hostKeyOldFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Previous fingerprint'**
  String get hostKeyOldFingerprint;

  /// No description provided for @hostKeyNewFingerprint.
  ///
  /// In en, this message translates to:
  /// **'New fingerprint'**
  String get hostKeyNewFingerprint;

  /// No description provided for @hostKeyAccept.
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get hostKeyAccept;

  /// No description provided for @hostKeyAcceptChanged.
  ///
  /// In en, this message translates to:
  /// **'Trust Anyway'**
  String get hostKeyAcceptChanged;

  /// No description provided for @hostKeyReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get hostKeyReject;

  /// No description provided for @keybindingsNewConnection.
  ///
  /// In en, this message translates to:
  /// **'New Connection'**
  String get keybindingsNewConnection;

  /// No description provided for @keybindingsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get keybindingsOpenSettings;

  /// No description provided for @keybindingsToggleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Toggle Sidebar'**
  String get keybindingsToggleSidebar;

  /// No description provided for @keybindingsToggleAi.
  ///
  /// In en, this message translates to:
  /// **'Toggle AI Panel'**
  String get keybindingsToggleAi;

  /// No description provided for @keybindingsCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close Current Tab'**
  String get keybindingsCloseTab;

  /// No description provided for @keybindingsNextTab.
  ///
  /// In en, this message translates to:
  /// **'Next Tab'**
  String get keybindingsNextTab;

  /// No description provided for @keybindingsPrevTab.
  ///
  /// In en, this message translates to:
  /// **'Previous Tab'**
  String get keybindingsPrevTab;

  /// No description provided for @keybindingsGoToTab.
  ///
  /// In en, this message translates to:
  /// **'Go to Tab N'**
  String get keybindingsGoToTab;

  /// No description provided for @keybindingsGoToTab1.
  ///
  /// In en, this message translates to:
  /// **'Go to Tab 1'**
  String get keybindingsGoToTab1;

  /// No description provided for @keybindingsGoToTab2.
  ///
  /// In en, this message translates to:
  /// **'Go to Tab 2'**
  String get keybindingsGoToTab2;

  /// No description provided for @keybindingsGoToTab3.
  ///
  /// In en, this message translates to:
  /// **'Go to Tab 3'**
  String get keybindingsGoToTab3;

  /// No description provided for @keybindingsGoToTab4.
  ///
  /// In en, this message translates to:
  /// **'Go to Tab 4'**
  String get keybindingsGoToTab4;

  /// No description provided for @keybindingsGoToTab5.
  ///
  /// In en, this message translates to:
  /// **'Go to Tab 5'**
  String get keybindingsGoToTab5;

  /// No description provided for @keybindingsGoToTab6.
  ///
  /// In en, this message translates to:
  /// **'Go to Tab 6'**
  String get keybindingsGoToTab6;

  /// No description provided for @keybindingsGoToTab7.
  ///
  /// In en, this message translates to:
  /// **'Go to Tab 7'**
  String get keybindingsGoToTab7;

  /// No description provided for @keybindingsGoToTab8.
  ///
  /// In en, this message translates to:
  /// **'Go to Tab 8'**
  String get keybindingsGoToTab8;

  /// No description provided for @keybindingsGoToTab9.
  ///
  /// In en, this message translates to:
  /// **'Go to Tab 9'**
  String get keybindingsGoToTab9;

  /// No description provided for @keybindingsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search Terminal'**
  String get keybindingsSearch;

  /// No description provided for @keybindingsSearchAllTabs.
  ///
  /// In en, this message translates to:
  /// **'Search All Tabs'**
  String get keybindingsSearchAllTabs;

  /// No description provided for @keybindingsSplitVertical.
  ///
  /// In en, this message translates to:
  /// **'Split Vertical'**
  String get keybindingsSplitVertical;

  /// No description provided for @keybindingsSplitHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Split Horizontal'**
  String get keybindingsSplitHorizontal;

  /// No description provided for @keybindingsClosePaneOrTab.
  ///
  /// In en, this message translates to:
  /// **'Close Pane / Tab'**
  String get keybindingsClosePaneOrTab;

  /// No description provided for @keybindingsFocusPaneNext.
  ///
  /// In en, this message translates to:
  /// **'Focus Next Pane'**
  String get keybindingsFocusPaneNext;

  /// No description provided for @keybindingsFocusPanePrev.
  ///
  /// In en, this message translates to:
  /// **'Focus Previous Pane'**
  String get keybindingsFocusPanePrev;

  /// No description provided for @keybindingsFocusPaneUp.
  ///
  /// In en, this message translates to:
  /// **'Focus Pane Above'**
  String get keybindingsFocusPaneUp;

  /// No description provided for @keybindingsFocusPaneDown.
  ///
  /// In en, this message translates to:
  /// **'Focus Pane Below'**
  String get keybindingsFocusPaneDown;

  /// No description provided for @keybindingsFocusPaneLeft.
  ///
  /// In en, this message translates to:
  /// **'Focus Pane Left'**
  String get keybindingsFocusPaneLeft;

  /// No description provided for @keybindingsFocusPaneRight.
  ///
  /// In en, this message translates to:
  /// **'Focus Pane Right'**
  String get keybindingsFocusPaneRight;

  /// No description provided for @keybindingsToggleBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Toggle Broadcast'**
  String get keybindingsToggleBroadcast;

  /// No description provided for @keybindingsRecording.
  ///
  /// In en, this message translates to:
  /// **'Press shortcut...'**
  String get keybindingsRecording;

  /// Auto-imported from Tauri keybindings.conflict
  ///
  /// In en, this message translates to:
  /// **'Already used by \"{action}\"'**
  String keybindingsConflict(String action);

  /// No description provided for @keybindingsResetOne.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get keybindingsResetOne;

  /// No description provided for @keybindingsResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset All'**
  String get keybindingsResetAll;

  /// No description provided for @keybindingsResetAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset all keybindings to defaults?'**
  String get keybindingsResetAllConfirm;

  /// No description provided for @keybindingsRequireModifier.
  ///
  /// In en, this message translates to:
  /// **'Shortcut must include Cmd/Ctrl'**
  String get keybindingsRequireModifier;

  /// No description provided for @keybindingsReserved.
  ///
  /// In en, this message translates to:
  /// **'This shortcut is reserved by the system'**
  String get keybindingsReserved;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchPlaceholder;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResults;

  /// Auto-imported from Tauri search.matchCount
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String searchMatchCount(String current, String total);

  /// No description provided for @searchCaseSensitive.
  ///
  /// In en, this message translates to:
  /// **'Match Case'**
  String get searchCaseSensitive;

  /// No description provided for @searchRegex.
  ///
  /// In en, this message translates to:
  /// **'Regular Expression'**
  String get searchRegex;

  /// No description provided for @searchWholeWord.
  ///
  /// In en, this message translates to:
  /// **'Whole Word'**
  String get searchWholeWord;

  /// No description provided for @searchClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get searchClose;

  /// No description provided for @searchPreviousMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous Match'**
  String get searchPreviousMatch;

  /// No description provided for @searchNextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next Match'**
  String get searchNextMatch;

  /// No description provided for @searchSearchAllTabs.
  ///
  /// In en, this message translates to:
  /// **'Search All Tabs'**
  String get searchSearchAllTabs;

  /// No description provided for @searchSearchBtn.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchSearchBtn;

  /// No description provided for @searchSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searchSearching;

  /// Auto-imported from Tauri search.totalMatches
  ///
  /// In en, this message translates to:
  /// **'{count} match(es) in {tabs} tab(s)'**
  String searchTotalMatches(String count, String tabs);

  /// No description provided for @searchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get searchNoMatches;

  /// Auto-imported from Tauri search.moreMatches
  ///
  /// In en, this message translates to:
  /// **'... and {count} more match(es)'**
  String searchMoreMatches(String count);

  /// No description provided for @searchLine.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get searchLine;

  /// No description provided for @searchJumpToMatch.
  ///
  /// In en, this message translates to:
  /// **'Jump to match'**
  String get searchJumpToMatch;

  /// No description provided for @highlightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyword Highlights'**
  String get highlightsTitle;

  /// No description provided for @highlightsPattern.
  ///
  /// In en, this message translates to:
  /// **'Pattern'**
  String get highlightsPattern;

  /// No description provided for @highlightsRegex.
  ///
  /// In en, this message translates to:
  /// **'Regex'**
  String get highlightsRegex;

  /// No description provided for @highlightsCaseSensitive.
  ///
  /// In en, this message translates to:
  /// **'Case'**
  String get highlightsCaseSensitive;

  /// No description provided for @highlightsBgColor.
  ///
  /// In en, this message translates to:
  /// **'BG Color'**
  String get highlightsBgColor;

  /// No description provided for @highlightsFgColor.
  ///
  /// In en, this message translates to:
  /// **'FG Color'**
  String get highlightsFgColor;

  /// No description provided for @highlightsEnabled.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get highlightsEnabled;

  /// No description provided for @highlightsAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add Rule'**
  String get highlightsAddRule;

  /// No description provided for @highlightsLoadPresets.
  ///
  /// In en, this message translates to:
  /// **'Load Presets'**
  String get highlightsLoadPresets;

  /// No description provided for @highlightsDeleteRule.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get highlightsDeleteRule;

  /// No description provided for @highlightsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this highlight rule?'**
  String get highlightsDeleteConfirm;

  /// No description provided for @highlightsNoRules.
  ///
  /// In en, this message translates to:
  /// **'No keyword highlight rules. Click \"Add Rule\" or \"Load Presets\" to get started.'**
  String get highlightsNoRules;

  /// No description provided for @highlightsPresetsLoaded.
  ///
  /// In en, this message translates to:
  /// **'Preset rules loaded'**
  String get highlightsPresetsLoaded;

  /// No description provided for @highlightsPatternRequired.
  ///
  /// In en, this message translates to:
  /// **'Pattern is required'**
  String get highlightsPatternRequired;

  /// No description provided for @highlightsInvalidRegex.
  ///
  /// In en, this message translates to:
  /// **'Invalid regular expression'**
  String get highlightsInvalidRegex;

  /// No description provided for @aiConfigAddProvider.
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get aiConfigAddProvider;

  /// No description provided for @aiConfigNoProviders.
  ///
  /// In en, this message translates to:
  /// **'No AI providers yet. Click above to add one.'**
  String get aiConfigNoProviders;

  /// No description provided for @aiConfigProviderName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get aiConfigProviderName;

  /// No description provided for @aiConfigProviderType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get aiConfigProviderType;

  /// No description provided for @aiConfigModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get aiConfigModel;

  /// No description provided for @aiConfigSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set Default'**
  String get aiConfigSetDefault;

  /// No description provided for @aiConfigDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get aiConfigDefault;

  /// No description provided for @aiConfigDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this AI provider?'**
  String get aiConfigDeleteConfirm;

  /// No description provided for @aiConfigTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get aiConfigTest;

  /// No description provided for @aiConfigTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection test successful'**
  String get aiConfigTestSuccess;

  /// No description provided for @aiConfigTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection test failed'**
  String get aiConfigTestFailed;

  /// No description provided for @aiConfigLanOllama.
  ///
  /// In en, this message translates to:
  /// **'LAN'**
  String get aiConfigLanOllama;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupTitle;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Export Config'**
  String get backupExport;

  /// No description provided for @backupExportDesc.
  ///
  /// In en, this message translates to:
  /// **'Export servers, groups, and settings as an encrypted .termex file'**
  String get backupExportDesc;

  /// No description provided for @backupExportBtn.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get backupExportBtn;

  /// No description provided for @backupExportPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Set export password (at least 4 chars)'**
  String get backupExportPasswordHint;

  /// No description provided for @backupExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Export successful'**
  String get backupExportSuccess;

  /// No description provided for @backupPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 4 characters'**
  String get backupPasswordTooShort;

  /// No description provided for @backupImport.
  ///
  /// In en, this message translates to:
  /// **'Import Config'**
  String get backupImport;

  /// No description provided for @backupImportDesc.
  ///
  /// In en, this message translates to:
  /// **'Restore config data from an encrypted .termex file'**
  String get backupImportDesc;

  /// No description provided for @backupImportBtn.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get backupImportBtn;

  /// No description provided for @backupImportPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the password used during export'**
  String get backupImportPasswordHint;

  /// No description provided for @backupImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import successful'**
  String get backupImportSuccess;

  /// No description provided for @backupRecordingDir.
  ///
  /// In en, this message translates to:
  /// **'Recording Directory'**
  String get backupRecordingDir;

  /// No description provided for @backupRecordingDirDesc.
  ///
  /// In en, this message translates to:
  /// **'Terminal session recordings are stored here'**
  String get backupRecordingDirDesc;

  /// No description provided for @backupOpenDir.
  ///
  /// In en, this message translates to:
  /// **'Open Directory'**
  String get backupOpenDir;

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Version Info'**
  String get updateTitle;

  /// No description provided for @updateCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current Version'**
  String get updateCurrentVersion;

  /// No description provided for @updateLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest Version'**
  String get updateLatestVersion;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re running the latest version!'**
  String get updateUpToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get updateCheckFailed;

  /// No description provided for @updateReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get updateReleaseNotes;

  /// No description provided for @updateNoAsset.
  ///
  /// In en, this message translates to:
  /// **'No installer available for your platform. Please download manually.'**
  String get updateNoAsset;

  /// No description provided for @updateUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get updateUpgrade;

  /// No description provided for @updateRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get updateRetry;

  /// No description provided for @updateViewRelease.
  ///
  /// In en, this message translates to:
  /// **'View Release'**
  String get updateViewRelease;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get updateDownloading;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get updateDownloadFailed;

  /// No description provided for @updateInstallLaunched.
  ///
  /// In en, this message translates to:
  /// **'Installer launched. Termex will close shortly.'**
  String get updateInstallLaunched;

  /// No description provided for @updateNewVersion.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get updateNewVersion;

  /// No description provided for @keychainVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Credentials'**
  String get keychainVerificationTitle;

  /// No description provided for @keychainVerificationMessage.
  ///
  /// In en, this message translates to:
  /// **'Your system password may have changed. Please verify to access your saved credentials.'**
  String get keychainVerificationMessage;

  /// No description provided for @keychainVerificationVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get keychainVerificationVerify;

  /// No description provided for @keychainVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Some credentials may be temporarily inaccessible. You can still use Termex, but you may need to re-enter passwords.'**
  String get keychainVerificationFailed;

  /// No description provided for @autocompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Autocomplete'**
  String get autocompleteTitle;

  /// No description provided for @autocompleteEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable terminal inline autocomplete'**
  String get autocompleteEnabled;

  /// No description provided for @autocompleteDebounce.
  ///
  /// In en, this message translates to:
  /// **'Trigger delay'**
  String get autocompleteDebounce;

  /// No description provided for @autocompleteDebounceUnit.
  ///
  /// In en, this message translates to:
  /// **'ms'**
  String get autocompleteDebounceUnit;

  /// No description provided for @autocompleteMinChars.
  ///
  /// In en, this message translates to:
  /// **'Minimum characters'**
  String get autocompleteMinChars;

  /// No description provided for @autocompletePreferLocal.
  ///
  /// In en, this message translates to:
  /// **'Prefer local AI model'**
  String get autocompletePreferLocal;

  /// No description provided for @autocompletePreferLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Use local engine when running, lower latency'**
  String get autocompletePreferLocalHint;

  /// No description provided for @localAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Local AI Models'**
  String get localAiTitle;

  /// No description provided for @localAiEngineRunning.
  ///
  /// In en, this message translates to:
  /// **'Engine Running'**
  String get localAiEngineRunning;

  /// No description provided for @localAiEngineStopped.
  ///
  /// In en, this message translates to:
  /// **'Engine Stopped'**
  String get localAiEngineStopped;

  /// No description provided for @localAiMicroTier.
  ///
  /// In en, this message translates to:
  /// **'Micro (~200MB, 2GB RAM)'**
  String get localAiMicroTier;

  /// No description provided for @localAiMicroDesc.
  ///
  /// In en, this message translates to:
  /// **'Ultra-lightweight models for minimal resource usage'**
  String get localAiMicroDesc;

  /// No description provided for @localAiSmallTier.
  ///
  /// In en, this message translates to:
  /// **'Small (~400MB, 4GB RAM)'**
  String get localAiSmallTier;

  /// No description provided for @localAiSmallDesc.
  ///
  /// In en, this message translates to:
  /// **'Lightweight models for basic command explanation, ideal for low-resource environments'**
  String get localAiSmallDesc;

  /// No description provided for @localAiMediumTier.
  ///
  /// In en, this message translates to:
  /// **'Medium (~2GB, 8GB RAM)'**
  String get localAiMediumTier;

  /// No description provided for @localAiMediumDesc.
  ///
  /// In en, this message translates to:
  /// **'Balanced performance and quality, suitable for daily use'**
  String get localAiMediumDesc;

  /// No description provided for @localAiLargeTier.
  ///
  /// In en, this message translates to:
  /// **'Large (~5GB, 16GB RAM) ⭐ Recommended'**
  String get localAiLargeTier;

  /// No description provided for @localAiLargeDesc.
  ///
  /// In en, this message translates to:
  /// **'Best quality and capabilities, recommended for optimal experience'**
  String get localAiLargeDesc;

  /// No description provided for @localAiNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not Downloaded'**
  String get localAiNotDownloaded;

  /// No description provided for @localAiDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get localAiDownloading;

  /// No description provided for @localAiDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get localAiDownloaded;

  /// No description provided for @localAiError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get localAiError;

  /// No description provided for @localAiVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get localAiVerifying;

  /// No description provided for @localAiSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get localAiSize;

  /// No description provided for @localAiMinRam.
  ///
  /// In en, this message translates to:
  /// **'Min RAM'**
  String get localAiMinRam;

  /// No description provided for @localAiContextLength.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get localAiContextLength;

  /// No description provided for @localAiLocalModels.
  ///
  /// In en, this message translates to:
  /// **'Local Models'**
  String get localAiLocalModels;

  /// No description provided for @localAiDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get localAiDownload;

  /// No description provided for @localAiCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get localAiCancel;

  /// No description provided for @localAiDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get localAiDelete;

  /// No description provided for @localAiRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get localAiRetry;

  /// No description provided for @localAiUseAsProvider.
  ///
  /// In en, this message translates to:
  /// **'Use as Provider'**
  String get localAiUseAsProvider;

  /// No description provided for @localAiRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get localAiRecommended;

  /// Auto-imported from Tauri localAi.downloadStarted
  ///
  /// In en, this message translates to:
  /// **'Download started for {name}'**
  String localAiDownloadStarted(String name);

  /// Auto-imported from Tauri localAi.downloadFailed
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String localAiDownloadFailed(String error);

  /// No description provided for @localAiDownloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled'**
  String get localAiDownloadCancelled;

  /// No description provided for @localAiDeleted.
  ///
  /// In en, this message translates to:
  /// **'Model deleted'**
  String get localAiDeleted;

  /// No description provided for @localAiAddedAsProvider.
  ///
  /// In en, this message translates to:
  /// **'Added as AI provider'**
  String get localAiAddedAsProvider;

  /// Auto-imported from Tauri localAi.deleteConfirm
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This cannot be undone.'**
  String localAiDeleteConfirm(String name);

  /// No description provided for @localAiWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get localAiWarning;

  /// No description provided for @localAiCatalogUpdated.
  ///
  /// In en, this message translates to:
  /// **'The model catalog has been updated. Check the Local AI Models section for new models.'**
  String get localAiCatalogUpdated;

  /// No description provided for @localAiNoModels.
  ///
  /// In en, this message translates to:
  /// **'No local models downloaded yet. Please download a model in the Local AI Models panel.'**
  String get localAiNoModels;

  /// No description provided for @localAiOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get localAiOk;

  /// No description provided for @localAiAutoStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting Local AI'**
  String get localAiAutoStarting;

  /// Auto-imported from Tauri localAi.autoStartingMsg
  ///
  /// In en, this message translates to:
  /// **'Auto-starting {model} in {seconds}s... Close to cancel.'**
  String localAiAutoStartingMsg(String model, String seconds);

  /// Auto-imported from Tauri localAi.startingModel
  ///
  /// In en, this message translates to:
  /// **'Loading model {model}, please wait...'**
  String localAiStartingModel(String model);

  /// Auto-imported from Tauri localAi.startedModel
  ///
  /// In en, this message translates to:
  /// **'Local AI started: {model}'**
  String localAiStartedModel(String model);

  /// Auto-imported from Tauri localAi.reusedInstance
  ///
  /// In en, this message translates to:
  /// **'Reusing existing instance: {model}'**
  String localAiReusedInstance(String model);

  /// No description provided for @localAiStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start local AI'**
  String get localAiStartFailed;

  /// No description provided for @localAiSwitchModel.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get localAiSwitchModel;

  /// No description provided for @localAiAutoStart.
  ///
  /// In en, this message translates to:
  /// **'Auto-start on launch'**
  String get localAiAutoStart;

  /// No description provided for @localAiAutoStartHint.
  ///
  /// In en, this message translates to:
  /// **'Automatically start the last used model when Termex opens'**
  String get localAiAutoStartHint;

  /// No description provided for @sshConfigImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import SSH Config'**
  String get sshConfigImportTitle;

  /// No description provided for @sshConfigImportDescription.
  ///
  /// In en, this message translates to:
  /// **'Import servers from ~/.ssh/config'**
  String get sshConfigImportDescription;

  /// No description provided for @sshConfigPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get sshConfigPreview;

  /// No description provided for @sshConfigImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get sshConfigImporting;

  /// No description provided for @sshConfigSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get sshConfigSelectAll;

  /// No description provided for @sshConfigDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get sshConfigDeselectAll;

  /// No description provided for @sshConfigImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import Selected'**
  String get sshConfigImportButton;

  /// No description provided for @sshConfigImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get sshConfigImported;

  /// No description provided for @sshConfigSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get sshConfigSkipped;

  /// No description provided for @sshConfigErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get sshConfigErrors;

  /// No description provided for @sshConfigHostAlias.
  ///
  /// In en, this message translates to:
  /// **'Host Alias'**
  String get sshConfigHostAlias;

  /// No description provided for @sshConfigHostname.
  ///
  /// In en, this message translates to:
  /// **'Hostname'**
  String get sshConfigHostname;

  /// No description provided for @sshConfigPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get sshConfigPort;

  /// No description provided for @sshConfigUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get sshConfigUser;

  /// No description provided for @sshConfigAuthType.
  ///
  /// In en, this message translates to:
  /// **'Auth'**
  String get sshConfigAuthType;

  /// No description provided for @sshConfigAuthKey.
  ///
  /// In en, this message translates to:
  /// **'Key Authentication'**
  String get sshConfigAuthKey;

  /// No description provided for @sshConfigAuthPassword.
  ///
  /// In en, this message translates to:
  /// **'Password Authentication'**
  String get sshConfigAuthPassword;

  /// No description provided for @sshConfigNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No SSH config entries found'**
  String get sshConfigNoEntries;

  /// No description provided for @sshConfigParseWarnings.
  ///
  /// In en, this message translates to:
  /// **'Parse Warnings'**
  String get sshConfigParseWarnings;

  /// Auto-imported from Tauri sshConfig.selectedCount
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} selected'**
  String sshConfigSelectedCount(String count, String total);

  /// No description provided for @sshConfigImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get sshConfigImport;

  /// Auto-imported from Tauri sshConfig.resultSummary
  ///
  /// In en, this message translates to:
  /// **'{imported} imported, {skipped} skipped, {errors} error(s)'**
  String sshConfigResultSummary(String imported, String skipped, String errors);

  /// No description provided for @sshConfigErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error Details'**
  String get sshConfigErrorDetails;

  /// No description provided for @sshConfigDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get sshConfigDone;

  /// No description provided for @sshConfigNonInteractive.
  ///
  /// In en, this message translates to:
  /// **'Non-SSH'**
  String get sshConfigNonInteractive;

  /// No description provided for @snippetTitle.
  ///
  /// In en, this message translates to:
  /// **'Snippets'**
  String get snippetTitle;

  /// No description provided for @snippetSearch.
  ///
  /// In en, this message translates to:
  /// **'Search snippets...'**
  String get snippetSearch;

  /// No description provided for @snippetCreate.
  ///
  /// In en, this message translates to:
  /// **'New Snippet'**
  String get snippetCreate;

  /// No description provided for @snippetCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New Snippet'**
  String get snippetCreateTitle;

  /// No description provided for @snippetEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Snippet'**
  String get snippetEditTitle;

  /// No description provided for @snippetEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Snippet'**
  String get snippetEdit;

  /// No description provided for @snippetDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Snippet'**
  String get snippetDelete;

  /// No description provided for @snippetDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this snippet?'**
  String get snippetDeleteConfirm;

  /// No description provided for @snippetExecute.
  ///
  /// In en, this message translates to:
  /// **'Execute'**
  String get snippetExecute;

  /// No description provided for @snippetSaveAsSnippet.
  ///
  /// In en, this message translates to:
  /// **'Save as Snippet'**
  String get snippetSaveAsSnippet;

  /// No description provided for @snippetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get snippetSave;

  /// No description provided for @snippetCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get snippetCancel;

  /// No description provided for @snippetName.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get snippetName;

  /// No description provided for @snippetTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get snippetTitleLabel;

  /// No description provided for @snippetTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter snippet title'**
  String get snippetTitlePlaceholder;

  /// No description provided for @snippetCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get snippetCommand;

  /// No description provided for @snippetCommandLabel.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get snippetCommandLabel;

  /// No description provided for @snippetCommandPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter command...'**
  String get snippetCommandPlaceholder;

  /// No description provided for @snippetDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get snippetDescription;

  /// No description provided for @snippetDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get snippetDescriptionLabel;

  /// No description provided for @snippetDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Optional description'**
  String get snippetDescriptionPlaceholder;

  /// No description provided for @snippetTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get snippetTags;

  /// No description provided for @snippetTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get snippetTagsLabel;

  /// No description provided for @snippetTagsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated tags'**
  String get snippetTagsPlaceholder;

  /// No description provided for @snippetTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated tags'**
  String get snippetTagsHint;

  /// No description provided for @snippetFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get snippetFolder;

  /// No description provided for @snippetFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get snippetFolderLabel;

  /// No description provided for @snippetFolderNone.
  ///
  /// In en, this message translates to:
  /// **'No folder'**
  String get snippetFolderNone;

  /// No description provided for @snippetFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get snippetFavorite;

  /// No description provided for @snippetFavoriteLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get snippetFavoriteLabel;

  /// No description provided for @snippetUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get snippetUnfavorite;

  /// No description provided for @snippetNoSnippets.
  ///
  /// In en, this message translates to:
  /// **'No snippets yet'**
  String get snippetNoSnippets;

  /// No description provided for @snippetEmpty.
  ///
  /// In en, this message translates to:
  /// **'No snippets yet'**
  String get snippetEmpty;

  /// No description provided for @snippetCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'Create your first snippet'**
  String get snippetCreateFirst;

  /// No description provided for @snippetNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching snippets'**
  String get snippetNoResults;

  /// No description provided for @snippetPalette.
  ///
  /// In en, this message translates to:
  /// **'Snippet Palette'**
  String get snippetPalette;

  /// No description provided for @snippetPaletteSearch.
  ///
  /// In en, this message translates to:
  /// **'Search snippets...'**
  String get snippetPaletteSearch;

  /// No description provided for @snippetVariableTitle.
  ///
  /// In en, this message translates to:
  /// **'Fill Variables'**
  String get snippetVariableTitle;

  /// No description provided for @snippetVariablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Fill Variables'**
  String get snippetVariablesTitle;

  /// No description provided for @snippetVariableHint.
  ///
  /// In en, this message translates to:
  /// **'Enter values for template variables'**
  String get snippetVariableHint;

  /// Auto-imported from Tauri snippet.usageCount
  ///
  /// In en, this message translates to:
  /// **'Used {count} times'**
  String snippetUsageCount(String count);

  /// No description provided for @snippetAllFolders.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get snippetAllFolders;

  /// No description provided for @snippetAllFolder.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get snippetAllFolder;

  /// No description provided for @snippetNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get snippetNewFolder;

  /// No description provided for @snippetFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get snippetFolderName;

  /// No description provided for @snippetNavigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get snippetNavigate;

  /// No description provided for @snippetRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get snippetRun;

  /// No description provided for @snippetClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get snippetClose;

  /// No description provided for @monitorTitle.
  ///
  /// In en, this message translates to:
  /// **'Server Monitor'**
  String get monitorTitle;

  /// No description provided for @monitorCollectionInterval.
  ///
  /// In en, this message translates to:
  /// **'Collection Interval'**
  String get monitorCollectionInterval;

  /// No description provided for @monitorAutoStart.
  ///
  /// In en, this message translates to:
  /// **'Auto-start monitoring on connect'**
  String get monitorAutoStart;

  /// No description provided for @monitorVisiblePanels.
  ///
  /// In en, this message translates to:
  /// **'Visible Panels'**
  String get monitorVisiblePanels;

  /// No description provided for @teamTitle.
  ///
  /// In en, this message translates to:
  /// **'Team Collaboration'**
  String get teamTitle;

  /// No description provided for @teamDescription.
  ///
  /// In en, this message translates to:
  /// **'Share server configs via Git repo. All credentials are encrypted with a team key.'**
  String get teamDescription;

  /// No description provided for @teamCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Team'**
  String get teamCreate;

  /// No description provided for @teamJoin.
  ///
  /// In en, this message translates to:
  /// **'Join Team'**
  String get teamJoin;

  /// No description provided for @teamLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave Team'**
  String get teamLeave;

  /// No description provided for @teamLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave this team? Imported servers will be kept locally but won\'t sync.'**
  String get teamLeaveConfirm;

  /// No description provided for @teamLeftSuccess.
  ///
  /// In en, this message translates to:
  /// **'Left the team'**
  String get teamLeftSuccess;

  /// No description provided for @teamSync.
  ///
  /// In en, this message translates to:
  /// **'Sync to Cloud'**
  String get teamSync;

  /// No description provided for @teamSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing to Cloud...'**
  String get teamSyncing;

  /// Auto-imported from Tauri team.syncSuccess
  ///
  /// In en, this message translates to:
  /// **'Synced: imported {imported}, exported {exported}'**
  String teamSyncSuccess(String imported, String exported);

  /// No description provided for @teamSyncUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get teamSyncUpToDate;

  /// No description provided for @teamTeamName.
  ///
  /// In en, this message translates to:
  /// **'Team Name'**
  String get teamTeamName;

  /// No description provided for @teamPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Team Passphrase'**
  String get teamPassphrase;

  /// No description provided for @teamPassphraseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Passphrase'**
  String get teamPassphraseConfirm;

  /// No description provided for @teamPassphraseHint.
  ///
  /// In en, this message translates to:
  /// **'All members need the same passphrase. Share it securely.'**
  String get teamPassphraseHint;

  /// No description provided for @teamRepoUrl.
  ///
  /// In en, this message translates to:
  /// **'Git Repository URL'**
  String get teamRepoUrl;

  /// No description provided for @teamRepoUrlHint.
  ///
  /// In en, this message translates to:
  /// **'SSH (git@...) or HTTPS (https://...)'**
  String get teamRepoUrlHint;

  /// No description provided for @teamGitAuth.
  ///
  /// In en, this message translates to:
  /// **'Git Authentication'**
  String get teamGitAuth;

  /// No description provided for @teamGitAuthSsh.
  ///
  /// In en, this message translates to:
  /// **'SSH Key'**
  String get teamGitAuthSsh;

  /// No description provided for @teamGitAuthToken.
  ///
  /// In en, this message translates to:
  /// **'HTTPS Token'**
  String get teamGitAuthToken;

  /// No description provided for @teamGitAuthUserPass.
  ///
  /// In en, this message translates to:
  /// **'HTTPS User/Pass'**
  String get teamGitAuthUserPass;

  /// No description provided for @teamUsername.
  ///
  /// In en, this message translates to:
  /// **'Your Username'**
  String get teamUsername;

  /// No description provided for @teamUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Display name in the team'**
  String get teamUsernameHint;

  /// No description provided for @teamRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get teamRole;

  /// No description provided for @teamRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get teamRoleAdmin;

  /// No description provided for @teamRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get teamRoleMember;

  /// No description provided for @teamRoleReadonly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get teamRoleReadonly;

  /// No description provided for @teamMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get teamMembers;

  /// No description provided for @teamMemberManage.
  ///
  /// In en, this message translates to:
  /// **'Manage Members'**
  String get teamMemberManage;

  /// No description provided for @teamMemberRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove Member'**
  String get teamMemberRemove;

  /// Auto-imported from Tauri team.memberRemoveConfirm
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the team?'**
  String teamMemberRemoveConfirm(String name);

  /// No description provided for @teamShareServer.
  ///
  /// In en, this message translates to:
  /// **'Share with Team'**
  String get teamShareServer;

  /// No description provided for @teamShareServerHint.
  ///
  /// In en, this message translates to:
  /// **'Sync this server config to all team members'**
  String get teamShareServerHint;

  /// Auto-imported from Tauri team.sharedBy
  ///
  /// In en, this message translates to:
  /// **'Shared by {name}'**
  String teamSharedBy(String name);

  /// No description provided for @teamSharedWithTeam.
  ///
  /// In en, this message translates to:
  /// **'Shared with team · will sync on next push'**
  String get teamSharedWithTeam;

  /// No description provided for @teamMakePrivate.
  ///
  /// In en, this message translates to:
  /// **'Make Private'**
  String get teamMakePrivate;

  /// Auto-imported from Tauri team.receivedFrom
  ///
  /// In en, this message translates to:
  /// **'Received from {name}'**
  String teamReceivedFrom(String name);

  /// No description provided for @teamTeamServers.
  ///
  /// In en, this message translates to:
  /// **'Team Nodes'**
  String get teamTeamServers;

  /// No description provided for @teamLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get teamLastSync;

  /// No description provided for @teamNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get teamNeverSynced;

  /// No description provided for @teamJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get teamJustNow;

  /// No description provided for @teamMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'min ago'**
  String get teamMinutesAgo;

  /// No description provided for @teamPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'Pending changes'**
  String get teamPendingChanges;

  /// No description provided for @teamCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Team created successfully'**
  String get teamCreateSuccess;

  /// No description provided for @teamJoinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Joined team successfully'**
  String get teamJoinSuccess;

  /// No description provided for @teamStep1Info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get teamStep1Info;

  /// No description provided for @teamStep2Repo.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get teamStep2Repo;

  /// No description provided for @teamStep3Done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get teamStep3Done;

  /// No description provided for @teamNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get teamNext;

  /// No description provided for @teamDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get teamDone;

  /// No description provided for @teamEnterPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Enter Team Passphrase'**
  String get teamEnterPassphrase;

  /// No description provided for @teamPassphraseRequired.
  ///
  /// In en, this message translates to:
  /// **'Team passphrase is required to sync shared configurations.'**
  String get teamPassphraseRequired;

  /// No description provided for @teamPassphraseWrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect team passphrase'**
  String get teamPassphraseWrong;

  /// No description provided for @teamRememberPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Remember passphrase'**
  String get teamRememberPassphrase;

  /// No description provided for @teamRotateKey.
  ///
  /// In en, this message translates to:
  /// **'Rotate Password'**
  String get teamRotateKey;

  /// No description provided for @teamCurrentPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Current passphrase'**
  String get teamCurrentPassphrase;

  /// No description provided for @teamNewPassphrase.
  ///
  /// In en, this message translates to:
  /// **'New passphrase'**
  String get teamNewPassphrase;

  /// No description provided for @teamPassphraseTooShort.
  ///
  /// In en, this message translates to:
  /// **'Passphrase must be at least 8 characters'**
  String get teamPassphraseTooShort;

  /// No description provided for @teamPassphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passphrases do not match'**
  String get teamPassphraseMismatch;

  /// No description provided for @teamRotateKeySuccess.
  ///
  /// In en, this message translates to:
  /// **'Team password rotated successfully'**
  String get teamRotateKeySuccess;

  /// No description provided for @recordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Recording'**
  String get recordingTitle;

  /// No description provided for @recordingRetentionPeriod.
  ///
  /// In en, this message translates to:
  /// **'Retention Period'**
  String get recordingRetentionPeriod;

  /// No description provided for @recordingRetentionDesc.
  ///
  /// In en, this message translates to:
  /// **'Recordings older than this will be cleaned up on startup.'**
  String get recordingRetentionDesc;

  /// No description provided for @recordingDays30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get recordingDays30;

  /// No description provided for @recordingDays60.
  ///
  /// In en, this message translates to:
  /// **'60 days'**
  String get recordingDays60;

  /// No description provided for @recordingDays90.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get recordingDays90;

  /// No description provided for @recordingKeepForever.
  ///
  /// In en, this message translates to:
  /// **'Keep forever'**
  String get recordingKeepForever;

  /// No description provided for @recordingCleanup.
  ///
  /// In en, this message translates to:
  /// **'Clean up expired'**
  String get recordingCleanup;

  /// Auto-imported from Tauri recording.cleanupResult
  ///
  /// In en, this message translates to:
  /// **'Cleaned up {count} recordings'**
  String recordingCleanupResult(String count);

  /// No description provided for @recordingStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get recordingStartRecording;

  /// No description provided for @recordingStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get recordingStopRecording;

  /// No description provided for @cloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Resources'**
  String get cloudTitle;

  /// No description provided for @cloudRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get cloudRefresh;

  /// No description provided for @cloudFilterPods.
  ///
  /// In en, this message translates to:
  /// **'Filter pods...'**
  String get cloudFilterPods;

  /// No description provided for @cloudFilterInstances.
  ///
  /// In en, this message translates to:
  /// **'Filter instances...'**
  String get cloudFilterInstances;

  /// No description provided for @cloudKubeClusters.
  ///
  /// In en, this message translates to:
  /// **'K8s Clusters'**
  String get cloudKubeClusters;

  /// No description provided for @cloudKubeConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get cloudKubeConnect;

  /// No description provided for @cloudKubeViewLogs.
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get cloudKubeViewLogs;

  /// No description provided for @cloudKubePodDetail.
  ///
  /// In en, this message translates to:
  /// **'Pod Details'**
  String get cloudKubePodDetail;

  /// No description provided for @cloudKubeSelectContainer.
  ///
  /// In en, this message translates to:
  /// **'Select container'**
  String get cloudKubeSelectContainer;

  /// No description provided for @cloudKubeSelectShell.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get cloudKubeSelectShell;

  /// No description provided for @cloudKubeNoContexts.
  ///
  /// In en, this message translates to:
  /// **'No clusters configured'**
  String get cloudKubeNoContexts;

  /// No description provided for @cloudKubeNoPods.
  ///
  /// In en, this message translates to:
  /// **'No pods in this namespace'**
  String get cloudKubeNoPods;

  /// No description provided for @cloudKubeExecFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to exec into pod'**
  String get cloudKubeExecFailed;

  /// No description provided for @cloudKubeRbacDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied. Required: pods/exec'**
  String get cloudKubeRbacDenied;

  /// No description provided for @cloudSsmTitle.
  ///
  /// In en, this message translates to:
  /// **'AWS SSM'**
  String get cloudSsmTitle;

  /// No description provided for @cloudSsmConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get cloudSsmConnect;

  /// No description provided for @cloudSsmNoInstances.
  ///
  /// In en, this message translates to:
  /// **'No reachable instances'**
  String get cloudSsmNoInstances;

  /// No description provided for @cloudSsmAgentOffline.
  ///
  /// In en, this message translates to:
  /// **'SSM Agent offline'**
  String get cloudSsmAgentOffline;

  /// No description provided for @cloudSsmCredExpired.
  ///
  /// In en, this message translates to:
  /// **'AWS credentials expired. Run: aws sso login'**
  String get cloudSsmCredExpired;

  /// No description provided for @cloudLogsTailLines.
  ///
  /// In en, this message translates to:
  /// **'Tail lines'**
  String get cloudLogsTailLines;

  /// No description provided for @cloudLogsSince.
  ///
  /// In en, this message translates to:
  /// **'Since'**
  String get cloudLogsSince;

  /// No description provided for @cloudLogsFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get cloudLogsFollow;

  /// No description provided for @cloudLogsStreamEnded.
  ///
  /// In en, this message translates to:
  /// **'Log stream ended'**
  String get cloudLogsStreamEnded;

  /// No description provided for @cloudSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Native Setup'**
  String get cloudSetupTitle;

  /// No description provided for @cloudSetupDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect to K8s clusters and AWS EC2 instances'**
  String get cloudSetupDesc;

  /// No description provided for @cloudSetupDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get cloudSetupDetected;

  /// No description provided for @cloudSetupNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get cloudSetupNotInstalled;

  /// No description provided for @cloudSetupRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh Detection'**
  String get cloudSetupRefresh;

  /// No description provided for @cloudSetupSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get cloudSetupSkip;

  /// No description provided for @cloudInstallCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy install command'**
  String get cloudInstallCopy;

  /// No description provided for @cloudTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get cloudTimeout;

  /// Auto-imported from Tauri cloud.toolNotFound
  ///
  /// In en, this message translates to:
  /// **'{tool} not found'**
  String cloudToolNotFound(String tool);

  /// No description provided for @cloudTeamFavorites.
  ///
  /// In en, this message translates to:
  /// **'Team Cloud Resources'**
  String get cloudTeamFavorites;

  /// No description provided for @cloudNoTeamFavorites.
  ///
  /// In en, this message translates to:
  /// **'No team cloud resources yet. Share a K8s context or AWS profile from the private section.'**
  String get cloudNoTeamFavorites;

  /// No description provided for @teamV2RoleOps.
  ///
  /// In en, this message translates to:
  /// **'Ops'**
  String get teamV2RoleOps;

  /// No description provided for @teamV2RoleDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get teamV2RoleDeveloper;

  /// No description provided for @teamV2RoleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get teamV2RoleViewer;

  /// No description provided for @teamV2RoleCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Role'**
  String get teamV2RoleCustom;

  /// No description provided for @teamV2ManageRoles.
  ///
  /// In en, this message translates to:
  /// **'Manage Roles'**
  String get teamV2ManageRoles;

  /// No description provided for @teamV2CreateRole.
  ///
  /// In en, this message translates to:
  /// **'Create Role'**
  String get teamV2CreateRole;

  /// No description provided for @teamV2DeleteRole.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get teamV2DeleteRole;

  /// No description provided for @teamV2DeleteRoleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this custom role?'**
  String get teamV2DeleteRoleConfirm;

  /// No description provided for @teamV2PresetRoleReadonly.
  ///
  /// In en, this message translates to:
  /// **'preset'**
  String get teamV2PresetRoleReadonly;

  /// No description provided for @teamV2CapServerConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get teamV2CapServerConnect;

  /// No description provided for @teamV2CapServerCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Server'**
  String get teamV2CapServerCreate;

  /// No description provided for @teamV2CapServerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Server'**
  String get teamV2CapServerEdit;

  /// No description provided for @teamV2CapServerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Server'**
  String get teamV2CapServerDelete;

  /// No description provided for @teamV2CapServerViewCredentials.
  ///
  /// In en, this message translates to:
  /// **'View Credentials'**
  String get teamV2CapServerViewCredentials;

  /// No description provided for @teamV2CapSnippetCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Snippet'**
  String get teamV2CapSnippetCreate;

  /// No description provided for @teamV2CapSnippetEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Snippet'**
  String get teamV2CapSnippetEdit;

  /// No description provided for @teamV2CapSnippetDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Snippet'**
  String get teamV2CapSnippetDelete;

  /// No description provided for @teamV2CapSnippetExecute.
  ///
  /// In en, this message translates to:
  /// **'Execute Snippet'**
  String get teamV2CapSnippetExecute;

  /// No description provided for @teamV2CapTeamInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get teamV2CapTeamInvite;

  /// No description provided for @teamV2CapTeamRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove Member'**
  String get teamV2CapTeamRemove;

  /// No description provided for @teamV2CapTeamRoleAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign Role'**
  String get teamV2CapTeamRoleAssign;

  /// No description provided for @teamV2CapTeamSettingsEdit.
  ///
  /// In en, this message translates to:
  /// **'Team Settings'**
  String get teamV2CapTeamSettingsEdit;

  /// No description provided for @teamV2CapSyncPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get teamV2CapSyncPush;

  /// No description provided for @teamV2CapSyncPull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get teamV2CapSyncPull;

  /// No description provided for @teamV2CapAuditView.
  ///
  /// In en, this message translates to:
  /// **'View Audit'**
  String get teamV2CapAuditView;

  /// No description provided for @teamV2CapAuditExport.
  ///
  /// In en, this message translates to:
  /// **'Export Audit'**
  String get teamV2CapAuditExport;

  /// No description provided for @teamV2EditRole.
  ///
  /// In en, this message translates to:
  /// **'Edit Role'**
  String get teamV2EditRole;

  /// Auto-imported from Tauri teamV2.roleInUse
  ///
  /// In en, this message translates to:
  /// **'This role is in use by {count} member(s)'**
  String teamV2RoleInUse(String count);

  /// No description provided for @teamV2CredProtected.
  ///
  /// In en, this message translates to:
  /// **'Credentials protected by team permissions.'**
  String get teamV2CredProtected;

  /// No description provided for @teamV2CredContactAdmin.
  ///
  /// In en, this message translates to:
  /// **'Contact your admin for access.'**
  String get teamV2CredContactAdmin;

  /// No description provided for @teamV2PasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Team password was updated. Please enter the new password.'**
  String get teamV2PasswordUpdated;

  /// No description provided for @teamV2PasswordPendingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Team password needs update'**
  String get teamV2PasswordPendingUpdate;

  /// Auto-imported from Tauri teamV2.conflictResolved
  ///
  /// In en, this message translates to:
  /// **'Resolved {count} conflict(s)'**
  String teamV2ConflictResolved(String count);

  /// No description provided for @teamV2NoPermission.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission for this action.'**
  String get teamV2NoPermission;

  /// Auto-imported from Tauri teamV2.noPermissionDetail
  ///
  /// In en, this message translates to:
  /// **'Required: {capability}'**
  String teamV2NoPermissionDetail(String capability);

  /// No description provided for @teamV2AuditDashboard.
  ///
  /// In en, this message translates to:
  /// **'Audit Dashboard'**
  String get teamV2AuditDashboard;

  /// No description provided for @teamV2AuditExportReport.
  ///
  /// In en, this message translates to:
  /// **'Export...'**
  String get teamV2AuditExportReport;

  /// No description provided for @teamV2AuditConnections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get teamV2AuditConnections;

  /// No description provided for @teamV2AuditCredAccess.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get teamV2AuditCredAccess;

  /// No description provided for @teamV2AuditConfigChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get teamV2AuditConfigChanges;

  /// No description provided for @teamV2AuditMemberOps.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get teamV2AuditMemberOps;

  /// No description provided for @teamV2AuditRecentOps.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get teamV2AuditRecentOps;

  /// No description provided for @teamV2AuditViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get teamV2AuditViewAll;

  /// No description provided for @teamV2AuditFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All Events'**
  String get teamV2AuditFilterAll;

  /// No description provided for @teamV2AuditDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get teamV2AuditDateRange;

  /// No description provided for @teamV2AuditThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get teamV2AuditThisWeek;

  /// No description provided for @teamV2AuditThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get teamV2AuditThisMonth;

  /// No description provided for @teamV2AuditAll.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get teamV2AuditAll;

  /// No description provided for @teamV2AuditFormatJson.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get teamV2AuditFormatJson;

  /// No description provided for @teamV2AuditFormatCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get teamV2AuditFormatCsv;

  /// No description provided for @teamV2AuditFormatHtml.
  ///
  /// In en, this message translates to:
  /// **'HTML'**
  String get teamV2AuditFormatHtml;

  /// No description provided for @teamV2InviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite Member'**
  String get teamV2InviteMember;

  /// No description provided for @teamV2InviteRole.
  ///
  /// In en, this message translates to:
  /// **'Invite as'**
  String get teamV2InviteRole;

  /// No description provided for @teamV2InviteExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expires in'**
  String get teamV2InviteExpiry;

  /// No description provided for @teamV2InviteGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate Invite Code'**
  String get teamV2InviteGenerate;

  /// No description provided for @teamV2InviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get teamV2InviteCode;

  /// No description provided for @teamV2InviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get teamV2InviteCopied;

  /// No description provided for @teamV2InviteHint.
  ///
  /// In en, this message translates to:
  /// **'Send this code and team password separately to the invitee.'**
  String get teamV2InviteHint;

  /// No description provided for @teamV2InviteExpired.
  ///
  /// In en, this message translates to:
  /// **'Invite code expired'**
  String get teamV2InviteExpired;

  /// No description provided for @teamV2InviteInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid invite code'**
  String get teamV2InviteInvalid;

  /// Auto-imported from Tauri teamV2.inviteDays
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String teamV2InviteDays(String n);

  /// No description provided for @teamV2JoinViaInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get teamV2JoinViaInvite;

  /// No description provided for @teamV2ConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflicts'**
  String get teamV2ConflictTitle;

  /// No description provided for @teamV2ConflictDesc.
  ///
  /// In en, this message translates to:
  /// **'The following items have conflicting changes between local and remote:'**
  String get teamV2ConflictDesc;

  /// No description provided for @teamV2ConflictLocalVersion.
  ///
  /// In en, this message translates to:
  /// **'Local (You)'**
  String get teamV2ConflictLocalVersion;

  /// Auto-imported from Tauri teamV2.conflictRemoteVersion
  ///
  /// In en, this message translates to:
  /// **'Remote ({user})'**
  String teamV2ConflictRemoteVersion(String user);

  /// No description provided for @teamV2ConflictKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep Local'**
  String get teamV2ConflictKeepLocal;

  /// No description provided for @teamV2ConflictUseRemote.
  ///
  /// In en, this message translates to:
  /// **'Use Remote'**
  String get teamV2ConflictUseRemote;

  /// No description provided for @teamV2ConflictSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get teamV2ConflictSkip;

  /// No description provided for @teamV2ConflictApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get teamV2ConflictApply;

  /// No description provided for @teamV2ConflictAllLocal.
  ///
  /// In en, this message translates to:
  /// **'All Local'**
  String get teamV2ConflictAllLocal;

  /// No description provided for @teamV2ConflictAllRemote.
  ///
  /// In en, this message translates to:
  /// **'All Remote'**
  String get teamV2ConflictAllRemote;

  /// Auto-imported from Tauri teamV2.conflictPending
  ///
  /// In en, this message translates to:
  /// **'{count} conflict(s) need resolution'**
  String teamV2ConflictPending(String count);

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Your always-on cloud AI workspace in the AI era'**
  String get aboutTagline;

  /// Auto-added for about_tab.dart i18n pilot
  ///
  /// In en, this message translates to:
  /// **'Update available v{version}'**
  String aboutUpdateAvailable(String version);

  /// Auto-added for about_tab.dart i18n pilot
  ///
  /// In en, this message translates to:
  /// **'Ready to install v{version}'**
  String aboutUpdateReady(String version);

  /// Auto-added for about_tab.dart i18n pilot
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String aboutUpdateFailed(String error);

  /// No description provided for @aboutAutoDownload.
  ///
  /// In en, this message translates to:
  /// **'Auto-download updates'**
  String get aboutAutoDownload;

  /// No description provided for @aboutCheckFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Check frequency:'**
  String get aboutCheckFrequencyLabel;

  /// No description provided for @aboutFrequencyHourly.
  ///
  /// In en, this message translates to:
  /// **'Every hour'**
  String get aboutFrequencyHourly;

  /// No description provided for @aboutFrequencyDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get aboutFrequencyDaily;

  /// No description provided for @aboutFrequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get aboutFrequencyWeekly;

  /// No description provided for @aboutCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get aboutCheckNow;

  /// Auto-added for about_tab.dart i18n pilot
  ///
  /// In en, this message translates to:
  /// **'Download v{version}'**
  String aboutDownloadButton(String version);

  /// No description provided for @aboutApplyAndRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart & apply'**
  String get aboutApplyAndRestart;

  /// No description provided for @aboutWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get aboutWebsite;

  /// No description provided for @aboutSessionPoolTitle.
  ///
  /// In en, this message translates to:
  /// **'Session pool status (debug)'**
  String get aboutSessionPoolTitle;

  /// No description provided for @aboutSessionPoolHelp.
  ///
  /// In en, this message translates to:
  /// **'When multiple servers share the same proxy or jump host the upstream TCP connection is reused; each entry shows ref count and bytes transferred.'**
  String get aboutSessionPoolHelp;

  /// No description provided for @aboutSessionPoolEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active pool entries'**
  String get aboutSessionPoolEmpty;

  /// Auto-added for about_tab.dart i18n pilot
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String aboutUpdateDownloadingPercent(String percent);

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// Auto-added for about_tab.dart i18n pilot
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String commonLoadFailed(String error);

  /// No description provided for @settingsAi.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get settingsAi;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get settingsAudit;

  /// No description provided for @settingsLocalAi.
  ///
  /// In en, this message translates to:
  /// **'Local AI'**
  String get settingsLocalAi;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search settings…'**
  String get settingsSearchPlaceholder;

  /// No description provided for @settingsSearchNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching settings'**
  String get settingsSearchNoMatch;

  /// No description provided for @settingsIdxThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsIdxThemeLabel;

  /// No description provided for @settingsIdxThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Light / Dark / Follow system'**
  String get settingsIdxThemeDesc;

  /// No description provided for @settingsIdxFontLabel.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get settingsIdxFontLabel;

  /// No description provided for @settingsIdxFontDesc.
  ///
  /// In en, this message translates to:
  /// **'Terminal font and size'**
  String get settingsIdxFontDesc;

  /// No description provided for @settingsIdxCursorLabel.
  ///
  /// In en, this message translates to:
  /// **'Cursor'**
  String get settingsIdxCursorLabel;

  /// No description provided for @settingsIdxCursorDesc.
  ///
  /// In en, this message translates to:
  /// **'Cursor shape and blink'**
  String get settingsIdxCursorDesc;

  /// No description provided for @settingsIdxScrollbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Scrollback'**
  String get settingsIdxScrollbackLabel;

  /// No description provided for @settingsIdxScrollbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Terminal history lines'**
  String get settingsIdxScrollbackDesc;

  /// No description provided for @settingsIdxTabWidthLabel.
  ///
  /// In en, this message translates to:
  /// **'Tab width'**
  String get settingsIdxTabWidthLabel;

  /// No description provided for @settingsIdxTabWidthDesc.
  ///
  /// In en, this message translates to:
  /// **'2 / 4 / 8 spaces'**
  String get settingsIdxTabWidthDesc;

  /// No description provided for @settingsIdxKeybindingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get settingsIdxKeybindingsLabel;

  /// No description provided for @settingsIdxKeybindingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Custom commands and conflict detection'**
  String get settingsIdxKeybindingsDesc;

  /// No description provided for @settingsIdxAiProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Provider'**
  String get settingsIdxAiProviderLabel;

  /// No description provided for @settingsIdxAiProviderDesc.
  ///
  /// In en, this message translates to:
  /// **'Claude / OpenAI / Ollama / Local'**
  String get settingsIdxAiProviderDesc;

  /// No description provided for @settingsIdxAiContextLabel.
  ///
  /// In en, this message translates to:
  /// **'AI context'**
  String get settingsIdxAiContextLabel;

  /// No description provided for @settingsIdxAiContextDesc.
  ///
  /// In en, this message translates to:
  /// **'Terminal lines sent to AI'**
  String get settingsIdxAiContextDesc;

  /// No description provided for @settingsIdxTeamPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Team passphrase'**
  String get settingsIdxTeamPassphraseLabel;

  /// No description provided for @settingsIdxTeamPassphraseDesc.
  ///
  /// In en, this message translates to:
  /// **'Team sync unlock'**
  String get settingsIdxTeamPassphraseDesc;

  /// No description provided for @settingsIdxPrivacyClearLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy data wipe'**
  String get settingsIdxPrivacyClearLabel;

  /// No description provided for @settingsIdxPrivacyClearDesc.
  ///
  /// In en, this message translates to:
  /// **'Connection history / AI conversations / Snippet stats'**
  String get settingsIdxPrivacyClearDesc;

  /// No description provided for @settingsIdxGdprEraseLabel.
  ///
  /// In en, this message translates to:
  /// **'GDPR data erasure'**
  String get settingsIdxGdprEraseLabel;

  /// No description provided for @settingsIdxGdprEraseDesc.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all local data'**
  String get settingsIdxGdprEraseDesc;

  /// No description provided for @settingsIdxBackupLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup import/export'**
  String get settingsIdxBackupLabel;

  /// No description provided for @settingsIdxBackupDesc.
  ///
  /// In en, this message translates to:
  /// **'.termex encrypted file'**
  String get settingsIdxBackupDesc;

  /// No description provided for @settingsIdxAuditLabel.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get settingsIdxAuditLabel;

  /// No description provided for @settingsIdxAuditDesc.
  ///
  /// In en, this message translates to:
  /// **'Event query / CSV export'**
  String get settingsIdxAuditDesc;

  /// No description provided for @settingsIdxLocalAiLabel.
  ///
  /// In en, this message translates to:
  /// **'Local AI'**
  String get settingsIdxLocalAiLabel;

  /// No description provided for @settingsIdxLocalAiDesc.
  ///
  /// In en, this message translates to:
  /// **'llama-server port and model'**
  String get settingsIdxLocalAiDesc;

  /// No description provided for @settingsIdxAboutLabel.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsIdxAboutLabel;

  /// No description provided for @settingsIdxAboutDesc.
  ///
  /// In en, this message translates to:
  /// **'Version and license'**
  String get settingsIdxAboutDesc;

  /// No description provided for @backupAutoFreqLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup frequency'**
  String get backupAutoFreqLabel;

  /// No description provided for @backupAutoFreqHint.
  ///
  /// In en, this message translates to:
  /// **'How often .termex encrypted backups are generated'**
  String get backupAutoFreqHint;

  /// No description provided for @backupFreqOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get backupFreqOff;

  /// No description provided for @backupFreqDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get backupFreqDaily;

  /// No description provided for @backupFreqWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get backupFreqWeekly;

  /// No description provided for @backupEncryptionNote.
  ///
  /// In en, this message translates to:
  /// **'.termex backups use AES-256-GCM + Argon2id encryption.'**
  String get backupEncryptionNote;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Backup now'**
  String get backupNow;

  /// No description provided for @backupImportConfig.
  ///
  /// In en, this message translates to:
  /// **'Import config'**
  String get backupImportConfig;

  /// No description provided for @backupEnterEncryptPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter encryption password'**
  String get backupEnterEncryptPassword;

  /// No description provided for @backupEnterDecryptPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter decryption password'**
  String get backupEnterDecryptPassword;

  /// backup_tab.dart i18n
  ///
  /// In en, this message translates to:
  /// **'Backup complete: {file}'**
  String backupDone(String file);

  /// backup_tab.dart i18n
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String backupFailed(String error);

  /// No description provided for @backupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password (12+ characters)'**
  String get backupPasswordHint;

  /// No description provided for @backupConfirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get backupConfirm;

  /// No description provided for @backupHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup history'**
  String get backupHistoryTitle;

  /// No description provided for @backupHistoryClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get backupHistoryClear;

  /// backup_tab.dart i18n
  ///
  /// In en, this message translates to:
  /// **'Keeping the latest {max} records'**
  String backupHistoryMaxNote(String max);

  /// No description provided for @backupHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No backup records yet'**
  String get backupHistoryEmpty;

  /// No description provided for @cloudTabScheduledBackup.
  ///
  /// In en, this message translates to:
  /// **'Scheduled backup'**
  String get cloudTabScheduledBackup;

  /// No description provided for @cloudK8sSelectContext.
  ///
  /// In en, this message translates to:
  /// **'Select a context to view pods'**
  String get cloudK8sSelectContext;

  /// No description provided for @cloudK8sColName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get cloudK8sColName;

  /// No description provided for @cloudK8sColStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get cloudK8sColStatus;

  /// No description provided for @cloudK8sColRestarts.
  ///
  /// In en, this message translates to:
  /// **'Restarts'**
  String get cloudK8sColRestarts;

  /// No description provided for @cloudK8sColAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get cloudK8sColAge;

  /// No description provided for @cloudK8sColImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get cloudK8sColImage;

  /// No description provided for @cloudSsmEmpty.
  ///
  /// In en, this message translates to:
  /// **'No SSM instances found'**
  String get cloudSsmEmpty;

  /// No description provided for @cloudSsmStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start session'**
  String get cloudSsmStartSession;

  /// No description provided for @cloudEcsFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'ECS favorites'**
  String get cloudEcsFavoritesTitle;

  /// No description provided for @cloudEcsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get cloudEcsAdd;

  /// No description provided for @cloudEcsFavoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorited ECS instances'**
  String get cloudEcsFavoritesEmpty;

  /// No description provided for @cloudEcsConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get cloudEcsConnect;

  /// No description provided for @cloudScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled backup'**
  String get cloudScheduleTitle;

  /// No description provided for @cloudScheduleNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get cloudScheduleNew;

  /// No description provided for @cloudScheduleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No scheduled backups configured'**
  String get cloudScheduleEmpty;

  /// No description provided for @cloudHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No backup records'**
  String get cloudHistoryEmpty;

  /// cloud_panel.dart i18n
  ///
  /// In en, this message translates to:
  /// **'Every {weekday} · {hour}:{minute} UTC'**
  String cloudScheduleWeekly(String weekday, String hour, String minute);

  /// cloud_panel.dart i18n
  ///
  /// In en, this message translates to:
  /// **'Every {day}th · {hour}:{minute} UTC'**
  String cloudScheduleMonthly(String day, String hour, String minute);

  /// cloud_panel.dart i18n
  ///
  /// In en, this message translates to:
  /// **'Daily · {hour}:{minute} UTC'**
  String cloudScheduleDaily(String hour, String minute);

  /// No description provided for @cloudScheduleRunNow.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get cloudScheduleRunNow;

  /// No description provided for @cloudScheduleDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get cloudScheduleDelete;

  /// No description provided for @privacyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyDialogTitle;

  /// No description provided for @privacyEffectiveDate.
  ///
  /// In en, this message translates to:
  /// **'Effective · 2026-05-07'**
  String get privacyEffectiveDate;

  /// No description provided for @privacyClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get privacyClose;

  /// No description provided for @privacySec1Heading.
  ///
  /// In en, this message translates to:
  /// **'1. Overview'**
  String get privacySec1Heading;

  /// No description provided for @privacySec1Body.
  ///
  /// In en, this message translates to:
  /// **'Termex is an open-source SSH client. We take your privacy seriously: this app does not collect, transmit, or store any user data on Termex servers — Termex has no backend servers.'**
  String get privacySec1Body;

  /// No description provided for @privacySec2Heading.
  ///
  /// In en, this message translates to:
  /// **'2. Data Storage'**
  String get privacySec2Heading;

  /// No description provided for @privacySec2Body.
  ///
  /// In en, this message translates to:
  /// **'All data is stored only on your device:\n· Server configs: local SQLite, SQLCipher AES-256 encryption.\n· SSH passwords / key passphrases: system Keychain (macOS) / Credential Manager (Windows) / Secret Service (Linux).\n· AI API keys: same — stored in the system Keychain.\n· Session recordings: local filesystem.\n· Monitor history: local SQLite, SQLCipher encrypted.'**
  String get privacySec2Body;

  /// No description provided for @privacySec3Heading.
  ///
  /// In en, this message translates to:
  /// **'3. Network Connections'**
  String get privacySec3Heading;

  /// No description provided for @privacySec3Body.
  ///
  /// In en, this message translates to:
  /// **'Termex only establishes these network connections:\n· SSH connections: direct to the server you specify; no intermediate nodes.\n· AI requests: direct to the AI provider you configure (OpenAI, Anthropic, etc.); Termex never acts as a proxy or relay.\n· App updates: queries the official appcast feed for version information.'**
  String get privacySec3Body;

  /// No description provided for @privacySec4Heading.
  ///
  /// In en, this message translates to:
  /// **'4. Team Sync (Optional)'**
  String get privacySec4Heading;

  /// No description provided for @privacySec4Body.
  ///
  /// In en, this message translates to:
  /// **'If you enable team features, Termex syncs encrypted configs via the Git repository you specify. Termex is not a sync server; all data is encrypted with the team key before transmission.'**
  String get privacySec4Body;

  /// No description provided for @privacySec5Heading.
  ///
  /// In en, this message translates to:
  /// **'5. Your Rights (GDPR / CCPA)'**
  String get privacySec5Heading;

  /// No description provided for @privacySec5Body.
  ///
  /// In en, this message translates to:
  /// **'Because Termex collects no personal data:\n· Data access / export: all data is locally readable.\n· Data deletion: Settings → Privacy → Erase all data.\n· Data portability: Settings → Data → Export encrypted backup.'**
  String get privacySec5Body;

  /// No description provided for @privacySec6Heading.
  ///
  /// In en, this message translates to:
  /// **'6. Contact'**
  String get privacySec6Heading;

  /// No description provided for @privacySec6Body.
  ///
  /// In en, this message translates to:
  /// **'The full privacy policy lives at docs/privacy-policy.md in the project repository. For privacy-related questions please contact us via GitHub Issues.'**
  String get privacySec6Body;

  /// No description provided for @proxiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Proxy configurations'**
  String get proxiesTitle;

  /// No description provided for @proxiesAddProxy.
  ///
  /// In en, this message translates to:
  /// **'Add proxy'**
  String get proxiesAddProxy;

  /// No description provided for @proxiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No proxies configured\nClick \'Add proxy\' to create an HTTP or SOCKS5 proxy'**
  String get proxiesEmpty;

  /// No description provided for @proxiesDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get proxiesDefault;

  /// No description provided for @proxiesTestConn.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get proxiesTestConn;

  /// No description provided for @proxiesTestOk.
  ///
  /// In en, this message translates to:
  /// **'Proxy connection OK ✓'**
  String get proxiesTestOk;

  /// No description provided for @proxiesTestFail.
  ///
  /// In en, this message translates to:
  /// **'Proxy connection failed'**
  String get proxiesTestFail;

  /// No description provided for @proxiesTestError.
  ///
  /// In en, this message translates to:
  /// **'Test failed: {error}'**
  String proxiesTestError(String error);

  /// No description provided for @proxiesSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get proxiesSetDefault;

  /// No description provided for @proxiesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get proxiesDelete;

  /// No description provided for @proxiesDialogName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get proxiesDialogName;

  /// No description provided for @proxiesDialogType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get proxiesDialogType;

  /// No description provided for @proxiesDialogHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get proxiesDialogHost;

  /// No description provided for @proxiesDialogPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get proxiesDialogPort;

  /// No description provided for @proxiesDialogUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get proxiesDialogUsername;

  /// No description provided for @proxiesDialogPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get proxiesDialogPassword;

  /// No description provided for @proxiesDialogOptional.
  ///
  /// In en, this message translates to:
  /// **'(optional)'**
  String get proxiesDialogOptional;

  /// No description provided for @proxiesDialogAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get proxiesDialogAdd;

  /// No description provided for @proxiesDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get proxiesDefaultName;

  /// No description provided for @gitSyncExtraReposTitle.
  ///
  /// In en, this message translates to:
  /// **'Additional repositories'**
  String get gitSyncExtraReposTitle;

  /// No description provided for @gitSyncNoExtraRepos.
  ///
  /// In en, this message translates to:
  /// **'No additional repositories'**
  String get gitSyncNoExtraRepos;

  /// No description provided for @gitSyncAddRepo.
  ///
  /// In en, this message translates to:
  /// **'Add repository'**
  String get gitSyncAddRepo;

  /// No description provided for @gitSyncAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Git Sync repository'**
  String get gitSyncAddDialogTitle;

  /// No description provided for @gitSyncLocalPath.
  ///
  /// In en, this message translates to:
  /// **'Local path'**
  String get gitSyncLocalPath;

  /// No description provided for @gitSyncRemoteUrl.
  ///
  /// In en, this message translates to:
  /// **'Remote URL'**
  String get gitSyncRemoteUrl;

  /// No description provided for @gitSyncRemoteUrlGitSsh.
  ///
  /// In en, this message translates to:
  /// **'Remote URL (git/ssh)'**
  String get gitSyncRemoteUrlGitSsh;

  /// No description provided for @gitSyncAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get gitSyncAdd;

  /// No description provided for @gitSyncManualSync.
  ///
  /// In en, this message translates to:
  /// **'Manual sync'**
  String get gitSyncManualSync;

  /// No description provided for @gitSyncEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get gitSyncEnable;

  /// No description provided for @gitSyncRowLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get gitSyncRowLocal;

  /// No description provided for @gitSyncRowRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get gitSyncRowRemote;

  /// No description provided for @gitSyncRowLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get gitSyncRowLastSync;

  /// No description provided for @gitSyncResolveConflicts.
  ///
  /// In en, this message translates to:
  /// **'Resolve conflicts ({count})'**
  String gitSyncResolveConflicts(String count);

  /// No description provided for @gitSyncEnableDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Git Sync'**
  String get gitSyncEnableDialogTitle;

  /// No description provided for @gitSyncLocalRepoPath.
  ///
  /// In en, this message translates to:
  /// **'Local repo path'**
  String get gitSyncLocalRepoPath;

  /// No description provided for @gitSyncRowError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String gitSyncRowError(String message);

  /// No description provided for @sftpSortNameAsc.
  ///
  /// In en, this message translates to:
  /// **'Name ↑'**
  String get sftpSortNameAsc;

  /// No description provided for @sftpSortNameDesc.
  ///
  /// In en, this message translates to:
  /// **'Name ↓'**
  String get sftpSortNameDesc;

  /// No description provided for @sftpSortSizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sftpSortSizeDesc;

  /// No description provided for @sftpSortModifiedDesc.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get sftpSortModifiedDesc;

  /// No description provided for @sftpSortTypeFirst.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sftpSortTypeFirst;

  /// No description provided for @sftpShowHidden.
  ///
  /// In en, this message translates to:
  /// **'Show hidden'**
  String get sftpShowHidden;

  /// No description provided for @sftpSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sftpSortTooltip;

  /// No description provided for @sftpColName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sftpColName;

  /// No description provided for @sftpColSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sftpColSize;

  /// No description provided for @sftpColModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get sftpColModified;

  /// No description provided for @sftpColPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get sftpColPermissions;

  /// No description provided for @sftpEmptyDir.
  ///
  /// In en, this message translates to:
  /// **'(empty directory)'**
  String get sftpEmptyDir;

  /// No description provided for @sftpActionDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get sftpActionDownload;

  /// No description provided for @sftpActionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get sftpActionRename;

  /// No description provided for @sftpActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sftpActionDelete;

  /// No description provided for @sftpActionChmod.
  ///
  /// In en, this message translates to:
  /// **'Change permissions'**
  String get sftpActionChmod;

  /// No description provided for @sftpActionNewFile.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get sftpActionNewFile;

  /// No description provided for @sftpActionNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get sftpActionNewFolder;

  /// No description provided for @sftpActionProperties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get sftpActionProperties;

  /// No description provided for @teamOfflineToast.
  ///
  /// In en, this message translates to:
  /// **'Network unreachable, entering offline mode'**
  String get teamOfflineToast;

  /// No description provided for @teamLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave team'**
  String get teamLeaveTitle;

  /// No description provided for @teamLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Leaving will delete all local team data — this cannot be undone.'**
  String get teamLeaveBody;

  /// No description provided for @teamStatMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get teamStatMembers;

  /// No description provided for @teamStatSharedServers.
  ///
  /// In en, this message translates to:
  /// **'Shared servers'**
  String get teamStatSharedServers;

  /// No description provided for @teamStatSharedProxies.
  ///
  /// In en, this message translates to:
  /// **'Shared proxies'**
  String get teamStatSharedProxies;

  /// No description provided for @teamOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'Offline — local browse only'**
  String get teamOfflineBanner;

  /// No description provided for @teamMyRole.
  ///
  /// In en, this message translates to:
  /// **'My role'**
  String get teamMyRole;

  /// No description provided for @teamConflictsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sync conflicts — tap to resolve'**
  String teamConflictsCount(String count);

  /// No description provided for @teamItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String teamItemsCount(String count);

  /// No description provided for @teamSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get teamSyncNow;

  /// No description provided for @teamRelJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get teamRelJustNow;

  /// No description provided for @teamRelMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} minutes ago'**
  String teamRelMinutesAgo(String n);

  /// No description provided for @teamRelHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} hours ago'**
  String teamRelHoursAgo(String n);

  /// No description provided for @teamRelDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} days ago'**
  String teamRelDaysAgo(String n);

  /// No description provided for @teamLeaveButton.
  ///
  /// In en, this message translates to:
  /// **'Leave team'**
  String get teamLeaveButton;

  /// No description provided for @teamDashLocked.
  ///
  /// In en, this message translates to:
  /// **'Team features locked'**
  String get teamDashLocked;

  /// No description provided for @teamDashUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock team'**
  String get teamDashUnlock;

  /// No description provided for @teamDashMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Team members'**
  String get teamDashMembersTitle;

  /// No description provided for @teamDashMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} member(s)'**
  String teamDashMemberCount(String count);

  /// No description provided for @teamDashLastSyncShort.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {ago}'**
  String teamDashLastSyncShort(String ago);

  /// No description provided for @teamDashInviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite member'**
  String get teamDashInviteMember;

  /// No description provided for @teamDashConflictsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} sync conflicts'**
  String teamDashConflictsShort(String count);

  /// No description provided for @teamDashPendingInvites.
  ///
  /// In en, this message translates to:
  /// **'Pending invites'**
  String get teamDashPendingInvites;

  /// No description provided for @teamDashSyncShort.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get teamDashSyncShort;

  /// No description provided for @teamDashResolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get teamDashResolve;

  /// No description provided for @teamDashRevokeInvite.
  ///
  /// In en, this message translates to:
  /// **'Revoke invite'**
  String get teamDashRevokeInvite;

  /// No description provided for @recordingCleanupDone.
  ///
  /// In en, this message translates to:
  /// **'Cleaned up expired recording files'**
  String get recordingCleanupDone;

  /// No description provided for @recordingCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Cleanup failed: {error}'**
  String recordingCleanupFailed(String error);

  /// No description provided for @recordingSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Recording save settings'**
  String get recordingSaveSettings;

  /// No description provided for @recordingFormat.
  ///
  /// In en, this message translates to:
  /// **'Recording format'**
  String get recordingFormat;

  /// No description provided for @recordingFormatJsonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Structured JSON format, plays back in asciinema players\nCompact, recommended for sharing'**
  String get recordingFormatJsonSubtitle;

  /// No description provided for @recordingFormatRawSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Raw terminal byte stream, suitable for offline replay\nLarger, keeps the full output'**
  String get recordingFormatRawSubtitle;

  /// No description provided for @recordingStorageNote.
  ///
  /// In en, this message translates to:
  /// **'Recordings are saved under the recordings/ folder of the app data directory.\nFiles older than the retention period are cleaned up at every startup.'**
  String get recordingStorageNote;

  /// No description provided for @recordingRetentionForever.
  ///
  /// In en, this message translates to:
  /// **'Keep forever'**
  String get recordingRetentionForever;

  /// No description provided for @recordingRetentionNone.
  ///
  /// In en, this message translates to:
  /// **'Do not keep'**
  String get recordingRetentionNone;

  /// No description provided for @recordingRetentionDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String recordingRetentionDays(String days);

  /// No description provided for @recordingRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording retention'**
  String get recordingRetentionTitle;

  /// No description provided for @recordingForever.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get recordingForever;

  /// No description provided for @recordingOneYear.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get recordingOneYear;

  /// No description provided for @recordingCleanupNow.
  ///
  /// In en, this message translates to:
  /// **'Clean up expired now'**
  String get recordingCleanupNow;

  /// No description provided for @recordingCleanupRunning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning up…'**
  String get recordingCleanupRunning;
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
