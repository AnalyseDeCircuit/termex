/// Kubernetes pods table widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../state/cloud_provider.dart';

class K8sPodsTable extends ConsumerWidget {
  const K8sPodsTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pods = ref.watch(cloudProvider).k8sPods;
    if (pods.isEmpty) {
      return Center(
        child: Text('无 Pod', style: TextStyle(color: TermexColors.textSecondary)),
      );
    }

    return ListView.builder(
      itemCount: pods.length,
      itemBuilder: (ctx, i) {
        final p = pods[i];
        return ListTile(
          dense: true,
          leading: Icon(
            p.status == 'Running' ? Icons.check_circle : Icons.pause_circle,
            color: p.status == 'Running' ? Colors.green : Colors.orange,
            size: 16,
          ),
          title: Text(p.name,
              style: TextStyle(fontSize: 12, color: TermexColors.textPrimary)),
          subtitle: Text(
            '${p.namespace} · restarts=${p.restarts} · age=${p.age}',
            style: TextStyle(fontSize: 11, color: TermexColors.textSecondary),
          ),
        );
      },
    );
  }
}
