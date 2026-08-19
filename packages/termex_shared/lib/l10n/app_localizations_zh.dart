// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get commonConfirm => '确认';

  @override
  String get commonCancel => '取消';

  @override
  String get commonClose => '关闭';

  @override
  String get commonSearch => '搜索...';

  @override
  String get commonEmpty => '暂无数据';

  @override
  String get commonLoading => '加载中...';

  @override
  String get commonError => '出错了';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonRetry => '重试';

  @override
  String get validatorRequired => '此项为必填';

  @override
  String get validatorEmail => '邮箱格式不正确';

  @override
  String validatorMinLength(int n) {
    return '至少 $n 个字符';
  }

  @override
  String validatorMaxLength(int n) {
    return '最多 $n 个字符';
  }

  @override
  String get themeSaveError => '主题保存失败';

  @override
  String get selectNoOptions => '暂无选项';

  @override
  String get dialogDefaultConfirm => '确认';

  @override
  String get dialogDefaultCancel => '取消';

  @override
  String get shortcutsHintTitle => '当前可用快捷键';

  @override
  String get crossTabSearchPlaceholder => '在所有 Tab 中搜索...';

  @override
  String get crossTabSearchNoMatches => '无命中';

  @override
  String crossTabSearchMatchesFound(int count) {
    return '$count 处命中';
  }

  @override
  String get idleLockTitle => '已锁定';

  @override
  String get idleLockHint => '长时间未活动，请输入主密码继续';

  @override
  String get pluginsTitle => '插件';

  @override
  String get pluginsInstall => '从 .zip 安装';

  @override
  String get pluginsDeveloperMode => '开发者模式';

  @override
  String get pluginsPermissionTitle => '插件权限请求';

  @override
  String get pluginsPermissionDeny => '拒绝';

  @override
  String get pluginsPermissionGrantOnce => '仅本次';

  @override
  String get pluginsPermissionGrant => '授予';

  @override
  String get appName => 'Termex';

  @override
  String get appSlogan => '一款开源 AI 驱动的本地 SSH 客户端';

  @override
  String get sidebarServers => '服务器';

  @override
  String get serverListEmpty => '暂无服务器';

  @override
  String get notificationsSectionTitle => '通知';

  @override
  String get notificationsTestButton => '发送测试通知';

  @override
  String get notificationsTestSent => '测试通知已发送';

  @override
  String get notificationsTestDenied => '系统通知权限未授权——请在系统设置中开启';

  @override
  String get notificationsTestTitle => 'Termex 测试通知';

  @override
  String get notificationsTestBody => '如果你能看到这条通知，AI 任务完成时也会到这里。';

  @override
  String get notificationsDemoTaskButton => '触发示例任务事件';

  @override
  String get notificationsDemoTaskTitle => '示例任务已完成';

  @override
  String get notificationsDemoTaskSummary => '从设置发出的合成事件——用于验证总线到通知器的链路。';

  @override
  String get notificationsDemoTaskSent => '示例任务事件已发布——通知应很快到达';

  @override
  String get taskDetailHeader => '任务详情';

  @override
  String get taskDetailUnknownTask => '未知任务';

  @override
  String get taskDetailNoSummary => '暂无摘要。';

  @override
  String get taskDetailOutputComingSoon =>
      '输出和结果将在 daemon 事件流接入后展示（v0.79.24+）。';

  @override
  String get taskDetailStatusUnknown => '未知';

  @override
  String get taskDetailStatusPending => '等待中';

  @override
  String get taskDetailStatusAwaitingConfirmation => '等待确认';

  @override
  String get taskDetailStatusRunning => '运行中';

  @override
  String get taskDetailStatusSucceeded => '已完成';

  @override
  String get taskDetailStatusFailed => '失败';

  @override
  String get taskDetailStatusCancelled => '已取消';

  @override
  String get taskHistoryHeader => '任务历史';

  @override
  String get taskHistoryEmptyTitle => '暂无任务记录';

  @override
  String get taskHistoryEmptyHint =>
      'daemon 或应用内事件源发布后会在这里出现。可在设置里点「触发示例任务事件」体验。';

  @override
  String get taskHistoryEntryAction => '查看任务历史';

  @override
  String get taskHistoryActionDelete => '删除';

  @override
  String get taskHistoryActionClearAll => '清空全部';

  @override
  String get taskHistoryDeleteConfirmTitle => '删除任务？';

  @override
  String taskHistoryDeleteConfirmBody(String title) {
    return '将「$title」从历史中移除，操作不可撤销。';
  }

  @override
  String get taskHistoryClearAllConfirmTitle => '清空所有任务？';

  @override
  String taskHistoryClearAllConfirmBody(int count) {
    return '将清除全部 $count 条记录，操作不可撤销。';
  }

  @override
  String taskSftpUploadSucceededTitle(String fileName) {
    return '已上传 $fileName';
  }

  @override
  String taskSftpDownloadSucceededTitle(String fileName) {
    return '已下载 $fileName';
  }

  @override
  String taskSftpUploadFailedTitle(String fileName) {
    return '上传失败：$fileName';
  }

  @override
  String taskSftpDownloadFailedTitle(String fileName) {
    return '下载失败：$fileName';
  }

  @override
  String taskSftpUploadCancelledTitle(String fileName) {
    return '上传已取消：$fileName';
  }

  @override
  String taskSftpDownloadCancelledTitle(String fileName) {
    return '下载已取消：$fileName';
  }

  @override
  String taskSftpUploadSucceededBody(String size) {
    return '上传完成（$size）';
  }

  @override
  String taskSftpDownloadSucceededBody(String size) {
    return '下载完成（$size）';
  }

  @override
  String taskSftpFailedBody(String action, String error) {
    return '$action失败 — $error';
  }

  @override
  String taskSftpCancelledBody(
      String action, String transferred, String total) {
    return '$action于 $transferred / $total 时取消';
  }

  @override
  String get taskSftpActionUpload => '上传';

  @override
  String get taskSftpActionDownload => '下载';

  @override
  String get taskPollerSummarySucceeded => '任务成功完成';

  @override
  String get taskPollerSummaryFailed => '任务失败';

  @override
  String taskPollerSummaryFailedWithExit(int exitCode) {
    return '任务失败（退出码 $exitCode）';
  }

  @override
  String get taskPollerSummaryCancelled => '任务已取消';

  @override
  String get taskPollerSummaryRunning => '任务已启动';

  @override
  String get taskPollerSummaryPending => '任务排队中';

  @override
  String get taskPollerSummaryAwaitingConfirmation => '任务等待确认';

  @override
  String taskAiSucceededTitle(String model) {
    return 'AI 回复（$model）';
  }

  @override
  String taskAiSucceededTitleWithConversation(
      String conversation, String model) {
    return '$conversation — 来自 $model 的回复';
  }

  @override
  String get taskAiFailedTitle => 'AI 生成失败';

  @override
  String taskAiFailedTitleWithConversation(String conversation) {
    return '$conversation — 失败';
  }

  @override
  String get taskAiCancelledTitle => 'AI 生成已取消';

  @override
  String taskAiCancelledTitleWithConversation(String conversation) {
    return '$conversation — 已取消';
  }

  @override
  String get taskAiSucceededBody => '回复已生成';

  @override
  String taskAiSucceededBodyWithLength(int chars) {
    return '回复已生成（$chars 字符）';
  }

  @override
  String taskAiSucceededBodyWithTokens(int chars, int tokensIn, int tokensOut) {
    return '回复已生成（$chars 字符 · ↑$tokensIn ↓$tokensOut tokens）';
  }

  @override
  String taskAiSucceededBodyWithCost(
      int chars, int tokensIn, int tokensOut, String cost) {
    return '回复已生成（$chars 字符 · ↑$tokensIn ↓$tokensOut tokens · $cost）';
  }

  @override
  String get taskAiFailedBody => '生成失败';

  @override
  String taskAiFailedBodyWithError(String error) {
    return '生成失败 — $error';
  }

  @override
  String get taskAiCancelledBody => '生成已取消';

  @override
  String get notificationThresholdsTitle => '通知阈值';

  @override
  String get notificationThresholdsSftpToggleLabel => 'SFTP 成功时通知';

  @override
  String get notificationThresholdsSftpToggleHint =>
      '关闭后所有 SFTP 成功事件不弹通知；失败仍会通知。';

  @override
  String get notificationThresholdsSizeLabel => '最小文件大小';

  @override
  String notificationThresholdsSizeValue(double mb) {
    final intl.NumberFormat mbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String mbString = mbNumberFormat.format(mb);

    return '$mbString MB';
  }

  @override
  String get notificationThresholdsDurationLabel => '最小持续时间';

  @override
  String notificationThresholdsDurationValue(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get notificationThresholdsHelp =>
      'SFTP 成功事件只要满足大小或时长任一阈值就通知。失败 / AI 完成始终通知。';

  @override
  String get notificationThresholdsReset => '恢复默认';

  @override
  String get notificationThresholdsResetDone => '已恢复默认';

  @override
  String get notificationThresholdsUndoWindowLabel => '撤销窗口';

  @override
  String notificationThresholdsUndoWindowValue(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get notificationThresholdsUndoWindowOff => '关闭（立即删除）';

  @override
  String get taskHistoryUndoDeleted => '已删除';

  @override
  String taskHistoryUndoCleared(int count) {
    return '已清空 $count 条记录';
  }

  @override
  String get taskHistoryUndoAction => '撤销';

  @override
  String get taskHistoryFilterAll => '全部';

  @override
  String get taskHistoryFilterSftp => 'SFTP';

  @override
  String get taskHistoryFilterAi => 'AI';

  @override
  String get taskHistoryFilterOther => '其他';

  @override
  String get taskHistoryFilterEmptyTitle => '该筛选下暂无任务';

  @override
  String get taskHistoryFilterEmptyHint => '切换到「全部」查看所有任务。';

  @override
  String get taskHistorySearchPlaceholder => '按标题或摘要搜索…';

  @override
  String get taskHistorySearchEmptyTitle => '未找到匹配的任务';

  @override
  String get taskHistorySearchEmptyHint => '清空搜索框或调整关键词。';

  @override
  String get taskHistoryActionClearFiltered => '清除筛选项';

  @override
  String taskHistoryActionClearFilteredWithCount(int count) {
    return '清除筛选项（$count）';
  }

  @override
  String get taskHistoryClearFilteredConfirmTitle => '清除筛选下的任务？';

  @override
  String taskHistoryClearFilteredConfirmBody(int count) {
    return '将清除筛选下的 $count 条记录，未筛选条目保留。撤销窗口关闭后操作不可恢复。';
  }

  @override
  String taskHistoryRelativeSecondsAgo(int seconds) {
    return '$seconds 秒前';
  }

  @override
  String taskHistoryRelativeMinutesAgo(int minutes) {
    return '$minutes 分钟前';
  }

  @override
  String taskHistoryRelativeHoursAgo(int hours) {
    return '$hours 小时前';
  }

  @override
  String taskHistoryRelativeDaysAgo(int days) {
    return '$days 天前';
  }

  @override
  String get sidebarSearch => '搜索服务器...';

  @override
  String get sidebarNewConnection => '新建连接';

  @override
  String get sidebarNewGroup => '新建分组';

  @override
  String get sidebarGroupNameHint => '请输入分组名称';

  @override
  String get sidebarGroupNameRequired => '分组名称不能为空';

  @override
  String get sidebarQuickConnect => '快速连接';

  @override
  String get sidebarImportConfig => '导入配置';

  @override
  String get sidebarExportConfig => '导出配置';

  @override
  String sidebarBastionUsedBy(String count) {
    return '被 $count 个连接用作跳板機';
  }

  @override
  String get sidebarImportSshConfig => '导入 SSH 配置';

  @override
  String get sidebarSnippets => '命令片段';

  @override
  String get sidebarRecordings => '录制记录';

  @override
  String get sidebarCloud => '云原生';

  @override
  String get sidebarFilterall => '全部';

  @override
  String get sidebarFilterprivate => '私人';

  @override
  String get sidebarFilterteam => '团队';

  @override
  String get sidebarPrivateServers => '私人节点';

  @override
  String get sidebarTeamServers => '团队节点';

  @override
  String get sidebarTeamEmptyHint => '团队节点来自同步，不能直接创建。';

  @override
  String get sidebarTeamEmptySync => '先将私人节点共享给团队，再执行同步即可推送给队友。';

  @override
  String get sidebarGoToPrivate => '查看私人节点';

  @override
  String get terminalNewTab => '新建标签';

  @override
  String get terminalCloseTab => '关闭标签';

  @override
  String get terminalDisconnect => '断开连接';

  @override
  String get terminalReconnect => '重新连接';

  @override
  String get terminalReconnecting => '正在重连...';

  @override
  String get terminalReconnected => '已重连';

  @override
  String get terminalReconnectFailed => '重连失败';

  @override
  String terminalReconnectAttempt(String attempt, String max) {
    return '正在重连... 第 $attempt/$max 次';
  }

  @override
  String terminalReconnectAttemptFailed(String attempt) {
    return '第 $attempt 次尝试失败';
  }

  @override
  String terminalReconnectGaveUp(String max) {
    return '重连失败，已尝试 $max 次';
  }

  @override
  String get terminalOpenLocalTerminal => '打开本地终端';

  @override
  String get terminalOpenLocalTerminalError => '无法打开终端';

  @override
  String get terminalSplitVertical => '向右分屏';

  @override
  String get terminalSplitHorizontal => '向下分屏';

  @override
  String get terminalClosePane => '关闭面板';

  @override
  String get terminalMaxSplitDepth => '已达最大分屏层数';

  @override
  String get terminalBroadcastOn => '广播中';

  @override
  String get terminalBroadcastOff => '广播';

  @override
  String get terminalBroadcastHintOn => '输入已发送到所有面板';

  @override
  String get terminalBroadcastToggle => '切换窗格广播';

  @override
  String get terminalBroadcastHintOff => '开启广播模式';

  @override
  String terminalPaneCount(String count) {
    return '$count 个面板';
  }

  @override
  String terminalMouseReportingHint(String key) {
    return '鼠标已被远程程序捕获。按住 $key+拖拽可本地选择复制文本。';
  }

  @override
  String terminalMouseReportingActive(String key) {
    return '鼠标已捕获 · $key+拖拽可选择';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get aiOnboardingHeadline => '尚未配置 AI Provider';

  @override
  String get aiOnboardingBody =>
      'AI 对话需要先在设置中添加 Claude / OpenAI / Gemini 的 API Key，或配置本地 Ollama 端点。';

  @override
  String get aiOnboardingCta => '前往设置 → AI';

  @override
  String get aiOnboardingFallbackHint => '前往「设置 → AI 助手」添加一个 Provider。';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsTerminal => '终端';

  @override
  String get settingsKeybindings => '快捷键';

  @override
  String get settingsSecurity => '安全';

  @override
  String get settingsAiConfig => 'AI 配置';

  @override
  String get settingsBackup => '备份';

  @override
  String get settingsHighlights => '高亮';

  @override
  String get settingsProxies => '代理';

  @override
  String get settingsMonitor => '监控';

  @override
  String get settingsTeam => '团队';

  @override
  String get settingsData => '数据';

  @override
  String get fontsFontFamily => '字体';

  @override
  String get fontsFontSize => '字号';

  @override
  String get fontsUploadFont => '上传字体';

  @override
  String get fontsBuiltIn => '内置字体';

  @override
  String get fontsCustom => '自定义字体';

  @override
  String fontsDeleteConfirm(String name) {
    return '确定删除字体「$name」？';
  }

  @override
  String get fontsDeleteTitle => '删除字体';

  @override
  String get fontsUploaded => '字体上传成功';

  @override
  String get fontsDeleted => '字体已删除';

  @override
  String get fontsInvalidFormat => '不支持的格式，请使用 .ttf、.otf、.woff 或 .woff2';

  @override
  String get fontsUploadFailed => '字体上传失败';

  @override
  String get tabClose => '关闭';

  @override
  String get tabCloseOthers => '关闭其他连接';

  @override
  String get tabDuplicate => '复制';

  @override
  String get tabSplitVertical => '左右分屏';

  @override
  String get tabSplitHorizontal => '上下分屏';

  @override
  String get tabRename => '重命名';

  @override
  String get tabRenameHint => '请输入新名称';

  @override
  String get tabReconnect => '刷新';

  @override
  String get tabReconnectAll => '刷新全部';

  @override
  String get appearanceTheme => '主题';

  @override
  String get appearanceLanguage => '语言';

  @override
  String get appearanceFollowSystem => '跟随系统';

  @override
  String get appearanceSidebarTransition => '侧边栏切换动画';

  @override
  String get appearanceTransFlip => '翻转门';

  @override
  String get appearanceTransSlide => '滑动';

  @override
  String get appearanceTransFade => '淡入淡出';

  @override
  String get appearanceTransScale => '缩放';

  @override
  String get appearanceTransSlideUp => '上滑';

  @override
  String get appearanceTransNone => '无';

  @override
  String get sftpTitle => 'SFTP';

  @override
  String get sftpName => '名称';

  @override
  String get sftpSize => '大小';

  @override
  String get sftpPermissions => '权限';

  @override
  String get sftpModified => '修改时间';

  @override
  String get sftpGoUp => '返回上级';

  @override
  String get sftpRefresh => '刷新';

  @override
  String get sftpNewFolder => '新建文件夹';

  @override
  String get sftpNewFolderPrompt => '请输入文件夹名称';

  @override
  String get sftpClose => '关闭';

  @override
  String get sftpDelete => '删除';

  @override
  String sftpDeleteConfirm(String name) {
    return '确定删除 $name 吗？';
  }

  @override
  String get sftpDeleted => '已删除';

  @override
  String get sftpRename => '重命名';

  @override
  String get sftpRenamePrompt => '请输入新名称';

  @override
  String get sftpDownload => '下载';

  @override
  String get sftpDownloadPrompt => '保存到本地路径';

  @override
  String get sftpDownloadStarted => '下载已开始';

  @override
  String get sftpUpload => '上传';

  @override
  String get sftpUploadStarted => '上传已开始';

  @override
  String get sftpUploadError => '上传错误';

  @override
  String get sftpTransfers => '传输';

  @override
  String get sftpFiles => '文件';

  @override
  String get sftpCompleted => '已完成';

  @override
  String get sftpConnecting => '连接中';

  @override
  String get sftpClearCompleted => '清除已完成';

  @override
  String get sftpNoTransfers => '无传输';

  @override
  String get sftpConfirm => '确定';

  @override
  String get sftpCancel => '取消';

  @override
  String get sftpEmpty => '空目录';

  @override
  String get sftpLocal => '本地';

  @override
  String get sftpRemote => '远程';

  @override
  String get sftpOpenSftp => '打开 SFTP';

  @override
  String get sftpDropToUpload => '拖动文件到此处上传';

  @override
  String get sftpDropToDownload => '拖动到此处下载';

  @override
  String get sftpCwdSyncOn => '同步中 — 跟随终端工作目录';

  @override
  String get sftpCwdSyncOff => '同步 SFTP 路径与终端工作目录';

  @override
  String get sftpCloseSplit => '关闭分屏面板';

  @override
  String get sftpNotConnected => 'SFTP 未连接';

  @override
  String get sftpDownloadError => '下载错误';

  @override
  String get sftpCleared => '已清除已完成的传输';

  @override
  String get sftpCopy => '复制';

  @override
  String get sftpCut => '剪切';

  @override
  String get sftpPaste => '粘贴';

  @override
  String get sftpMore => '更多';

  @override
  String get sftpCopyPath => '复制文件路径';

  @override
  String get sftpEditPath => '编辑路径';

  @override
  String get sftpNewFile => '新建文件';

  @override
  String get sftpMkdir => '新建文件夹';

  @override
  String get sftpSelectAll => '全选';

  @override
  String get sftpChmod => '编辑权限';

  @override
  String get sftpFileInfo => '文件信息';

  @override
  String get sftpEdit => '编辑';

  @override
  String get sftpType => '类型';

  @override
  String get sftpDirectory => '目录';

  @override
  String get sftpFile => '文件';

  @override
  String get sftpUid => 'UID';

  @override
  String get sftpGid => 'GID';

  @override
  String get sftpSymlink => '符号链接';

  @override
  String get sftpYes => '是';

  @override
  String get sftpNo => '否';

  @override
  String get sftpChmodFile => '文件';

  @override
  String get sftpChmodOctal => '八进制权限 (例如 755)';

  @override
  String get sftpChmodExample => '例如 755';

  @override
  String get sftpChmodHelp => '八进制表示法: 读=4, 写=2, 执行=1。示例: 755 = rwxr-xr-x';

  @override
  String get sftpChmodRequired => '请输入权限值';

  @override
  String get sftpChmodInvalid => '无效的八进制值 (0-7777)';

  @override
  String get sftpPermissionsUpdated => '权限已更新';

  @override
  String get sftpCopied => '已复制';

  @override
  String get sftpPathCopied => '路径已复制到剪贴板';

  @override
  String get sftpFileCreated => '文件已创建';

  @override
  String get sftpFolderCreated => '文件夹已创建';

  @override
  String get sftpNewFilePrompt => '请输入文件名';

  @override
  String get sftpSelectAllTodo => '多选功能即将上线';

  @override
  String get sftpEditTodo => '文件编辑功能即将上线';

  @override
  String get sftpPreparing => '准备中';

  @override
  String get sftpRemove => '移除';

  @override
  String get sftpError => '错误';

  @override
  String get sftpServerTransfer => '服务器间传输已开始';

  @override
  String sftpTransferError(String error) {
    return '传输失败：$error';
  }

  @override
  String get sftpServerDisconnected => '服务器已断连';

  @override
  String get sftpDirTransferTodo => '目录传输功能即将上线';

  @override
  String get aiPanelTitle => 'AI 助手';

  @override
  String get aiInputPlaceholder => '描述你想执行的操作...';

  @override
  String get aiSend => '发送';

  @override
  String get aiCopy => '复制';

  @override
  String get aiInsert => '插入终端';

  @override
  String get aiCopied => '已复制';

  @override
  String get aiEmptyHint => '输入自然语言描述，AI 将生成对应命令';

  @override
  String get aiExplain => '解释命令';

  @override
  String get aiDanger => '危险命令';

  @override
  String aiDangerWarning(String desc) {
    return '⚠️ 该命令可能有风险：$desc';
  }

  @override
  String aiDangerCritical(String desc) {
    return '🚫 高危命令：$desc';
  }

  @override
  String get aiConfirm => '确认执行';

  @override
  String get aiCancel => '取消';

  @override
  String get aiClear => '清空对话';

  @override
  String get aiNoProviderHint => '尚未配置 AI 提供商，请先完成配置';

  @override
  String get aiNoProviderShort => '请先配置 AI';

  @override
  String get aiGoConfig => '前往配置';

  @override
  String get aiSaveAsSnippet => '保存为片段';

  @override
  String get aiIncludeContext => '附带终端上下文';

  @override
  String get aiThinking => '思考中...';

  @override
  String get aiErrorDetected => '检测到错误';

  @override
  String get aiAnalyzing => '正在分析错误...';

  @override
  String get aiDismiss => '忽略';

  @override
  String get aiCommand => '命令';

  @override
  String get aiRunFix => '执行修复';

  @override
  String get aiRunAll => '全部执行';

  @override
  String get aiRun => '执行';

  @override
  String get aiConfirmRun => '确认并执行';

  @override
  String get aiPlaybook => '操作手册';

  @override
  String get aiPlaybookGenerating => '正在生成步骤...';

  @override
  String aiPlaybookReady(String count) {
    return '就绪（$count 个步骤）';
  }

  @override
  String get aiStepSuccess => '成功';

  @override
  String get aiStepFailed => '失败';

  @override
  String get aiSummarize => '会话总结';

  @override
  String get aiSummarizing => '正在生成总结...';

  @override
  String get aiExportMarkdown => '导出为 Markdown';

  @override
  String get aiDiagnosisTitle => 'AI 诊断';

  @override
  String get aiAlertCpuThreshold => 'CPU 告警阈值 (%)';

  @override
  String get aiAlertMemoryThreshold => '内存告警阈值 (%)';

  @override
  String get aiAlertDiskThreshold => '磁盘告警阈值 (%)';

  @override
  String get aiAutoDiagnose => '自动诊断错误';

  @override
  String get aiAutoDiagnoseHint => 'AI 自动分析命令错误';

  @override
  String get portForwardTitle => '端口转发';

  @override
  String get portForwardLocal => '本地转发';

  @override
  String get portForwardRemote => '远程转发';

  @override
  String get portForwardDynamic => '动态转发';

  @override
  String get portForwardLocalHost => '本地地址';

  @override
  String get portForwardLocalPort => '本地端口';

  @override
  String get portForwardRemoteHost => '远程地址';

  @override
  String get portForwardRemotePort => '远程端口';

  @override
  String get portForwardAutoStart => '自动启动';

  @override
  String get portForwardStart => '启动';

  @override
  String get portForwardStop => '停止';

  @override
  String get portForwardAdd => '添加规则';

  @override
  String get portForwardDelete => '删除';

  @override
  String get portForwardRunning => '运行中';

  @override
  String get portForwardStopped => '已停止';

  @override
  String get configExportTitle => '导出配置';

  @override
  String get configImportTitle => '导入配置';

  @override
  String get configPassword => '导出密码';

  @override
  String get configPasswordHint => '设置一个独立的导出密码';

  @override
  String get configFilePath => '文件路径';

  @override
  String get configOnConflict => '冲突处理';

  @override
  String get configSkip => '跳过已存在';

  @override
  String get configOverwrite => '覆盖';

  @override
  String get configExportSuccess => '导出成功';

  @override
  String configImportSuccess(String imported, String skipped) {
    return '导入完成：导入 $imported 项，跳过 $skipped 项';
  }

  @override
  String get connectionEditConnection => '编辑连接';

  @override
  String get connectionName => '名称';

  @override
  String get connectionHost => '主机';

  @override
  String get connectionPort => '端口';

  @override
  String get connectionUsername => '用户名';

  @override
  String get connectionPassword => '密码';

  @override
  String get connectionAuthType => '认证方式';

  @override
  String get connectionPrivateKey => '私钥';

  @override
  String get connectionBrowseKey => '浏览文件';

  @override
  String get connectionSshAgent => 'SSH Agent';

  @override
  String get connectionSshAgentInfo =>
      '使用系统 SSH Agent (\$SSH_AUTH_SOCK) 进行认证，无需在 Termex 中保存私钥凭证。';

  @override
  String get connectionGroup => '分组';

  @override
  String get connectionGroupNone => '无分组';

  @override
  String get connectionTags => '标签';

  @override
  String get connectionTagsHint => '逗号分隔，例如：production, linux';

  @override
  String get connectionAuthTypePassword => '密码';

  @override
  String get connectionAuthTypeKey => '私钥';

  @override
  String get connectionAuthTypeInteractive => '交互式';

  @override
  String get connectionPassphrase => '私钥密码';

  @override
  String get connectionAuthorizationInfo => '授权信息';

  @override
  String get connectionSshTunnel => 'SSH 隧道';

  @override
  String get connectionBastion => '跳板機 / 跳转主機';

  @override
  String get connectionBastionHint => '跳板機在侧边栏服务器列表中管理。任何已保存的服务器均可用作跳板機。';

  @override
  String get connectionSelectBastion => '搜索或选择跳板機服务器...';

  @override
  String get connectionConnectionPath => '连接路径';

  @override
  String get connectionNoProxyConfigured => '未配置跳板機，将直接连接目标服务器。';

  @override
  String get connectionRemoveTunnel => '删除';

  @override
  String get connectionSave => '保存';

  @override
  String get connectionCancel => '取消';

  @override
  String get connectionConnect => '连接';

  @override
  String get connectionTest => '测试连接';

  @override
  String get connectionTesting => '正在测试连接…';

  @override
  String get connectionTestSuccess => '连接测试成功';

  @override
  String get connectionTestFailed => '连接测试失败';

  @override
  String get connectionKeySourcePath => '文件路径';

  @override
  String get connectionKeySourcePaste => '粘贴内容';

  @override
  String get connectionKeyContent => '私钥内容';

  @override
  String get connectionKeyContentPlaceholder =>
      '-----BEGIN OPENSSH PRIVATE KEY-----\n…';

  @override
  String get connectionAddServer => '添加服务器';

  @override
  String get connectionEditServer => '编辑服务器';

  @override
  String get connectionProxy => '代理';

  @override
  String get connectionNetworkProxy => '网络代理';

  @override
  String get connectionNetworkProxyHint =>
      '代理在侧边栏 Proxy 面板中管理。请切换到侧边栏的 Proxy 面板添加或编辑代理。';

  @override
  String get connectionProxyNone => '无（直连）';

  @override
  String get connectionProxyName => '代理名称';

  @override
  String get connectionProxyType => '代理类型';

  @override
  String get connectionProxySocks5 => 'SOCKS5';

  @override
  String get connectionProxySocks4 => 'SOCKS4';

  @override
  String get connectionProxyHttp => 'HTTP CONNECT';

  @override
  String get connectionProxyHost => '代理主机';

  @override
  String get connectionProxyPort => '代理端口';

  @override
  String get connectionProxyUsername => '用户名';

  @override
  String get connectionProxyPassword => '密码';

  @override
  String get connectionProxyAdd => '添加代理';

  @override
  String get connectionProxyEdit => '编辑代理';

  @override
  String get connectionProxyDelete => '删除代理';

  @override
  String connectionProxyDeleteConfirm(String name) {
    return '确定删除代理「$name」？使用该代理的服务器将切换为直连。';
  }

  @override
  String connectionProxyUsedBy(String count) {
    return '被 $count 个服务器使用';
  }

  @override
  String get connectionProxyNoConfig => '暂无代理配置。';

  @override
  String get connectionProxyGoSettings => '前往 设置 → 代理 添加。';

  @override
  String get connectionProxyTestReachable => '代理可达';

  @override
  String get connectionProxyTor => 'Tor';

  @override
  String connectionProxyTorRunning(String port) {
    return '检测到 Tor 服务，端口 $port';
  }

  @override
  String get connectionProxyTorNotFound => '未检测到 Tor 服务（请先安装并启动 Tor）';

  @override
  String get connectionProxyTlsEnable => '启用 TLS (HTTPS)';

  @override
  String get connectionProxyTlsVerify => '验证证书';

  @override
  String get connectionProxyCaCert => 'CA 证书路径 (.pem)';

  @override
  String get connectionProxyClientCert => '客户端证书路径 (.pem/.crt)';

  @override
  String get connectionProxyClientKey => '客户端私钥路径 (.pem/.key)';

  @override
  String get connectionProxyCommand => 'ProxyCommand';

  @override
  String get connectionProxyCommandPlaceholder =>
      '例如 cloudflared access ssh --hostname %h';

  @override
  String get connectionProxyCommandHint =>
      '变量: %h = 主机名, %p = 端口, %r = 用户名。通过 sh -c 执行。';

  @override
  String get connectionSync => '同步';

  @override
  String get connectionTmuxMode => 'tmux 模式';

  @override
  String get connectionAutoRecord => '自动录制会话';

  @override
  String get connectionAutoRecordDesc => '连接此服务器后立即开始录制';

  @override
  String get connectionMaxRecordingMb => '录制大小上限 (MB)';

  @override
  String get connectionTmuxDisabled => '禁用 — 普通 shell';

  @override
  String get connectionTmuxAuto => '自动 — 检测并自动使用';

  @override
  String get connectionTmuxAlways => '始终 — 必须使用 tmux（不可用时报错）';

  @override
  String get connectionTmuxCloseAction => '关闭 Tab 行为';

  @override
  String get connectionTmuxDetach => 'Detach — 保持远程会话运行';

  @override
  String get connectionTmuxKill => 'Kill — 销毁远程会话';

  @override
  String get connectionGitSyncEnable => '启用 Git 自动同步';

  @override
  String get connectionGitSyncRemotePath => '远程仓库路径';

  @override
  String get connectionGitSyncLocalPath => '本地仓库路径';

  @override
  String get connectionGitSyncMode => '同步模式';

  @override
  String get connectionGitSyncNotify => '仅通知 — 推送完成时桌面通知';

  @override
  String get connectionGitSyncAutoPull => '自动拉取 — 自动 pull 到本地';

  @override
  String get connectionGitSyncHint => '请确保远程仓库的 .gitignore 已排除 .env 等敏感文件。';

  @override
  String get connectionForwarding => '端口转发';

  @override
  String get connectionForwardAdd => '添加转发规则';

  @override
  String get connectionForwardLocal => '本地转发';

  @override
  String get connectionForwardDynamic => '动态转发 (SOCKS5)';

  @override
  String get connectionForwardDynamicHint => 'SOCKS5 代理 — 所有浏览器流量通过远程服务器转发';

  @override
  String get connectionForwardNone => '暂无转发规则。';

  @override
  String get ctxProxySetDefault => '设为默认';

  @override
  String get ctxProxyTest => '测试连接';

  @override
  String get ctxProxyCopyAddress => '复制地址';

  @override
  String get ctxProxyDelete => '删除代理';

  @override
  String get ctxSnippetCopyContent => '复制内容';

  @override
  String get ctxRecordingCopyPath => '复制文件路径';

  @override
  String get ctxCloudCopyLabel => '复制名称';

  @override
  String get ctxCopied => '已复制到剪贴板';

  @override
  String get ctxCloudCopyDetail => '复制详情';

  @override
  String get monitorPriming => '正在建立基线：CPU 与网络为累计计数器，需要两次采样才能得出速率。';

  @override
  String get contextConnect => '连接';

  @override
  String get contextEdit => '编辑';

  @override
  String get contextDuplicate => '复制';

  @override
  String get contextRename => '重命名';

  @override
  String get contextRenameHint => '请输入新名称';

  @override
  String get contextNameRequired => '名称不能为空';

  @override
  String get contextMoveTo => '移动到分组';

  @override
  String get contextUngroup => '取消分组';

  @override
  String get contextDelete => '删除';

  @override
  String contextDeleteConfirm(String name) {
    return '确定删除服务器「$name」？';
  }

  @override
  String get contextShareWithTeam => '共享给团队';

  @override
  String get contextMakePrivate => '设为私有';

  @override
  String contextDeleteGroupConfirm(String name) {
    return '确定删除分组「$name」？分组内服务器将变为未分组。';
  }

  @override
  String get contextNewSubgroup => '新建子分组';

  @override
  String get securityProtectionMode => '凭证保护方式';

  @override
  String securityKeychainActive(String platform) {
    return '已启用 $platform，所有密码和密钥安全存储在操作系统密钥管理器中';
  }

  @override
  String get securityKeychainUnavailable => '操作系统密钥管理器不可用，当前使用本地加密存储';

  @override
  String get securityStoredCredentials => '已保护的凭证数量';

  @override
  String get securityCredentialHint => 'SSH 密码、私钥口令、AI API Key';

  @override
  String get securityHowItWorks => '工作原理';

  @override
  String get securityHint1 => '密码和密钥存储在操作系统的密钥管理器中，不存在 termex.db';

  @override
  String get securityHint2 => 'termex.db 仅保存密钥管理器的引用 ID';

  @override
  String get securityHint3 => '即使 termex.db 文件泄露，也无法获取任何密码';

  @override
  String get hostKeyTitle => '主机密钥验证';

  @override
  String get hostKeyWarningTitle => '警告：主机密钥已变更！';

  @override
  String get hostKeyWarningDesc => '此服务器的主机密钥已发生变化。这可能表示中间人攻击，或服务器已重新配置。';

  @override
  String get hostKeyHost => '主机';

  @override
  String get hostKeyKeyType => '类型';

  @override
  String get hostKeyFingerprint => '指纹';

  @override
  String get hostKeyOldFingerprint => '原指纹';

  @override
  String get hostKeyNewFingerprint => '新指纹';

  @override
  String get hostKeyAccept => '信任';

  @override
  String get hostKeyAcceptChanged => '仍然信任';

  @override
  String get hostKeyReject => '拒绝';

  @override
  String get keybindingsNewConnection => '新建连接';

  @override
  String get keybindingsOpenSettings => '打开设置';

  @override
  String get keybindingsToggleSidebar => '切换侧边栏';

  @override
  String get keybindingsToggleAi => '切换 AI 面板';

  @override
  String get keybindingsCloseTab => '关闭当前标签';

  @override
  String get keybindingsNextTab => '下一个标签';

  @override
  String get keybindingsPrevTab => '上一个标签';

  @override
  String get keybindingsGoToTab => '跳转到第 N 个标签';

  @override
  String get keybindingsGoToTab1 => '跳转到第 1 个标签';

  @override
  String get keybindingsGoToTab2 => '跳转到第 2 个标签';

  @override
  String get keybindingsGoToTab3 => '跳转到第 3 个标签';

  @override
  String get keybindingsGoToTab4 => '跳转到第 4 个标签';

  @override
  String get keybindingsGoToTab5 => '跳转到第 5 个标签';

  @override
  String get keybindingsGoToTab6 => '跳转到第 6 个标签';

  @override
  String get keybindingsGoToTab7 => '跳转到第 7 个标签';

  @override
  String get keybindingsGoToTab8 => '跳转到第 8 个标签';

  @override
  String get keybindingsGoToTab9 => '跳转到第 9 个标签';

  @override
  String get keybindingsSearch => '搜索终端';

  @override
  String get keybindingsSearchAllTabs => '搜索所有标签页';

  @override
  String get keybindingsSplitVertical => '垂直分屏';

  @override
  String get keybindingsSplitHorizontal => '水平分屏';

  @override
  String get keybindingsClosePaneOrTab => '关闭面板 / 标签';

  @override
  String get keybindingsFocusPaneNext => '聚焦下一面板';

  @override
  String get keybindingsFocusPanePrev => '聚焦上一面板';

  @override
  String get keybindingsFocusPaneUp => '聚焦上方面板';

  @override
  String get keybindingsFocusPaneDown => '聚焦下方面板';

  @override
  String get keybindingsFocusPaneLeft => '聚焦左侧面板';

  @override
  String get keybindingsFocusPaneRight => '聚焦右侧面板';

  @override
  String get keybindingsToggleBroadcast => '切换广播模式';

  @override
  String get keybindingsRecording => '请按下快捷键...';

  @override
  String keybindingsConflict(String action) {
    return '已被「$action」占用';
  }

  @override
  String get keybindingsResetOne => '恢复默认';

  @override
  String get keybindingsResetAll => '全部重置';

  @override
  String get keybindingsResetAllConfirm => '确定将所有快捷键恢复为默认值？';

  @override
  String get keybindingsRequireModifier => '快捷键必须包含 Cmd/Ctrl';

  @override
  String get keybindingsReserved => '该快捷键被系统保留';

  @override
  String get searchPlaceholder => '搜索...';

  @override
  String get searchNoResults => '无结果';

  @override
  String searchMatchCount(String current, String total) {
    return '$current / $total';
  }

  @override
  String get searchCaseSensitive => '区分大小写';

  @override
  String get searchRegex => '正则表达式';

  @override
  String get searchWholeWord => '全词匹配';

  @override
  String get searchClose => '关闭';

  @override
  String get searchPreviousMatch => '上一个';

  @override
  String get searchNextMatch => '下一个';

  @override
  String get searchSearchAllTabs => '搜索所有标签页';

  @override
  String get searchSearchBtn => '搜索';

  @override
  String get searchSearching => '搜索中...';

  @override
  String searchTotalMatches(String count, String tabs) {
    return '在 $tabs 个标签页中找到 $count 个匹配';
  }

  @override
  String get searchNoMatches => '未找到匹配';

  @override
  String searchMoreMatches(String count) {
    return '... 还有 $count 个匹配';
  }

  @override
  String get searchLine => '行';

  @override
  String get searchJumpToMatch => '跳转到匹配';

  @override
  String get highlightsTitle => '关键词高亮';

  @override
  String get highlightsPattern => '匹配模式';

  @override
  String get highlightsRegex => '正则';

  @override
  String get highlightsCaseSensitive => '大小写';

  @override
  String get highlightsBgColor => '背景色';

  @override
  String get highlightsFgColor => '前景色';

  @override
  String get highlightsEnabled => '启用';

  @override
  String get highlightsAddRule => '添加规则';

  @override
  String get highlightsLoadPresets => '加载预设';

  @override
  String get highlightsDeleteRule => '删除';

  @override
  String get highlightsDeleteConfirm => '确定删除此高亮规则？';

  @override
  String get highlightsNoRules => '暂无关键词高亮规则，点击「添加规则」或「加载预设」开始使用。';

  @override
  String get highlightsPresetsLoaded => '预设规则已加载';

  @override
  String get highlightsPatternRequired => '请输入匹配模式';

  @override
  String get highlightsInvalidRegex => '无效的正则表达式';

  @override
  String get aiConfigAddProvider => '添加提供商';

  @override
  String get aiConfigNoProviders => '暂无 AI 提供商，点击上方添加';

  @override
  String get aiConfigProviderName => '名称';

  @override
  String get aiConfigProviderType => '类型';

  @override
  String get aiConfigModel => '模型';

  @override
  String get aiConfigSetDefault => '设为默认';

  @override
  String get aiConfigDefault => '默认';

  @override
  String get aiConfigDeleteConfirm => '确定删除该 AI 提供商？';

  @override
  String get aiConfigTest => '测试';

  @override
  String get aiConfigTestSuccess => '连接测试成功';

  @override
  String get aiConfigTestFailed => '连接测试失败';

  @override
  String get aiConfigLanOllama => '局域网';

  @override
  String get backupTitle => '备份与恢复';

  @override
  String get backupExport => '导出配置';

  @override
  String get backupExportDesc => '将服务器、分组、设置等数据加密导出为 .termex 文件';

  @override
  String get backupExportBtn => '导出';

  @override
  String get backupExportPasswordHint => '设置导出密码（至少 4 位）';

  @override
  String get backupExportSuccess => '导出成功';

  @override
  String get backupPasswordTooShort => '密码至少 4 位';

  @override
  String get backupImport => '导入配置';

  @override
  String get backupImportDesc => '从 .termex 加密文件恢复配置数据';

  @override
  String get backupImportBtn => '导入';

  @override
  String get backupImportPasswordHint => '输入导出时设置的密码';

  @override
  String get backupImportSuccess => '导入成功';

  @override
  String get backupRecordingDir => '录制目录';

  @override
  String get backupRecordingDirDesc => '终端会话录制文件存储位置';

  @override
  String get backupOpenDir => '打开目录';

  @override
  String get updateTitle => '版本信息';

  @override
  String get updateCurrentVersion => '当前版本';

  @override
  String get updateLatestVersion => '最新版本';

  @override
  String get updateChecking => '正在检查更新...';

  @override
  String get updateUpToDate => '已是最新版本！';

  @override
  String get updateCheckFailed => '检查更新失败';

  @override
  String get updateReleaseNotes => '更新内容';

  @override
  String get updateNoAsset => '没有适用于您平台的安装包，请手动下载';

  @override
  String get updateUpgrade => '升级';

  @override
  String get updateRetry => '重试';

  @override
  String get updateViewRelease => '查看发布';

  @override
  String get updateDownloading => '下载中...';

  @override
  String get updateDownloadFailed => '下载失败';

  @override
  String get updateInstallLaunched => '安装包已打开，应用即将关闭';

  @override
  String get updateNewVersion => '新版本可用';

  @override
  String get keychainVerificationTitle => '验证凭证';

  @override
  String get keychainVerificationMessage => '系统密码可能已经修改，请验证以访问保存的密码。';

  @override
  String get keychainVerificationVerify => '验证';

  @override
  String get keychainVerificationFailed =>
      '验证失败。查末凭证可能不可用。您仍然可以使用 Termex，但可能需要重新输入密码。';

  @override
  String get autocompleteTitle => '智能补全';

  @override
  String get autocompleteEnabled => '启用终端内联智能补全';

  @override
  String get autocompleteDebounce => '触发延迟';

  @override
  String get autocompleteDebounceUnit => '毫秒';

  @override
  String get autocompleteMinChars => '最少字符数';

  @override
  String get autocompletePreferLocal => '优先使用本地 AI 模型';

  @override
  String get autocompletePreferLocalHint => '本地引擎运行时自动使用，延迟更低';

  @override
  String get localAiTitle => '本地 AI 模型';

  @override
  String get localAiEngineRunning => '推理引擎运行中';

  @override
  String get localAiEngineStopped => '推理引擎未运行';

  @override
  String get localAiMicroTier => '微型 (~200MB, 2GB 内存)';

  @override
  String get localAiMicroDesc => '超轻量级模型，资源使用最少';

  @override
  String get localAiSmallTier => '小型 (~400MB, 4GB 内存)';

  @override
  String get localAiSmallDesc => '轻量级模型，適合低配置环境，適合基础命令解释';

  @override
  String get localAiMediumTier => '中型 (~2GB, 8GB 内存)';

  @override
  String get localAiMediumDesc => '性能和质量均衡，適合日常使用';

  @override
  String get localAiLargeTier => '大型 (~5GB, 16GB 内存) ⭐ 推荐';

  @override
  String get localAiLargeDesc => '最佳质量和能力，推荐使用';

  @override
  String get localAiNotDownloaded => '未下载';

  @override
  String get localAiDownloading => '下载中';

  @override
  String get localAiDownloaded => '已下载';

  @override
  String get localAiError => '错误';

  @override
  String get localAiVerifying => '正在验证';

  @override
  String get localAiSize => '大小';

  @override
  String get localAiMinRam => '最低内存';

  @override
  String get localAiContextLength => '上下文';

  @override
  String get localAiLocalModels => '本地模型';

  @override
  String get localAiDownload => '下载';

  @override
  String get localAiCancel => '取消';

  @override
  String get localAiDelete => '删除';

  @override
  String get localAiRetry => '重试';

  @override
  String get localAiUseAsProvider => '用作 AI 提供商';

  @override
  String get localAiRecommended => '推荐';

  @override
  String localAiDownloadStarted(String name) {
    return '开始下载 $name';
  }

  @override
  String localAiDownloadFailed(String error) {
    return '下载失败: $error';
  }

  @override
  String get localAiDownloadCancelled => '已取消下载';

  @override
  String get localAiDeleted => '模型已删除';

  @override
  String get localAiAddedAsProvider => '已添加为 AI 提供商';

  @override
  String localAiDeleteConfirm(String name) {
    return '删除 $name？此操作不可恢复。';
  }

  @override
  String get localAiWarning => '警告';

  @override
  String get localAiCatalogUpdated => '模型目录已更新。请检查「本地 AI 模型」段落来查看新增模型。';

  @override
  String get localAiNoModels => '暂未下载任何本地模型。请先前往「本地 AI 模型」面板下载模型。';

  @override
  String get localAiOk => '确定';

  @override
  String get localAiAutoStarting => '正在启动本地 AI';

  @override
  String localAiAutoStartingMsg(String model, String seconds) {
    return '$seconds 秒后自动启动 $model... 关闭可取消。';
  }

  @override
  String localAiStartingModel(String model) {
    return '正在加载模型 $model，请稍候...';
  }

  @override
  String localAiStartedModel(String model) {
    return '本地 AI 已启动: $model';
  }

  @override
  String localAiReusedInstance(String model) {
    return '复用已运行实例: $model';
  }

  @override
  String get localAiStartFailed => '本地 AI 启动失败';

  @override
  String get localAiSwitchModel => '切换';

  @override
  String get localAiAutoStart => '启动时自动加载';

  @override
  String get localAiAutoStartHint => '打开 Termex 时自动启动上次使用的模型';

  @override
  String get sshConfigImportTitle => '导入 SSH 配置';

  @override
  String get sshConfigImportDescription => '从 ~/.ssh/config 导入服务器';

  @override
  String get sshConfigPreview => '预览';

  @override
  String get sshConfigImporting => '导入中...';

  @override
  String get sshConfigSelectAll => '全选';

  @override
  String get sshConfigDeselectAll => '取消全选';

  @override
  String get sshConfigImportButton => '导入选中';

  @override
  String get sshConfigImported => '已导入';

  @override
  String get sshConfigSkipped => '已跳过';

  @override
  String get sshConfigErrors => '错误';

  @override
  String get sshConfigHostAlias => '主机别名';

  @override
  String get sshConfigHostname => '主机名';

  @override
  String get sshConfigPort => '端口';

  @override
  String get sshConfigUser => '用户';

  @override
  String get sshConfigAuthType => '认证';

  @override
  String get sshConfigAuthKey => '密钥认证';

  @override
  String get sshConfigAuthPassword => '密码认证';

  @override
  String get sshConfigNoEntries => '未找到 SSH 配置条目';

  @override
  String get sshConfigParseWarnings => '解析警告';

  @override
  String sshConfigSelectedCount(String count, String total) {
    return '已选 $count/$total';
  }

  @override
  String get sshConfigImport => '导入';

  @override
  String sshConfigResultSummary(
      String imported, String skipped, String errors) {
    return '已导入 $imported 个，跳过 $skipped 个，$errors 个错误';
  }

  @override
  String get sshConfigErrorDetails => '错误详情';

  @override
  String get sshConfigDone => '完成';

  @override
  String get sshConfigNonInteractive => '非 SSH';

  @override
  String get snippetTitle => '命令片段';

  @override
  String get snippetSearch => '搜索片段...';

  @override
  String get snippetCreate => '新建片段';

  @override
  String get snippetCreateTitle => '新建片段';

  @override
  String get snippetEditTitle => '编辑片段';

  @override
  String get snippetEdit => '编辑片段';

  @override
  String get snippetDelete => '删除片段';

  @override
  String get snippetDeleteConfirm => '确定要删除这个片段吗？';

  @override
  String get snippetExecute => '执行';

  @override
  String get snippetSaveAsSnippet => '保存为片段';

  @override
  String get snippetSave => '保存';

  @override
  String get snippetCancel => '取消';

  @override
  String get snippetName => '标题';

  @override
  String get snippetTitleLabel => '标题';

  @override
  String get snippetTitlePlaceholder => '输入片段标题';

  @override
  String get snippetCommand => '命令';

  @override
  String get snippetCommandLabel => '命令';

  @override
  String get snippetCommandPlaceholder => '输入命令...';

  @override
  String get snippetDescription => '描述';

  @override
  String get snippetDescriptionLabel => '描述';

  @override
  String get snippetDescriptionPlaceholder => '可选描述';

  @override
  String get snippetTags => '标签';

  @override
  String get snippetTagsLabel => '标签';

  @override
  String get snippetTagsPlaceholder => '逗号分隔的标签';

  @override
  String get snippetTagsHint => '逗号分隔的标签';

  @override
  String get snippetFolder => '文件夹';

  @override
  String get snippetFolderLabel => '文件夹';

  @override
  String get snippetFolderNone => '无文件夹';

  @override
  String get snippetFavorite => '收藏';

  @override
  String get snippetFavoriteLabel => '收藏';

  @override
  String get snippetUnfavorite => '取消收藏';

  @override
  String get snippetNoSnippets => '暂无片段';

  @override
  String get snippetEmpty => '暂无片段';

  @override
  String get snippetCreateFirst => '创建第一个片段';

  @override
  String get snippetNoResults => '没有匹配的片段';

  @override
  String get snippetPalette => '片段面板';

  @override
  String get snippetPaletteSearch => '搜索片段...';

  @override
  String get snippetVariableTitle => '填写变量';

  @override
  String get snippetVariablesTitle => '填写变量';

  @override
  String get snippetVariableHint => '为模板变量输入值';

  @override
  String snippetUsageCount(String count) {
    return '已使用 $count 次';
  }

  @override
  String get snippetAllFolders => '全部';

  @override
  String get snippetCategoryFilter => '分类';

  @override
  String get snippetCategoryAll => '全部分类';

  @override
  String snippetCategoryCount(int count) {
    return '$count 个分类';
  }

  @override
  String get snippetCategoryNone => '暂无分类';

  @override
  String get snippetAllFolder => '全部';

  @override
  String get snippetNewFolder => '新建文件夹';

  @override
  String get snippetFolderName => '文件夹名称';

  @override
  String get snippetNavigate => '导航';

  @override
  String get snippetRun => '运行';

  @override
  String get snippetClose => '关闭';

  @override
  String get monitorTitle => '服务器监控';

  @override
  String get monitorCollectionInterval => '采集间隔';

  @override
  String get monitorAutoStart => '连接时自动启动监控';

  @override
  String get monitorVisiblePanels => '显示面板';

  @override
  String get teamTitle => '团队协作';

  @override
  String get teamDescription => '通过 Git 仓库共享服务器配置。所有凭据使用团队密钥加密。';

  @override
  String get teamCreate => '创建团队';

  @override
  String get teamJoin => '加入团队';

  @override
  String get teamLeave => '离开团队';

  @override
  String get teamLeaveConfirm => '确定离开团队？已导入的服务器将保留但不再同步。';

  @override
  String get teamLeftSuccess => '已离开团队';

  @override
  String get teamSync => '同步到云端';

  @override
  String get teamSyncing => '同步到云端...';

  @override
  String teamSyncSuccess(String imported, String exported) {
    return '同步完成：导入 $imported，推送 $exported';
  }

  @override
  String get teamSyncUpToDate => '已是最新';

  @override
  String get teamTeamName => '团队名称';

  @override
  String get teamPassphrase => '团队密码';

  @override
  String get teamPassphraseConfirm => '确认密码';

  @override
  String get teamPassphraseHint => '所有成员需使用相同密码。请通过安全渠道分享。';

  @override
  String get teamRepoUrl => 'Git 仓库 URL';

  @override
  String get teamRepoUrlHint => '支持 SSH (git@...) 和 HTTPS (https://...)';

  @override
  String get teamGitAuth => 'Git 认证方式';

  @override
  String get teamGitAuthSsh => 'SSH Key';

  @override
  String get teamGitAuthToken => 'HTTPS Token';

  @override
  String get teamGitAuthUserPass => 'HTTPS 用户名密码';

  @override
  String get teamUsername => '你的用户名';

  @override
  String get teamUsernameHint => '在团队中显示的名称';

  @override
  String get teamRole => '角色';

  @override
  String get teamRoleAdmin => '管理员';

  @override
  String get teamRoleMember => '成员';

  @override
  String get teamRoleReadonly => '只读';

  @override
  String get teamMembers => '团队成员';

  @override
  String get teamMemberManage => '成员管理';

  @override
  String get teamMemberRemove => '移除成员';

  @override
  String teamMemberRemoveConfirm(String name) {
    return '确定移除 $name？';
  }

  @override
  String get teamShareServer => '共享到团队';

  @override
  String get teamShareServerHint => '开启后此服务器配置将同步给所有团队成员';

  @override
  String teamSharedBy(String name) {
    return '由 $name 共享';
  }

  @override
  String get teamSharedWithTeam => '已共享给团队 · 下次同步时推送';

  @override
  String get teamMakePrivate => '设为私人';

  @override
  String teamReceivedFrom(String name) {
    return '来自 $name';
  }

  @override
  String get teamTeamServers => '团队节点';

  @override
  String get teamLastSync => '最后同步';

  @override
  String get teamNeverSynced => '从未同步';

  @override
  String get teamJustNow => '刚刚';

  @override
  String get teamMinutesAgo => '分钟前';

  @override
  String get teamPendingChanges => '有未推送的变更';

  @override
  String get teamCreateSuccess => '团队创建成功';

  @override
  String get teamJoinSuccess => '已加入团队';

  @override
  String get teamStep1Info => '基本信息';

  @override
  String get teamStep2Repo => '仓库配置';

  @override
  String get teamStep3Done => '完成';

  @override
  String get teamNext => '下一步';

  @override
  String get teamDone => '完成';

  @override
  String get teamEnterPassphrase => '输入团队密码';

  @override
  String get teamPassphraseRequired => '需要团队密码才能同步共享配置。';

  @override
  String get teamPassphraseWrong => '团队密码错误';

  @override
  String get teamRememberPassphrase => '记住团队密码';

  @override
  String get teamRotateKey => '轮换密码';

  @override
  String get teamCurrentPassphrase => '当前密码';

  @override
  String get teamNewPassphrase => '新密码';

  @override
  String get teamPassphraseTooShort => '密码至少 8 个字符';

  @override
  String get teamPassphraseMismatch => '两次密码不一致';

  @override
  String get teamRotateKeySuccess => '团队密码轮换成功';

  @override
  String get recordingTitle => '会话录制';

  @override
  String get recordingPlay => '播放';

  @override
  String get recordingPause => '暂停';

  @override
  String get recordingEmptyCast => '此录制不包含任何输出';

  @override
  String get recordingRetentionPeriod => '保留周期';

  @override
  String get recordingRetentionDesc => '超过此期限的录制将在启动时自动清理。';

  @override
  String get recordingDays30 => '30 天';

  @override
  String get recordingDays60 => '60 天';

  @override
  String get recordingDays90 => '90 天';

  @override
  String get recordingKeepForever => '永久保留';

  @override
  String get recordingCleanup => '清理过期录制';

  @override
  String recordingCleanupResult(String count) {
    return '已清理 $count 条录制';
  }

  @override
  String get recordingStartRecording => '开始录制';

  @override
  String get recordingStopRecording => '停止录制';

  @override
  String get cloudTitle => '云资源';

  @override
  String get cloudRefresh => '刷新';

  @override
  String get cloudFilterPods => '搜索 Pod...';

  @override
  String get cloudFilterInstances => '搜索实例...';

  @override
  String get cloudKubeClusters => 'K8s 集群';

  @override
  String get cloudKubeConnect => '连接';

  @override
  String get cloudKubeViewLogs => '查看日志';

  @override
  String get cloudKubePodDetail => 'Pod 详情';

  @override
  String get cloudKubeSelectContainer => '选择容器';

  @override
  String get cloudKubeSelectShell => 'Shell';

  @override
  String get cloudKubeNoContexts => '未配置集群';

  @override
  String get cloudKubeNoPods => '当前命名空间无 Pod';

  @override
  String get cloudKubeExecFailed => '进入 Pod 失败';

  @override
  String get cloudKubeRbacDenied => '权限不足，需要: pods/exec';

  @override
  String get cloudSsmTitle => 'AWS SSM';

  @override
  String get cloudSsmConnect => '连接';

  @override
  String get cloudSsmNoInstances => '无可连接的实例';

  @override
  String get cloudSsmAgentOffline => 'SSM Agent 离线';

  @override
  String get cloudSsmCredExpired => 'AWS 凭证已过期，请执行: aws sso login';

  @override
  String get cloudLogsTailLines => '尾部行数';

  @override
  String get cloudLogsSince => '起始时间';

  @override
  String get cloudLogsFollow => '实时跟踪';

  @override
  String get cloudLogsStreamEnded => '日志流已结束';

  @override
  String get cloudSetupTitle => '云原生配置';

  @override
  String get cloudSetupDesc => '连接 K8s 集群和 AWS EC2 实例';

  @override
  String get cloudSetupDetected => '已检测到';

  @override
  String get cloudSetupNotInstalled => '未安装';

  @override
  String get cloudSetupRefresh => '刷新检测';

  @override
  String get cloudSetupSkip => '稍后配置';

  @override
  String get cloudInstallCopy => '复制安装命令';

  @override
  String get cloudTimeout => '连接超时';

  @override
  String cloudToolNotFound(String tool) {
    return '未找到 $tool';
  }

  @override
  String get cloudTeamFavorites => '团队云资源';

  @override
  String get cloudNoTeamFavorites =>
      '暂无团队云资源。在私人区域将 K8s Context 或 AWS Profile 共享给团队。';

  @override
  String get teamV2RoleOps => '运维';

  @override
  String get teamV2RoleDeveloper => '开发者';

  @override
  String get teamV2RoleViewer => '只读';

  @override
  String get teamV2RoleCustom => '自定义角色';

  @override
  String get teamV2ManageRoles => '管理角色';

  @override
  String get teamV2CreateRole => '新建角色';

  @override
  String get teamV2DeleteRole => '删除';

  @override
  String get teamV2DeleteRoleConfirm => '确定删除此自定义角色？';

  @override
  String get teamV2PresetRoleReadonly => '预设';

  @override
  String get teamV2CapServerConnect => '连接';

  @override
  String get teamV2CapServerCreate => '创建服务器';

  @override
  String get teamV2CapServerEdit => '编辑服务器';

  @override
  String get teamV2CapServerDelete => '删除服务器';

  @override
  String get teamV2CapServerViewCredentials => '查看凭证';

  @override
  String get teamV2CapSnippetCreate => '创建片段';

  @override
  String get teamV2CapSnippetEdit => '编辑片段';

  @override
  String get teamV2CapSnippetDelete => '删除片段';

  @override
  String get teamV2CapSnippetExecute => '执行片段';

  @override
  String get teamV2CapTeamInvite => '邀请';

  @override
  String get teamV2CapTeamRemove => '移除成员';

  @override
  String get teamV2CapTeamRoleAssign => '分配角色';

  @override
  String get teamV2CapTeamSettingsEdit => '团队设置';

  @override
  String get teamV2CapSyncPush => '推送';

  @override
  String get teamV2CapSyncPull => '拉取';

  @override
  String get teamV2CapAuditView => '查看审计';

  @override
  String get teamV2CapAuditExport => '导出审计';

  @override
  String get teamV2EditRole => '编辑角色';

  @override
  String teamV2RoleInUse(String count) {
    return '该角色正被 $count 个成员使用';
  }

  @override
  String get teamV2CredProtected => '凭证受团队权限保护。';

  @override
  String get teamV2CredContactAdmin => '如需查看，请联系管理员。';

  @override
  String get teamV2PasswordUpdated => '团队密码已更新，请输入新密码。';

  @override
  String get teamV2PasswordPendingUpdate => '团队密码待更新';

  @override
  String teamV2ConflictResolved(String count) {
    return '已解决 $count 个冲突';
  }

  @override
  String get teamV2NoPermission => '无操作权限';

  @override
  String teamV2NoPermissionDetail(String capability) {
    return '需要权限: $capability';
  }

  @override
  String get teamV2AuditDashboard => '审计仪表盘';

  @override
  String get teamV2AuditExportReport => '导出...';

  @override
  String get teamV2AuditConnections => '连接';

  @override
  String get teamV2AuditCredAccess => '凭证';

  @override
  String get teamV2AuditConfigChanges => '变更';

  @override
  String get teamV2AuditMemberOps => '成员';

  @override
  String get teamV2AuditRecentOps => '最近';

  @override
  String get teamV2AuditViewAll => '查看全部';

  @override
  String get teamV2AuditFilterAll => '全部事件';

  @override
  String get teamV2AuditDateRange => '日期范围';

  @override
  String get teamV2AuditThisWeek => '本周';

  @override
  String get teamV2AuditThisMonth => '本月';

  @override
  String get teamV2AuditAll => '全部时间';

  @override
  String get teamV2AuditFormatJson => 'JSON';

  @override
  String get teamV2AuditFormatCsv => 'CSV';

  @override
  String get teamV2AuditFormatHtml => 'HTML';

  @override
  String get teamV2InviteMember => '邀请成员';

  @override
  String get teamV2InviteRole => '邀请角色';

  @override
  String get teamV2InviteExpiry => '有效期';

  @override
  String get teamV2InviteGenerate => '生成邀请码';

  @override
  String get teamV2InviteCode => '邀请码';

  @override
  String get teamV2InviteCopied => '已复制';

  @override
  String get teamV2InviteHint => '请将邀请码和团队密码分别发送给被邀请者。';

  @override
  String get teamV2InviteExpired => '邀请码已过期';

  @override
  String get teamV2InviteInvalid => '无效的邀请码';

  @override
  String teamV2InviteDays(String n) {
    return '$n 天';
  }

  @override
  String get teamV2JoinViaInvite => '邀请码';

  @override
  String get teamV2ConflictTitle => '同步冲突';

  @override
  String get teamV2ConflictDesc => '以下项目在本地和远程之间存在冲突变更：';

  @override
  String get teamV2ConflictLocalVersion => '本地 (你)';

  @override
  String teamV2ConflictRemoteVersion(String user) {
    return '远程 ($user)';
  }

  @override
  String get teamV2ConflictKeepLocal => '保留本地';

  @override
  String get teamV2ConflictUseRemote => '使用远程';

  @override
  String get teamV2ConflictSkip => '跳过';

  @override
  String get teamV2ConflictApply => '应用';

  @override
  String get teamV2ConflictAllLocal => '全部本地';

  @override
  String get teamV2ConflictAllRemote => '全部远程';

  @override
  String teamV2ConflictPending(String count) {
    return '$count 个冲突待解决';
  }

  @override
  String get aboutTagline => 'AI 时代永不断线的云端智能工作平台';

  @override
  String aboutUpdateAvailable(String version) {
    return '有可用更新 v$version';
  }

  @override
  String aboutUpdateReady(String version) {
    return '准备就绪 v$version';
  }

  @override
  String aboutUpdateFailed(String error) {
    return '更新失败: $error';
  }

  @override
  String get aboutAutoDownload => '自动下载更新';

  @override
  String get aboutCheckFrequencyLabel => '检查频率:';

  @override
  String get aboutFrequencyHourly => '每小时';

  @override
  String get aboutFrequencyDaily => '每天';

  @override
  String get aboutFrequencyWeekly => '每周';

  @override
  String get aboutCheckNow => '立即检查';

  @override
  String aboutDownloadButton(String version) {
    return '下载 v$version';
  }

  @override
  String get aboutApplyAndRestart => '重启并应用';

  @override
  String get aboutWebsite => '官网';

  @override
  String get aboutSessionPoolTitle => '会话池状态（调试）';

  @override
  String get aboutSessionPoolHelp =>
      '多 server 共用同一代理/跳板时复用上游 TCP 连接，每条 entry 显示引用计数与累计传输字节数。';

  @override
  String get aboutSessionPoolEmpty => '当前无活跃池条目';

  @override
  String aboutUpdateDownloadingPercent(String percent) {
    return '下载中 $percent%';
  }

  @override
  String get commonRefresh => '刷新';

  @override
  String commonLoadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String get settingsAi => 'AI 助手';

  @override
  String get settingsPrivacy => '隐私';

  @override
  String get settingsAudit => '审计日志';

  @override
  String get settingsLocalAi => '本地 AI';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsSearchPlaceholder => '搜索设置…';

  @override
  String get settingsSearchNoMatch => '无匹配的设置项';

  @override
  String get settingsIdxThemeLabel => '主题';

  @override
  String get settingsIdxThemeDesc => '浅色 / 深色 / 跟随系统';

  @override
  String get settingsIdxFontLabel => '字体';

  @override
  String get settingsIdxFontDesc => '终端字体与字号';

  @override
  String get settingsIdxCursorLabel => '光标';

  @override
  String get settingsIdxCursorDesc => '光标形状与闪烁';

  @override
  String get settingsIdxScrollbackLabel => '滚动缓冲';

  @override
  String get settingsIdxScrollbackDesc => '终端历史行数';

  @override
  String get settingsIdxTabWidthLabel => 'Tab 宽度';

  @override
  String get settingsIdxTabWidthDesc => '2 / 4 / 8 空格';

  @override
  String get settingsIdxKeybindingsLabel => '快捷键';

  @override
  String get settingsIdxKeybindingsDesc => '自定义命令与冲突检测';

  @override
  String get settingsIdxAiProviderLabel => 'AI Provider';

  @override
  String get settingsIdxAiProviderDesc => 'Claude / OpenAI / Ollama / Local';

  @override
  String get settingsIdxAiContextLabel => 'AI 上下文';

  @override
  String get settingsIdxAiContextDesc => '发送给 AI 的终端行数';

  @override
  String get settingsIdxTeamPassphraseLabel => '团队加密密码';

  @override
  String get settingsIdxTeamPassphraseDesc => '团队同步解锁';

  @override
  String get settingsIdxPrivacyClearLabel => '隐私数据清除';

  @override
  String get settingsIdxPrivacyClearDesc => '连接历史 / AI 对话 / Snippet 统计';

  @override
  String get settingsIdxGdprEraseLabel => 'GDPR 数据擦除';

  @override
  String get settingsIdxGdprEraseDesc => '永久删除所有本地数据';

  @override
  String get settingsIdxBackupLabel => '备份导出/导入';

  @override
  String get settingsIdxBackupDesc => '.termex 加密文件';

  @override
  String get settingsIdxAuditLabel => '审计日志';

  @override
  String get settingsIdxAuditDesc => '事件查询 / CSV 导出';

  @override
  String get settingsIdxLocalAiLabel => '本地 AI';

  @override
  String get settingsIdxLocalAiDesc => 'llama-server 端口与模型';

  @override
  String get settingsIdxAboutLabel => '关于';

  @override
  String get settingsIdxAboutDesc => '版本与许可证';

  @override
  String get backupAutoFreqLabel => '自动备份频率';

  @override
  String get backupAutoFreqHint => '.termex 加密备份的自动生成周期';

  @override
  String get backupFreqOff => '关闭';

  @override
  String get backupFreqDaily => '每日';

  @override
  String get backupFreqWeekly => '每周';

  @override
  String get backupEncryptionNote =>
      '.termex 备份文件使用 AES-256-GCM + Argon2id 加密。';

  @override
  String get backupNow => '立即备份';

  @override
  String get backupImportConfig => '导入配置';

  @override
  String get backupEnterEncryptPassword => '输入加密密码';

  @override
  String get backupEnterDecryptPassword => '输入解密密码';

  @override
  String backupDone(String file) {
    return '备份完成：$file';
  }

  @override
  String backupFailed(String error) {
    return '备份失败：$error';
  }

  @override
  String get backupPasswordHint => '密码（至少 12 位）';

  @override
  String get backupConfirm => '确定';

  @override
  String get backupHistoryTitle => '备份历史';

  @override
  String get backupHistoryClear => '清空';

  @override
  String backupHistoryMaxNote(String max) {
    return '保留最近 $max 条记录';
  }

  @override
  String get backupHistoryEmpty => '尚无备份记录';

  @override
  String get cloudTabScheduledBackup => '定时备份';

  @override
  String get cloudK8sSelectContext => '选择 Context 查看 Pods';

  @override
  String get cloudK8sColName => '名称';

  @override
  String get cloudK8sColStatus => '状态';

  @override
  String get cloudK8sColRestarts => '重启';

  @override
  String get cloudK8sColAge => 'Age';

  @override
  String get cloudK8sColImage => '镜像';

  @override
  String get cloudSsmEmpty => '未发现 SSM 实例';

  @override
  String get cloudSsmStartSession => '启动会话';

  @override
  String get cloudEcsFavoritesTitle => 'ECS 收藏夹';

  @override
  String get cloudEcsAdd => '添加';

  @override
  String get cloudEcsFavoritesEmpty => '尚无收藏的 ECS 实例';

  @override
  String get cloudEcsConnect => '连接';

  @override
  String get cloudScheduleTitle => '定时备份';

  @override
  String get cloudScheduleNew => '新建';

  @override
  String get cloudScheduleEmpty => '尚未配置定时备份';

  @override
  String get cloudHistoryEmpty => '暂无备份记录';

  @override
  String cloudScheduleWeekly(String weekday, String hour, String minute) {
    return '每周 $weekday · $hour:$minute UTC';
  }

  @override
  String cloudScheduleMonthly(String day, String hour, String minute) {
    return '每月 $day 号 · $hour:$minute UTC';
  }

  @override
  String cloudScheduleDaily(String hour, String minute) {
    return '每天 · $hour:$minute UTC';
  }

  @override
  String get cloudScheduleRunNow => '立即运行';

  @override
  String get cloudScheduleDelete => '删除';

  @override
  String get privacyDialogTitle => '隐私政策';

  @override
  String get privacyEffectiveDate => '生效日期 · 2026-05-07';

  @override
  String get privacyClose => '关闭';

  @override
  String get privacySec1Heading => '1. 概述';

  @override
  String get privacySec1Body =>
      'Termex 是一款开源 SSH 客户端。我们重视您的隐私：本应用不收集、不传输、不存储任何用户数据到 Termex 服务器 —— Termex 没有任何后端服务器。';

  @override
  String get privacySec2Heading => '2. 数据存储';

  @override
  String get privacySec2Body =>
      '所有数据仅存储在您的设备本地：\n· 服务器配置：本地 SQLite，SQLCipher AES-256 加密。\n· SSH 密码 / 密钥密语：系统 Keychain（macOS）/ Credential Manager（Windows）/ Secret Service（Linux）。\n· AI API 密钥：同上，存于系统 Keychain。\n· 会话录制：本地文件系统。\n· 监控历史：本地 SQLite，SQLCipher 加密。';

  @override
  String get privacySec3Heading => '3. 网络连接';

  @override
  String get privacySec3Body =>
      'Termex 仅建立以下网络连接：\n· SSH 连接：直连您指定的服务器，不经过任何中间节点。\n· AI 请求：直连您配置的 AI 服务提供商（OpenAI、Anthropic 等），Termex 不作为代理或中转。\n· 应用更新：检查官方 appcast feed 以获取版本信息。';

  @override
  String get privacySec4Heading => '4. 团队同步（可选）';

  @override
  String get privacySec4Body =>
      '若您启用团队功能，Termex 会通过您指定的 Git 仓库同步加密后的配置。Termex 不作为同步服务器；所有数据在传输前已用团队密钥加密。';

  @override
  String get privacySec5Heading => '5. 您的权利（GDPR / CCPA）';

  @override
  String get privacySec5Body =>
      '由于 Termex 不收集任何个人数据：\n· 数据访问 / 导出：所有数据本地可读。\n· 数据删除：设置 → 隐私 → 擦除所有数据。\n· 数据可携：设置 → 数据 → 导出加密备份。';

  @override
  String get privacySec6Heading => '6. 联系方式';

  @override
  String get privacySec6Body =>
      '完整版隐私政策请见项目仓库 docs/privacy-policy.md。如有任何隐私相关问题，请通过 GitHub Issues 联系我们。';

  @override
  String get proxiesTitle => '代理配置';

  @override
  String get proxiesAddProxy => '添加代理';

  @override
  String get proxiesEmpty => '尚未配置代理\n点击\"添加代理\"创建 HTTP 或 SOCKS5 代理';

  @override
  String get proxiesDefault => '默认';

  @override
  String get proxiesTestConn => '测试连接';

  @override
  String get proxiesTestOk => '代理连接正常 ✓';

  @override
  String get proxiesTestFail => '代理连接失败';

  @override
  String proxiesTestError(String error) {
    return '测试失败: $error';
  }

  @override
  String get proxiesSetDefault => '设为默认';

  @override
  String get proxiesDelete => '删除';

  @override
  String get proxiesDialogName => '名称';

  @override
  String get proxiesDialogType => '类型';

  @override
  String get proxiesDialogHost => '主机';

  @override
  String get proxiesDialogPort => '端口';

  @override
  String get proxiesDialogUsername => '用户名';

  @override
  String get proxiesDialogPassword => '密码';

  @override
  String get proxiesDialogOptional => '（可选）';

  @override
  String get proxiesDialogAdd => '添加';

  @override
  String get proxiesDefaultName => '代理';

  @override
  String get gitSyncExtraReposTitle => '附加仓库';

  @override
  String get gitSyncNoExtraRepos => '未配置附加仓库';

  @override
  String get gitSyncAddRepo => '添加仓库';

  @override
  String get gitSyncAddDialogTitle => '添加 Git Sync 仓库';

  @override
  String get gitSyncLocalPath => '本地路径';

  @override
  String get gitSyncRemoteUrl => '远端 URL';

  @override
  String get gitSyncRemoteUrlGitSsh => '远端 URL (git/ssh)';

  @override
  String get gitSyncAdd => '添加';

  @override
  String get gitSyncManualSync => '手动同步';

  @override
  String get gitSyncEnable => '启用';

  @override
  String get gitSyncRowLocal => '本地';

  @override
  String get gitSyncRowRemote => '远端';

  @override
  String get gitSyncRowLastSync => '最近同步';

  @override
  String gitSyncResolveConflicts(String count) {
    return '解决冲突 ($count)';
  }

  @override
  String get gitSyncEnableDialogTitle => '启用 Git Sync';

  @override
  String get gitSyncLocalRepoPath => '本地仓库路径';

  @override
  String gitSyncRowError(String message) {
    return '错误: $message';
  }

  @override
  String get sftpSortNameAsc => '名称 ↑';

  @override
  String get sftpSortNameDesc => '名称 ↓';

  @override
  String get sftpSortSizeDesc => '大小';

  @override
  String get sftpSortModifiedDesc => '修改时间';

  @override
  String get sftpSortTypeFirst => '类型';

  @override
  String get sftpShowHidden => '显示隐藏';

  @override
  String get sftpSortTooltip => '排序';

  @override
  String get sftpColName => '名称';

  @override
  String get sftpColSize => '大小';

  @override
  String get sftpColModified => '修改时间';

  @override
  String get sftpColPermissions => '权限';

  @override
  String get sftpEmptyDir => '（空目录）';

  @override
  String get sftpActionDownload => '下载';

  @override
  String get sftpActionRename => '重命名';

  @override
  String get sftpActionEdit => '编辑';

  @override
  String get sftpActionCopyPath => '复制路径';

  @override
  String get sftpActionSelectAll => '全选';

  @override
  String get sftpActionDelete => '删除';

  @override
  String get sftpActionChmod => '修改权限';

  @override
  String get sftpActionNewFile => '新建文件';

  @override
  String get sftpActionNewFolder => '新建文件夹';

  @override
  String get sftpActionProperties => '属性';

  @override
  String get teamOfflineToast => '网络不可达，进入离线模式';

  @override
  String get teamLeaveTitle => '离开团队';

  @override
  String get teamLeaveBody => '离开后将删除本地团队数据，不可恢复。';

  @override
  String get teamStatMembers => '成员';

  @override
  String get teamStatSharedServers => '共享服务器';

  @override
  String get teamStatSharedProxies => '共享代理';

  @override
  String get teamOfflineBanner => '离线模式 — 仅可浏览本地';

  @override
  String get teamMyRole => '我的角色';

  @override
  String teamConflictsCount(String count) {
    return '$count 个同步冲突 — 点击解决';
  }

  @override
  String teamItemsCount(String count) {
    return '$count 项';
  }

  @override
  String get teamSyncNow => '立即同步';

  @override
  String get teamRelJustNow => '刚刚';

  @override
  String teamRelMinutesAgo(String n) {
    return '$n 分钟前';
  }

  @override
  String teamRelHoursAgo(String n) {
    return '$n 小时前';
  }

  @override
  String teamRelDaysAgo(String n) {
    return '$n 天前';
  }

  @override
  String get teamLeaveButton => '离开团队';

  @override
  String get teamDashLocked => '团队功能已锁定';

  @override
  String get teamDashUnlock => '解锁团队协作';

  @override
  String get teamDashMembersTitle => '团队成员';

  @override
  String teamDashMemberCount(String count) {
    return '$count 名成员';
  }

  @override
  String teamDashLastSyncShort(String ago) {
    return '上次同步: $ago';
  }

  @override
  String get teamDashInviteMember => '邀请成员';

  @override
  String teamDashConflictsShort(String count) {
    return '$count 个同步冲突';
  }

  @override
  String get teamDashPendingInvites => '待接受邀请';

  @override
  String get teamDashSyncShort => '同步';

  @override
  String get teamDashResolve => '解决';

  @override
  String get teamDashRevokeInvite => '撤销邀请';

  @override
  String get recordingCleanupDone => '已清理过期录制文件';

  @override
  String recordingCleanupFailed(String error) {
    return '清理失败: $error';
  }

  @override
  String get recordingSaveSettings => '录制保存设置';

  @override
  String get recordingFormat => '录制格式';

  @override
  String get recordingFormatJsonSubtitle =>
      '结构化 JSON 格式，支持 asciinema 播放器回放\n体积小，推荐用于分享';

  @override
  String get recordingFormatRawSubtitle => '原始终端字节流，适合离线回放\n体积较大，保存完整输出';

  @override
  String get recordingStorageNote =>
      '录制文件保存在应用数据目录下的 recordings/ 子目录中。\n超过保留期限的录制文件将在每次启动时自动清理。';

  @override
  String get recordingRetentionForever => '永久保留';

  @override
  String get recordingRetentionNone => '不保留';

  @override
  String recordingRetentionDays(String days) {
    return '$days 天';
  }

  @override
  String get recordingRetentionTitle => '录制保留期限';

  @override
  String get recordingForever => '永久';

  @override
  String get recordingOneYear => '1年';

  @override
  String get recordingCleanupNow => '立即清理过期录制';

  @override
  String get recordingCleanupRunning => '清理中…';

  @override
  String get keybindingsNewTab => '新建标签页';

  @override
  String get keybindingsClosePane => '关闭窗格';

  @override
  String get keybindingsCopy => '复制';

  @override
  String get keybindingsPaste => '粘贴';

  @override
  String get keybindingsSelectAll => '全选';

  @override
  String get keybindingsZoomIn => '放大字号';

  @override
  String get keybindingsZoomOut => '缩小字号';

  @override
  String get keybindingsResetZoom => '重置字号';

  @override
  String get keybindingsCommandPalette => '命令面板';

  @override
  String get keybindingsAiDiagnose => 'AI 诊断';

  @override
  String get keybindingsNl2cmd => '自然语言转命令';

  @override
  String get keybindingsSftpPanel => 'SFTP 面板';

  @override
  String get keybindingsSftpUpload => '上传文件';

  @override
  String get keybindingsSftpDownload => '下载文件';

  @override
  String get keybindingsToggleSftp => '切换 SFTP';

  @override
  String get keybindingsReloadWindow => '重新载入窗口';

  @override
  String get keybindingsToggleFullscreen => '切换全屏';

  @override
  String get sidebarProxies => '代理';

  @override
  String get keybindingsUntranslated => '(未翻译)';

  @override
  String get settingsTerminalScrollback => '滚动缓冲行数';

  @override
  String get settingsTerminalScrollbackHint => '向上回滚历史的最大行数';

  @override
  String settingsTerminalLinesOption(String count) {
    return '$count 行';
  }

  @override
  String get settingsTerminalTabWidth => 'Tab 宽度';

  @override
  String settingsTerminalSpacesOption(String count) {
    return '$count 空格';
  }

  @override
  String get settingsTerminalCursorShape => '光标形状';

  @override
  String get settingsTerminalCursorBlock => '方块';

  @override
  String get settingsTerminalCursorUnderline => '下划线';

  @override
  String get settingsTerminalCursorBar => '竖线';

  @override
  String get settingsTerminalCursorBlink => '光标闪烁';

  @override
  String get settingsTerminalTmux => 'Tmux 多路复用';

  @override
  String get settingsTerminalTmuxHint => '检测远端 tmux 会话并在状态栏显示';

  @override
  String get settingsAiAllConfigured => '所有 Provider 都已配置';

  @override
  String get settingsAiContextLines => '默认上下文行数';

  @override
  String get settingsAiContextLinesHint => '发送给 AI 的终端历史行数上限';

  @override
  String get settingsAiAutoDiagnose => '自动错误诊断';

  @override
  String get settingsAiAutoDiagnoseHint => '命令失败时自动触发 AI 分析';

  @override
  String settingsAiRemoveProviderTitle(String name) {
    return '移除 $name?';
  }

  @override
  String settingsAiRemoveProviderHint(String name) {
    return '将删除 $name 的本地配置（API key 仍保留在系统钥匙串中，重新配置时会自动加载）。';
  }

  @override
  String get settingsAiRemove => '移除';

  @override
  String get settingsAiEmptyTitle => '尚未配置 AI Provider';

  @override
  String get settingsAiEmptyHint => '点击右上「Add Provider」选择一个开始';

  @override
  String get settingsAiBadgeActive => '当前';

  @override
  String get settingsAiBadgeConfigured => '已配置';

  @override
  String get settingsAiActivate => '激活';

  @override
  String get settingsAiCollapse => '收起';

  @override
  String get settingsAiConfigure => '配置';

  @override
  String get settingsAiAddProvider => 'Add Provider';

  @override
  String get settingsAiPricingTitle => 'AI 成本估算价格表';

  @override
  String settingsAiPricingUpdated(String iso, String age) {
    return '更新于 $iso · $age';
  }

  @override
  String get settingsAiPricingStale => ' · 建议刷新';

  @override
  String get settingsAiPricingDateUnknown => '日期未知';

  @override
  String get settingsAiPricingToday => '今天更新';

  @override
  String settingsAiPricingDaysAgo(String count) {
    return '$count 天前';
  }

  @override
  String get settingsKeybindingsResetTitle => '恢复默认快捷键?';

  @override
  String get settingsKeybindingsResetBody => '所有自定义的快捷键将被覆盖为出厂默认值。';

  @override
  String get settingsKeybindingsReset => '恢复';

  @override
  String get settingsKeybindingsColCommand => '命令';

  @override
  String get settingsKeybindingsColShortcut => '快捷键';

  @override
  String get settingsKeybindingsColContext => '上下文';

  @override
  String get settingsKeybindingsResetTooltip => '恢复默认';

  @override
  String get gitConflictTitle => '⚠ Git Sync 冲突';

  @override
  String get gitConflictFilesLabel => '以下文件存在冲突：';

  @override
  String get gitConflictStrategyLabel => '选择解决策略：';

  @override
  String get gitConflictResolveInTerminal => '终端中解决';

  @override
  String get gitConflictUseRemote => '使用远端';

  @override
  String get gitConflictKeepLocal => '保留本地';

  @override
  String sftpChmodTitleNamed(String name) {
    return '修改权限：$name';
  }

  @override
  String get sftpChmodOwner => '所有者';

  @override
  String get sftpChmodGroup => '组';

  @override
  String get sftpChmodOthers => '其他';

  @override
  String get sftpChmodOctalShort => '八进制';

  @override
  String get sftpChmodRead => '读';

  @override
  String get sftpChmodWrite => '写';

  @override
  String get sftpChmodExec => '执行';

  @override
  String get sftpRenameEmpty => '名称不能为空';

  @override
  String get sftpRenameSlash => '名称不能包含 /';

  @override
  String get sftpRenameNewName => '新名称';

  @override
  String get settingsHighlightsTitle => '关键词高亮';

  @override
  String get settingsHighlightsLoadPresets => '加载预设';

  @override
  String get settingsHighlightsAddRule => '+ 新增规则';

  @override
  String get settingsHighlightsEmpty => '尚未配置任何高亮规则';

  @override
  String get settingsHighlightsPatternHint => '关键字 / 正则';

  @override
  String get settingsHighlightsRegex => '正则';

  @override
  String get settingsHighlightsCaseSensitive => '区分大小写';

  @override
  String get settingsHighlightsBgColor => '背景色';

  @override
  String get settingsHighlightsFgColor => '前景色 (留空 = 跟随主题)';

  @override
  String get settingsHighlightsEnabled => '启用';

  @override
  String get settingsHighlightsColorInputHint => '输入十六进制颜色（如 #6366F1）';

  @override
  String get settingsHighlightsColorClear => '清除';

  @override
  String get settingsHighlightsColorConfirm => '确定';

  @override
  String get settingsPrivacyClearHistoryTitle => '清除历史数据';

  @override
  String get settingsPrivacyClearHistoryHint => '保留账号设置与凭据，仅清空相应历史。';

  @override
  String get settingsPrivacyClearConnections => '清除最近连接历史';

  @override
  String get settingsPrivacyClearConnectionsMsg =>
      '将删除全部\"最近连接\"记录，已保存的服务器配置不受影响。';

  @override
  String get settingsPrivacyClearedConnections => '已清除连接历史';

  @override
  String get settingsPrivacyClearAi => '清除 AI 对话历史';

  @override
  String get settingsPrivacyClearAiMsg =>
      '将永久删除所有 AI 对话与消息。Provider 配置 / API Key 保留。';

  @override
  String get settingsPrivacyClearedAi => '已清除 AI 对话历史';

  @override
  String get settingsPrivacyClearSnippet => '清除 Snippet 使用统计';

  @override
  String get settingsPrivacyClearSnippetMsg =>
      '将重置所有 Snippet 的使用次数，Snippet 本身保留。';

  @override
  String get settingsPrivacyClearedSnippet => '已清除使用统计';

  @override
  String get settingsPrivacyGdprTitle => 'GDPR 数据擦除';

  @override
  String get settingsPrivacyGdprHint => '永久删除所有本地数据（服务器配置、凭据、对话、设置）。此操作不可恢复。';

  @override
  String get settingsPrivacyGdprButton => '擦除所有数据';

  @override
  String get settingsPrivacyConfirmClear => '清除';

  @override
  String get settingsPrivacyGdprDialogTitle => '确认擦除所有数据';

  @override
  String get settingsPrivacyGdprDialogBody =>
      '此操作将永久删除所有数据，无法恢复。\n请输入主密码并键入 \"DELETE ALL\" 确认。';

  @override
  String get settingsPrivacyMasterPassword => '主密码';

  @override
  String get settingsPrivacyConfirmTextLabel => '确认文本';

  @override
  String get settingsPrivacyErase => '擦除';

  @override
  String get settingsPrivacyEraseError => '确认文字不正确或主密码错误';

  @override
  String get settingsPrivacyErased => '数据已擦除';

  @override
  String get settingsSecurityLoading => '加载中…';

  @override
  String get settingsSecurityLoadError => '无法读取安全状态';

  @override
  String get settingsSecurityProtectionTitle => '密钥保护模式';

  @override
  String settingsSecurityProtectionActive(String platform) {
    return '已使用 $platform 安全存储凭据。Termex 仅在启动时读取一次主密钥条目。';
  }

  @override
  String get settingsSecurityProtectionFallback =>
      '系统密钥库不可用，已回退到本地加密（AES-256-GCM + Argon2id）。';

  @override
  String get settingsSecuritySavedCredentials => '已保存的凭据';

  @override
  String get settingsSecurityCredentialTypes =>
      '包括 SSH 密码、SSH 私钥口令、AI Provider API Key';

  @override
  String get settingsSecurityHowItWorks => '工作原理';

  @override
  String get settingsSecurityHint1 => '凭据从未以明文写入数据库 — 仅保存系统密钥库的引用 ID';

  @override
  String get settingsSecurityHint2 => '主密钥条目在每次启动时只读取一次，避免反复弹出系统密码框';

  @override
  String get settingsSecurityHint3 => 'GDPR 数据擦除会同步清空密钥库中所有 Termex 条目';

  @override
  String get auditDetailTitle => '审计详情';

  @override
  String get auditFieldEventType => '事件类型';

  @override
  String get auditFieldTime => '时间';

  @override
  String get auditFieldDetail => '详情';

  @override
  String get auditCopyDetail => '复制详情';

  @override
  String get auditKpiTotal => '总记录';

  @override
  String get auditKpiConnections => '连接';

  @override
  String get auditKpiCredentialAccess => '凭据访问';

  @override
  String get auditKpiConfigChanges => '配置变更';

  @override
  String get auditKpiMemberOps => '成员操作';

  @override
  String get auditColEvent => '事件';

  @override
  String get auditPagerPrev => '上一页';

  @override
  String get auditPagerNext => '下一页';

  @override
  String get auditEmptyTitle => '暂无审计日志';

  @override
  String get auditEmptyHint => '建立 SSH 连接、修改设置或团队操作会写入审计日志';

  @override
  String get auditExport => '导出';

  @override
  String get auditExportCsv => '导出 CSV';

  @override
  String get auditExportJson => '导出 JSON';

  @override
  String auditExported(String path) {
    return '已导出 $path';
  }

  @override
  String auditExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get auditLabelDate => '日期：';

  @override
  String get auditLabelEvent => '事件：';

  @override
  String get auditRangeToday => '今天';

  @override
  String get auditRangeWeek => '本周';

  @override
  String get auditRangeMonth => '本月';

  @override
  String get auditRangeAll => '全部';

  @override
  String snippetUsageTimes(int count) {
    return '$count 次';
  }

  @override
  String get snippetCopy => '复制';

  @override
  String get snippetCopiedToClipboard => '已复制到剪贴板';

  @override
  String get snippetDeleteTitle => '删除 Snippet';

  @override
  String snippetDeleteConfirmNamed(String title) {
    return '确定要删除「$title」吗？';
  }

  @override
  String get snippetNewTitle => '新建 Snippet';

  @override
  String get snippetEditSnippet => '编辑 Snippet';

  @override
  String get snippetNamePlaceholder => 'Snippet 名称';

  @override
  String get snippetTagsCommaLabel => '标签（逗号分隔）';

  @override
  String get snippetTagsPlaceholderExample => 'ssh, 常用, docker';

  @override
  String get snippetContentLabel => '命令内容（使用 ｛｛变量名:默认值｝｝ 插入变量）';

  @override
  String snippetVariableTitleNamed(String title) {
    return '填写变量 — $title';
  }

  @override
  String get snippetPreview => '预览';

  @override
  String get snippetConfirmExecute => '确认执行';

  @override
  String snippetVariableDefault(String value) {
    return '默认: $value';
  }

  @override
  String get snippetVariableInputHint => '请输入值';

  @override
  String get snippetSearchPlaceholder => '搜索 snippet…';

  @override
  String get snippetNoMatch => '没有匹配的 Snippet';

  @override
  String get sftpPath => '路径';

  @override
  String get sftpOwner => '所有者';

  @override
  String get sftpGroup => '所属组';

  @override
  String sftpSizeBytes(int bytes) {
    return '$bytes 字节';
  }

  @override
  String get sftpFileNameHint => '文件名';

  @override
  String get sftpFolderNameHint => '文件夹名';

  @override
  String get sftpCreate => '创建';

  @override
  String sftpEditorTooLarge(String size) {
    return '文件过大（$size），请用 scp 下载到本地编辑。';
  }

  @override
  String get sftpEditorBinary => '检测到二进制内容，无法使用内联编辑器编辑。';

  @override
  String sftpEditorReadFailed(String error) {
    return '读取失败：$error';
  }

  @override
  String sftpEditorSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get sftpEditorModified => '已修改';

  @override
  String get sftpTransferResume => '继续';

  @override
  String get sftpTransferPause => '暂停';

  @override
  String get sftpTransferDone => '完成';

  @override
  String sftpTransferFailed(String error) {
    return '失败：$error';
  }

  @override
  String get sftpTransferCancelled => '已取消';

  @override
  String get sftpTransferPaused => '已暂停';

  @override
  String get aiConversationsTitle => '对话';

  @override
  String get aiConversationEmpty => '点击 + 开始新对话';

  @override
  String get aiRenameConversation => '重命名对话';

  @override
  String get aiRenameHint => '输入新标题';

  @override
  String get aiModelListLoading => '正在加载模型列表…';

  @override
  String get aiDeleteModelTitle => '删除模型';

  @override
  String aiDeleteModelConfirm(String name) {
    return '确定要删除 $name 吗？';
  }

  @override
  String get localAiRunning => '运行中';

  @override
  String get localAiStart => '启动';

  @override
  String localAiDownloadWithSize(String size) {
    return '下载 ($size)';
  }

  @override
  String get aiNl2cmdTitle => '自然语言 → 命令';

  @override
  String get aiNl2cmdHint => '描述你想做什么，例如：查找大于 100MB 的文件';

  @override
  String get aiNl2cmdSent => '(已发送到 AI 对话)';

  @override
  String get aiNl2cmdGenerate => '生成';

  @override
  String settingsAiConfigureTitle(String name) {
    return '配置 $name';
  }

  @override
  String get settingsAiTerminalContextLines => '终端上下文行数';

  @override
  String settingsAiLinesUnit(int count) {
    return '$count 行';
  }

  @override
  String get settingsAiVerify => '验证';

  @override
  String get settingsAiSelectModelError => '请选择模型';

  @override
  String get settingsAiApiKeyRequired => '请填写 API Key';

  @override
  String get settingsAiVerifySuccess => '验证成功';

  @override
  String get settingsAiVerifyFailed => '验证失败';

  @override
  String get settingsAiLlamaEngine => 'llama-server 引擎';

  @override
  String get settingsAiServerPort => '服务端口';

  @override
  String get settingsAiInferenceThreads => '推理线程数';

  @override
  String get settingsAiContextWindow => '上下文窗口 (token)';

  @override
  String get settingsAiAutoStartEngine => '启动时自动启动引擎';

  @override
  String teamSyncDoneCount(int count) {
    return '同步完成（$count 项变更）';
  }

  @override
  String teamSyncFailed(String error) {
    return '同步失败：$error';
  }

  @override
  String get teamApplied => '已应用';

  @override
  String teamResolveFailed(String error) {
    return '解决失败：$error';
  }

  @override
  String get teamRoleUpdated => '已更新角色';

  @override
  String teamUpdateFailed(String error) {
    return '更新失败：$error';
  }

  @override
  String get teamRemoved => '已移除';

  @override
  String teamRemoveFailed(String error) {
    return '移除失败：$error';
  }

  @override
  String get teamWorkspace => '团队工作区';

  @override
  String teamMemberBadge(int count) {
    return '$count 成员';
  }

  @override
  String teamConflictBadge(int count) {
    return '$count 冲突';
  }

  @override
  String get teamChangePassphrase => '修改口令';

  @override
  String get teamNoMembers => '暂无成员（生成邀请码后即可加入）';

  @override
  String get teamUnnamed => '(未命名)';

  @override
  String get teamPendingConflicts => '待解决的同步冲突';

  @override
  String teamConflictServerField(String serverId, String field) {
    return '服务器 $serverId · 字段 $field';
  }

  @override
  String get teamConflictLocal => '本地';

  @override
  String get teamConflictRemote => '远端';

  @override
  String get teamUseThisValue => '使用此值';

  @override
  String get teamInviteNewMember => '邀请新成员';

  @override
  String get teamInviteDesc => '为新成员生成一次性邀请码（72 小时内有效）。';

  @override
  String get teamGenerateHint => '点击下方按钮生成邀请码。';

  @override
  String get teamGenerating => '生成中…';

  @override
  String teamExpiresAt(String time) {
    return '过期：$time';
  }

  @override
  String get teamVerifyPassphraseTitle => '验证团队口令';

  @override
  String get teamVerifyPassphraseDesc => '输入团队加密口令验证当前会话。';

  @override
  String get teamPassphrasePlaceholder => '口令';

  @override
  String get teamVerify => '验证';

  @override
  String get teamPassphraseIncorrect => '口令不正确';

  @override
  String get teamVerifyPassed => '验证通过';

  @override
  String teamVerifyFailed(String error) {
    return '验证失败：$error';
  }

  @override
  String get teamLoadFailed => '加载团队信息失败';

  @override
  String get proxyNone => '不使用代理';

  @override
  String get proxyLoading => '加载中…';

  @override
  String get proxySelect => '选择代理';

  @override
  String get proxyAddNew => '+ 新建代理';

  @override
  String get proxyNewTitle => '新建代理';

  @override
  String get proxyNamePlaceholder => '我的代理';

  @override
  String get proxyUsernameOptional => '用户名（可选）';

  @override
  String get proxyPasswordOptional => '密码（可选）';

  @override
  String get proxyWarpHint => '将通过本机 Cloudflare WARP 客户端路由连接。';

  @override
  String get proxyTorHint => '将通过本机 Tor 网络路由连接。注意：上架时需在隐私声明中说明。';

  @override
  String get proxySave => '保存代理';

  @override
  String get serverUnshareFromTeam => '取消团队共享';

  @override
  String get serverShareToTeam => '分享到团队';

  @override
  String get serverUnsharedFromTeamToast => '已取消团队共享';

  @override
  String get serverSharedToTeam => '已分享至团队';

  @override
  String get serverUnshareAction => '取消共享';

  @override
  String get serverShareAction => '分享';

  @override
  String serverActionFailed(String action, String error) {
    return '$action失败：$error';
  }

  @override
  String get serverBadgeProxyTooltip => '已配置网络代理';

  @override
  String get serverBadgeBastionTooltip => '经跳板机连接';

  @override
  String get sftpCancelEdit => '取消编辑';

  @override
  String get settingsAppearanceLight => '浅色';

  @override
  String get settingsAppearanceDark => '深色';

  @override
  String get settingsAppearanceColorScheme => '终端配色方案';

  @override
  String get settingsAppearanceFontSize => '字体大小';

  @override
  String get settingsAppearanceChinese => '中文';

  @override
  String get updateDialogTitle => '检查更新';

  @override
  String get updateInProgress => '正在检查更新…';

  @override
  String get updateUpToDateTitle => '已是最新版本';

  @override
  String updateUpToDateDetail(String version, String channel) {
    return '当前版本 v$version 是 $channel 渠道的最新发布。';
  }

  @override
  String get updateCheckFailedTitle => '检查失败';

  @override
  String updateNewVersionTitle(String version) {
    return '新版本 v$version';
  }

  @override
  String get updateNoReleaseNotes => '（无发布说明）';

  @override
  String get updateViewDownloadPage => '查看下载页';

  @override
  String get updateRecheck => '重新检查';

  @override
  String get monitorSampleInterval => '采样间隔';

  @override
  String get monitorSampleIntervalHint => '每个监控指标的刷新频率';

  @override
  String get monitorAutoStartLabel => '自动启动';

  @override
  String get monitorAutoStartHint => '标签连接成功后自动开启监控';

  @override
  String get monitorPanelDisplay => '面板显示';

  @override
  String get monitorPanelDisplayHint => '选择需要展示的监控指标';

  @override
  String get monitorMemory => '内存';

  @override
  String get monitorDisk => '磁盘';

  @override
  String get monitorNetwork => '网络';

  @override
  String get monitorProcesses => '进程';

  @override
  String get settingsLocalAiContextSize => '上下文窗口大小';

  @override
  String get settingsLocalAiContextSizeHint => '单位：token';

  @override
  String get settingsLocalAiModelManagement => '本地模型管理';

  @override
  String get recordingDeleted => '已删除';

  @override
  String recordingDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get recordingNoServer => '未关联服务器';

  @override
  String get recordingEmpty => '暂无录制';

  @override
  String get recordingEmptyHint => '在终端启用录制以收集会话回放';

  @override
  String get recordingOpen => '打开';

  @override
  String get tabWorkspaceSftpLocalDisabled => '本地终端不支持 SFTP';

  @override
  String get tabWorkspaceTransfersLocalDisabled => '本地终端不支持文件传输';

  @override
  String get tabWorkspaceNoTransfers => '暂无传输任务';

  @override
  String get aiCodeBlockRun => '运行';

  @override
  String get sftpChmodOwnershipSection => '属主与用户组（数字 UID / GID）';

  @override
  String sftpChmodApplyFailed(String error) {
    return '应用失败：$error';
  }

  @override
  String get localAiLoadingModels => '正在加载模型列表…';

  @override
  String get localAiAdoptedModel => '本地已有';

  @override
  String get localAiAdoptedHint => '在模型目录中找到，不在内置目录中。';

  @override
  String localAiRamRequirement(int gb) {
    return '$gb GB 内存';
  }

  @override
  String localAiContextTokens(String tokens) {
    return '$tokens 上下文';
  }
}
