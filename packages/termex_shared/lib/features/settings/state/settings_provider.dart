import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:termex_bridge/src/models.dart' as bridge_models;

import '../../../design/theme.dart' as design;
import '../../../design/theme_provider.dart';

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
  // ── Newer fields (v0.54.x — mirror the Rust AppSettings struct) ───────────
  final bool localAiAutoStart;
  final String keywordRulesJson;
  final int monitorIntervalMs;
  final bool monitorAutoStart;
  final bool monitorShowCpu;
  final bool monitorShowMemory;
  final bool monitorShowDisk;
  final bool monitorShowNetwork;
  final bool monitorShowProcesses;
  final int recordingRetentionDays;
  final String recordingFormat;

  const AppSettings({
    // v0.77.0: default to OS-following. The legacy Tauri build defaulted
    // to "dark" because the Vue terminal renderer didn't support live
    // theme flips; Flutter does, so respecting the system theme out of
    // the box matches macOS / Windows / GNOME convention.
    this.themeMode = ThemeMode.system,
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
    this.localAiAutoStart = true,
    this.keywordRulesJson = '[]',
    this.monitorIntervalMs = 2000,
    this.monitorAutoStart = false,
    this.monitorShowCpu = true,
    this.monitorShowMemory = true,
    this.monitorShowDisk = true,
    this.monitorShowNetwork = true,
    this.monitorShowProcesses = true,
    this.recordingRetentionDays = 30,
    this.recordingFormat = 'asciicast',
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
    bool? localAiAutoStart,
    String? keywordRulesJson,
    int? monitorIntervalMs,
    bool? monitorAutoStart,
    bool? monitorShowCpu,
    bool? monitorShowMemory,
    bool? monitorShowDisk,
    bool? monitorShowNetwork,
    bool? monitorShowProcesses,
    int? recordingRetentionDays,
    String? recordingFormat,
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
        localAiAutoStart: localAiAutoStart ?? this.localAiAutoStart,
        keywordRulesJson: keywordRulesJson ?? this.keywordRulesJson,
        monitorIntervalMs: monitorIntervalMs ?? this.monitorIntervalMs,
        monitorAutoStart: monitorAutoStart ?? this.monitorAutoStart,
        monitorShowCpu: monitorShowCpu ?? this.monitorShowCpu,
        monitorShowMemory: monitorShowMemory ?? this.monitorShowMemory,
        monitorShowDisk: monitorShowDisk ?? this.monitorShowDisk,
        monitorShowNetwork: monitorShowNetwork ?? this.monitorShowNetwork,
        monitorShowProcesses: monitorShowProcesses ?? this.monitorShowProcesses,
        recordingRetentionDays:
            recordingRetentionDays ?? this.recordingRetentionDays,
        recordingFormat: recordingFormat ?? this.recordingFormat,
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
      final loaded = _fromBridge(remote);
      state = state.copyWith(settings: loaded, isLoading: false);
      _pushThemeToLive(loaded.themeMode);
    } catch (_) {
      // native not ready — keep defaults
      state = state.copyWith(isLoading: false);
      _pushThemeToLive(state.settings.themeMode);
    }
  }

  /// Applies a settings change and persists it immediately.
  ///
  /// Settings are auto-saved: there is no explicit Save/Cancel step. The
  /// previous flow flipped `isDirty`, which made a Save/Cancel bar appear
  /// at the top of the settings panel on every keystroke or toggle —
  /// intrusive for a surface where each control is independent and
  /// instantly reversible. State updates optimistically so the UI reacts
  /// without waiting on the round-trip; a persistence failure surfaces
  /// through `errorMessage` rather than blocking the change.
  void update(AppSettings settings) {
    state = state.copyWith(settings: settings, isDirty: false);
    _pushThemeToLive(settings.themeMode);
    _persist(settings);
  }

  /// Debounced write-behind for [update]. Rapid changes (dragging the
  /// font-size slider, typing in a text field) coalesce into one bridge
  /// call instead of hammering the DB on every frame.
  Timer? _persistTimer;

  void _persist(AppSettings settings) {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        await bridge.settingsSave(settings: _toBridge(settings));
      } catch (e) {
        state = state.copyWith(errorMessage: e.toString());
      }
    });
  }

  /// Mirrors the user's settings-page selection into the live theme
  /// provider so the change applies instantly — without this, settings
  /// would only take effect after a save+restart.
  void _pushThemeToLive(ThemeMode m) {
    final mapped = switch (m) {
      ThemeMode.light => design.TermexThemeMode.light,
      ThemeMode.dark => design.TermexThemeMode.dark,
      ThemeMode.system => design.TermexThemeMode.system,
    };
    ref.read(themeModeProvider.notifier).setMode(mapped);
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
  Future<void> importConfig(String path, String password) async {
    try {
      final remote =
          await bridge.settingsImport(path: path, password: password);
      state = state.copyWith(settings: _fromBridge(remote), isDirty: false);
    } catch (_) {
      state = state.copyWith(isDirty: false);
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
        localAiAutoStart: s.localAiAutoStart,
        keywordRulesJson: s.keywordRulesJson,
        monitorIntervalMs: s.monitorIntervalMs,
        monitorAutoStart: s.monitorAutoStart,
        monitorShowCpu: s.monitorShowCpu,
        monitorShowMemory: s.monitorShowMemory,
        monitorShowDisk: s.monitorShowDisk,
        monitorShowNetwork: s.monitorShowNetwork,
        monitorShowProcesses: s.monitorShowProcesses,
        recordingRetentionDays: s.recordingRetentionDays,
        recordingFormat: s.recordingFormat,
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
        localAiAutoStart: s.localAiAutoStart,
        keywordRulesJson: s.keywordRulesJson,
        monitorIntervalMs: s.monitorIntervalMs,
        monitorAutoStart: s.monitorAutoStart,
        monitorShowCpu: s.monitorShowCpu,
        monitorShowMemory: s.monitorShowMemory,
        monitorShowDisk: s.monitorShowDisk,
        monitorShowNetwork: s.monitorShowNetwork,
        monitorShowProcesses: s.monitorShowProcesses,
        recordingRetentionDays: s.recordingRetentionDays,
        recordingFormat: s.recordingFormat,
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
