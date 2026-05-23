import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/radius.dart';
import '../../../design/spacing.dart';
import '../../../design/elevation.dart';
import '../../../icons/termex_icons.dart';
import '../../server_list/models/server_dto.dart';
import '../../server_list/state/server_provider.dart';

/// Dropdown shown when pressing the "+" button in the tab bar.
///
/// First item is a "Local Terminal" tile rendered with a green success
/// accent so it stands apart from the neutral-styled remote SSH server
/// tiles that follow.
class NewTabMenu extends ConsumerWidget {
  /// Called with the selected server.
  final void Function(ServerDto server) onSelect;

  /// Called when the user picks the local-terminal tile.
  final VoidCallback onLocalTerminal;

  final VoidCallback onDismiss;

  const NewTabMenu({
    super.key,
    required this.onSelect,
    required this.onLocalTerminal,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(serverListProvider);
    final servers = serversAsync.valueOrNull ?? const [];

    // Sort by lastConnected descending, take up to 10
    final recent = [...servers]
      ..sort((a, b) {
        if (a.lastConnected == null && b.lastConnected == null) return 0;
        if (a.lastConnected == null) return 1;
        if (b.lastConnected == null) return -1;
        return b.lastConnected!.compareTo(a.lastConnected!);
      });
    final displayed = recent.take(10).toList();

    return Container(
      width: 260,
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: TermexRadius.md,
        border: Border.all(color: TermexColors.border),
        boxShadow: TermexElevation.e2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LocalTerminalTile(
            onTap: () {
              onDismiss();
              onLocalTerminal();
            },
          ),
          const SizedBox(
            height: 1,
            child: ColoredBox(color: TermexColors.border),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TermexSpacing.md,
              TermexSpacing.md,
              TermexSpacing.md,
              TermexSpacing.xs,
            ),
            child: Text(
              'Recent Servers',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
              ),
            ),
          ),
          if (displayed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TermexSpacing.md,
                vertical: TermexSpacing.lg,
              ),
              child: Text(
                'No recent servers.',
                style: TermexTypography.body.copyWith(
                  color: TermexColors.textMuted,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(vertical: TermexSpacing.xs),
                itemCount: displayed.length,
                itemBuilder: (ctx, i) {
                  final s = displayed[i];
                  return _RecentServerTile(
                    server: s,
                    onTap: () {
                      onDismiss();
                      onSelect(s);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// First-row tile in the new-tab dropdown — opens a local PTY shell.
///
/// Painted with a green (`TermexColors.success`) accent — left border,
/// tinted background, accent-colored icon and title — to make it clearly
/// distinct from the neutral-colored remote SSH server tiles below.
class _LocalTerminalTile extends StatefulWidget {
  final VoidCallback onTap;

  const _LocalTerminalTile({required this.onTap});

  @override
  State<_LocalTerminalTile> createState() => _LocalTerminalTileState();
}

class _LocalTerminalTileState extends State<_LocalTerminalTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const accent = TermexColors.success;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.md,
            vertical: TermexSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0x1A1A7F37) // 10% success tint on hover
                : const Color(0x0D1A7F37), // 5% success tint at rest
            border: const Border(
              left: BorderSide(color: accent, width: 3),
            ),
          ),
          child: Row(
            children: [
              const TermexIconWidget(
                TermexIcons.terminal,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: TermexSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本地命令行',
                      style: TermexTypography.body.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '在本机打开一个 shell',
                      style: TermexTypography.caption.copyWith(
                        color: TermexColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentServerTile extends StatefulWidget {
  final ServerDto server;
  final VoidCallback onTap;

  const _RecentServerTile({required this.server, required this.onTap});

  @override
  State<_RecentServerTile> createState() => _RecentServerTileState();
}

class _RecentServerTileState extends State<_RecentServerTile> {
  bool _hovered = false;

  String _relativeTime(String? iso) {
    if (iso == null) return 'never';
    try {
      return timeago.format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.server;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.md,
            vertical: TermexSpacing.sm,
          ),
          color: _hovered
              ? TermexColors.backgroundTertiary
              : const Color(0x00000000),
          child: Row(
            children: [
              const TermexIconWidget(
                TermexIcons.server,
                size: 14,
                color: TermexColors.neutral,
              ),
              const SizedBox(width: TermexSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TermexTypography.body.copyWith(
                        color: TermexColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${s.username}@${s.host}:${s.port}',
                      style: TermexTypography.caption.copyWith(
                        color: TermexColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TermexSpacing.sm),
              Text(
                _relativeTime(s.lastConnected),
                style: TermexTypography.caption.copyWith(
                  color: TermexColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
