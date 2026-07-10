/// AI assistant settings tab.
///
/// v0.78.0: redesigned to a user-managed list. Instead of pre-rendering
/// all 11 registry entries, the tab now shows only the providers the
/// user has actually configured. A "+ Add Provider" button at the top
/// opens a dropdown of remaining (un-added) providers; picking one
/// inserts an empty config row and immediately opens its inline form.
/// Mirrors the legacy `AiConfigTab.vue` flow where `aiStore.providers`
/// was user-managed CRUD, not a fixed enumeration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../icons/termex_icons.dart';
import '../../ai/provider/provider_inline_form.dart';
import '../../ai/provider/provider_registry.dart';
import '../../ai/state/ai_pricing.dart';
import '../../ai/state/conversation_provider.dart' show AiProvider;
import '../../ai/state/provider_config_provider.dart';
import '../state/settings_provider.dart';
import '../widgets/setting_row.dart';

class AiTab extends ConsumerStatefulWidget {
  const AiTab({super.key});

  @override
  ConsumerState<AiTab> createState() => _AiTabState();
}

class _AiTabState extends ConsumerState<AiTab> {
  /// Currently-expanded provider, or null when no row is editing.
  AiProvider? _editingProvider;

  void _toggleEdit(AiProvider provider) {
    setState(() {
      _editingProvider =
          _editingProvider == provider ? null : provider;
    });
  }

  /// "Configured" mirrors [`ProviderSwitcher._isConfigured`]: cloud needs
  /// API key; local needs config row exists.
  bool _isConfigured(AiProvider provider, ProviderConfigState cfgState) {
    final cfg = cfgState.configs[provider];
    if (cfg == null) return false;
    final isCloud = provider != AiProvider.ollama &&
        provider != AiProvider.localLlama;
    if (isCloud) return (cfg.apiKey ?? '').isNotEmpty;
    return true;
  }

  /// "Visible" providers in the list = configured OR currently being
  /// edited (so a freshly-added row stays put while the user fills in
  /// the form).
  ///
  /// v0.79.57: dropped the "active provider is always visible" rule.
  /// Default `activeProvider = AiProvider.claude` was making Claude
  /// permanently visible in the empty list even though the user had
  /// added nothing — confusingly suggesting Claude was already set up.
  /// Now the list honestly reflects what's in `configs` + what's being
  /// edited; the empty state hint takes over when nothing is configured.
  bool _shouldShow(AiProvider provider, ProviderConfigState cfgState) {
    if (provider == _editingProvider) return true;
    return _isConfigured(provider, cfgState) ||
        cfgState.configs.containsKey(provider);
  }

