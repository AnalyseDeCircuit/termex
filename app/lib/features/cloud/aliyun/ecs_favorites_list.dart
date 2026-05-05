/// Aliyun ECS favourites list widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../state/cloud_provider.dart';

class EcsFavoritesList extends ConsumerWidget {
  const EcsFavoritesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(cloudProvider).ecsFavorites;
    final notifier = ref.read(cloudProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text('阿里云 ECS 收藏夹',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: TermexColors.textPrimary,
                    )),
              ),
              OutlinedButton.icon(
                onPressed: () => _showAddDialog(context, notifier),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('添加', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: favorites.isEmpty
              ? Center(
                  child: Text('暂无收藏',
                      style: TextStyle(
                          fontSize: 12, color: TermexColors.textSecondary)),
                )
              : ListView.builder(
                  itemCount: favorites.length,
                  itemBuilder: (ctx, i) {
                    final f = favorites[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.cloud_outlined,
                          size: 16, color: TermexColors.textSecondary),
                      title: Text(f.name,
                          style: TextStyle(
                              fontSize: 13,
                              color: TermexColors.textPrimary)),
                      subtitle: Text(
                        '${f.instanceId} · ${f.region} · ${f.ip}',
                        style: TextStyle(
                            fontSize: 11,
                            color: TermexColors.textSecondary),
                      ),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.close, size: 14),
                        onPressed: () =>
                            notifier.removeEcsFavorite(f.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog(
      BuildContext context, CloudNotifier notifier) async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final regionCtrl = TextEditingController(text: 'cn-hangzhou');
    final ipCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加 ECS 实例'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(labelText: 'Instance ID')),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: regionCtrl,
                  decoration: const InputDecoration(labelText: 'Region')),
              TextField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(labelText: 'IP / Endpoint')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('添加')),
        ],
      ),
    );

    if (ok == true && idCtrl.text.isNotEmpty) {
      await notifier.addEcsFavorite(
        idCtrl.text,
        nameCtrl.text.isEmpty ? idCtrl.text : nameCtrl.text,
        regionCtrl.text,
        ipCtrl.text,
      );
    }
  }
}
