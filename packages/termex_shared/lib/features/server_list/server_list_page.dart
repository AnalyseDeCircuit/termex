import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/server_dto.dart';
import 'state/server_provider.dart';

class ServerListPage extends ConsumerWidget {
  const ServerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serverListProvider);
    return Container(
      color: const Color(0xFF1E1E2E),
      child: servers.when(
        data: (list) => list.isEmpty
            ? const Center(
                child: Text(
                  'No servers yet',
                  style: TextStyle(
                    color: Color(0xFF6C7086),
                    decoration: TextDecoration.none,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => _ServerTile(server: list[i]),
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
  const _ServerTile({required this.server});

  final ServerDto server;

  @override
  Widget build(BuildContext context) {
    return Container(
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
  }
}
