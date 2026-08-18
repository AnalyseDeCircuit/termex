import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/clickable.dart';
import 'models/server_dto.dart';
import 'state/server_provider.dart';
import 'widgets/delete_server_dialog.dart';
import 'widgets/server_form_dialog.dart';

class ServerListPage extends ConsumerWidget {
  /// Optional tap handler. When provided, each server tile becomes
  /// interactive — used by the mobile shell to push the terminal page.
  /// Desktop wiring keeps using the legacy sidebar/menu paths, so this
  /// remains opt-in.
  final void Function(ServerDto server)? onServerTap;

  const ServerListPage({super.key, this.onServerTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serverListProvider);
    final l10n = AppLocalizations.of(context);
    return Container(
      color: const Color(0xFF1E1E2E),
      child: servers.when(
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  l10n.serverListEmpty,
                  style: const TextStyle(
                    color: Color(0xFF6C7086),
                    decoration: TextDecoration.none,
                  ),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: list.length,
                itemBuilder: (_, i) => _ServerTile(
                  server: list[i],
                  onTap: onServerTap == null
                      ? null
                      : () => onServerTap!(list[i]),
                  onLongPress: () =>
                      _showServerActions(context, list[i]),
                ),
              ),
        loading: () => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: const TextStyle(
              color: Color(0xFFF38BA8),
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.server,
    this.onTap,
    this.onLongPress,
  });

  final ServerDto server;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF313244)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            server.name,
            style: const TextStyle(
              color: Color(0xFFCDD6F4),
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${server.username}@${server.host}:${server.port}',
            style: const TextStyle(
              color: Color(0xFF6C7086),
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
    if (onTap == null && onLongPress == null) return tile;
    return Clickable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: tile,
    );
  }
}

Future<void> _showServerActions(
  BuildContext context,
  ServerDto server,
) async {
  final action = await showModalBottomSheet<_ServerAction>(
    context: context,
    backgroundColor: const Color(0xFF1E1E2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  server.name,
                  style: const TextStyle(
                    color: Color(0xFFCDD6F4),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF313244)),
            _ActionSheetItem(
              icon: Icons.edit_outlined,
              label: l10n.commonEdit,
              onTap: () =>
                  Navigator.of(sheetContext).pop(_ServerAction.edit),
            ),
            const Divider(height: 1, color: Color(0xFF313244)),
            _ActionSheetItem(
              icon: Icons.delete_outline,
              label: l10n.commonDelete,
              destructive: true,
              onTap: () =>
                  Navigator.of(sheetContext).pop(_ServerAction.delete),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFF313244)),
            _ActionSheetItem(
              icon: Icons.close,
              label: l10n.commonCancel,
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _ServerAction.edit:
      await ServerFormDialog.show(context, editId: server.id);
    case _ServerAction.delete:
      await DeleteServerDialog.show(
        context,
        serverId: server.id,
        serverName: server.name,
      );
  }
}

enum _ServerAction { edit, delete }

class _ActionSheetItem extends StatelessWidget {
  const _ActionSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? const Color(0xFFF38BA8) : const Color(0xFFCDD6F4);
    return Clickable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
