/// System tray service (v0.48 spec §6.4).
///
/// Platform-level tray wiring (flutter_system_tray or tray_manager) is done
/// outside this service.  This class holds the model and callback registry so
/// the rest of the app does not depend on specific plugin APIs.
library;

class TrayItem {
  final String id;
  final String label;
  final bool isSeparator;
  final void Function()? onTap;

  const TrayItem({
    required this.id,
    required this.label,
    this.isSeparator = false,
    this.onTap,
  });

  factory TrayItem.separator() =>
      const TrayItem(id: '_sep', label: '---', isSeparator: true);
}

class TrayService {
  TrayService._();

  static final TrayService instance = TrayService._();

  List<TrayItem> _items = const [];
  void Function()? _onIconTap;

  /// Updates the context menu shown when the tray icon is right-clicked.
  void setItems(List<TrayItem> items) {
    _items = List.unmodifiable(items);
  }

  List<TrayItem> get items => _items;

  void onIconTap(void Function() handler) {
    _onIconTap = handler;
  }

  /// Called by the platform channel when the tray icon is tapped.
  void handleIconTap() => _onIconTap?.call();

  /// Fires the handler for [itemId], returns true if found.
  bool activate(String itemId) {
    for (final item in _items) {
      if (item.id == itemId) {
        item.onTap?.call();
        return true;
      }
    }
    return false;
  }
}
