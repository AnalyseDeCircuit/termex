/// Shared visibility state for the sidebar's collapsible search fields.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keys for [sidebarSearchVisibleProvider].
///
/// Plain strings rather than the host app's `SidebarCategory`: that enum lives
/// in the desktop shell, which termex_shared cannot depend on.
class SidebarSearchPanel {
  static const String servers = 'servers';
  static const String proxies = 'proxies';
  static const String snippets = 'snippets';
  static const String recordings = 'recordings';

  const SidebarSearchPanel._();
}

/// Whether a given sidebar panel's search field is revealed.
///
/// Each panel's field used to occupy its header permanently. They now sit
/// behind a toggle in the section header so a short list reads as a plain
/// list. Shared state because the toggle and the field live in sibling
/// widgets — the header is painted by the desktop shell, the field by the
/// panel itself.
final sidebarSearchVisibleProvider =
    StateProvider.family<bool, String>((_, __) => false);
