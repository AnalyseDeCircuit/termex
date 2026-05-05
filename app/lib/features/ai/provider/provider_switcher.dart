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
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: TermexColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              config.model,
              style: TextStyle(
                fontSize: 11,
                color: TermexColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 14, color: TermexColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) async {
    final result = await showMenu<_MenuAction>(
      context: context,
      position: _menuPosition(context),
      color: TermexColors.backgroundSecondary,
      items: [
        // Provider items
        ...kProviderRegistry.map((meta) => PopupMenuItem<_MenuAction>(
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

class _ProviderMenuItem extends StatelessWidget {
  final ProviderMeta meta;
  const _ProviderMenuItem({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.smart_toy_outlined,
            size: 14, color: TermexColors.textSecondary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(meta.label,
                style: TextStyle(
                    fontSize: 12, color: TermexColors.textPrimary)),
            Text(meta.description,
                style: TextStyle(
                    fontSize: 10, color: TermexColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _ConfigureMenuItem extends StatelessWidget {
  const _ConfigureMenuItem();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.settings_outlined, size: 14, color: TermexColors.textSecondary),
        const SizedBox(width: 8),
        Text('配置当前 Provider',
            style: TextStyle(fontSize: 12, color: TermexColors.textPrimary)),
      ],
    );
  }
}
