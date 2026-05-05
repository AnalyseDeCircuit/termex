import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:termex_bridge/src/models.dart' as bridge_models;

import '../../../system/sentinel_flag.dart';
import 'config_matcher.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

enum ThemeMode { system, light, dark }
enum CursorShape { block, underline, bar }
enum ScrollbackSize { small, medium, large }  // 1000 / 10000 / 100000
enum BackupFrequency { off, daily, weekly }
enum Language { zhCN, enUS }

class AppSettings {
  final ThemeMode themeMode;
  final String colorScheme;
  final String fontFamily;
  final double fontSize;
  final CursorShape cursorShape;
  final bool cursorBlink;
  final int scrollbackLines;
  final int tabWidth;
  final Language language;
  final bool aiAutoDiagnose;
  final int aiContextLines;
  final BackupFrequency backupFrequency;
  final int auditRetentionDays;
  final int localAiPort;
  final int localAiThreads;
  final int localAiContextSize;

  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.colorScheme = 'github-dark',
    this.fontFamily = 'JetBrainsMono',
    this.fontSize = 13.0,
    this.cursorShape = CursorShape.block,
    this.cursorBlink = true,
    this.scrollbackLines = 10000,
    this.tabWidth = 4,
    this.language = Language.zhCN,
    this.aiAutoDiagnose = true,
    this.aiContextLines = 100,
    this.backupFrequency = BackupFrequency.off,
    this.auditRetentionDays = 90,
    this.localAiPort = 8080,
    this.localAiThreads = 4,
    this.localAiContextSize = 4096,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? colorScheme,
    String? fontFamily,
    double? fontSize,
    CursorShape? cursorShape,
    bool? cursorBlink,
    int? scrollbackLines,
    int? tabWidth,
    Language? language,
    bool? aiAutoDiagnose,
    int? aiContextLines,
    BackupFrequency? backupFrequency,
    int? auditRetentionDays,
    int? localAiPort,
    int? localAiThreads,
    int? localAiContextSize,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        colorScheme: colorScheme ?? this.colorScheme,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        cursorShape: cursorShape ?? this.cursorShape,
        cursorBlink: cursorBlink ?? this.cursorBlink,
        scrollbackLines: scrollbackLines ?? this.scrollbackLines,
        tabWidth: tabWidth ?? this.tabWidth,
        language: language ?? this.language,
        aiAutoDiagnose: aiAutoDiagnose ?? this.aiAutoDiagnose,
        aiContextLines: aiContextLines ?? this.aiContextLines,
        backupFrequency: backupFrequency ?? this.backupFrequency,
        auditRetentionDays: auditRetentionDays ?? this.auditRetentionDays,
        localAiPort: localAiPort ?? this.localAiPort,
        localAiThreads: localAiThreads ?? this.localAiThreads,
        localAiContextSize: localAiContextSize ?? this.localAiContextSize,
      );
}

// ─── Audit log ────────────────────────────────────────────────────────────────

class AuditLogEntry {
  final String id;
  final String eventType;
  final String detail;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.eventType,
    required this.detail,
    required this.createdAt,
  });
}

// ─── State ────────────────────────────────────────────────────────────────────

class SettingsState {
  final AppSettings settings;
  final bool isLoading;
  final bool isDirty;
  final String? errorMessage;
  final List<AuditLogEntry> auditLogs;

  const SettingsState({
    this.settings = const AppSettings(),
    this.isLoading = false,
    this.isDirty = false,
    this.errorMessage,
    this.auditLogs = const [],
  });

