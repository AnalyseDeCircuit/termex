import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/cloud_provider.dart';

class CloudPanel extends ConsumerStatefulWidget {
  const CloudPanel({super.key});

  @override
  ConsumerState<CloudPanel> createState() => _CloudPanelState();
}

class _CloudPanelState extends ConsumerState<CloudPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cloudProvider.notifier).loadK8sContexts();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: TermexColors.backgroundSecondary,
          child: TabBar(
            controller: _tab,
            labelColor: TermexColors.primary,
            unselectedLabelColor: TermexColors.textSecondary,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            indicatorColor: TermexColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Kubernetes'),
              Tab(text: 'AWS SSM'),
              Tab(text: 'Aliyun ECS'),
            ],
            onTap: (i) {
              final n = ref.read(cloudProvider.notifier);
              if (i == 0) n.loadK8sContexts();
              if (i == 1) n.loadSsmInstances();
              if (i == 2) n.loadEcsFavorites();
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _K8sTab(),
              _SsmTab(),
              _EcsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Kubernetes ───────────────────────────────────────────────────────────────

class _K8sTab extends ConsumerWidget {
  const _K8sTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudProvider);

    if (state.isLoading && state.k8sContexts.isEmpty) {
      return Center(child: CircularProgressIndicator(color: TermexColors.primary));
    }

    return Row(
      children: [
        // Context list
        SizedBox(
          width: 200,
          child: Container(
            color: TermexColors.backgroundSecondary,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Contexts',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: TermexColors.textSecondary,
                          letterSpacing: 0.5)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    children: state.k8sContexts
                        .map((c) => _K8sContextTile(context: c))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // Pods list
        Expanded(
          child: state.k8sPods.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.view_module_outlined, size: 36, color: TermexColors.textSecondary),
                      const SizedBox(height: 8),
                      Text('选择 Context 查看 Pods',
                          style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
                    ],
                  ),
                )
              : _PodsTable(pods: state.k8sPods),
        ),
      ],
    );
  }
}

class _K8sContextTile extends ConsumerWidget {
  final K8sContext context;
  const _K8sContextTile({required this.context});

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(cloudProvider.notifier).switchContext(context.name);
        ref.read(cloudProvider.notifier).loadPods(context.name, context.namespace);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.isActive ? TermexColors.primary.withOpacity(0.1) : null,
          border: Border(
            left: BorderSide(
              color: context.isActive ? TermexColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.name,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.isActive ? TermexColors.textPrimary : TermexColors.textSecondary)),
            Text(context.namespace,
                style: TextStyle(fontSize: 10, color: TermexColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _PodsTable extends StatelessWidget {
  final List<K8sPod> pods;
  const _PodsTable({required this.pods});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _PodHeader(),
        ...pods.map((p) => _PodRow(pod: p)),
      ],
    );
  }
}

class _PodHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: TermexColors.backgroundTertiary,
      child: Row(
        children: ['名称', '状态', '重启', 'Age', '镜像'].map((h) => Expanded(
          child: Text(h,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TermexColors.textSecondary,
                  letterSpacing: 0.5)),
        )).toList(),
      ),
    );
  }
}

class _PodRow extends StatelessWidget {
  final K8sPod pod;
  const _PodRow({required this.pod});

  @override
  Widget build(BuildContext context) {
    final isRunning = pod.status == 'Running';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(pod.name, style: TextStyle(fontSize: 11, color: TermexColors.textPrimary, fontFamily: 'monospace'))),
          Expanded(child: _StatusBadge(status: pod.status)),
          Expanded(child: Text('${pod.restarts}', style: TextStyle(fontSize: 11, color: TermexColors.textSecondary))),
          Expanded(child: Text(pod.age, style: TextStyle(fontSize: 11, color: TermexColors.textSecondary))),
          Expanded(child: Text(pod.image, style: TextStyle(fontSize: 11, color: TermexColors.textSecondary, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Running' => TermexColors.success,
      'Completed' => TermexColors.textSecondary,
      'Failed' => TermexColors.danger,
      _ => TermexColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ─── AWS SSM ─────────────────────────────────────────────────────────────────

class _SsmTab extends ConsumerWidget {
  const _SsmTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudProvider);

    if (state.isLoading && state.ssmInstances.isEmpty) {
      return Center(child: CircularProgressIndicator(color: TermexColors.primary));
    }

    if (state.ssmInstances.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 36, color: TermexColors.textSecondary),
            const SizedBox(height: 8),
            Text('未发现 SSM 实例', style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.read(cloudProvider.notifier).loadSsmInstances(),
              style: OutlinedButton.styleFrom(foregroundColor: TermexColors.textSecondary),
              child: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: state.ssmInstances.map((i) => _SsmInstanceCard(instance: i)).toList(),
    );
  }
}

class _SsmInstanceCard extends StatelessWidget {
  final SsmInstance instance;
  const _SsmInstanceCard({required this.instance});

  @override
  Widget build(BuildContext context) {
    final isOnline = instance.status == 'Online';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TermexColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? TermexColors.success : TermexColors.danger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(instance.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: TermexColors.textPrimary)),
                Text('${instance.instanceId} · ${instance.region} · ${instance.platform}',
                    style: TextStyle(fontSize: 11, color: TermexColors.textSecondary)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isOnline ? () {} : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: TermexColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(72, 28),
              textStyle: const TextStyle(fontSize: 11),
            ),
            child: const Text('启动会话'),
          ),
        ],
      ),
    );
  }
}

// ─── Aliyun ECS ──────────────────────────────────────────────────────────────

class _EcsTab extends ConsumerWidget {
  const _EcsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(cloudProvider).ecsFavorites;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('ECS 收藏夹', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TermexColors.textPrimary)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 14),
                label: const Text('添加', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TermexColors.textSecondary,
                  side: BorderSide(color: TermexColors.border),
                  minimumSize: const Size(72, 30),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: favorites.isEmpty
              ? Center(child: Text('尚无收藏的 ECS 实例', style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: favorites.map((f) => _EcsFavCard(fav: f)).toList(),
                ),
        ),
      ],
    );
  }
}

class _EcsFavCard extends ConsumerWidget {
  final EcsFavorite fav;
  const _EcsFavCard({required this.fav});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TermexColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_outlined, size: 18, color: TermexColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fav.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: TermexColors.textPrimary)),
                Text('${fav.instanceId} · ${fav.region} · ${fav.ip}',
                    style: TextStyle(fontSize: 11, color: TermexColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: TermexColors.danger),
            onPressed: () => ref.read(cloudProvider.notifier).removeEcsFavorite(fav.id),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: TermexColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 28),
              textStyle: const TextStyle(fontSize: 11),
            ),
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }
}
