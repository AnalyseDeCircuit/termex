/// Plugin state management (v0.48 spec §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

enum PluginState { enabled, disabled }

class PluginInfo {
  final String id;
  final String name;
  final String version;
  final String description;
  final String? author;
  final PluginState state;
  final List<String> permissions;
  final List<String> grantedPermissions;
  final String installPath;

  const PluginInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    this.author,
    required this.state,
    required this.permissions,
    required this.grantedPermissions,
    required this.installPath,
  });

  PluginInfo copyWith({
    PluginState? state,
    List<String>? grantedPermissions,
  }) =>
      PluginInfo(
        id: id,
        name: name,
        version: version,
        description: description,
        author: author,
        state: state ?? this.state,
        permissions: permissions,
        grantedPermissions: grantedPermissions ?? this.grantedPermissions,
        installPath: installPath,
      );
}

class PluginsState {
  final List<PluginInfo> plugins;
  final bool developerMode;

  const PluginsState({
    this.plugins = const [],
    this.developerMode = false,
  });

  PluginsState copyWith({
    List<PluginInfo>? plugins,
    bool? developerMode,
  }) =>
      PluginsState(
        plugins: plugins ?? this.plugins,
        developerMode: developerMode ?? this.developerMode,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class PluginsNotifier extends Notifier<PluginsState> {
  @override
  PluginsState build() => const PluginsState();

  void add(PluginInfo plugin) {
    state = state.copyWith(plugins: [...state.plugins, plugin]);
  }

  void remove(String id) {
    state = state.copyWith(
      plugins: state.plugins.where((p) => p.id != id).toList(),
    );
  }

  void enable(String id) => _updateState(id, PluginState.enabled);
  void disable(String id) => _updateState(id, PluginState.disabled);

  void _updateState(String id, PluginState newState) {
    state = state.copyWith(
      plugins: state.plugins
          .map((p) => p.id == id ? p.copyWith(state: newState) : p)
          .toList(),
    );
  }

  /// Grants [permission] to plugin [id].
  ///
  /// No-op when the permission is not in the plugin's declared list.
  void grantPermission(String id, String permission) {
    final plugin = state.plugins.firstWhere((p) => p.id == id,
        orElse: () => throw StateError('plugin $id not found'));
    if (!plugin.permissions.contains(permission)) return;
    if (plugin.grantedPermissions.contains(permission)) return;
    _updateGrants(
        id, [...plugin.grantedPermissions, permission]);
  }

  void revokePermission(String id, String permission) {
    final plugin = state.plugins.firstWhere((p) => p.id == id,
        orElse: () => throw StateError('plugin $id not found'));
    _updateGrants(
        id, plugin.grantedPermissions.where((p) => p != permission).toList());
  }

  void _updateGrants(String id, List<String> grants) {
    state = state.copyWith(
      plugins: state.plugins
          .map((p) =>
              p.id == id ? p.copyWith(grantedPermissions: grants) : p)
          .toList(),
    );
  }

  void setDeveloperMode(bool enabled) {
    state = state.copyWith(developerMode: enabled);
  }

  bool hasPermission(String id, String permission) {
    return state.plugins
        .where((p) => p.id == id)
        .any((p) => p.grantedPermissions.contains(permission));
  }
}

final pluginsProvider = NotifierProvider<PluginsNotifier, PluginsState>(
  PluginsNotifier.new,
);