  SettingsState copyWith({
    AppSettings? settings,
    bool? isLoading,
    bool? isDirty,
    String? errorMessage,
    List<AuditLogEntry>? auditLogs,
    bool clearError = false,
  }) =>
      SettingsState(
        settings: settings ?? this.settings,
        isLoading: isLoading ?? this.isLoading,
        isDirty: isDirty ?? this.isDirty,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        auditLogs: auditLogs ?? this.auditLogs,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    Future.microtask(_load);
    return const SettingsState();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      final remote = await bridge.settingsLoad();
      state = state.copyWith(
        settings: _fromBridge(remote),
        isLoading: false,
      );
    } catch (_) {
      // native not ready — keep defaults
      state = state.copyWith(isLoading: false);
    }
  }

  void update(AppSettings settings) {
    state = state.copyWith(settings: settings, isDirty: true);
  }

  Future<void> save() async {
    try {
      await bridge.settingsSave(settings: _toBridge(state.settings));
      state = state.copyWith(isDirty: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isDirty: false, errorMessage: e.toString());
    }
  }

  Future<void> resetToDefaults() async {
    try {
      await bridge.settingsResetToDefaults();
    } catch (_) {}
    state = state.copyWith(settings: const AppSettings(), isDirty: false);
  }

  Future<void> exportConfig(String path, String password) async {
    try {
      await bridge.settingsExport(path: path, password: password);
    } catch (_) {}
  }

  /// Imports settings from an encrypted `.tmx` archive.
  /// Layout: [header (64 bytes) | salt (16 bytes) | ciphertext | hmac (32 bytes)]
  /// The salt MUST be regenerated per export (PBKDF2 forward secrecy).
  Future<void> importConfig(String path, String password) async {
    try {
      final remote =
          await bridge.settingsImport(path: path, password: password);
      state = state.copyWith(settings: _fromBridge(remote), isDirty: false);
    } catch (_) {
      state = state.copyWith(isDirty: false);
    }
    if (kSentinelEnabled) {
      // Snapshot schema alignment check across minor-version boundaries.
      validateConfigAlignment(const <String>[], const <String>[]);
    }
  }

  Future<void> loadAuditLogs({String? eventType}) async {
    try {
      final logs =
          await bridge.auditList(limit: 100, eventType: eventType);
      state = state.copyWith(
        auditLogs: logs
            .map((e) => AuditLogEntry(
                  id: e.id,
                  eventType: e.eventType,
                  detail: e.detail,
                  createdAt: DateTime.tryParse(e.createdAt) ?? DateTime.now(),
                ))
            .toList(),
      );
    } catch (_) {
      state = state.copyWith(auditLogs: []);
    }
  }

  Future<void> clearConnectionHistory() async {
    try {
      await bridge.privacyClearConnectionHistory();
    } catch (_) {}
  }

  Future<void> clearAiConversations() async {
    try {
      await bridge.privacyClearAiConversations();
    } catch (_) {}
  }

  Future<void> clearSnippetStats() async {
    try {
      await bridge.privacyClearSnippetStats();
    } catch (_) {}
  }

  Future<bool> gdprEraseAll(String password, String confirmation) async {
    if (confirmation != 'DELETE ALL') return false;
    try {
      await bridge.privacyGdprEraseAll(
        masterPassword: password,
        confirmation: confirmation,
      );
    } catch (_) {}
    return true;
  }

  // ─── Bridge <-> local model conversion ────────────────────────────────
  bridge_models.AppSettings _toBridge(AppSettings s) =>
      bridge_models.AppSettings(
        themeMode: _themeModeToString(s.themeMode),
        colorScheme: s.colorScheme,
        fontFamily: s.fontFamily,
        fontSize: s.fontSize,
        cursorShape: _cursorToString(s.cursorShape),
        cursorBlink: s.cursorBlink,
        scrollbackLines: s.scrollbackLines,
        tabWidth: s.tabWidth,
        language: s.language == Language.zhCN ? 'zh-CN' : 'en-US',
        aiAutoDiagnose: s.aiAutoDiagnose,
        aiContextLines: s.aiContextLines,
        backupFrequency: _backupToString(s.backupFrequency),
        auditRetentionDays: s.auditRetentionDays,
        localAiPort: s.localAiPort,
        localAiThreads: s.localAiThreads,
        localAiContextSize: s.localAiContextSize,
        k8SKubeconfigPath: '',
      );

  AppSettings _fromBridge(bridge_models.AppSettings s) => AppSettings(
        themeMode: _themeModeFromString(s.themeMode),
        colorScheme: s.colorScheme,
        fontFamily: s.fontFamily,
        fontSize: s.fontSize,
        cursorShape: _cursorFromString(s.cursorShape),
        cursorBlink: s.cursorBlink,
        scrollbackLines: s.scrollbackLines,
        tabWidth: s.tabWidth,
        language: s.language == 'zh-CN' ? Language.zhCN : Language.enUS,
        aiAutoDiagnose: s.aiAutoDiagnose,
        aiContextLines: s.aiContextLines,
        backupFrequency: _backupFromString(s.backupFrequency),
        auditRetentionDays: s.auditRetentionDays,
        localAiPort: s.localAiPort,
        localAiThreads: s.localAiThreads,
        localAiContextSize: s.localAiContextSize,
      );

  String _themeModeToString(ThemeMode m) => switch (m) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      };
  ThemeMode _themeModeFromString(String s) => switch (s) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
  String _cursorToString(CursorShape c) => switch (c) {
        CursorShape.block => 'block',
        CursorShape.underline => 'underline',
        CursorShape.bar => 'bar',
      };
  CursorShape _cursorFromString(String s) => switch (s) {
        'underline' => CursorShape.underline,
        'bar' => CursorShape.bar,
        _ => CursorShape.block,
      };
  String _backupToString(BackupFrequency b) => switch (b) {
        BackupFrequency.off => 'off',
        BackupFrequency.daily => 'daily',
        BackupFrequency.weekly => 'weekly',
      };
  BackupFrequency _backupFromString(String s) => switch (s) {
        'daily' => BackupFrequency.daily,
        'weekly' => BackupFrequency.weekly,
        _ => BackupFrequency.off,
      };
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
