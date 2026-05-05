/// Shortcut scope hierarchy (v0.48 spec §4.1).
library;

/// Priority levels for shortcut dispatch.
///
/// Higher numeric value = higher priority.  A scope that captures an event
/// does NOT propagate it to lower-priority scopes.
enum ShortcutScope {
  /// Widget-level (e.g. focused TextField).
  widget(priority: 40),
  /// Single terminal / SFTP pane.
  terminal(priority: 30),
  /// Tab-level shortcuts that apply when a tab is active.
  tab(priority: 20),
  /// Application-wide shortcuts always active.
  global(priority: 10);

  const ShortcutScope({required this.priority});

  final int priority;

  bool captures(ShortcutScope other) => priority >= other.priority;
}
