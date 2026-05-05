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
/// Displays recently connected servers for quick reopening.
class NewTabMenu extends ConsumerWidget {
  /// Called with the selected server.
  final void Function(ServerDto server) onSelect;
  final VoidCallback onDismiss;

  const NewTabMenu({
    super.key,
    required this.onSelect,
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

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: 260,
            constraints: const BoxConstraints(maxHeight: 320),
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
                      padding: const EdgeInsets.symmetric(
                          vertical: TermexSpacing.xs),
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
          ),
        ),
      ],
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
              TermexIconWidget(
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
