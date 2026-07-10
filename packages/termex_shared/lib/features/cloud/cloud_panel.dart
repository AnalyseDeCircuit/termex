/// Sidebar panel surfacing cloud-provider resources: Kubernetes contexts,
/// AWS SSM instances, and Alibaba Cloud ECS favorites.
///
/// Mirrors the Tauri/Vue `CloudPanel.vue` sidebar entry. The OSS build's
/// `cloud_k8s_*` and `cloud_ssm_*` FRB calls return empty lists by design
/// (heavy integrations live in the closed-source termex-core-private
/// crate). This is the **same OSS behavior** as the legacy Tauri OSS build,
/// which gates those features behind the `private` Cargo feature.
///
/// What IS functional here today: the Alibaba Cloud ECS favorites table
/// (cloud_favorites SQLite table) and credential profile storage.
///
/// v0.77.0 PC final parity: restored to OSS termex_shared after v0.69
/// erroneously demoted Cloud to a "Pro forever stub".
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../icons/termex_icons.dart';

class CloudPanel extends ConsumerStatefulWidget {
  const CloudPanel({super.key});

  @override
  ConsumerState<CloudPanel> createState() => _CloudPanelState();
}

class _CloudPanelState extends ConsumerState<CloudPanel> {
  late Future<_CloudData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CloudData> _load() async {
    final results = await Future.wait<dynamic>([
      bridge.cloudK8SListContexts().catchError((_) => <bridge.K8sContext>[]),
      bridge
          .cloudSsmListInstances(region: 'us-east-1')
          .catchError((_) => <bridge.SsmInstance>[]),
      bridge.cloudEcsListFavorites().catchError((_) => <bridge.EcsFavorite>[]),
    ]);
    return _CloudData(
      contexts: results[0] as List<bridge.K8sContext>,
      ssm: results[1] as List<bridge.SsmInstance>,
      ecs: results[2] as List<bridge.EcsFavorite>,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(onRefresh: _reload),
        Expanded(
          child: FutureBuilder<_CloudData>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: TermexIconWidget(
                    TermexIcons.refresh,
                    size: 14,
                    color: TermexColors.textMuted,
                  ),
                );
              }
              final d = snap.data ?? const _CloudData();
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _Section(
                    title: 'Kubernetes 上下文',
                    emptyHint: '未检测到 kubectl 配置\n（功能由 Pro 集成提供）',
                    isEmpty: d.contexts.isEmpty,
                    children: d.contexts
                        .map((c) => _Row(
                              label: c.name,
                              sub: '${c.cluster} · ${c.namespace}',
                              icon: TermexIcons.cloud,
                              accent: c.isActive,
                            ))
                        .toList(growable: false),
                  ),
                  _Section(
                    title: 'AWS SSM 实例',
                    emptyHint: '未检测到 AWS CLI / SSM 注册实例\n（功能由 Pro 集成提供）',
                    isEmpty: d.ssm.isEmpty,
                    children: d.ssm
                        .map((s) => _Row(
                              label: s.name ?? s.instanceId,
                              sub: '${s.region} · ${s.state}',
                              icon: TermexIcons.server,
                            ))
                        .toList(growable: false),
                  ),
                  _Section(
                    title: '阿里云 ECS 收藏',
                    emptyHint: '暂无 ECS 收藏\n通过设置 → 云服务添加',
                    isEmpty: d.ecs.isEmpty,
                    children: d.ecs
                        .map((e) => _Row(
                              label: e.name,
                              sub: '${e.region} · ${e.instanceId}',
                              icon: TermexIcons.server,
                            ))
                        .toList(growable: false),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CloudData {
  final List<bridge.K8sContext> contexts;
  final List<bridge.SsmInstance> ssm;
  final List<bridge.EcsFavorite> ecs;

  const _CloudData({
    this.contexts = const [],
    this.ssm = const [],
    this.ecs = const [],
  });
}

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.md,
          vertical: TermexSpacing.sm,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: TermexColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            const TermexIconWidget(
              TermexIcons.cloud,
              size: 14,
              color: TermexColors.textSecondary,
            ),
            const SizedBox(width: TermexSpacing.sm),
            Text(
              '云端资源',
              style: TermexTypography.bodySmall.copyWith(
                color: TermexColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onRefresh,
              child: const TermexIconWidget(
                TermexIcons.refresh,
                size: 12,
                color: TermexColors.textMuted,
              ),
            ),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final String emptyHint;
  final bool isEmpty;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.emptyHint,
    required this.isEmpty,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TermexSpacing.md,
            TermexSpacing.sm,
            TermexSpacing.md,
            4,
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TermexTypography.caption.copyWith(
              color: TermexColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TermexSpacing.md,
              0,
              TermexSpacing.md,
              TermexSpacing.sm,
            ),
            child: Text(
              emptyHint,
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
              ),
            ),
          )
        else
          ...children,
      ],
    );
  }
}

class _Row extends StatefulWidget {
  final String label;
  final String sub;
  final IconData icon;
  final bool accent;

  const _Row({
    required this.label,
    required this.sub,
    required this.icon,
    this.accent = false,
  });

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.md,
            vertical: TermexSpacing.xs,
          ),
          color: _hovered
              ? TermexColors.backgroundTertiary
              : const Color(0x00000000),
          child: Row(
            children: [
              TermexIconWidget(
                widget.icon,
                size: 12,
                color: widget.accent
                    ? TermexColors.primary
                    : TermexColors.textSecondary,
              ),
              const SizedBox(width: TermexSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermexTypography.bodySmall.copyWith(
                        color: widget.accent
                            ? TermexColors.primary
                            : TermexColors.textPrimary,
                        fontWeight: widget.accent ? FontWeight.w600 : null,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
      );
}