  Future<void> _addProvider() async {
    final cfgState = ref.read(providerConfigProvider);
    final available = kProviderRegistry
        .where((meta) => !_shouldShow(meta.provider, cfgState))
        .toList(growable: false);
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有 Provider 都已配置')),
      );
      return;
    }
    final picked = await _showAddProviderMenu(context, available);
    if (picked == null) return;
    // Seed an empty config row so the inline form has somewhere to
    // write into, then open it. The user closes the form to commit, or
    // navigates away (form has its own save button).
    final notifier = ref.read(providerConfigProvider.notifier);
    if (cfgState.configs[picked] == null) {
      notifier.upsertEmpty(picked);
    }
    if (!mounted) return;
    setState(() => _editingProvider = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cfgState = ref.watch(providerConfigProvider);
    final settings = ref.watch(settingsProvider).settings;
    final notifier = ref.read(settingsProvider.notifier);

    final visibleProviders = kProviderRegistry
        .where((meta) => _shouldShow(meta.provider, cfgState))
        .toList(growable: false);
    final allConfigured = visibleProviders.length == kProviderRegistry.length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SettingRow(
          label: '默认上下文行数',
          hint: '发送给 AI 的终端历史行数上限',
          child: DropdownButton<int>(
            value: _coerceContextLines(settings.aiContextLines),
            dropdownColor: TermexColors.backgroundSecondary,
            items: const [
              DropdownMenuItem(value: 50, child: Text('50 行')),
              DropdownMenuItem(value: 100, child: Text('100 行')),
              DropdownMenuItem(value: 200, child: Text('200 行')),
              DropdownMenuItem(value: 500, child: Text('500 行')),
            ],
            onChanged: (v) =>
                notifier.update(settings.copyWith(aiContextLines: v!)),
            style: const TextStyle(
                fontSize: 12, color: TermexColors.textPrimary),
          ),
        ),
        SettingRow(
          label: '自动错误诊断',
          hint: '命令失败时自动触发 AI 分析',
          child: Switch(
            value: settings.aiAutoDiagnose,
            onChanged: (v) =>
                notifier.update(settings.copyWith(aiAutoDiagnose: v)),
          ),
        ),
        const SizedBox(height: 20),
        // ─── Header: "AI Provider" + Add button ────────────────────────
        Row(
          children: [
            const _SectionHeader('AI Provider'),
            const Spacer(),
            if (!allConfigured)
              _AddProviderButton(onPressed: _addProvider),
          ],
        ),
        const SizedBox(height: 8),
        if (visibleProviders.isEmpty)
          _EmptyProvidersHint(onAdd: _addProvider)
        else
          ...visibleProviders.expand((meta) sync* {
            final isActive = meta.provider == cfgState.activeProvider;
            final isConfigured = _isConfigured(meta.provider, cfgState);
            final isEditing = _editingProvider == meta.provider;
            // v0.79.57: delete button is available on any provider whose
            // row the user has explicitly added (anything sitting in
            // `configs`), regardless of `isActive` / `isConfigured`. The
            // previous `!isActive && isConfigured` gate meant Claude
            // (default active, half-configured) had no way out — user
            // could see the row but not delete it. `removeConfig` now
            // re-points active to the next configured provider when
            // deleting the active one (see [ProviderConfigNotifier]).
            final hasRow = cfgState.configs.containsKey(meta.provider);
            yield _ProviderRow(
              meta: meta,
              isActive: isActive,
              isConfigured: isConfigured,
              isEditing: isEditing,
              onEditToggle: () => _toggleEdit(meta.provider),
              onActivate: () => ref
                  .read(providerConfigProvider.notifier)
                  .setActiveProvider(meta.provider),
              onRemove: hasRow ? () => _confirmRemove(meta) : null,
            );
            if (isEditing) {
              yield Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ProviderInlineForm(
                  key: ValueKey('inline-${meta.provider}'),
                  provider: meta.provider,
                  onClose: () =>
                      setState(() => _editingProvider = null),
                ),
              );
            }
          }),
        const SizedBox(height: 20),
        const _PricingSnapshotFooter(),
      ],
    );
  }

  Future<void> _confirmRemove(ProviderMeta meta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: Text('移除 ${meta.label}?',
            style: const TextStyle(
                fontSize: 14, color: TermexColors.textPrimary)),
        content: Text(
          '将删除 ${meta.label} 的本地配置（API key 仍保留在系统钥匙串中，重新配置时会自动加载）。',
          style: const TextStyle(
              fontSize: 12, color: TermexColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: TermexColors.danger),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(providerConfigProvider.notifier)
          .removeConfig(meta.provider);
    }
  }
}

/// Opens a positioned popup menu showing each [`available`] provider as
/// a row (icon + label + description). Returns the chosen provider or
/// null when dismissed.
Future<AiProvider?> _showAddProviderMenu(
  BuildContext context,
  List<ProviderMeta> available,
) async {
  final box = context.findRenderObject() as RenderBox?;
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return null;
  final btnTopRight = box.localToGlobal(Offset(box.size.width, 0));
  final result = await showMenu<AiProvider>(
    context: context,
    color: TermexColors.backgroundSecondary,
    position: RelativeRect.fromLTRB(
      btnTopRight.dx - 280,
      btnTopRight.dy + 24,
      0,
      0,
    ),
    items: available
        .map((meta) => PopupMenuItem<AiProvider>(
              value: meta.provider,
              child: SizedBox(
                width: 260,
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy_outlined,
                        size: 14, color: TermexColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(meta.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: TermexColors.textPrimary)),
                          Text(meta.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: TermexColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ))
        .toList(),
  );
  return result;
}

// ─── + Add Provider button ─────────────────────────────────────────────────

class _AddProviderButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AddProviderButton({required this.onPressed});

  @override
  State<_AddProviderButton> createState() => _AddProviderButtonState();
}

class _AddProviderButtonState extends State<_AddProviderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? TermexColors.primary.withOpacity(0.15)
                : TermexColors.backgroundTertiary,
            border: Border.all(
              color: _hovered
                  ? TermexColors.primary
                  : TermexColors.border,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              TermexIconWidget(
                TermexIcons.add,
                size: 11,
                color: TermexColors.textPrimary,
              ),
              SizedBox(width: 4),
              Text(
                'Add Provider',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: TermexColors.textPrimary,
                ),
              ),
              SizedBox(width: 2),
              TermexIconWidget(
                TermexIcons.chevronDown,
                size: 10,
                color: TermexColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state hint ─────────────────────────────────────────────────────

class _EmptyProvidersHint extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyProvidersHint({required this.onAdd});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: TermexColors.backgroundSecondary,
          border: Border.all(color: TermexColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            const Icon(Icons.smart_toy_outlined,
                size: 32, color: TermexColors.textMuted),
            const SizedBox(height: 8),
            const Text(
              '尚未配置 AI Provider',
              style: TextStyle(
                  fontSize: 13, color: TermexColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              '点击右上「Add Provider」选择一个开始',
              style: TextStyle(
                  fontSize: 11, color: TermexColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _AddProviderButton(onPressed: onAdd),
          ],
        ),
      );
}

// ─── Section header ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: TermexColors.textSecondary,
          letterSpacing: 0.5,
        ),
      );
}

