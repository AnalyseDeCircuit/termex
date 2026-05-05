import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

// ─── Models ───────────────────────────────────────────────────────────────────

class KeybindingEntry {
  final String action;
  final String keyCombination;
  final String context; // "global" | "terminal" | "sftp"

  const KeybindingEntry({
    required this.action,
    required this.keyCombination,
    required this.context,
  });

  KeybindingEntry copyWith({String? keyCombination}) => KeybindingEntry(
        action: action,
        keyCombination: keyCombination ?? this.keyCombination,
        context: context,
      );
}

const List<KeybindingEntry> kDefaultKeybindings = [
  KeybindingEntry(action: 'new_tab', keyCombination: '⌘T', context: 'global'),
  KeybindingEntry(action: 'close_tab', keyCombination: '⌘W', context: 'global'),
  KeybindingEntry(action: 'search_terminal', keyCombination: '⌘F', context: 'terminal'),
  KeybindingEntry(action: 'split_horizontal', keyCombination: '⌘D', context: 'terminal'),
  KeybindingEntry(action: 'split_vertical', keyCombination: '⌘⇧D', context: 'terminal'),
  KeybindingEntry(action: 'ai_panel', keyCombination: '⌘J', context: 'global'),
  KeybindingEntry(action: 'focus_next_pane', keyCombination: '⌘]', context: 'terminal'),
  KeybindingEntry(action: 'focus_prev_pane', keyCombination: '⌘[', context: 'terminal'),
  KeybindingEntry(action: 'toggle_sftp', keyCombination: '⌘⇧S', context: 'global'),
  KeybindingEntry(action: 'copy', keyCombination: '⌘C', context: 'terminal'),
  KeybindingEntry(action: 'paste', keyCombination: '⌘V', context: 'terminal'),
  KeybindingEntry(action: 'select_all', keyCombination: '⌘A', context: 'terminal'),
  KeybindingEntry(action: 'zoom_in', keyCombination: '⌘=', context: 'terminal'),
  KeybindingEntry(action: 'zoom_out', keyCombination: '⌘-', context: 'terminal'),
  KeybindingEntry(action: 'reset_zoom', keyCombination: '⌘0', context: 'terminal'),
];

// ─── State ────────────────────────────────────────────────────────────────────

class KeybindingState {
  final List<KeybindingEntry> bindings;
  final String? conflict; // conflicting action name if any

  const KeybindingState({
    this.bindings = kDefaultKeybindings,
    this.conflict,
  });

  KeybindingState copyWith({
    List<KeybindingEntry>? bindings,
    String? conflict,
    bool clearConflict = false,
  }) =>
      KeybindingState(
        bindings: bindings ?? this.bindings,
        conflict: clearConflict ? null : (conflict ?? this.conflict),
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class KeybindingNotifier extends Notifier<KeybindingState> {
  @override
  KeybindingState build() {
    Future.microtask(_loadAsync);
    return const KeybindingState();
  }

  Future<void> _loadAsync() async {
    try {
      final remote = await bridge.keybindingList();
      if (remote.isEmpty) return;
      final bindings = remote
          .map((e) => KeybindingEntry(
                action: e.action,
                keyCombination: e.keyCombination,
                context: e.context,
              ))
          .toList();
      state = state.copyWith(bindings: bindings);
    } catch (_) {
      // keep defaults when FRB stub / native not ready
    }
  }

  /// Returns conflicting action name, or null if no conflict.
  String? checkConflict(String action, String keyCombination, String context) {
    for (final b in state.bindings) {
      if (b.action == action) continue;
      if (b.keyCombination == keyCombination &&
          (b.context == context || b.context == 'global' || context == 'global')) {
        return b.action;
      }
    }
    return null;
  }

  bool setBinding(String action, String keyCombination) {
    final entry =
        state.bindings.firstWhere((b) => b.action == action, orElse: () {
      throw StateError('Unknown action: $action');
    });
    final conflict = checkConflict(action, keyCombination, entry.context);
    if (conflict != null) {
      state = state.copyWith(conflict: conflict);
      return false;
    }
    final updated = state.bindings.map((b) {
      if (b.action == action) return b.copyWith(keyCombination: keyCombination);
      return b;
    }).toList();
    state = state.copyWith(bindings: updated, clearConflict: true);
    try {
      bridge
          .keybindingSet(
            action: action,
            keyCombination: keyCombination,
            context: entry.context,
          )
          .catchError((_) {});
    } catch (_) {}
    return true;
  }

  void resetAction(String action) {
    final def = kDefaultKeybindings.firstWhere((b) => b.action == action);
    setBinding(action, def.keyCombination);
  }

  void resetAll() {
    state = const KeybindingState();
    try {
      bridge.keybindingResetAll().catchError((_) {});
    } catch (_) {}
  }

  void clearConflict() => state = state.copyWith(clearConflict: true);
}

final keybindingProvider =
    NotifierProvider<KeybindingNotifier, KeybindingState>(KeybindingNotifier.new);
