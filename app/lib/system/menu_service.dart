/// Native menu-bar abstraction (v0.48 spec §6.3).
///
/// On macOS the platform channel populates NSMenu; on Windows/Linux an
/// in-app hamburger menu replicates the structure.  This file defines the
/// menu model; platform wiring lives in the native embedding layer.
library;

// ─── Menu model ──────────────────────────────────────────────────────────────

/// A single menu item.
class MenuItem {
  final String id;
  final String label;
  final String? shortcut;
  final void Function()? onActivate;
  final bool isSeparator;
  final List<MenuItem> children;

  const MenuItem({
    required this.id,
    required this.label,
    this.shortcut,
    this.onActivate,
    this.isSeparator = false,
    this.children = const [],
  });

  factory MenuItem.separator() => const MenuItem(
      id: '_sep', label: '---', isSeparator: true);
}

/// Top-level menu.
class Menu {
  final String label;
  final List<MenuItem> items;

  const Menu({required this.label, required this.items});
}

// ─── Service ─────────────────────────────────────────────────────────────────

class MenuService {
  MenuService._();

  static final MenuService instance = MenuService._();

  List<Menu>? _menus;

  void configure(List<Menu> menus) {
    _menus = menus;
  }

  List<Menu> get menus => _menus ?? const [];

  /// Fires the handler for [itemId], returns true if found.
  bool activate(String itemId) {
    for (final menu in menus) {
      for (final item in menu.items) {
        if (_activate(item, itemId)) return true;
      }
    }
    return false;
  }

  bool _activate(MenuItem item, String id) {
    if (item.id == id) {
      item.onActivate?.call();
      return true;
    }
    for (final child in item.children) {
      if (_activate(child, id)) return true;
    }
    return false;
  }
}