// ─── Provider row ─────────────────────────────────────────────────────────

class _ProviderRow extends StatefulWidget {
  final ProviderMeta meta;
  final bool isActive;
  final bool isConfigured;
  final bool isEditing;
  final VoidCallback onEditToggle;
  final VoidCallback onActivate;
  final VoidCallback? onRemove;

  const _ProviderRow({
    required this.meta,
    required this.isActive,
    required this.isConfigured,
    required this.isEditing,
    required this.onEditToggle,
    required this.onActivate,
    this.onRemove,
  });

  @override
  State<_ProviderRow> createState() => _ProviderRowState();
}

class _ProviderRowState extends State<_ProviderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.isEditing
        ? const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          )
        : BorderRadius.circular(6);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        margin: EdgeInsets.only(bottom: widget.isEditing ? 0 : 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered
              ? TermexColors.backgroundTertiary
              : TermexColors.backgroundSecondary,
          border: Border.all(
            color: widget.isActive
                ? TermexColors.primary.withOpacity(0.5)
                : TermexColors.border,
          ),
          borderRadius: radius,
        ),
        child: Row(
          children: [
            const Icon(Icons.smart_toy_outlined,
                size: 16, color: TermexColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.meta.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: TermexColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (widget.isActive) const _Badge('当前', primary: true),
                      if (widget.isConfigured && !widget.isActive)
                        const _Badge('已配置'),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.meta.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: TermexColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!widget.isActive && widget.isConfigured)
              _MiniBtn(label: '激活', onTap: widget.onActivate),
            const SizedBox(width: 4),
            _MiniBtn(
              label: widget.isEditing
                  ? '收起'
                  : (widget.isConfigured ? '编辑' : '配置'),
              primary: !widget.isConfigured && !widget.isEditing,
              onTap: widget.onEditToggle,
            ),
            if (widget.onRemove != null) ...[
              const SizedBox(width: 4),
              _IconBtn(
                icon: TermexIcons.delete,
                tooltip: '移除',
                onTap: widget.onRemove!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool primary;
  const _Badge(this.text, {this.primary = false});

  @override
  Widget build(BuildContext context) {
    final color =
        primary ? TermexColors.primary : TermexColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _MiniBtn({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: primary
                ? TermexColors.primary
                : TermexColors.backgroundTertiary,
            border: Border.all(
              color: primary
                  ? TermexColors.primary
                  : TermexColors.border,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: primary ? Colors.white : TermexColors.textPrimary,
            ),
          ),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: TermexColors.backgroundTertiary,
              border: Border.all(color: TermexColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: TermexIconWidget(
              icon,
              size: 11,
              color: TermexColors.textSecondary,
            ),
          ),
        ),
      );
}

/// Footer line that surfaces the cost-estimation pricing snapshot
/// (vendor rate table embedded in [ai_pricing.dart]). Shows when the
/// snapshot was last refreshed, days elapsed, and a warning chip when
/// the table is older than [kPricingStaleAfterDays]. Without this the
/// stale-check helper added in v0.79.51 is dead UI.
class _PricingSnapshotFooter extends StatelessWidget {
  const _PricingSnapshotFooter();

  @override
  Widget build(BuildContext context) {
    final stale = isPricingStale();
    final age = pricingAgeDays();
    final ageLabel = age < 0
        ? '日期未知'
        : age == 0
            ? '今天更新'
            : '$age 天前';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border.all(
          color: stale
              ? TermexColors.warning.withOpacity(0.5)
              : TermexColors.border,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            stale ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 14,
            color:
                stale ? TermexColors.warning : TermexColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 成本估算价格表',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: TermexColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '更新于 $kPricingLastUpdatedIso · $ageLabel'
                  '${stale ? ' · 建议刷新' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: TermexColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (stale)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: TermexColors.warning.withOpacity(0.15),
                border: Border.all(color: TermexColors.warning.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'Stale',
                style: TextStyle(
                  fontSize: 9,
                  color: TermexColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Snaps an arbitrary stored AI context-lines value to the nearest
/// supported option. Without this, DropdownButton asserts when `value`
/// doesn't match exactly one DropdownMenuItem.
int _coerceContextLines(int stored) {
  const options = [50, 100, 200, 500];
  if (options.contains(stored)) return stored;
  int best = options.first;
  int bestDist = (stored - best).abs();
  for (final o in options.skip(1)) {
    final d = (stored - o).abs();
    if (d < bestDist) {
      best = o;
      bestDist = d;
    }
  }
  return best;
}
