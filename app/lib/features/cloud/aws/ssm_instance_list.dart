/// AWS SSM instance list widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../state/cloud_provider.dart';

class SsmInstanceList extends ConsumerWidget {
  final void Function(SsmInstance) onStartSession;

  const SsmInstanceList({super.key, required this.onStartSession});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instances = ref.watch(cloudProvider).ssmInstances;

    if (instances.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('无可用 SSM 实例',
                style: TextStyle(
                    fontSize: 13, color: TermexColors.textSecondary)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  ref.read(cloudProvider.notifier).loadSsmInstances(),
              child: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: instances.length,
      itemBuilder: (ctx, i) {
        final s = instances[i];
        return ListTile(
          dense: true,
          leading: Icon(Icons.cloud_outlined,
              size: 16, color: TermexColors.textSecondary),
          title: Text(s.name,
              style: TextStyle(fontSize: 13, color: TermexColors.textPrimary)),
          subtitle: Text(
            '${s.instanceId} · ${s.region} · ${s.platform}',
            style: TextStyle(fontSize: 11, color: TermexColors.textSecondary),
          ),
          trailing: TextButton(
            onPressed: () => onStartSession(s),
            child: const Text('Start Session'),
          ),
        );
      },
    );
  }
}
