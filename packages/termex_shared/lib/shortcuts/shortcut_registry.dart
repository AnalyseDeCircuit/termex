/// Global shortcut registry (v0.48 spec §4.2).
library;

import 'shortcut_scope.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

/// Normalized keyboard combination, e.g. `"cmd+t"` or `"ctrl+shift+f"`.
class KeyCombination {
  final String raw;
  const KeyCombination(this.raw);

  @override
  bool operator ==(Object other) =>
      other is KeyCombination && other.raw.toLowerCase() == raw.toLowerCase();

  @override
  int get hashCode => raw.toLowerCase().hashCode;

  @override
  String toString() => raw;
}

/// A single shortcut binding entry.
class ShortcutBinding {
  final String commandId;
  final KeyCombination combo;
  final ShortcutScope scope;
  final void Function()? handler;
  final String? description;

  const ShortcutBinding({
    required this.commandId,
    required this.combo,
    required this.scope,
    this.handler,
    this.description,
  });

  ShortcutBinding copyWith({
    void Function()? handler,
    String? description,
  }) {
    return ShortcutBinding(
      commandId: commandId,
      combo: combo,
      scope: scope,
      handler: handler ?? this.handler,
      description: description ?? this.description,
    );
  }
}

// ─── Registry ────────────────────────────────────────────────────────────────

/// Application-wide shortcut registry.
///
/// User-overridden key combinations (loaded from the `keybindings` DB table
/// via the `BuiltInShortcuts` helper) take precedence over built-in defaults.
/// Scoped dispatch ensures terminal shortcuts don't fire when a dialog is open.
class ShortcutRegistry {
  ShortcutRegistry._();

  static final ShortcutRegistry instance = ShortcutRegistry._();

  final Map<String, ShortcutBinding> _bindings = {};

  // ── Registration ───────────────────────────────────────────────────────────

  /// Registers [binding], replacing any prior binding with the same commandId.
  void register(ShortcutBinding binding) {
    _bindings[binding.commandId] = binding;
  }

  /// Removes the binding for [commandId] (restores to no-op).
  void unregister(String commandId) {
    _bindings.remove(commandId);
  }

  /// Applies a user-override combo to an existing commandId.
  ///
  /// Preserves the original handler and description.
  void applyOverride(String commandId, KeyCombination combo) {
    final existing = _bindings[commandId];
    if (existing == null) return;
    _bindings[commandId] = ShortcutBinding(
      commandId: commandId,
      combo: combo,
      scope: existing.scope,
      handler: existing.handler,
      description: existing.description,
    );
  }

  // ── Query ──────────────────────────────────────────────────────────────────

  /// All bindings that belong to [scope] or are in a lower-priority scope that
  /// this scope captures.
  List<ShortcutBinding> forScope(ShortcutScope scope) {
    return _bindings.values
        .where((b) => scope.captures(b.scope))
        .toList(growable: false);
  }

  /// Resolves [combo] in the given [activeScope].
  ///
  /// Returns the matching binding when the active scope captures its scope,
  /// otherwise returns `null`.
  ShortcutBinding? resolve(KeyCombination combo, ShortcutScope activeScope) {
    for (final b in _bindings.values) {
      if (b.combo == combo && activeScope.captures(b.scope)) {
        return b;
      }
    }
    return null;
  }

  /// Checks whether [combo] in [context] conflicts with any registered binding.
  ///
  /// Returns the conflicting commandId, or `null` if no conflict.
  String? checkConflict(
      KeyCombination combo, ShortcutScope context, String excludeCommandId) {
    for (final b in _bindings.values) {
      if (b.commandId == excludeCommandId) continue;
      if (b.combo == combo) {
        if (context.captures(b.scope) || b.scope.captures(context)) {
          return b.commandId;
        }
      }
    }
    return null;
  }

  /// All registered bindings (unordered).
  List<ShortcutBinding> get all => _bindings.values.toList(growable: false);

  // ── Dispatch ───────────────────────────────────────────────────────────────

  /// Attempts to execute the handler bound to [combo] in [activeScope].
  ///
  /// Returns `true` when a handler was found and invoked, `false` otherwise.
  bool dispatch(KeyCombination combo, ShortcutScope activeScope) {
    final binding = resolve(combo, activeScope);
    if (binding?.handler != null) {
      binding!.handler!();
      return true;
    }
    return false;
  }

  /// Clears all bindings — used in tests.
  void clear() => _bindings.clear();
}
