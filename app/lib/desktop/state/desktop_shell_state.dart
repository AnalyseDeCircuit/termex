import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Slide-in side panel slots above the terminal area.
enum DesktopSidePanel { none, sftp, ai, settings, portForward }

/// Whether the left server sidebar is visible.
final sidebarVisibleProvider = StateProvider<bool>((ref) => true);

/// Currently active side panel (SFTP / AI / Settings) or none.
final desktopSidePanelProvider =
    StateProvider<DesktopSidePanel>((ref) => DesktopSidePanel.none);

/// Toggles the side panel: tapping the same panel closes it; tapping a
/// different panel switches to it.
void toggleDesktopSidePanel(WidgetRef ref, DesktopSidePanel target) {
  final current = ref.read(desktopSidePanelProvider);
  ref.read(desktopSidePanelProvider.notifier).state =
      current == target ? DesktopSidePanel.none : target;
}
