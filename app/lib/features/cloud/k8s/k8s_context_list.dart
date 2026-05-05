/// Kubernetes context selector (v0.46 spec §6.2).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../state/cloud_provider.dart';

class K8sContextList extends ConsumerWidget {
  const K8sContextList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contexts = ref.watch(cloudProvider).k8sContexts;
    final notifier = ref.read(cloudProvider.notifier);

    if (contexts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('暂无 K8s Context',
                style: TextStyle(
                    fontSize: 13, color: TermexColors.textSecondary)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => notifier.loadK8sContexts(),
              child: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: contexts.length,
      itemBuilder: (ctx, i) {
        final c = contexts[i];
        return ListTile(
          dense: true,
          leading: Icon(
            c.isActive ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 16,
            color: c.isActive ? TermexColors.primary : TermexColors.textSecondary,
          ),
          title: Text(c.name,
              style: TextStyle(fontSize: 13, color: TermexColors.textPrimary)),
          subtitle: Text('${c.cluster} — ${c.namespace}',
              style:
                  TextStyle(fontSize: 11, color: TermexColors.textSecondary)),
          onTap: () => notifier.switchContext(c.name),
        );
      },
    );
  }
}
