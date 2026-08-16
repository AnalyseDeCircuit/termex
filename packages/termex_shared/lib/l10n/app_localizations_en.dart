// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSearch => 'Search...';

  @override
  String get commonEmpty => 'No data';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRetry => 'Retry';

  @override
  String get validatorRequired => 'This field is required';

  @override
  String get validatorEmail => 'Invalid email format';

  @override
  String validatorMinLength(int n) {
    return 'At least $n characters';
  }

  @override
  String validatorMaxLength(int n) {
    return 'At most $n characters';
  }

  @override
  String get themeSaveError => 'Failed to save theme';

  @override
  String get selectNoOptions => 'No options';

  @override
  String get dialogDefaultConfirm => 'Confirm';

  @override
  String get dialogDefaultCancel => 'Cancel';

  @override
  String get shortcutsHintTitle => 'Available Shortcuts';

  @override
  String get crossTabSearchPlaceholder => 'Search across all tabs...';

  @override
  String get crossTabSearchNoMatches => 'No matches';

  @override
  String crossTabSearchMatchesFound(int count) {
    return '$count match(es) found';
  }

  @override
  String get idleLockTitle => 'Locked';

  @override
  String get idleLockHint =>
      'You have been idle. Enter your master password to continue.';

  @override
  String get pluginsTitle => 'Plugins';

  @override
  String get pluginsInstall => 'Install from .zip';

  @override
  String get pluginsDeveloperMode => 'Developer Mode';

  @override
  String get pluginsPermissionTitle => 'Plugin Permission Request';

  @override
  String get pluginsPermissionDeny => 'Deny';

  @override
  String get pluginsPermissionGrantOnce => 'Grant Once';

  @override
  String get pluginsPermissionGrant => 'Grant';

  @override
  String get appName => 'Termex';

  @override
  String get appSlogan => 'Open-source AI-powered local SSH client';

  @override
  String get sidebarServers => 'Servers';

  @override
  String get serverListEmpty => 'No servers yet';

  @override
  String get notificationsSectionTitle => 'Notifications';

  @override
  String get notificationsTestButton => 'Send test notification';

  @override
  String get notificationsTestSent => 'Test notification sent';

  @override
  String get notificationsTestDenied =>
      'Notification permission denied — enable in system settings';

  @override
  String get notificationsTestTitle => 'Termex test';

  @override
  String get notificationsTestBody =>
      'If you can see this, AI task notifications will reach you here.';

  @override
  String get notificationsDemoTaskButton => 'Fire demo task event';

  @override
  String get notificationsDemoTaskTitle => 'Demo task completed';

  @override
  String get notificationsDemoTaskSummary =>
      'Synthetic event from Settings — verifies the bus → notifier path.';

  @override
  String get notificationsDemoTaskSent =>
      'Demo task event published — notification should fire shortly';

  @override
  String get taskDetailHeader => 'Task detail';

  @override
  String get taskDetailUnknownTask => 'Unknown task';

  @override
  String get taskDetailNoSummary => 'No summary available yet.';

  @override
  String get taskDetailOutputComingSoon =>
      'Output and artifacts will appear here once the daemon event stream is wired (v0.79.24+).';

  @override
  String get taskDetailStatusUnknown => 'Unknown';

  @override
  String get taskDetailStatusPending => 'Pending';

  @override
  String get taskDetailStatusAwaitingConfirmation => 'Awaiting confirmation';

  @override
  String get taskDetailStatusRunning => 'Running';

  @override
  String get taskDetailStatusSucceeded => 'Succeeded';

  @override
  String get taskDetailStatusFailed => 'Failed';

  @override
  String get taskDetailStatusCancelled => 'Cancelled';

  @override
  String get taskHistoryHeader => 'Task history';

  @override
  String get taskHistoryEmptyTitle => 'No tasks tracked yet';

  @override
  String get taskHistoryEmptyHint =>
      'Tasks appear here as soon as the daemon or in-app sources publish events. Try the \"Fire demo task event\" button in Settings.';

  @override
  String get taskHistoryEntryAction => 'View task history';

  @override
  String get taskHistoryActionDelete => 'Delete';

  @override
  String get taskHistoryActionClearAll => 'Clear all';

  @override
  String get taskHistoryDeleteConfirmTitle => 'Delete task?';

  @override
  String taskHistoryDeleteConfirmBody(String title) {
    return 'Remove \"$title\" from history. This cannot be undone.';
  }

  @override
  String get taskHistoryClearAllConfirmTitle => 'Clear all tasks?';

  @override
  String taskHistoryClearAllConfirmBody(int count) {
    return 'All $count entries will be removed. This cannot be undone.';
  }

  @override
  String taskSftpUploadSucceededTitle(String fileName) {
    return 'Uploaded $fileName';
  }

  @override
  String taskSftpDownloadSucceededTitle(String fileName) {
    return 'Downloaded $fileName';
  }

  @override
  String taskSftpUploadFailedTitle(String fileName) {
    return 'Upload failed: $fileName';
  }

  @override
  String taskSftpDownloadFailedTitle(String fileName) {
    return 'Download failed: $fileName';
  }

  @override
  String taskSftpUploadCancelledTitle(String fileName) {
    return 'Upload cancelled: $fileName';
  }

  @override
  String taskSftpDownloadCancelledTitle(String fileName) {
    return 'Download cancelled: $fileName';
  }

  @override
  String taskSftpUploadSucceededBody(String size) {
    return 'Upload completed ($size)';
  }

  @override
  String taskSftpDownloadSucceededBody(String size) {
    return 'Download completed ($size)';
  }

  @override
  String taskSftpFailedBody(String action, String error) {
    return '$action failed — $error';
  }

  @override
  String taskSftpCancelledBody(
      String action, String transferred, String total) {
    return '$action cancelled at $transferred of $total';
  }

  @override
  String get taskSftpActionUpload => 'Upload';

  @override
  String get taskSftpActionDownload => 'Download';

  @override
  String get taskPollerSummarySucceeded => 'Task completed successfully';

  @override
  String get taskPollerSummaryFailed => 'Task failed';

  @override
  String taskPollerSummaryFailedWithExit(int exitCode) {
    return 'Task failed (exit $exitCode)';
  }

  @override
  String get taskPollerSummaryCancelled => 'Task cancelled';

  @override
  String get taskPollerSummaryRunning => 'Task started';

  @override
  String get taskPollerSummaryPending => 'Task queued';

  @override
  String get taskPollerSummaryAwaitingConfirmation =>
      'Task awaiting confirmation';

  @override
  String taskAiSucceededTitle(String model) {
    return 'AI reply from $model';
  }

  @override
  String taskAiSucceededTitleWithConversation(
      String conversation, String model) {
    return '$conversation — reply from $model';
  }

  @override
  String get taskAiFailedTitle => 'AI generation failed';

  @override
  String taskAiFailedTitleWithConversation(String conversation) {
    return '$conversation — failed';
  }

  @override
  String get taskAiCancelledTitle => 'AI generation cancelled';

  @override
  String taskAiCancelledTitleWithConversation(String conversation) {
    return '$conversation — cancelled';
  }

  @override
  String get taskAiSucceededBody => 'Response generated';

  @override
  String taskAiSucceededBodyWithLength(int chars) {
    return 'Response generated ($chars chars)';
  }

  @override
  String taskAiSucceededBodyWithTokens(int chars, int tokensIn, int tokensOut) {
    return 'Response generated ($chars chars · ↑$tokensIn ↓$tokensOut tokens)';
  }

  @override
  String taskAiSucceededBodyWithCost(
      int chars, int tokensIn, int tokensOut, String cost) {
    return 'Response generated ($chars chars · ↑$tokensIn ↓$tokensOut tokens · $cost)';
  }

  @override
  String get taskAiFailedBody => 'Generation failed';

  @override
  String taskAiFailedBodyWithError(String error) {
    return 'Generation failed — $error';
  }

  @override
  String get taskAiCancelledBody => 'Generation cancelled';

  @override
  String get notificationThresholdsTitle => 'Notification thresholds';

  @override
  String get notificationThresholdsSftpToggleLabel => 'Notify on SFTP success';

  @override
  String get notificationThresholdsSftpToggleHint =>
      'Disable to silence all SFTP success notifications; failures still notify.';

  @override
  String get notificationThresholdsSizeLabel => 'Minimum file size';

  @override
  String notificationThresholdsSizeValue(double mb) {
    final intl.NumberFormat mbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String mbString = mbNumberFormat.format(mb);

    return '$mbString MB';
  }

  @override
  String get notificationThresholdsDurationLabel => 'Minimum duration';

  @override
  String notificationThresholdsDurationValue(int seconds) {
    return '$seconds s';
  }

  @override
  String get notificationThresholdsHelp =>
      'An SFTP success notifies when EITHER size or duration meets its threshold. Failures and AI completions always notify.';

  @override
  String get notificationThresholdsReset => 'Reset to defaults';

  @override
  String get notificationThresholdsResetDone => 'Reset to defaults';

  @override
  String get notificationThresholdsUndoWindowLabel => 'Undo window';

  @override
  String notificationThresholdsUndoWindowValue(int seconds) {
    return '$seconds s';
  }

  @override
  String get notificationThresholdsUndoWindowOff => 'Off (instant delete)';

  @override
  String get taskHistoryUndoDeleted => 'Deleted';

  @override
  String taskHistoryUndoCleared(int count) {
    return 'Cleared $count entries';
  }

  @override
  String get taskHistoryUndoAction => 'Undo';

  @override
  String get taskHistoryFilterAll => 'All';

  @override
  String get taskHistoryFilterSftp => 'SFTP';

  @override
  String get taskHistoryFilterAi => 'AI';

  @override
  String get taskHistoryFilterOther => 'Other';

  @override
  String get taskHistoryFilterEmptyTitle => 'No tasks match this filter';

  @override
  String get taskHistoryFilterEmptyHint => 'Switch to All to see every task.';

  @override
  String get taskHistorySearchPlaceholder => 'Search by title or summary…';

  @override
  String get taskHistorySearchEmptyTitle => 'No tasks match your search';

  @override
  String get taskHistorySearchEmptyHint =>
      'Clear the search box or adjust your query.';

  @override
  String get taskHistoryActionClearFiltered => 'Clear filtered';

  @override
  String taskHistoryActionClearFilteredWithCount(int count) {
    return 'Clear filtered ($count)';
  }

  @override
  String get taskHistoryClearFilteredConfirmTitle => 'Clear filtered tasks?';

  @override
  String taskHistoryClearFilteredConfirmBody(int count) {
    return 'The $count filtered entries will be removed. Unfiltered tasks stay. This cannot be undone after the window closes.';
  }

  @override
  String taskHistoryRelativeSecondsAgo(int seconds) {
    return '${seconds}s ago';
  }

  @override
  String taskHistoryRelativeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String taskHistoryRelativeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String taskHistoryRelativeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get sidebarSearch => 'Search servers...';

  @override
  String get sidebarNewConnection => 'New Connection';

  @override
  String get sidebarNewGroup => 'New Group';

  @override
  String get sidebarGroupNameHint => 'Enter group name';

  @override
  String get sidebarGroupNameRequired => 'Group name is required';

  @override
  String get sidebarQuickConnect => 'Quick Connect';

  @override
  String get sidebarImportConfig => 'Import Config';

  @override
  String get sidebarExportConfig => 'Export Config';

  @override
  String sidebarBastionUsedBy(String count) {
    return 'Used as bastion by $count connection(s)';
  }

  @override
  String get sidebarImportSshConfig => 'Import SSH Config';

  @override
  String get sidebarSnippets => 'Snippets';

  @override
  String get sidebarRecordings => 'Recordings';

  @override
  String get sidebarCloud => 'Cloud';

  @override
  String get sidebarFilterall => 'All';

  @override
  String get sidebarFilterprivate => 'Private';

  @override
  String get sidebarFilterteam => 'Team';

  @override
  String get sidebarPrivateServers => 'Private';

  @override
  String get sidebarTeamServers => 'Team Nodes';

  @override
  String get sidebarTeamEmptyHint =>
      'Team nodes are synced from your team — they can\'t be created directly.';

  @override
  String get sidebarTeamEmptySync =>
      'Share a private node first, then run a sync to push it to teammates.';

  @override
  String get sidebarGoToPrivate => 'View Private Nodes';

  @override
  String get terminalNewTab => 'New Tab';

  @override
  String get terminalCloseTab => 'Close Tab';

  @override
  String get terminalDisconnect => 'Disconnect';

  @override
  String get terminalReconnect => 'Reconnect';

  @override
  String get terminalReconnecting => 'Reconnecting...';

  @override
  String get terminalReconnected => 'Reconnected';

  @override
  String get terminalReconnectFailed => 'Reconnect failed';

  @override
  String terminalReconnectAttempt(String attempt, String max) {
    return 'Reconnecting... attempt $attempt/$max';
  }

  @override
  String terminalReconnectAttemptFailed(String attempt) {
    return 'Attempt $attempt failed';
  }

  @override
  String terminalReconnectGaveUp(String max) {
    return 'Reconnect failed after $max attempts';
  }

  @override
  String get terminalOpenLocalTerminal => 'Open Local Terminal';

  @override
  String get terminalOpenLocalTerminalError => 'Failed to open terminal';

  @override
  String get terminalSplitVertical => 'Split Right';

  @override
  String get terminalSplitHorizontal => 'Split Down';

  @override
  String get terminalClosePane => 'Close Pane';

  @override
  String get terminalMaxSplitDepth => 'Maximum split depth reached';

  @override
  String get terminalBroadcastOn => 'Broadcast ON';

  @override
  String get terminalBroadcastOff => 'Broadcast';

  @override
  String get terminalBroadcastHintOn => 'Input sent to all panes';

  @override
  String get terminalBroadcastToggle => 'Toggle pane broadcast';

  @override
  String get terminalBroadcastHintOff => 'Enable broadcast mode';

  @override
  String terminalPaneCount(String count) {
    return '$count panes';
  }

  @override
  String terminalMouseReportingHint(String key) {
    return 'Mouse captured by remote app. Hold $key+drag to select and copy text locally.';
  }

  @override
  String terminalMouseReportingActive(String key) {
    return 'Mouse captured · $key+drag to select';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get aiOnboardingHeadline => 'No AI provider configured';

  @override
  String get aiOnboardingBody =>
      'Add a Claude / OpenAI / Gemini API key or a local Ollama endpoint in Settings before starting a conversation.';

  @override
  String get aiOnboardingCta => 'Open Settings → AI';

  @override
  String get aiOnboardingFallbackHint =>
      'Open Settings → AI to add a provider.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsTerminal => 'Terminal';

  @override
  String get settingsKeybindings => 'Keybindings';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsAiConfig => 'AI Config';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsHighlights => 'Highlights';

  @override
  String get settingsProxies => 'Proxies';

  @override
  String get settingsMonitor => 'Monitor';

  @override
  String get settingsTeam => 'Team';

  @override
  String get settingsData => 'Data';

  @override
  String get fontsFontFamily => 'Font Family';

  @override
  String get fontsFontSize => 'Font Size';

  @override
  String get fontsUploadFont => 'Upload Font';

  @override
  String get fontsBuiltIn => 'Built-in Fonts';

  @override
  String get fontsCustom => 'Custom Fonts';

  @override
  String fontsDeleteConfirm(String name) {
    return 'Delete font \"$name\"?';
  }

  @override
  String get fontsDeleteTitle => 'Delete Font';

  @override
  String get fontsUploaded => 'Font uploaded successfully';

  @override
  String get fontsDeleted => 'Font deleted';

  @override
  String get fontsInvalidFormat =>
      'Unsupported format. Use .ttf, .otf, .woff, or .woff2';

  @override
  String get fontsUploadFailed => 'Failed to upload font';

  @override
  String get tabClose => 'Close';

  @override
  String get tabCloseOthers => 'Close Others';

  @override
  String get tabDuplicate => 'Duplicate';

  @override
  String get tabSplitVertical => 'Split Left/Right';

  @override
  String get tabSplitHorizontal => 'Split Top/Bottom';

  @override
  String get tabRename => 'Rename';

  @override
  String get tabRenameHint => 'Enter new name';

  @override
  String get tabReconnect => 'Reconnect';

  @override
  String get tabReconnectAll => 'Reconnect All';

  @override
  String get appearanceTheme => 'Theme';

  @override
  String get appearanceLanguage => 'Language';

  @override
  String get appearanceFollowSystem => 'Follow System';

  @override
  String get appearanceSidebarTransition => 'Sidebar Transition';

  @override
  String get appearanceTransFlip => 'Flip (3D Door)';

  @override
  String get appearanceTransSlide => 'Slide';

  @override
  String get appearanceTransFade => 'Fade';

  @override
  String get appearanceTransScale => 'Scale';

  @override
  String get appearanceTransSlideUp => 'Slide Up';

  @override
  String get appearanceTransNone => 'None';

  @override
  String get sftpTitle => 'SFTP';

  @override
  String get sftpName => 'Name';

  @override
  String get sftpSize => 'Size';

  @override
  String get sftpPermissions => 'Permissions';

  @override
  String get sftpModified => 'Modified';

  @override
  String get sftpGoUp => 'Go Up';

  @override
  String get sftpRefresh => 'Refresh';

  @override
  String get sftpNewFolder => 'New Folder';

  @override
  String get sftpNewFolderPrompt => 'Enter folder name';

  @override
  String get sftpClose => 'Close';

  @override
  String get sftpDelete => 'Delete';

  @override
  String sftpDeleteConfirm(String name) {
    return 'Delete $name?';
  }

  @override
  String get sftpDeleted => 'Deleted';

  @override
  String get sftpRename => 'Rename';

  @override
  String get sftpRenamePrompt => 'Enter new name';

  @override
  String get sftpDownload => 'Download';

  @override
  String get sftpDownloadPrompt => 'Save to local path';

  @override
  String get sftpDownloadStarted => 'Download started';

  @override
  String get sftpUpload => 'Upload';

  @override
  String get sftpUploadStarted => 'Upload started';

  @override
  String get sftpUploadError => 'Upload error';

  @override
  String get sftpTransfers => 'Transfers';

  @override
  String get sftpFiles => 'Files';

  @override
  String get sftpCompleted => 'Completed';

  @override
  String get sftpConnecting => 'Connecting';

  @override
  String get sftpClearCompleted => 'Clear completed';

  @override
  String get sftpNoTransfers => 'No transfers';

  @override
  String get sftpConfirm => 'OK';

  @override
  String get sftpCancel => 'Cancel';

  @override
  String get sftpEmpty => 'Empty directory';

  @override
  String get sftpLocal => 'Local';

  @override
  String get sftpRemote => 'Remote';

  @override
  String get sftpOpenSftp => 'Open SFTP';

  @override
  String get sftpDropToUpload => 'Drop files to upload';

  @override
  String get sftpDropToDownload => 'Drop to download here';

  @override
  String get sftpCwdSyncOn => 'Sync ON — following terminal CWD';

  @override
  String get sftpCwdSyncOff => 'Sync SFTP path with terminal CWD';

  @override
  String get sftpCloseSplit => 'Close split panel';

  @override
  String get sftpNotConnected => 'SFTP not connected';

  @override
  String get sftpDownloadError => 'Download error';

  @override
  String get sftpCleared => 'Cleared completed transfers';

  @override
  String get sftpCopy => 'Copy';

  @override
  String get sftpCut => 'Cut';

  @override
  String get sftpPaste => 'Paste';

  @override
  String get sftpMore => 'More';

  @override
  String get sftpCopyPath => 'Copy Path';

  @override
  String get sftpEditPath => 'Edit Path';

  @override
  String get sftpNewFile => 'New File';

  @override
  String get sftpMkdir => 'New Folder';

  @override
  String get sftpSelectAll => 'Select All';

  @override
  String get sftpChmod => 'Edit Permissions';

  @override
  String get sftpFileInfo => 'File Info';

  @override
  String get sftpEdit => 'Edit';

  @override
  String get sftpType => 'Type';

  @override
  String get sftpDirectory => 'Directory';

  @override
  String get sftpFile => 'File';

  @override
  String get sftpUid => 'UID';

  @override
  String get sftpGid => 'GID';

  @override
  String get sftpSymlink => 'Symbolic Link';

  @override
  String get sftpYes => 'Yes';

  @override
  String get sftpNo => 'No';

  @override
  String get sftpChmodFile => 'File';

  @override
  String get sftpChmodOctal => 'Octal Permissions (e.g., 755)';

  @override
  String get sftpChmodExample => 'e.g. 755';

  @override
  String get sftpChmodHelp =>
      'Octal notation: read=4, write=2, execute=1. Example: 755 = rwxr-xr-x';

  @override
  String get sftpChmodRequired => 'Please enter permissions';

  @override
  String get sftpChmodInvalid => 'Invalid octal value (0-7777)';

  @override
  String get sftpPermissionsUpdated => 'Permissions updated';

  @override
  String get sftpCopied => 'Copied';

  @override
  String get sftpPathCopied => 'Path copied to clipboard';

  @override
  String get sftpFileCreated => 'File created';

  @override
  String get sftpFolderCreated => 'Folder created';

  @override
  String get sftpNewFilePrompt => 'Enter file name';

  @override
  String get sftpSelectAllTodo => 'Multi-select coming soon';

  @override
  String get sftpEditTodo => 'File editing coming soon';

  @override
  String get sftpPreparing => 'Preparing';

  @override
  String get sftpRemove => 'Remove';

  @override
  String get sftpError => 'Error';

  @override
  String get sftpServerTransfer => 'Server transfer started';

  @override
  String sftpTransferError(String error) {
    return 'Transfer failed: $error';
  }

  @override
  String get sftpServerDisconnected => 'Server disconnected';

  @override
  String get sftpDirTransferTodo => 'Directory transfer coming soon';

  @override
  String get aiPanelTitle => 'AI Assistant';

  @override
  String get aiInputPlaceholder => 'Describe what you want to do...';

  @override
  String get aiSend => 'Send';

  @override
  String get aiCopy => 'Copy';

  @override
  String get aiInsert => 'Insert to Terminal';

  @override
  String get aiCopied => 'Copied';

  @override
  String get aiEmptyHint =>
      'Describe in natural language, AI will generate the command';

  @override
  String get aiExplain => 'Explain Command';

  @override
  String get aiDanger => 'Dangerous Command';

  @override
  String aiDangerWarning(String desc) {
    return '⚠️ This command may be risky: $desc';
  }

  @override
  String aiDangerCritical(String desc) {
    return '🚫 Critical danger: $desc';
  }

  @override
  String get aiConfirm => 'Confirm';

  @override
  String get aiCancel => 'Cancel';

  @override
  String get aiClear => 'Clear Chat';

  @override
  String get aiNoProviderHint =>
      'No AI provider configured yet. Please set up one first.';

  @override
  String get aiNoProviderShort => 'Configure AI first';

  @override
  String get aiGoConfig => 'Go to Settings';

  @override
  String get aiSaveAsSnippet => 'Save as Snippet';

  @override
  String get aiIncludeContext => 'Include terminal context';

  @override
  String get aiThinking => 'Thinking...';

  @override
  String get aiErrorDetected => 'Error Detected';

  @override
  String get aiAnalyzing => 'Analyzing error...';

  @override
  String get aiDismiss => 'Dismiss';

  @override
  String get aiCommand => 'Command';

  @override
  String get aiRunFix => 'Run fix';

  @override
  String get aiRunAll => 'Run All';

  @override
  String get aiRun => 'Run';

  @override
  String get aiConfirmRun => 'Confirm & Run';

  @override
  String get aiPlaybook => 'Playbook';

  @override
  String get aiPlaybookGenerating => 'Generating steps...';

  @override
  String aiPlaybookReady(String count) {
    return 'Ready ($count steps)';
  }

  @override
  String get aiStepSuccess => 'Success';

  @override
  String get aiStepFailed => 'Failed';

  @override
  String get aiSummarize => 'Summarize';

  @override
  String get aiSummarizing => 'Generating summary...';

  @override
  String get aiExportMarkdown => 'Export as Markdown';

  @override
  String get aiDiagnosisTitle => 'AI Diagnosis';

  @override
  String get aiAlertCpuThreshold => 'CPU alert threshold (%)';

  @override
  String get aiAlertMemoryThreshold => 'Memory alert threshold (%)';

  @override
  String get aiAlertDiskThreshold => 'Disk alert threshold (%)';

  @override
  String get aiAutoDiagnose => 'Auto-diagnose errors';

  @override
  String get aiAutoDiagnoseHint => 'AI automatically analyzes command errors';

  @override
  String get portForwardTitle => 'Port Forwarding';

  @override
  String get portForwardLocal => 'Local Forward';

  @override
  String get portForwardRemote => 'Remote Forward';

  @override
  String get portForwardDynamic => 'Dynamic Forward';

  @override
  String get portForwardLocalHost => 'Local Host';

  @override
  String get portForwardLocalPort => 'Local Port';

  @override
  String get portForwardRemoteHost => 'Remote Host';

  @override
  String get portForwardRemotePort => 'Remote Port';

  @override
  String get portForwardAutoStart => 'Auto Start';

  @override
  String get portForwardStart => 'Start';

  @override
  String get portForwardStop => 'Stop';

  @override
  String get portForwardAdd => 'Add Rule';

  @override
  String get portForwardDelete => 'Delete';

  @override
  String get portForwardRunning => 'Running';

  @override
  String get portForwardStopped => 'Stopped';

  @override
  String get configExportTitle => 'Export Config';

  @override
  String get configImportTitle => 'Import Config';

  @override
  String get configPassword => 'Export Password';

  @override
  String get configPasswordHint => 'Set a separate export password';

  @override
  String get configFilePath => 'File Path';

  @override
  String get configOnConflict => 'On Conflict';

  @override
  String get configSkip => 'Skip Existing';

  @override
  String get configOverwrite => 'Overwrite';

  @override
  String get configExportSuccess => 'Export successful';

  @override
  String configImportSuccess(String imported, String skipped) {
    return 'Import complete: $imported imported, $skipped skipped';
  }

  @override
  String get connectionEditConnection => 'Edit Connection';

  @override
  String get connectionName => 'Name';

  @override
  String get connectionHost => 'Host';

  @override
  String get connectionPort => 'Port';

  @override
  String get connectionUsername => 'Username';

  @override
  String get connectionPassword => 'Password';

  @override
  String get connectionAuthType => 'Auth Type';

  @override
  String get connectionPrivateKey => 'Private Key';

  @override
  String get connectionBrowseKey => 'Browse File';

  @override
  String get connectionSshAgent => 'SSH Agent';

  @override
  String get connectionSshAgentInfo =>
      'Use system SSH Agent (\$SSH_AUTH_SOCK) for authentication. No private key credentials stored in Termex.';

  @override
  String get connectionGroup => 'Group';

  @override
  String get connectionGroupNone => 'None';

  @override
  String get connectionTags => 'Tags';

  @override
  String get connectionTagsHint => 'comma separated, e.g. production, linux';

  @override
  String get connectionAuthTypePassword => 'Password';

  @override
  String get connectionAuthTypeKey => 'Private Key';

  @override
  String get connectionAuthTypeInteractive => 'Interactive';

  @override
  String get connectionPassphrase => 'Passphrase';

  @override
  String get connectionAuthorizationInfo => 'Authorization';

  @override
  String get connectionSshTunnel => 'SSH Tunnel';

  @override
  String get connectionBastion => 'Bastion / Jump Host';

  @override
  String get connectionBastionHint =>
      'Bastion servers are managed in the sidebar server list. Any saved server can be used as a bastion.';

  @override
  String get connectionSelectBastion => 'Search or select bastion server...';

  @override
  String get connectionConnectionPath => 'Connection Path';

  @override
  String get connectionNoProxyConfigured =>
      'No bastion configured. Will connect directly to target server.';

  @override
  String get connectionRemoveTunnel => 'Remove';

  @override
  String get connectionSave => 'Save';

  @override
  String get connectionCancel => 'Cancel';

  @override
  String get connectionConnect => 'Connect';

  @override
  String get connectionTest => 'Test Connection';

  @override
  String get connectionTesting => 'Testing connection…';

  @override
  String get connectionTestSuccess => 'Connection test successful';

  @override
  String get connectionTestFailed => 'Connection test failed';

  @override
  String get connectionKeySourcePath => 'File path';

  @override
  String get connectionKeySourcePaste => 'Paste content';

  @override
  String get connectionKeyContent => 'Private key content';

  @override
  String get connectionKeyContentPlaceholder =>
      '-----BEGIN OPENSSH PRIVATE KEY-----\n…';

  @override
  String get connectionAddServer => 'Add Server';

  @override
  String get connectionEditServer => 'Edit Server';

  @override
  String get connectionProxy => 'Proxy';

  @override
  String get connectionNetworkProxy => 'Network Proxy';

  @override
  String get connectionNetworkProxyHint =>
      'Proxies are managed in the sidebar Proxy panel. Switch to the Proxy tab in the sidebar to add or edit proxies.';

  @override
  String get connectionProxyNone => 'None (Direct)';

  @override
  String get connectionProxyName => 'Proxy Name';

  @override
  String get connectionProxyType => 'Proxy Type';

  @override
  String get connectionProxySocks5 => 'SOCKS5';

  @override
  String get connectionProxySocks4 => 'SOCKS4';

  @override
  String get connectionProxyHttp => 'HTTP CONNECT';

  @override
  String get connectionProxyHost => 'Proxy Host';

  @override
  String get connectionProxyPort => 'Proxy Port';

  @override
  String get connectionProxyUsername => 'Username';

  @override
  String get connectionProxyPassword => 'Password';

  @override
  String get connectionProxyAdd => 'Add Proxy';

  @override
  String get connectionProxyEdit => 'Edit Proxy';

  @override
  String get connectionProxyDelete => 'Delete Proxy';

  @override
  String connectionProxyDeleteConfirm(String name) {
    return 'Delete proxy \"$name\"? Servers using it will switch to direct connection.';
  }

  @override
  String connectionProxyUsedBy(String count) {
    return 'Used by $count server(s)';
  }

  @override
  String get connectionProxyNoConfig => 'No proxy configured yet.';

  @override
  String get connectionProxyGoSettings =>
      'Go to Settings → Proxies to add one.';

  @override
  String get connectionProxyTestReachable => 'Proxy is reachable';

  @override
  String get connectionProxyTor => 'Tor';

  @override
  String connectionProxyTorRunning(String port) {
    return 'Tor service detected on port $port';
  }

  @override
  String get connectionProxyTorNotFound =>
      'Tor service not detected (install and start Tor first)';

  @override
  String get connectionProxyTlsEnable => 'Enable TLS (HTTPS)';

  @override
  String get connectionProxyTlsVerify => 'Verify Certificate';

  @override
  String get connectionProxyCaCert => 'CA Certificate path (.pem)';

  @override
  String get connectionProxyClientCert => 'Client Certificate path (.pem/.crt)';

  @override
  String get connectionProxyClientKey => 'Client Key path (.pem/.key)';

  @override
  String get connectionProxyCommand => 'ProxyCommand';

  @override
  String get connectionProxyCommandPlaceholder =>
      'e.g. cloudflared access ssh --hostname %h';

  @override
  String get connectionProxyCommandHint =>
      'Variables: %h = hostname, %p = port, %r = username. Executed via sh -c.';

  @override
  String get connectionSync => 'Sync';

  @override
  String get connectionTmuxMode => 'tmux Mode';

  @override
  String get connectionTmuxDisabled => 'Disabled — Normal shell';

  @override
  String get connectionTmuxAuto => 'Auto — Detect and use if available';

  @override
  String get connectionTmuxAlways =>
      'Always — Require tmux (error if unavailable)';

  @override
  String get connectionTmuxCloseAction => 'On Tab Close';

  @override
  String get connectionTmuxDetach => 'Detach — Keep remote session running';

  @override
  String get connectionTmuxKill => 'Kill — Destroy remote session';

  @override
  String get connectionGitSyncEnable => 'Enable Git Auto Sync';

  @override
  String get connectionGitSyncRemotePath => 'Remote Repository Path';

  @override
  String get connectionGitSyncLocalPath => 'Local Repository Path';

  @override
  String get connectionGitSyncMode => 'Sync Mode';

  @override
  String get connectionGitSyncNotify =>
      'Notify Only — Desktop notification on push';

  @override
  String get connectionGitSyncAutoPull =>
      'Auto Pull — Automatically pull to local';

  @override
  String get connectionGitSyncHint =>
      'Ensure your remote .gitignore excludes .env and sensitive files.';

  @override
  String get connectionForwarding => 'Forwarding';

  @override
  String get connectionForwardAdd => 'Add Forward';

  @override
  String get connectionForwardLocal => 'Local Forward';

  @override
  String get connectionForwardDynamic => 'Dynamic Forward (SOCKS5)';

  @override
  String get connectionForwardDynamicHint =>
      'SOCKS5 proxy — all browser traffic routed through remote server';

  @override
  String get connectionForwardNone => 'No forwarding rules configured.';

  @override
  String get contextConnect => 'Connect';

  @override
  String get contextEdit => 'Edit';

  @override
  String get contextDuplicate => 'Duplicate';

  @override
  String get contextRename => 'Rename';

  @override
  String get contextRenameHint => 'Enter new name';

  @override
  String get contextNameRequired => 'Name is required';

  @override
  String get contextMoveTo => 'Move to Group';

  @override
  String get contextUngroup => 'Remove from Group';

  @override
  String get contextDelete => 'Delete';

  @override
  String contextDeleteConfirm(String name) {
    return 'Delete server \"$name\"?';
  }

  @override
  String get contextShareWithTeam => 'Share with Team';

  @override
  String get contextMakePrivate => 'Make Private';

  @override
  String contextDeleteGroupConfirm(String name) {
    return 'Delete group \"$name\"? Servers in this group will become ungrouped.';
  }

  @override
  String get contextNewSubgroup => 'New Subgroup';

  @override
  String get securityProtectionMode => 'Credential Protection';

  @override
  String securityKeychainActive(String platform) {
    return 'Using $platform. All passwords and keys are securely stored in the OS credential manager.';
  }

  @override
  String get securityKeychainUnavailable =>
      'OS keychain is not available. Using local encrypted storage.';

  @override
  String get securityStoredCredentials => 'Protected Credentials';

  @override
  String get securityCredentialHint =>
      'SSH passwords, passphrases, AI API keys';

  @override
  String get securityHowItWorks => 'How it works';

  @override
  String get securityHint1 =>
      'Passwords and keys are stored in the OS credential manager, not in termex.db';

  @override
  String get securityHint2 => 'termex.db only stores keychain reference IDs';

  @override
  String get securityHint3 =>
      'Even if termex.db is leaked, no credentials can be extracted';

  @override
  String get hostKeyTitle => 'Host Key Verification';

  @override
  String get hostKeyWarningTitle => 'WARNING: HOST KEY HAS CHANGED!';

  @override
  String get hostKeyWarningDesc =>
      'The host key for this server has changed. This could indicate a man-in-the-middle attack, or the server may have been reconfigured.';

  @override
  String get hostKeyHost => 'Host';

  @override
  String get hostKeyKeyType => 'Type';

  @override
  String get hostKeyFingerprint => 'Fingerprint';

  @override
  String get hostKeyOldFingerprint => 'Previous fingerprint';

  @override
  String get hostKeyNewFingerprint => 'New fingerprint';

  @override
  String get hostKeyAccept => 'Trust';

  @override
  String get hostKeyAcceptChanged => 'Trust Anyway';

  @override
  String get hostKeyReject => 'Reject';

  @override
  String get keybindingsNewConnection => 'New Connection';

  @override
  String get keybindingsOpenSettings => 'Open Settings';

  @override
  String get keybindingsToggleSidebar => 'Toggle Sidebar';

  @override
  String get keybindingsToggleAi => 'Toggle AI Panel';

  @override
  String get keybindingsCloseTab => 'Close Current Tab';

  @override
  String get keybindingsNextTab => 'Next Tab';

  @override
  String get keybindingsPrevTab => 'Previous Tab';

  @override
  String get keybindingsGoToTab => 'Go to Tab N';

  @override
  String get keybindingsGoToTab1 => 'Go to Tab 1';

  @override
  String get keybindingsGoToTab2 => 'Go to Tab 2';

  @override
  String get keybindingsGoToTab3 => 'Go to Tab 3';

  @override
  String get keybindingsGoToTab4 => 'Go to Tab 4';

  @override
  String get keybindingsGoToTab5 => 'Go to Tab 5';

  @override
  String get keybindingsGoToTab6 => 'Go to Tab 6';

  @override
  String get keybindingsGoToTab7 => 'Go to Tab 7';

  @override
  String get keybindingsGoToTab8 => 'Go to Tab 8';

  @override
  String get keybindingsGoToTab9 => 'Go to Tab 9';

  @override
  String get keybindingsSearch => 'Search Terminal';

  @override
  String get keybindingsSearchAllTabs => 'Search All Tabs';

  @override
  String get keybindingsSplitVertical => 'Split Vertical';

  @override
  String get keybindingsSplitHorizontal => 'Split Horizontal';

  @override
  String get keybindingsClosePaneOrTab => 'Close Pane / Tab';

  @override
  String get keybindingsFocusPaneNext => 'Focus Next Pane';

  @override
  String get keybindingsFocusPanePrev => 'Focus Previous Pane';

  @override
  String get keybindingsFocusPaneUp => 'Focus Pane Above';

  @override
  String get keybindingsFocusPaneDown => 'Focus Pane Below';

  @override
  String get keybindingsFocusPaneLeft => 'Focus Pane Left';

  @override
  String get keybindingsFocusPaneRight => 'Focus Pane Right';

  @override
  String get keybindingsToggleBroadcast => 'Toggle Broadcast';

  @override
  String get keybindingsRecording => 'Press shortcut...';

  @override
  String keybindingsConflict(String action) {
    return 'Already used by \"$action\"';
  }

  @override
  String get keybindingsResetOne => 'Reset to default';

  @override
  String get keybindingsResetAll => 'Reset All';

  @override
  String get keybindingsResetAllConfirm => 'Reset all keybindings to defaults?';

  @override
  String get keybindingsRequireModifier => 'Shortcut must include Cmd/Ctrl';

  @override
  String get keybindingsReserved => 'This shortcut is reserved by the system';

  @override
  String get searchPlaceholder => 'Search...';

  @override
  String get searchNoResults => 'No results';

  @override
  String searchMatchCount(String current, String total) {
    return '$current of $total';
  }

  @override
  String get searchCaseSensitive => 'Match Case';

  @override
  String get searchRegex => 'Regular Expression';

  @override
  String get searchWholeWord => 'Whole Word';

  @override
  String get searchClose => 'Close';

  @override
  String get searchPreviousMatch => 'Previous Match';

  @override
  String get searchNextMatch => 'Next Match';

  @override
  String get searchSearchAllTabs => 'Search All Tabs';

  @override
  String get searchSearchBtn => 'Search';

  @override
  String get searchSearching => 'Searching...';

  @override
  String searchTotalMatches(String count, String tabs) {
    return '$count match(es) in $tabs tab(s)';
  }

  @override
  String get searchNoMatches => 'No matches found';

  @override
  String searchMoreMatches(String count) {
    return '... and $count more match(es)';
  }

  @override
  String get searchLine => 'L';

  @override
  String get searchJumpToMatch => 'Jump to match';

  @override
  String get highlightsTitle => 'Keyword Highlights';

  @override
  String get highlightsPattern => 'Pattern';

  @override
  String get highlightsRegex => 'Regex';

  @override
  String get highlightsCaseSensitive => 'Case';

  @override
  String get highlightsBgColor => 'BG Color';

  @override
  String get highlightsFgColor => 'FG Color';

  @override
  String get highlightsEnabled => 'On';

  @override
  String get highlightsAddRule => 'Add Rule';

  @override
  String get highlightsLoadPresets => 'Load Presets';

  @override
  String get highlightsDeleteRule => 'Delete';

  @override
  String get highlightsDeleteConfirm => 'Delete this highlight rule?';

  @override
  String get highlightsNoRules =>
      'No keyword highlight rules. Click \"Add Rule\" or \"Load Presets\" to get started.';

  @override
  String get highlightsPresetsLoaded => 'Preset rules loaded';

  @override
  String get highlightsPatternRequired => 'Pattern is required';

  @override
  String get highlightsInvalidRegex => 'Invalid regular expression';

  @override
  String get aiConfigAddProvider => 'Add Provider';

  @override
  String get aiConfigNoProviders =>
      'No AI providers yet. Click above to add one.';

  @override
  String get aiConfigProviderName => 'Name';

  @override
  String get aiConfigProviderType => 'Type';

  @override
  String get aiConfigModel => 'Model';

  @override
  String get aiConfigSetDefault => 'Set Default';

  @override
  String get aiConfigDefault => 'Default';

  @override
  String get aiConfigDeleteConfirm => 'Delete this AI provider?';

  @override
  String get aiConfigTest => 'Test';

  @override
  String get aiConfigTestSuccess => 'Connection test successful';

  @override
  String get aiConfigTestFailed => 'Connection test failed';

  @override
  String get aiConfigLanOllama => 'LAN';

  @override
  String get backupTitle => 'Backup & Restore';

  @override
  String get backupExport => 'Export Config';

  @override
  String get backupExportDesc =>
      'Export servers, groups, and settings as an encrypted .termex file';

  @override
  String get backupExportBtn => 'Export';

  @override
  String get backupExportPasswordHint =>
      'Set export password (at least 4 chars)';

  @override
  String get backupExportSuccess => 'Export successful';

  @override
  String get backupPasswordTooShort => 'Password must be at least 4 characters';

  @override
  String get backupImport => 'Import Config';

  @override
  String get backupImportDesc =>
      'Restore config data from an encrypted .termex file';

  @override
  String get backupImportBtn => 'Import';

  @override
  String get backupImportPasswordHint =>
      'Enter the password used during export';

  @override
  String get backupImportSuccess => 'Import successful';

  @override
  String get backupRecordingDir => 'Recording Directory';

  @override
  String get backupRecordingDirDesc =>
      'Terminal session recordings are stored here';

  @override
  String get backupOpenDir => 'Open Directory';

  @override
  String get updateTitle => 'Version Info';

  @override
  String get updateCurrentVersion => 'Current Version';

  @override
  String get updateLatestVersion => 'Latest Version';

  @override
  String get updateChecking => 'Checking for updates...';

  @override
  String get updateUpToDate => 'You\'re running the latest version!';

  @override
  String get updateCheckFailed => 'Update check failed';

  @override
  String get updateReleaseNotes => 'What\'s new';

  @override
  String get updateNoAsset =>
      'No installer available for your platform. Please download manually.';

  @override
  String get updateUpgrade => 'Upgrade';

  @override
  String get updateRetry => 'Retry';

  @override
  String get updateViewRelease => 'View Release';

  @override
  String get updateDownloading => 'Downloading...';

  @override
  String get updateDownloadFailed => 'Download failed';

  @override
  String get updateInstallLaunched =>
      'Installer launched. Termex will close shortly.';

  @override
  String get updateNewVersion => 'New version available';

  @override
  String get keychainVerificationTitle => 'Verify Credentials';

  @override
  String get keychainVerificationMessage =>
      'Your system password may have changed. Please verify to access your saved credentials.';

  @override
  String get keychainVerificationVerify => 'Verify';

  @override
  String get keychainVerificationFailed =>
      'Verification failed. Some credentials may be temporarily inaccessible. You can still use Termex, but you may need to re-enter passwords.';

  @override
  String get autocompleteTitle => 'Smart Autocomplete';

  @override
  String get autocompleteEnabled => 'Enable terminal inline autocomplete';

  @override
  String get autocompleteDebounce => 'Trigger delay';

  @override
  String get autocompleteDebounceUnit => 'ms';

  @override
  String get autocompleteMinChars => 'Minimum characters';

  @override
  String get autocompletePreferLocal => 'Prefer local AI model';

  @override
  String get autocompletePreferLocalHint =>
      'Use local engine when running, lower latency';

  @override
  String get localAiTitle => 'Local AI Models';

  @override
  String get localAiEngineRunning => 'Engine Running';

  @override
  String get localAiEngineStopped => 'Engine Stopped';

  @override
  String get localAiMicroTier => 'Micro (~200MB, 2GB RAM)';

  @override
  String get localAiMicroDesc =>
      'Ultra-lightweight models for minimal resource usage';

  @override
  String get localAiSmallTier => 'Small (~400MB, 4GB RAM)';

  @override
  String get localAiSmallDesc =>
      'Lightweight models for basic command explanation, ideal for low-resource environments';

  @override
  String get localAiMediumTier => 'Medium (~2GB, 8GB RAM)';

  @override
  String get localAiMediumDesc =>
      'Balanced performance and quality, suitable for daily use';

  @override
  String get localAiLargeTier => 'Large (~5GB, 16GB RAM) ⭐ Recommended';

  @override
  String get localAiLargeDesc =>
      'Best quality and capabilities, recommended for optimal experience';

  @override
  String get localAiNotDownloaded => 'Not Downloaded';

  @override
  String get localAiDownloading => 'Downloading';

  @override
  String get localAiDownloaded => 'Downloaded';

  @override
  String get localAiError => 'Error';

  @override
  String get localAiVerifying => 'Verifying';

  @override
  String get localAiSize => 'Size';

  @override
  String get localAiMinRam => 'Min RAM';

  @override
  String get localAiContextLength => 'Context';

  @override
  String get localAiLocalModels => 'Local Models';

  @override
  String get localAiDownload => 'Download';

  @override
  String get localAiCancel => 'Cancel';

  @override
  String get localAiDelete => 'Delete';

  @override
  String get localAiRetry => 'Retry';

  @override
  String get localAiUseAsProvider => 'Use as Provider';

  @override
  String get localAiRecommended => 'Recommended';

  @override
  String localAiDownloadStarted(String name) {
    return 'Download started for $name';
  }

  @override
  String localAiDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get localAiDownloadCancelled => 'Download cancelled';

  @override
  String get localAiDeleted => 'Model deleted';

  @override
  String get localAiAddedAsProvider => 'Added as AI provider';

  @override
  String localAiDeleteConfirm(String name) {
    return 'Delete $name? This cannot be undone.';
  }

  @override
  String get localAiWarning => 'Warning';

  @override
  String get localAiCatalogUpdated =>
      'The model catalog has been updated. Check the Local AI Models section for new models.';

  @override
  String get localAiNoModels =>
      'No local models downloaded yet. Please download a model in the Local AI Models panel.';

  @override
  String get localAiOk => 'OK';

  @override
  String get localAiAutoStarting => 'Starting Local AI';

  @override
  String localAiAutoStartingMsg(String model, String seconds) {
    return 'Auto-starting $model in ${seconds}s... Close to cancel.';
  }

  @override
  String localAiStartingModel(String model) {
    return 'Loading model $model, please wait...';
  }

  @override
  String localAiStartedModel(String model) {
    return 'Local AI started: $model';
  }

  @override
  String localAiReusedInstance(String model) {
    return 'Reusing existing instance: $model';
  }

  @override
  String get localAiStartFailed => 'Failed to start local AI';

  @override
  String get localAiSwitchModel => 'Switch';

  @override
  String get localAiAutoStart => 'Auto-start on launch';

  @override
  String get localAiAutoStartHint =>
      'Automatically start the last used model when Termex opens';

  @override
  String get sshConfigImportTitle => 'Import SSH Config';

  @override
  String get sshConfigImportDescription => 'Import servers from ~/.ssh/config';

  @override
  String get sshConfigPreview => 'Preview';

  @override
  String get sshConfigImporting => 'Importing...';

  @override
  String get sshConfigSelectAll => 'Select All';

  @override
  String get sshConfigDeselectAll => 'Deselect All';

  @override
  String get sshConfigImportButton => 'Import Selected';

  @override
  String get sshConfigImported => 'Imported';

  @override
  String get sshConfigSkipped => 'Skipped';

  @override
  String get sshConfigErrors => 'Errors';

  @override
  String get sshConfigHostAlias => 'Host Alias';

  @override
  String get sshConfigHostname => 'Hostname';

  @override
  String get sshConfigPort => 'Port';

  @override
  String get sshConfigUser => 'User';

  @override
  String get sshConfigAuthType => 'Auth';

  @override
  String get sshConfigAuthKey => 'Key Authentication';

  @override
  String get sshConfigAuthPassword => 'Password Authentication';

  @override
  String get sshConfigNoEntries => 'No SSH config entries found';

  @override
  String get sshConfigParseWarnings => 'Parse Warnings';

  @override
  String sshConfigSelectedCount(String count, String total) {
    return '$count of $total selected';
  }

  @override
  String get sshConfigImport => 'Import';

  @override
  String sshConfigResultSummary(
      String imported, String skipped, String errors) {
    return '$imported imported, $skipped skipped, $errors error(s)';
  }

  @override
  String get sshConfigErrorDetails => 'Error Details';

  @override
  String get sshConfigDone => 'Done';

  @override
  String get sshConfigNonInteractive => 'Non-SSH';

  @override
  String get snippetTitle => 'Snippets';

  @override
  String get snippetSearch => 'Search snippets...';

  @override
  String get snippetCreate => 'New Snippet';

  @override
  String get snippetCreateTitle => 'New Snippet';

  @override
  String get snippetEditTitle => 'Edit Snippet';

  @override
  String get snippetEdit => 'Edit Snippet';

  @override
  String get snippetDelete => 'Delete Snippet';

  @override
  String get snippetDeleteConfirm =>
      'Are you sure you want to delete this snippet?';

  @override
  String get snippetExecute => 'Execute';

  @override
  String get snippetSaveAsSnippet => 'Save as Snippet';

  @override
  String get snippetSave => 'Save';

  @override
  String get snippetCancel => 'Cancel';

  @override
  String get snippetName => 'Title';

  @override
  String get snippetTitleLabel => 'Title';

  @override
  String get snippetTitlePlaceholder => 'Enter snippet title';

  @override
  String get snippetCommand => 'Command';

  @override
  String get snippetCommandLabel => 'Command';

  @override
  String get snippetCommandPlaceholder => 'Enter command...';

  @override
  String get snippetDescription => 'Description';

  @override
  String get snippetDescriptionLabel => 'Description';

  @override
  String get snippetDescriptionPlaceholder => 'Optional description';

  @override
  String get snippetTags => 'Tags';

  @override
  String get snippetTagsLabel => 'Tags';

  @override
  String get snippetTagsPlaceholder => 'Comma-separated tags';

  @override
  String get snippetTagsHint => 'Comma-separated tags';

  @override
  String get snippetFolder => 'Folder';

  @override
  String get snippetFolderLabel => 'Folder';

  @override
  String get snippetFolderNone => 'No folder';

  @override
  String get snippetFavorite => 'Favorite';

  @override
  String get snippetFavoriteLabel => 'Favorite';

  @override
  String get snippetUnfavorite => 'Unfavorite';

  @override
  String get snippetNoSnippets => 'No snippets yet';

  @override
  String get snippetEmpty => 'No snippets yet';

  @override
  String get snippetCreateFirst => 'Create your first snippet';

  @override
  String get snippetNoResults => 'No matching snippets';

  @override
  String get snippetPalette => 'Snippet Palette';

  @override
  String get snippetPaletteSearch => 'Search snippets...';

  @override
  String get snippetVariableTitle => 'Fill Variables';

  @override
  String get snippetVariablesTitle => 'Fill Variables';

  @override
  String get snippetVariableHint => 'Enter values for template variables';

  @override
  String snippetUsageCount(String count) {
    return 'Used $count times';
  }

  @override
  String get snippetAllFolders => 'All';

  @override
  String get snippetAllFolder => 'All';

  @override
  String get snippetNewFolder => 'New Folder';

  @override
  String get snippetFolderName => 'Folder name';

  @override
  String get snippetNavigate => 'Navigate';

  @override
  String get snippetRun => 'Run';

  @override
  String get snippetClose => 'Close';

  @override
  String get monitorTitle => 'Server Monitor';

  @override
  String get monitorCollectionInterval => 'Collection Interval';

  @override
  String get monitorAutoStart => 'Auto-start monitoring on connect';

  @override
  String get monitorVisiblePanels => 'Visible Panels';

  @override
  String get teamTitle => 'Team Collaboration';

  @override
  String get teamDescription =>
      'Share server configs via Git repo. All credentials are encrypted with a team key.';

  @override
  String get teamCreate => 'Create Team';

  @override
  String get teamJoin => 'Join Team';

  @override
  String get teamLeave => 'Leave Team';

  @override
  String get teamLeaveConfirm =>
      'Leave this team? Imported servers will be kept locally but won\'t sync.';

  @override
  String get teamLeftSuccess => 'Left the team';

  @override
  String get teamSync => 'Sync to Cloud';

  @override
  String get teamSyncing => 'Syncing to Cloud...';

  @override
  String teamSyncSuccess(String imported, String exported) {
    return 'Synced: imported $imported, exported $exported';
  }

  @override
  String get teamSyncUpToDate => 'Already up to date';

  @override
  String get teamTeamName => 'Team Name';

  @override
  String get teamPassphrase => 'Team Passphrase';

  @override
  String get teamPassphraseConfirm => 'Confirm Passphrase';

  @override
  String get teamPassphraseHint =>
      'All members need the same passphrase. Share it securely.';

  @override
  String get teamRepoUrl => 'Git Repository URL';

  @override
  String get teamRepoUrlHint => 'SSH (git@...) or HTTPS (https://...)';

  @override
  String get teamGitAuth => 'Git Authentication';

  @override
  String get teamGitAuthSsh => 'SSH Key';

  @override
  String get teamGitAuthToken => 'HTTPS Token';

  @override
  String get teamGitAuthUserPass => 'HTTPS User/Pass';

  @override
  String get teamUsername => 'Your Username';

  @override
  String get teamUsernameHint => 'Display name in the team';

  @override
  String get teamRole => 'Role';

  @override
  String get teamRoleAdmin => 'Admin';

  @override
  String get teamRoleMember => 'Member';

  @override
  String get teamRoleReadonly => 'Read-only';

  @override
  String get teamMembers => 'Members';

  @override
  String get teamMemberManage => 'Manage Members';

  @override
  String get teamMemberRemove => 'Remove Member';

  @override
  String teamMemberRemoveConfirm(String name) {
    return 'Remove $name from the team?';
  }

  @override
  String get teamShareServer => 'Share with Team';

  @override
  String get teamShareServerHint =>
      'Sync this server config to all team members';

  @override
  String teamSharedBy(String name) {
    return 'Shared by $name';
  }

  @override
  String get teamSharedWithTeam => 'Shared with team · will sync on next push';

  @override
  String get teamMakePrivate => 'Make Private';

  @override
  String teamReceivedFrom(String name) {
    return 'Received from $name';
  }

  @override
  String get teamTeamServers => 'Team Nodes';

  @override
  String get teamLastSync => 'Last sync';

  @override
  String get teamNeverSynced => 'Never synced';

  @override
  String get teamJustNow => 'Just now';

  @override
  String get teamMinutesAgo => 'min ago';

  @override
  String get teamPendingChanges => 'Pending changes';

  @override
  String get teamCreateSuccess => 'Team created successfully';

  @override
  String get teamJoinSuccess => 'Joined team successfully';

  @override
  String get teamStep1Info => 'Info';

  @override
  String get teamStep2Repo => 'Repository';

  @override
  String get teamStep3Done => 'Done';

  @override
  String get teamNext => 'Next';

  @override
  String get teamDone => 'Done';

  @override
  String get teamEnterPassphrase => 'Enter Team Passphrase';

  @override
  String get teamPassphraseRequired =>
      'Team passphrase is required to sync shared configurations.';

  @override
  String get teamPassphraseWrong => 'Incorrect team passphrase';

  @override
  String get teamRememberPassphrase => 'Remember passphrase';

  @override
  String get teamRotateKey => 'Rotate Password';

  @override
  String get teamCurrentPassphrase => 'Current passphrase';

  @override
  String get teamNewPassphrase => 'New passphrase';

  @override
  String get teamPassphraseTooShort =>
      'Passphrase must be at least 8 characters';

  @override
  String get teamPassphraseMismatch => 'Passphrases do not match';

  @override
  String get teamRotateKeySuccess => 'Team password rotated successfully';

  @override
  String get recordingTitle => 'Session Recording';

  @override
  String get recordingRetentionPeriod => 'Retention Period';

  @override
  String get recordingRetentionDesc =>
      'Recordings older than this will be cleaned up on startup.';

  @override
  String get recordingDays30 => '30 days';

  @override
  String get recordingDays60 => '60 days';

  @override
  String get recordingDays90 => '90 days';

  @override
  String get recordingKeepForever => 'Keep forever';

  @override
  String get recordingCleanup => 'Clean up expired';

  @override
  String recordingCleanupResult(String count) {
    return 'Cleaned up $count recordings';
  }

  @override
  String get recordingStartRecording => 'Start Recording';

  @override
  String get recordingStopRecording => 'Stop Recording';

  @override
  String get cloudTitle => 'Cloud Resources';

  @override
  String get cloudRefresh => 'Refresh';

  @override
  String get cloudFilterPods => 'Filter pods...';

  @override
  String get cloudFilterInstances => 'Filter instances...';

  @override
  String get cloudKubeClusters => 'K8s Clusters';

  @override
  String get cloudKubeConnect => 'Connect';

  @override
  String get cloudKubeViewLogs => 'View Logs';

  @override
  String get cloudKubePodDetail => 'Pod Details';

  @override
  String get cloudKubeSelectContainer => 'Select container';

  @override
  String get cloudKubeSelectShell => 'Shell';

  @override
  String get cloudKubeNoContexts => 'No clusters configured';

  @override
  String get cloudKubeNoPods => 'No pods in this namespace';

  @override
  String get cloudKubeExecFailed => 'Failed to exec into pod';

  @override
  String get cloudKubeRbacDenied => 'Permission denied. Required: pods/exec';

  @override
  String get cloudSsmTitle => 'AWS SSM';

  @override
  String get cloudSsmConnect => 'Connect';

  @override
  String get cloudSsmNoInstances => 'No reachable instances';

  @override
  String get cloudSsmAgentOffline => 'SSM Agent offline';

  @override
  String get cloudSsmCredExpired =>
      'AWS credentials expired. Run: aws sso login';

  @override
  String get cloudLogsTailLines => 'Tail lines';

  @override
  String get cloudLogsSince => 'Since';

  @override
  String get cloudLogsFollow => 'Follow';

  @override
  String get cloudLogsStreamEnded => 'Log stream ended';

  @override
  String get cloudSetupTitle => 'Cloud Native Setup';

  @override
  String get cloudSetupDesc => 'Connect to K8s clusters and AWS EC2 instances';

  @override
  String get cloudSetupDetected => 'Detected';

  @override
  String get cloudSetupNotInstalled => 'Not installed';

  @override
  String get cloudSetupRefresh => 'Refresh Detection';

  @override
  String get cloudSetupSkip => 'Skip for now';

  @override
  String get cloudInstallCopy => 'Copy install command';

  @override
  String get cloudTimeout => 'Connection timed out';

  @override
  String cloudToolNotFound(String tool) {
    return '$tool not found';
  }

  @override
  String get cloudTeamFavorites => 'Team Cloud Resources';

  @override
  String get cloudNoTeamFavorites =>
      'No team cloud resources yet. Share a K8s context or AWS profile from the private section.';

  @override
  String get teamV2RoleOps => 'Ops';

  @override
  String get teamV2RoleDeveloper => 'Developer';

  @override
  String get teamV2RoleViewer => 'Viewer';

  @override
  String get teamV2RoleCustom => 'Custom Role';

  @override
  String get teamV2ManageRoles => 'Manage Roles';

  @override
  String get teamV2CreateRole => 'Create Role';

  @override
  String get teamV2DeleteRole => 'Delete';

  @override
  String get teamV2DeleteRoleConfirm => 'Delete this custom role?';

  @override
  String get teamV2PresetRoleReadonly => 'preset';

  @override
  String get teamV2CapServerConnect => 'Connect';

  @override
  String get teamV2CapServerCreate => 'Create Server';

  @override
  String get teamV2CapServerEdit => 'Edit Server';

  @override
  String get teamV2CapServerDelete => 'Delete Server';

  @override
  String get teamV2CapServerViewCredentials => 'View Credentials';

  @override
  String get teamV2CapSnippetCreate => 'Create Snippet';

  @override
  String get teamV2CapSnippetEdit => 'Edit Snippet';

  @override
  String get teamV2CapSnippetDelete => 'Delete Snippet';

  @override
  String get teamV2CapSnippetExecute => 'Execute Snippet';

  @override
  String get teamV2CapTeamInvite => 'Invite';

  @override
  String get teamV2CapTeamRemove => 'Remove Member';

  @override
  String get teamV2CapTeamRoleAssign => 'Assign Role';

  @override
  String get teamV2CapTeamSettingsEdit => 'Team Settings';

  @override
  String get teamV2CapSyncPush => 'Push';

  @override
  String get teamV2CapSyncPull => 'Pull';

  @override
  String get teamV2CapAuditView => 'View Audit';

  @override
  String get teamV2CapAuditExport => 'Export Audit';

  @override
  String get teamV2EditRole => 'Edit Role';

  @override
  String teamV2RoleInUse(String count) {
    return 'This role is in use by $count member(s)';
  }

  @override
  String get teamV2CredProtected =>
      'Credentials protected by team permissions.';

  @override
  String get teamV2CredContactAdmin => 'Contact your admin for access.';

  @override
  String get teamV2PasswordUpdated =>
      'Team password was updated. Please enter the new password.';

  @override
  String get teamV2PasswordPendingUpdate => 'Team password needs update';

  @override
  String teamV2ConflictResolved(String count) {
    return 'Resolved $count conflict(s)';
  }

  @override
  String get teamV2NoPermission =>
      'You don\'t have permission for this action.';

  @override
  String teamV2NoPermissionDetail(String capability) {
    return 'Required: $capability';
  }

  @override
  String get teamV2AuditDashboard => 'Audit Dashboard';

  @override
  String get teamV2AuditExportReport => 'Export...';

  @override
  String get teamV2AuditConnections => 'Connections';

  @override
  String get teamV2AuditCredAccess => 'Credentials';

  @override
  String get teamV2AuditConfigChanges => 'Changes';

  @override
  String get teamV2AuditMemberOps => 'Members';

  @override
  String get teamV2AuditRecentOps => 'Recent';

  @override
  String get teamV2AuditViewAll => 'View All';

  @override
  String get teamV2AuditFilterAll => 'All Events';

  @override
  String get teamV2AuditDateRange => 'Date Range';

  @override
  String get teamV2AuditThisWeek => 'This Week';

  @override
  String get teamV2AuditThisMonth => 'This Month';

  @override
  String get teamV2AuditAll => 'All Time';

  @override
  String get teamV2AuditFormatJson => 'JSON';

  @override
  String get teamV2AuditFormatCsv => 'CSV';

  @override
  String get teamV2AuditFormatHtml => 'HTML';

  @override
  String get teamV2InviteMember => 'Invite Member';

  @override
  String get teamV2InviteRole => 'Invite as';

  @override
  String get teamV2InviteExpiry => 'Expires in';

  @override
  String get teamV2InviteGenerate => 'Generate Invite Code';

  @override
  String get teamV2InviteCode => 'Invite Code';

  @override
  String get teamV2InviteCopied => 'Copied';

  @override
  String get teamV2InviteHint =>
      'Send this code and team password separately to the invitee.';

  @override
  String get teamV2InviteExpired => 'Invite code expired';

  @override
  String get teamV2InviteInvalid => 'Invalid invite code';

  @override
  String teamV2InviteDays(String n) {
    return '$n days';
  }

  @override
  String get teamV2JoinViaInvite => 'Invite Code';

  @override
  String get teamV2ConflictTitle => 'Sync Conflicts';

  @override
  String get teamV2ConflictDesc =>
      'The following items have conflicting changes between local and remote:';

  @override
  String get teamV2ConflictLocalVersion => 'Local (You)';

  @override
  String teamV2ConflictRemoteVersion(String user) {
    return 'Remote ($user)';
  }

  @override
  String get teamV2ConflictKeepLocal => 'Keep Local';

  @override
  String get teamV2ConflictUseRemote => 'Use Remote';

  @override
  String get teamV2ConflictSkip => 'Skip';

  @override
  String get teamV2ConflictApply => 'Apply';

  @override
  String get teamV2ConflictAllLocal => 'All Local';

  @override
  String get teamV2ConflictAllRemote => 'All Remote';

  @override
  String teamV2ConflictPending(String count) {
    return '$count conflict(s) need resolution';
  }

  @override
  String get aboutTagline => 'Your always-on cloud AI workspace in the AI era';

  @override
  String aboutUpdateAvailable(String version) {
    return 'Update available v$version';
  }

  @override
  String aboutUpdateReady(String version) {
    return 'Ready to install v$version';
  }

  @override
  String aboutUpdateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get aboutAutoDownload => 'Auto-download updates';

  @override
  String get aboutCheckFrequencyLabel => 'Check frequency:';

  @override
  String get aboutFrequencyHourly => 'Every hour';

  @override
  String get aboutFrequencyDaily => 'Every day';

  @override
  String get aboutFrequencyWeekly => 'Every week';

  @override
  String get aboutCheckNow => 'Check now';

  @override
  String aboutDownloadButton(String version) {
    return 'Download v$version';
  }

  @override
  String get aboutApplyAndRestart => 'Restart & apply';

  @override
  String get aboutWebsite => 'Website';

  @override
  String get aboutSessionPoolTitle => 'Session pool status (debug)';

  @override
  String get aboutSessionPoolHelp =>
      'When multiple servers share the same proxy or jump host the upstream TCP connection is reused; each entry shows ref count and bytes transferred.';

  @override
  String get aboutSessionPoolEmpty => 'No active pool entries';

  @override
  String aboutUpdateDownloadingPercent(String percent) {
    return 'Downloading $percent%';
  }

  @override
  String get commonRefresh => 'Refresh';

  @override
  String commonLoadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String get settingsAi => 'AI Assistant';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAudit => 'Audit log';

  @override
  String get settingsLocalAi => 'Local AI';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsSearchPlaceholder => 'Search settings…';

  @override
  String get settingsSearchNoMatch => 'No matching settings';

  @override
  String get settingsIdxThemeLabel => 'Theme';

  @override
  String get settingsIdxThemeDesc => 'Light / Dark / Follow system';

  @override
  String get settingsIdxFontLabel => 'Font';

  @override
  String get settingsIdxFontDesc => 'Terminal font and size';

  @override
  String get settingsIdxCursorLabel => 'Cursor';

  @override
  String get settingsIdxCursorDesc => 'Cursor shape and blink';

  @override
  String get settingsIdxScrollbackLabel => 'Scrollback';

  @override
  String get settingsIdxScrollbackDesc => 'Terminal history lines';

  @override
  String get settingsIdxTabWidthLabel => 'Tab width';

  @override
  String get settingsIdxTabWidthDesc => '2 / 4 / 8 spaces';

  @override
  String get settingsIdxKeybindingsLabel => 'Shortcuts';

  @override
  String get settingsIdxKeybindingsDesc =>
      'Custom commands and conflict detection';

  @override
  String get settingsIdxAiProviderLabel => 'AI Provider';

  @override
  String get settingsIdxAiProviderDesc => 'Claude / OpenAI / Ollama / Local';

  @override
  String get settingsIdxAiContextLabel => 'AI context';

  @override
  String get settingsIdxAiContextDesc => 'Terminal lines sent to AI';

  @override
  String get settingsIdxTeamPassphraseLabel => 'Team passphrase';

  @override
  String get settingsIdxTeamPassphraseDesc => 'Team sync unlock';

  @override
  String get settingsIdxPrivacyClearLabel => 'Privacy data wipe';

  @override
  String get settingsIdxPrivacyClearDesc =>
      'Connection history / AI conversations / Snippet stats';

  @override
  String get settingsIdxGdprEraseLabel => 'GDPR data erasure';

  @override
  String get settingsIdxGdprEraseDesc => 'Permanently delete all local data';

  @override
  String get settingsIdxBackupLabel => 'Backup import/export';

  @override
  String get settingsIdxBackupDesc => '.termex encrypted file';

  @override
  String get settingsIdxAuditLabel => 'Audit log';

  @override
  String get settingsIdxAuditDesc => 'Event query / CSV export';

  @override
  String get settingsIdxLocalAiLabel => 'Local AI';

  @override
  String get settingsIdxLocalAiDesc => 'llama-server port and model';

  @override
  String get settingsIdxAboutLabel => 'About';

  @override
  String get settingsIdxAboutDesc => 'Version and license';

  @override
  String get backupAutoFreqLabel => 'Auto-backup frequency';

  @override
  String get backupAutoFreqHint =>
      'How often .termex encrypted backups are generated';

  @override
  String get backupFreqOff => 'Off';

  @override
  String get backupFreqDaily => 'Daily';

  @override
  String get backupFreqWeekly => 'Weekly';

  @override
  String get backupEncryptionNote =>
      '.termex backups use AES-256-GCM + Argon2id encryption.';

  @override
  String get backupNow => 'Backup now';

  @override
  String get backupImportConfig => 'Import config';

  @override
  String get backupEnterEncryptPassword => 'Enter encryption password';

  @override
  String get backupEnterDecryptPassword => 'Enter decryption password';

  @override
  String backupDone(String file) {
    return 'Backup complete: $file';
  }

  @override
  String backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get backupPasswordHint => 'Password (12+ characters)';

  @override
  String get backupConfirm => 'OK';

  @override
  String get backupHistoryTitle => 'Backup history';

  @override
  String get backupHistoryClear => 'Clear';

  @override
  String backupHistoryMaxNote(String max) {
    return 'Keeping the latest $max records';
  }

  @override
  String get backupHistoryEmpty => 'No backup records yet';

  @override
  String get cloudTabScheduledBackup => 'Scheduled backup';

  @override
  String get cloudK8sSelectContext => 'Select a context to view pods';

  @override
  String get cloudK8sColName => 'Name';

  @override
  String get cloudK8sColStatus => 'Status';

  @override
  String get cloudK8sColRestarts => 'Restarts';

  @override
  String get cloudK8sColAge => 'Age';

  @override
  String get cloudK8sColImage => 'Image';

  @override
  String get cloudSsmEmpty => 'No SSM instances found';

  @override
  String get cloudSsmStartSession => 'Start session';

  @override
  String get cloudEcsFavoritesTitle => 'ECS favorites';

  @override
  String get cloudEcsAdd => 'Add';

  @override
  String get cloudEcsFavoritesEmpty => 'No favorited ECS instances';

  @override
  String get cloudEcsConnect => 'Connect';

  @override
  String get cloudScheduleTitle => 'Scheduled backup';

  @override
  String get cloudScheduleNew => 'New';

  @override
  String get cloudScheduleEmpty => 'No scheduled backups configured';

  @override
  String get cloudHistoryEmpty => 'No backup records';

  @override
  String cloudScheduleWeekly(String weekday, String hour, String minute) {
    return 'Every $weekday · $hour:$minute UTC';
  }

  @override
  String cloudScheduleMonthly(String day, String hour, String minute) {
    return 'Every ${day}th · $hour:$minute UTC';
  }

  @override
  String cloudScheduleDaily(String hour, String minute) {
    return 'Daily · $hour:$minute UTC';
  }

  @override
  String get cloudScheduleRunNow => 'Run now';

  @override
  String get cloudScheduleDelete => 'Delete';

  @override
  String get privacyDialogTitle => 'Privacy Policy';

  @override
  String get privacyEffectiveDate => 'Effective · 2026-05-07';

  @override
  String get privacyClose => 'Close';

  @override
  String get privacySec1Heading => '1. Overview';

  @override
  String get privacySec1Body =>
      'Termex is an open-source SSH client. We take your privacy seriously: this app does not collect, transmit, or store any user data on Termex servers — Termex has no backend servers.';

  @override
  String get privacySec2Heading => '2. Data Storage';

  @override
  String get privacySec2Body =>
      'All data is stored only on your device:\n· Server configs: local SQLite, SQLCipher AES-256 encryption.\n· SSH passwords / key passphrases: system Keychain (macOS) / Credential Manager (Windows) / Secret Service (Linux).\n· AI API keys: same — stored in the system Keychain.\n· Session recordings: local filesystem.\n· Monitor history: local SQLite, SQLCipher encrypted.';

  @override
  String get privacySec3Heading => '3. Network Connections';

  @override
  String get privacySec3Body =>
      'Termex only establishes these network connections:\n· SSH connections: direct to the server you specify; no intermediate nodes.\n· AI requests: direct to the AI provider you configure (OpenAI, Anthropic, etc.); Termex never acts as a proxy or relay.\n· App updates: queries the official appcast feed for version information.';

  @override
  String get privacySec4Heading => '4. Team Sync (Optional)';

  @override
  String get privacySec4Body =>
      'If you enable team features, Termex syncs encrypted configs via the Git repository you specify. Termex is not a sync server; all data is encrypted with the team key before transmission.';

  @override
  String get privacySec5Heading => '5. Your Rights (GDPR / CCPA)';

  @override
  String get privacySec5Body =>
      'Because Termex collects no personal data:\n· Data access / export: all data is locally readable.\n· Data deletion: Settings → Privacy → Erase all data.\n· Data portability: Settings → Data → Export encrypted backup.';

  @override
  String get privacySec6Heading => '6. Contact';

  @override
  String get privacySec6Body =>
      'The full privacy policy lives at docs/privacy-policy.md in the project repository. For privacy-related questions please contact us via GitHub Issues.';

  @override
  String get proxiesTitle => 'Proxy configurations';

  @override
  String get proxiesAddProxy => 'Add proxy';

  @override
  String get proxiesEmpty =>
      'No proxies configured\nClick \'Add proxy\' to create an HTTP or SOCKS5 proxy';

  @override
  String get proxiesDefault => 'Default';

  @override
  String get proxiesTestConn => 'Test connection';

  @override
  String get proxiesTestOk => 'Proxy connection OK ✓';

  @override
  String get proxiesTestFail => 'Proxy connection failed';

  @override
  String proxiesTestError(String error) {
    return 'Test failed: $error';
  }

  @override
  String get proxiesSetDefault => 'Set as default';

  @override
  String get proxiesDelete => 'Delete';

  @override
  String get proxiesDialogName => 'Name';

  @override
  String get proxiesDialogType => 'Type';

  @override
  String get proxiesDialogHost => 'Host';

  @override
  String get proxiesDialogPort => 'Port';

  @override
  String get proxiesDialogUsername => 'Username';

  @override
  String get proxiesDialogPassword => 'Password';

  @override
  String get proxiesDialogOptional => '(optional)';

  @override
  String get proxiesDialogAdd => 'Add';

  @override
  String get proxiesDefaultName => 'Proxy';

  @override
  String get gitSyncExtraReposTitle => 'Additional repositories';

  @override
  String get gitSyncNoExtraRepos => 'No additional repositories';

  @override
  String get gitSyncAddRepo => 'Add repository';

  @override
  String get gitSyncAddDialogTitle => 'Add Git Sync repository';

  @override
  String get gitSyncLocalPath => 'Local path';

  @override
  String get gitSyncRemoteUrl => 'Remote URL';

  @override
  String get gitSyncRemoteUrlGitSsh => 'Remote URL (git/ssh)';

  @override
  String get gitSyncAdd => 'Add';

  @override
  String get gitSyncManualSync => 'Manual sync';

  @override
  String get gitSyncEnable => 'Enable';

  @override
  String get gitSyncRowLocal => 'Local';

  @override
  String get gitSyncRowRemote => 'Remote';

  @override
  String get gitSyncRowLastSync => 'Last sync';

  @override
  String gitSyncResolveConflicts(String count) {
    return 'Resolve conflicts ($count)';
  }

  @override
  String get gitSyncEnableDialogTitle => 'Enable Git Sync';

  @override
  String get gitSyncLocalRepoPath => 'Local repo path';

  @override
  String gitSyncRowError(String message) {
    return 'Error: $message';
  }

  @override
  String get sftpSortNameAsc => 'Name ↑';

  @override
  String get sftpSortNameDesc => 'Name ↓';

  @override
  String get sftpSortSizeDesc => 'Size';

  @override
  String get sftpSortModifiedDesc => 'Modified';

  @override
  String get sftpSortTypeFirst => 'Type';

  @override
  String get sftpShowHidden => 'Show hidden';

  @override
  String get sftpSortTooltip => 'Sort';

  @override
  String get sftpColName => 'Name';

  @override
  String get sftpColSize => 'Size';

  @override
  String get sftpColModified => 'Modified';

  @override
  String get sftpColPermissions => 'Permissions';

  @override
  String get sftpEmptyDir => '(empty directory)';

  @override
  String get sftpActionDownload => 'Download';

  @override
  String get sftpActionRename => 'Rename';

  @override
  String get sftpActionDelete => 'Delete';

  @override
  String get sftpActionChmod => 'Change permissions';

  @override
  String get sftpActionNewFile => 'New file';

  @override
  String get sftpActionNewFolder => 'New folder';

  @override
  String get sftpActionProperties => 'Properties';

  @override
  String get teamOfflineToast => 'Network unreachable, entering offline mode';

  @override
  String get teamLeaveTitle => 'Leave team';

  @override
  String get teamLeaveBody =>
      'Leaving will delete all local team data — this cannot be undone.';

  @override
  String get teamStatMembers => 'Members';

  @override
  String get teamStatSharedServers => 'Shared servers';

  @override
  String get teamStatSharedProxies => 'Shared proxies';

  @override
  String get teamOfflineBanner => 'Offline — local browse only';

  @override
  String get teamMyRole => 'My role';

  @override
  String teamConflictsCount(String count) {
    return '$count sync conflicts — tap to resolve';
  }

  @override
  String teamItemsCount(String count) {
    return '$count items';
  }

  @override
  String get teamSyncNow => 'Sync now';

  @override
  String get teamRelJustNow => 'just now';

  @override
  String teamRelMinutesAgo(String n) {
    return '$n minutes ago';
  }

  @override
  String teamRelHoursAgo(String n) {
    return '$n hours ago';
  }

  @override
  String teamRelDaysAgo(String n) {
    return '$n days ago';
  }

  @override
  String get teamLeaveButton => 'Leave team';

  @override
  String get teamDashLocked => 'Team features locked';

  @override
  String get teamDashUnlock => 'Unlock team';

  @override
  String get teamDashMembersTitle => 'Team members';

  @override
  String teamDashMemberCount(String count) {
    return '$count member(s)';
  }

  @override
  String teamDashLastSyncShort(String ago) {
    return 'Last sync: $ago';
  }

  @override
  String get teamDashInviteMember => 'Invite member';

  @override
  String teamDashConflictsShort(String count) {
    return '$count sync conflicts';
  }

  @override
  String get teamDashPendingInvites => 'Pending invites';

  @override
  String get teamDashSyncShort => 'Sync';

  @override
  String get teamDashResolve => 'Resolve';

  @override
  String get teamDashRevokeInvite => 'Revoke invite';

  @override
  String get recordingCleanupDone => 'Cleaned up expired recording files';

  @override
  String recordingCleanupFailed(String error) {
    return 'Cleanup failed: $error';
  }

  @override
  String get recordingSaveSettings => 'Recording save settings';

  @override
  String get recordingFormat => 'Recording format';

  @override
  String get recordingFormatJsonSubtitle =>
      'Structured JSON format, plays back in asciinema players\nCompact, recommended for sharing';

  @override
  String get recordingFormatRawSubtitle =>
      'Raw terminal byte stream, suitable for offline replay\nLarger, keeps the full output';

  @override
  String get recordingStorageNote =>
      'Recordings are saved under the recordings/ folder of the app data directory.\nFiles older than the retention period are cleaned up at every startup.';

  @override
  String get recordingRetentionForever => 'Keep forever';

  @override
  String get recordingRetentionNone => 'Do not keep';

  @override
  String recordingRetentionDays(String days) {
    return '$days days';
  }

  @override
  String get recordingRetentionTitle => 'Recording retention';

  @override
  String get recordingForever => 'Forever';

  @override
  String get recordingOneYear => '1 year';

  @override
  String get recordingCleanupNow => 'Clean up expired now';

  @override
  String get recordingCleanupRunning => 'Cleaning up…';

  @override
  String get keybindingsNewTab => 'New Tab';

  @override
  String get keybindingsClosePane => 'Close Pane';

  @override
  String get keybindingsCopy => 'Copy';

  @override
  String get keybindingsPaste => 'Paste';

  @override
  String get keybindingsSelectAll => 'Select All';

  @override
  String get keybindingsZoomIn => 'Zoom In';

  @override
  String get keybindingsZoomOut => 'Zoom Out';

  @override
  String get keybindingsResetZoom => 'Reset Zoom';

  @override
  String get keybindingsCommandPalette => 'Command Palette';

  @override
  String get keybindingsAiDiagnose => 'AI Diagnose';

  @override
  String get keybindingsNl2cmd => 'Natural Language to Command';

  @override
  String get keybindingsSftpPanel => 'SFTP Panel';

  @override
  String get keybindingsSftpUpload => 'SFTP Upload';

  @override
  String get keybindingsSftpDownload => 'SFTP Download';

  @override
  String get keybindingsToggleSftp => 'Toggle SFTP';

  @override
  String get keybindingsReloadWindow => 'Reload Window';

  @override
  String get keybindingsToggleFullscreen => 'Toggle Fullscreen';

  @override
  String get sidebarProxies => 'Proxies';

  @override
  String get keybindingsUntranslated => '(untranslated)';

  @override
  String get settingsTerminalScrollback => 'Scrollback lines';

  @override
  String get settingsTerminalScrollbackHint =>
      'Maximum number of history lines to keep for scrollback';

  @override
  String settingsTerminalLinesOption(String count) {
    return '$count lines';
  }

  @override
  String get settingsTerminalTabWidth => 'Tab width';

  @override
  String settingsTerminalSpacesOption(String count) {
    return '$count spaces';
  }

  @override
  String get settingsTerminalCursorShape => 'Cursor shape';

  @override
  String get settingsTerminalCursorBlock => 'Block';

  @override
  String get settingsTerminalCursorUnderline => 'Underline';

  @override
  String get settingsTerminalCursorBar => 'Bar';

  @override
  String get settingsTerminalCursorBlink => 'Cursor blink';

  @override
  String get settingsTerminalTmux => 'Tmux multiplexing';

  @override
  String get settingsTerminalTmuxHint =>
      'Detect remote tmux sessions and show them in the status bar';

  @override
  String get settingsAiAllConfigured => 'All providers are already configured';

  @override
  String get settingsAiContextLines => 'Default context lines';

  @override
  String get settingsAiContextLinesHint =>
      'Maximum terminal history lines sent to the AI';

  @override
  String get settingsAiAutoDiagnose => 'Auto error diagnosis';

  @override
  String get settingsAiAutoDiagnoseHint =>
      'Automatically run AI analysis when a command fails';

  @override
  String settingsAiRemoveProviderTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String settingsAiRemoveProviderHint(String name) {
    return 'Removes the local configuration for $name (the API key stays in the OS keychain and is reloaded automatically when you configure it again).';
  }

  @override
  String get settingsAiRemove => 'Remove';

  @override
  String get settingsAiEmptyTitle => 'No AI provider configured yet';

  @override
  String get settingsAiEmptyHint =>
      'Click “Add Provider” at the top right to get started';

  @override
  String get settingsAiBadgeActive => 'Active';

  @override
  String get settingsAiBadgeConfigured => 'Configured';

  @override
  String get settingsAiActivate => 'Activate';

  @override
  String get settingsAiCollapse => 'Collapse';

  @override
  String get settingsAiConfigure => 'Configure';

  @override
  String get settingsAiAddProvider => 'Add Provider';

  @override
  String get settingsAiPricingTitle => 'AI cost estimation price list';

  @override
  String settingsAiPricingUpdated(String iso, String age) {
    return 'Updated $iso · $age';
  }

  @override
  String get settingsAiPricingStale => ' · refresh recommended';

  @override
  String get settingsAiPricingDateUnknown => 'date unknown';

  @override
  String get settingsAiPricingToday => 'updated today';

  @override
  String settingsAiPricingDaysAgo(String count) {
    return '$count days ago';
  }

  @override
  String get settingsKeybindingsResetTitle => 'Restore default shortcuts?';

  @override
  String get settingsKeybindingsResetBody =>
      'All custom shortcuts will be overwritten with the factory defaults.';

  @override
  String get settingsKeybindingsReset => 'Restore';

  @override
  String get settingsKeybindingsColCommand => 'Command';

  @override
  String get settingsKeybindingsColShortcut => 'Shortcut';

  @override
  String get settingsKeybindingsColContext => 'Context';

  @override
  String get settingsKeybindingsResetTooltip => 'Restore defaults';

  @override
  String get gitConflictTitle => '⚠ Git Sync conflict';

  @override
  String get gitConflictFilesLabel => 'The following files have conflicts:';

  @override
  String get gitConflictStrategyLabel => 'Choose a resolution strategy:';

  @override
  String get gitConflictResolveInTerminal => 'Resolve in terminal';

  @override
  String get gitConflictUseRemote => 'Use remote';

  @override
  String get gitConflictKeepLocal => 'Keep local';

  @override
  String sftpChmodTitleNamed(String name) {
    return 'Change permissions: $name';
  }

  @override
  String get sftpChmodOwner => 'Owner';

  @override
  String get sftpChmodGroup => 'Group';

  @override
  String get sftpChmodOthers => 'Others';

  @override
  String get sftpChmodOctalShort => 'Octal';

  @override
  String get sftpChmodRead => 'Read';

  @override
  String get sftpChmodWrite => 'Write';

  @override
  String get sftpChmodExec => 'Execute';

  @override
  String get sftpRenameEmpty => 'Name cannot be empty';

  @override
  String get sftpRenameSlash => 'Name cannot contain /';

  @override
  String get sftpRenameNewName => 'New name';

  @override
  String get settingsHighlightsTitle => 'Keyword highlighting';

  @override
  String get settingsHighlightsLoadPresets => 'Load presets';

  @override
  String get settingsHighlightsAddRule => '+ Add rule';

  @override
  String get settingsHighlightsEmpty => 'No highlight rules configured yet';

  @override
  String get settingsHighlightsPatternHint => 'Keyword / regex';

  @override
  String get settingsHighlightsRegex => 'Regex';

  @override
  String get settingsHighlightsCaseSensitive => 'Case sensitive';

  @override
  String get settingsHighlightsBgColor => 'Background color';

  @override
  String get settingsHighlightsFgColor =>
      'Foreground color (empty = follow theme)';

  @override
  String get settingsHighlightsEnabled => 'Enabled';

  @override
  String get settingsHighlightsColorInputHint =>
      'Enter a hex color (e.g. #6366F1)';

  @override
  String get settingsHighlightsColorClear => 'Clear';

  @override
  String get settingsHighlightsColorConfirm => 'OK';

  @override
  String get settingsPrivacyClearHistoryTitle => 'Clear history data';

  @override
  String get settingsPrivacyClearHistoryHint =>
      'Keeps account settings and credentials; only clears the corresponding history.';

  @override
  String get settingsPrivacyClearConnections =>
      'Clear recent connection history';

  @override
  String get settingsPrivacyClearConnectionsMsg =>
      'This will delete all \"recent connections\" records. Saved server configurations are not affected.';

  @override
  String get settingsPrivacyClearedConnections => 'Connection history cleared';

  @override
  String get settingsPrivacyClearAi => 'Clear AI conversation history';

  @override
  String get settingsPrivacyClearAiMsg =>
      'This will permanently delete all AI conversations and messages. Provider configs / API keys are kept.';

  @override
  String get settingsPrivacyClearedAi => 'AI conversation history cleared';

  @override
  String get settingsPrivacyClearSnippet => 'Clear snippet usage stats';

  @override
  String get settingsPrivacyClearSnippetMsg =>
      'This will reset the usage count of all snippets. The snippets themselves are kept.';

  @override
  String get settingsPrivacyClearedSnippet => 'Usage stats cleared';

  @override
  String get settingsPrivacyGdprTitle => 'GDPR data erasure';

  @override
  String get settingsPrivacyGdprHint =>
      'Permanently delete all local data (server configs, credentials, conversations, settings). This action cannot be undone.';

  @override
  String get settingsPrivacyGdprButton => 'Erase all data';

  @override
  String get settingsPrivacyConfirmClear => 'Clear';

  @override
  String get settingsPrivacyGdprDialogTitle => 'Confirm erasing all data';

  @override
  String get settingsPrivacyGdprDialogBody =>
      'This action will permanently delete all data and cannot be undone.\nEnter your master password and type \"DELETE ALL\" to confirm.';

  @override
  String get settingsPrivacyMasterPassword => 'Master password';

  @override
  String get settingsPrivacyConfirmTextLabel => 'Confirmation text';

  @override
  String get settingsPrivacyErase => 'Erase';

  @override
  String get settingsPrivacyEraseError =>
      'Confirmation text is incorrect or the master password is wrong';

  @override
  String get settingsPrivacyErased => 'Data erased';

  @override
  String get settingsSecurityLoading => 'Loading…';

  @override
  String get settingsSecurityLoadError => 'Unable to read security status';

  @override
  String get settingsSecurityProtectionTitle => 'Key protection mode';

  @override
  String settingsSecurityProtectionActive(String platform) {
    return 'Credentials are securely stored using $platform. Termex reads the master key entry only once at startup.';
  }

  @override
  String get settingsSecurityProtectionFallback =>
      'System keychain unavailable; fell back to local encryption (AES-256-GCM + Argon2id).';

  @override
  String get settingsSecuritySavedCredentials => 'Saved credentials';

  @override
  String get settingsSecurityCredentialTypes =>
      'Includes SSH passwords, SSH private key passphrases, AI provider API keys';

  @override
  String get settingsSecurityHowItWorks => 'How it works';

  @override
  String get settingsSecurityHint1 =>
      'Credentials are never written to the database in plaintext — only a reference ID from the system keychain is stored';

  @override
  String get settingsSecurityHint2 =>
      'The master key entry is read only once per startup, avoiding repeated system password prompts';

  @override
  String get settingsSecurityHint3 =>
      'GDPR data erasure also clears all Termex entries in the keychain';

  @override
  String get auditDetailTitle => 'Audit Detail';

  @override
  String get auditFieldEventType => 'Event Type';

  @override
  String get auditFieldTime => 'Time';

  @override
  String get auditFieldDetail => 'Detail';

  @override
  String get auditCopyDetail => 'Copy Detail';

  @override
  String get auditKpiTotal => 'Total';

  @override
  String get auditKpiConnections => 'Connections';

  @override
  String get auditKpiCredentialAccess => 'Credential Access';

  @override
  String get auditKpiConfigChanges => 'Config Changes';

  @override
  String get auditKpiMemberOps => 'Member Ops';

  @override
  String get auditColEvent => 'Event';

  @override
  String get auditPagerPrev => 'Previous';

  @override
  String get auditPagerNext => 'Next';

  @override
  String get auditEmptyTitle => 'No audit logs';

  @override
  String get auditEmptyHint =>
      'SSH connections, settings changes, or team operations will be written to the audit log';

  @override
  String get auditExport => 'Export';

  @override
  String get auditExportCsv => 'Export CSV';

  @override
  String get auditExportJson => 'Export JSON';

  @override
  String auditExported(String path) {
    return 'Exported $path';
  }

  @override
  String auditExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get auditLabelDate => 'Date: ';

  @override
  String get auditLabelEvent => 'Event: ';

  @override
  String get auditRangeToday => 'Today';

  @override
  String get auditRangeWeek => 'This Week';

  @override
  String get auditRangeMonth => 'This Month';

  @override
  String get auditRangeAll => 'All';

  @override
  String snippetUsageTimes(int count) {
    return '$count times';
  }

  @override
  String get snippetCopy => 'Copy';

  @override
  String get snippetCopiedToClipboard => 'Copied to clipboard';

  @override
  String get snippetDeleteTitle => 'Delete Snippet';

  @override
  String snippetDeleteConfirmNamed(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get snippetNewTitle => 'New Snippet';

  @override
  String get snippetEditSnippet => 'Edit Snippet';

  @override
  String get snippetNamePlaceholder => 'Snippet name';

  @override
  String get snippetTagsCommaLabel => 'Tags (comma-separated)';

  @override
  String get snippetTagsPlaceholderExample => 'ssh, common, docker';

  @override
  String get snippetContentLabel =>
      'Command (use ｛｛name:default｝｝ to insert a variable)';

  @override
  String snippetVariableTitleNamed(String title) {
    return 'Fill variables — $title';
  }

  @override
  String get snippetPreview => 'Preview';

  @override
  String get snippetConfirmExecute => 'Confirm & Run';

  @override
  String snippetVariableDefault(String value) {
    return 'Default: $value';
  }

  @override
  String get snippetVariableInputHint => 'Enter a value';

  @override
  String get snippetSearchPlaceholder => 'Search snippets…';

  @override
  String get snippetNoMatch => 'No matching snippets';

  @override
  String get sftpPath => 'Path';

  @override
  String get sftpOwner => 'Owner';

  @override
  String get sftpGroup => 'Group';

  @override
  String sftpSizeBytes(int bytes) {
    return '$bytes bytes';
  }

  @override
  String get sftpFileNameHint => 'File name';

  @override
  String get sftpFolderNameHint => 'Folder name';

  @override
  String get sftpCreate => 'Create';

  @override
  String sftpEditorTooLarge(String size) {
    return 'File too large ($size); use scp to download and edit locally.';
  }

  @override
  String get sftpEditorBinary =>
      'Binary content detected; cannot use the inline editor.';

  @override
  String sftpEditorReadFailed(String error) {
    return 'Read failed: $error';
  }

  @override
  String sftpEditorSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get sftpEditorModified => 'Modified';

  @override
  String get sftpTransferResume => 'Resume';

  @override
  String get sftpTransferPause => 'Pause';

  @override
  String get sftpTransferDone => 'Done';

  @override
  String sftpTransferFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get sftpTransferCancelled => 'Cancelled';

  @override
  String get sftpTransferPaused => 'Paused';

  @override
  String get aiConversationsTitle => 'Conversations';

  @override
  String get aiConversationEmpty => 'Tap + to start a new conversation';

  @override
  String get aiRenameConversation => 'Rename Conversation';

  @override
  String get aiRenameHint => 'Enter a new title';

  @override
  String get aiModelListLoading => 'Loading model list…';

  @override
  String get aiDeleteModelTitle => 'Delete Model';

  @override
  String aiDeleteModelConfirm(String name) {
    return 'Delete $name?';
  }

  @override
  String get localAiRunning => 'Running';

  @override
  String get localAiStart => 'Start';

  @override
  String localAiDownloadWithSize(String size) {
    return 'Download ($size)';
  }

  @override
  String get aiNl2cmdTitle => 'Natural Language → Command';

  @override
  String get aiNl2cmdHint =>
      'Describe what you want to do, e.g. find files larger than 100MB';

  @override
  String get aiNl2cmdSent => '(Sent to AI conversation)';

  @override
  String get aiNl2cmdGenerate => 'Generate';

  @override
  String settingsAiConfigureTitle(String name) {
    return 'Configure $name';
  }

  @override
  String get settingsAiTerminalContextLines => 'Terminal context lines';

  @override
  String settingsAiLinesUnit(int count) {
    return '$count lines';
  }

  @override
  String get settingsAiVerify => 'Verify';

  @override
  String get settingsAiSelectModelError => 'Please select a model';

  @override
  String get settingsAiApiKeyRequired => 'Please enter an API Key';

  @override
  String get settingsAiVerifySuccess => 'Verification succeeded';

  @override
  String get settingsAiVerifyFailed => 'Verification failed';

  @override
  String get settingsAiLlamaEngine => 'llama-server engine';

  @override
  String get settingsAiServerPort => 'Server port';

  @override
  String get settingsAiInferenceThreads => 'Inference threads';

  @override
  String get settingsAiContextWindow => 'Context window (tokens)';

  @override
  String get settingsAiAutoStartEngine => 'Auto-start engine on launch';

  @override
  String teamSyncDoneCount(int count) {
    return 'Sync complete ($count changes)';
  }

  @override
  String teamSyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get teamApplied => 'Applied';

  @override
  String teamResolveFailed(String error) {
    return 'Resolve failed: $error';
  }

  @override
  String get teamRoleUpdated => 'Role updated';

  @override
  String teamUpdateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get teamRemoved => 'Removed';

  @override
  String teamRemoveFailed(String error) {
    return 'Remove failed: $error';
  }

  @override
  String get teamWorkspace => 'Team Workspace';

  @override
  String teamMemberBadge(int count) {
    return '$count members';
  }

  @override
  String teamConflictBadge(int count) {
    return '$count conflicts';
  }

  @override
  String get teamChangePassphrase => 'Change Passphrase';

  @override
  String get teamNoMembers =>
      'No members yet (generate an invite code to add them)';

  @override
  String get teamUnnamed => '(Unnamed)';

  @override
  String get teamPendingConflicts => 'Pending sync conflicts';

  @override
  String teamConflictServerField(String serverId, String field) {
    return 'Server $serverId · Field $field';
  }

  @override
  String get teamConflictLocal => 'Local';

  @override
  String get teamConflictRemote => 'Remote';

  @override
  String get teamUseThisValue => 'Use this value';

  @override
  String get teamInviteNewMember => 'Invite New Member';

  @override
  String get teamInviteDesc =>
      'Generate a one-time invite code for the new member (valid for 72 hours).';

  @override
  String get teamGenerateHint =>
      'Click the button below to generate an invite code.';

  @override
  String get teamGenerating => 'Generating…';

  @override
  String teamExpiresAt(String time) {
    return 'Expires: $time';
  }

  @override
  String get teamVerifyPassphraseTitle => 'Verify Team Passphrase';

  @override
  String get teamVerifyPassphraseDesc =>
      'Enter the team encryption passphrase to verify this session.';

  @override
  String get teamPassphrasePlaceholder => 'Passphrase';

  @override
  String get teamVerify => 'Verify';

  @override
  String get teamPassphraseIncorrect => 'Incorrect passphrase';

  @override
  String get teamVerifyPassed => 'Verified';

  @override
  String teamVerifyFailed(String error) {
    return 'Verification failed: $error';
  }

  @override
  String get teamLoadFailed => 'Failed to load team info';

  @override
  String get proxyNone => 'No proxy';

  @override
  String get proxyLoading => 'Loading…';

  @override
  String get proxySelect => 'Select proxy';

  @override
  String get proxyAddNew => '+ New proxy';

  @override
  String get proxyNewTitle => 'New proxy';

  @override
  String get proxyNamePlaceholder => 'My proxy';

  @override
  String get proxyUsernameOptional => 'Username (optional)';

  @override
  String get proxyPasswordOptional => 'Password (optional)';

  @override
  String get proxyWarpHint =>
      'Connections will be routed through the local Cloudflare WARP client.';

  @override
  String get proxyTorHint =>
      'Connections will be routed through the local Tor network. Note: this must be disclosed in the privacy statement when publishing.';

  @override
  String get proxySave => 'Save proxy';

  @override
  String get serverUnshareFromTeam => 'Unshare from team';

  @override
  String get serverShareToTeam => 'Share to team';

  @override
  String get serverUnsharedFromTeamToast => 'Unshared from team';

  @override
  String get serverSharedToTeam => 'Shared to team';

  @override
  String get serverUnshareAction => 'Unshare';

  @override
  String get serverShareAction => 'Share';

  @override
  String serverActionFailed(String action, String error) {
    return '$action failed: $error';
  }

  @override
  String get serverBadgeProxyTooltip => 'Network proxy configured';

  @override
  String get serverBadgeBastionTooltip => 'Connected via bastion';

  @override
  String get sftpCancelEdit => 'Cancel edit';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceDark => 'Dark';

  @override
  String get settingsAppearanceColorScheme => 'Terminal Color Scheme';

  @override
  String get settingsAppearanceFontSize => 'Font Size';

  @override
  String get settingsAppearanceChinese => '中文';

  @override
  String get updateDialogTitle => 'Check for Updates';

  @override
  String get updateInProgress => 'Checking for updates…';

  @override
  String get updateUpToDateTitle => 'You\'re up to date';

  @override
  String updateUpToDateDetail(String version, String channel) {
    return 'Version v$version is the latest release on the $channel channel.';
  }

  @override
  String get updateCheckFailedTitle => 'Check failed';

  @override
  String updateNewVersionTitle(String version) {
    return 'New version v$version';
  }

  @override
  String get updateNoReleaseNotes => '(No release notes)';

  @override
  String get updateViewDownloadPage => 'View download page';

  @override
  String get updateRecheck => 'Check again';

  @override
  String get monitorSampleInterval => 'Sample Interval';

  @override
  String get monitorSampleIntervalHint =>
      'Refresh rate for each monitoring metric';

  @override
  String get monitorAutoStartLabel => 'Auto-start';

  @override
  String get monitorAutoStartHint =>
      'Automatically start monitoring after a tab connects';

  @override
  String get monitorPanelDisplay => 'Panel Display';

  @override
  String get monitorPanelDisplayHint =>
      'Choose which monitoring metrics to show';

  @override
  String get monitorMemory => 'Memory';

  @override
  String get monitorDisk => 'Disk';

  @override
  String get monitorNetwork => 'Network';

  @override
  String get monitorProcesses => 'Processes';

  @override
  String get settingsLocalAiContextSize => 'Context Window Size';

  @override
  String get settingsLocalAiContextSizeHint => 'Unit: tokens';

  @override
  String get settingsLocalAiModelManagement => 'Local Model Management';

  @override
  String get recordingDeleted => 'Deleted';

  @override
  String recordingDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get recordingNoServer => 'No linked server';

  @override
  String get recordingEmpty => 'No recordings';

  @override
  String get recordingEmptyHint =>
      'Enable recording in the terminal to collect session replays';

  @override
  String get recordingOpen => 'Open';

  @override
  String get tabWorkspaceSftpLocalDisabled =>
      'Local terminal does not support SFTP';

  @override
  String get tabWorkspaceTransfersLocalDisabled =>
      'Local terminal does not support file transfer';

  @override
  String get tabWorkspaceNoTransfers => 'No transfer tasks';

  @override
  String get aiCodeBlockRun => 'Run';
}
