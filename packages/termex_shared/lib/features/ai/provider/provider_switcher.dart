import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../state/conversation_provider.dart';
import '../state/provider_config_provider.dart';
import 'provider_config_dialog.dart';
import 'provider_registry.dart';

/// Compact provider + model selector shown in the AI panel toolbar.
class ProviderSwitcher extends ConsumerWidget {
  const ProviderSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configState = ref.watch(providerConfigProvider);
    final active = configState.activeProvider;
    final meta = metaFor(active);
    final config = configState.activeConfig;

    return GestureDetector(
      onTap: () => _showMenu(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: TermexColors.border),
          borderRadius: BorderRadius.circular(6),
          color: TermexColors.backgroundTertiary,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              meta.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: TermexColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              config.model,
              style: const TextStyle(
                fontSize: 11,
                color: TermexColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 14, color: TermexColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// A provider counts as "configured" when:
  ///   - cloud providers (require API key): an `AiProviderConfig` exists
  ///     AND its `apiKey` is non-empty;
  ///   - local providers (Ollama / Local AI, no API key required): any
  ///     `AiProviderConfig` row exists for them (the user has at minimum
  ///     opened the inline form once and saved).
  ///
  /// v0.79.56: dropped the "active provider always counts" special case.
  /// That special case made the default `activeProvider = claude` look
  /// configured in the switcher dropdown even when no API key was set —
  /// users would pick Claude, send a message, and hit "API key missing"
  /// at runtime. Now the switcher honestly shows zero items when nothing
  /// is configured; [AiPanel] gates the whole chat surface on
  /// [ProviderConfigState.hasAnyConfigured] before the switcher even
  /// renders.
  bool _isConfigured(
    AiProvider provider,
    ProviderConfigState state,
  ) {
    final cfg = state.configs[provider];
    if (cfg == null) return false;
    final isCloud =
        provider != AiProvider.ollama && provider != AiProvider.localLlama;
    if (isCloud) return (cfg.apiKey ?? '').isNotEmpty;
    return true;
  }

  void _showMenu(BuildContext context, WidgetRef ref) async {
    final cfgState = ref.read(providerConfigProvider);
    // v0.78.0: filter to providers the user has actually configured.
    // Showing all 11 registry entries here used to confuse users who
    // would pick an unconfigured provider and immediately get an
    // "API key missing" error when they tried to send a message. The
    // active provider stays in the list as a safety net (see comment
    // on `_isConfigured`).
    final visibleProviders = kProviderRegistry
        .where((meta) => _isConfigured(meta.provider, cfgState))
        .toList(growable: false);
    final result = await showMenu<_MenuAction>(
      context: context,
      position: _menuPosition(context),
      color: TermexColors.backgroundSecondary,
      items: [
        // Provider items — only those that are configured.
        if (visibleProviders.isEmpty)
          const PopupMenuItem<_MenuAction>(
            enabled: false,
            child: _EmptyHint(),
          )
        else
          ...visibleProviders.map((meta) => PopupMenuItem<_MenuAction>(
                value: _MenuAction.switchProvider(meta.provider),
                child: _ProviderMenuItem(meta: meta),
              )),
        const PopupMenuDivider(),
        // Configure current provider
        const PopupMenuItem<_MenuAction>(
          value: _MenuAction.configure,
          child: _ConfigureMenuItem(),
        ),
      ],
    );

    if (result == null || !context.mounted) return;

    if (result.isSwitch) {
      ref
          .read(providerConfigProvider.notifier)
          .setActiveProvider(result.provider!);
    } else {
      await showProviderConfigDialog(
        context,
        ref.read(providerConfigProvider).activeProvider,
      );
    }
  }

  RelativeRect _menuPosition(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return RelativeRect.fill;
    final offset = box.localToGlobal(Offset.zero);
    return RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + box.size.height + 4,
      offset.dx + box.size.width,
      0,
    );
  }
}

class _MenuAction {
  final bool isSwitch;
  final AiProvider? provider;

  const _MenuAction._({required this.isSwitch, this.provider});
  factory _MenuAction.switchProvider(AiProvider p) =>
      _MenuAction._(isSwitch: true, provider: p);
  static const configure = _MenuAction._(isSwitch: false);
}

/// Width clamp shared across every menu item so Material's `showMenu`
/// doesn't auto-expand to the longest English description (e.g.
/// "Anthropic Claude — best for code and reasoning"), which previously
/// overflowed the right edge of the AI panel by ~5px.
const double _kProviderMenuItemWidth = 260;

class _ProviderMenuItem extends StatelessWidget {
  final ProviderMeta meta;
  const _ProviderMenuItem({required this.meta});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kProviderMenuItemWidth,
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
                Text(
                  meta.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: TermexColors.textPrimary),
                ),
                Text(
                  meta.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, color: TermexColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown inside the dropdown when **no** provider has been configured
/// yet (and the active provider somehow also has no config). Prompts
/// the user to open settings instead of leaving an empty menu that
/// reads as "broken".
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kProviderMenuItemWidth,
      child: Row(
        children: const [
          Icon(Icons.info_outline,
              size: 14, color: TermexColors.textSecondary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '尚未配置 Provider\n打开设置 → AI 助手添加',
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                color: TermexColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigureMenuItem extends StatelessWidget {
  const _ConfigureMenuItem();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: _kProviderMenuItemWidth,
      child: Row(
        children: [
          Icon(Icons.settings_outlined,
              size: 14, color: TermexColors.textSecondary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '配置当前 Provider',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: TermexColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
