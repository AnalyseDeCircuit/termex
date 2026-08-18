import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/bottom_sheet.dart';
import '../../../widgets/button.dart';
import '../../../widgets/list_item.dart';
import '../../../widgets/segmented.dart';
import '../../../widgets/text_field.dart';

// ─── Proxy data models ────────────────────────────────────────────────────────

enum ProxyType { socks5, http, cloudflareWarp, tor }

extension ProxyTypeLabel on ProxyType {
  String get label => switch (this) {
        ProxyType.socks5 => 'SOCKS5',
        ProxyType.http => 'HTTP/HTTPS',
        ProxyType.cloudflareWarp => 'Cloudflare WARP',
        ProxyType.tor => 'Tor',
      };

  bool get requiresHostPort => this == ProxyType.socks5 || this == ProxyType.http;
}

class ProxyConfig {
  final String id;
  final String name;
  final ProxyType type;
  final String? host;
  final int? port;
  final String? username;

  const ProxyConfig({
    required this.id,
    required this.name,
    required this.type,
    this.host,
    this.port,
    this.username,
  });
}

// Stub provider — will be replaced by FRB-backed provider in v0.57.0.
final _proxyListProvider = Provider<List<ProxyConfig>>((ref) => []);

// ─── ProxyPicker widget ───────────────────────────────────────────────────────

/// Displays the currently selected proxy config and lets the user pick or
/// create one via a BottomSheet.
class ProxyPicker extends ConsumerWidget {
  final String? selectedProxyId;
  final ValueChanged<String?> onChanged;

  const ProxyPicker({
    super.key,
    required this.selectedProxyId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final proxies = ref.watch(_proxyListProvider);
    final selected = proxies.where((p) => p.id == selectedProxyId).firstOrNull;

    final subtitle = selectedProxyId == null
        ? l10n.proxyNone
        : selected != null
            ? '${selected.type.label} — ${selected.host ?? ''}:${selected.port ?? ''}'
            : l10n.proxyLoading;

    return TermexListItem(
      title: l10n.connectionProxy,
      subtitle: subtitle,
      trailing: _ChevronIcon(),
      onTap: () async {
        final picked = await showTermexBottomSheet<String?>(
          context: context,
          child: _ProxyPickerSheet(
            proxies: proxies,
            currentId: selectedProxyId,
            onPick: (id) => Navigator.of(context, rootNavigator: true).pop(id),
            onCreateNew: (cfg) => Navigator.of(context, rootNavigator: true).pop(cfg.id),
          ),
        );
        if (picked != null || picked == null && selectedProxyId != null) {
          onChanged(picked);
        }
      },
    );
  }
}

// ─── Picker sheet ─────────────────────────────────────────────────────────────

class _ProxyPickerSheet extends StatefulWidget {
  final List<ProxyConfig> proxies;
  final String? currentId;
  final ValueChanged<String?> onPick;
  final ValueChanged<ProxyConfig> onCreateNew;

  const _ProxyPickerSheet({
    required this.proxies,
    required this.currentId,
    required this.onPick,
    required this.onCreateNew,
  });

  @override
  State<_ProxyPickerSheet> createState() => _ProxyPickerSheetState();
}

class _ProxyPickerSheetState extends State<_ProxyPickerSheet> {
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    if (_showForm) return _NewProxyForm(onSave: widget.onCreateNew);

    final l10n = AppLocalizations.of(context);
    final colors = TermexColorScheme.dark();
    return Padding(
      padding: const EdgeInsets.only(
        left: TermexSpacing.md,
        right: TermexSpacing.md,
        bottom: TermexSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TermexSpacing.md),
            child: Text(
              l10n.proxySelect,
              style: TermexTypography.heading3.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          TermexListItem(
            title: l10n.proxyNone,
            selected: widget.currentId == null,
            onTap: () => widget.onPick(null),
          ),
          const SizedBox(height: TermexSpacing.xs),
          ...widget.proxies.map((p) => TermexListItem(
                title: p.name,
                subtitle: '${p.type.label} — ${p.host ?? ''}:${p.port ?? ''}',
                selected: p.id == widget.currentId,
                onTap: () => widget.onPick(p.id),
              )),
          const SizedBox(height: TermexSpacing.sm),
          TermexButton(
            label: l10n.proxyAddNew,
            variant: ButtonVariant.ghost,
            onPressed: () => setState(() => _showForm = true),
          ),
        ],
      ),
    );
  }
}

// ─── New proxy form ───────────────────────────────────────────────────────────

class _NewProxyForm extends StatefulWidget {
  final ValueChanged<ProxyConfig> onSave;
  const _NewProxyForm({required this.onSave});

  @override
  State<_NewProxyForm> createState() => _NewProxyFormState();
}

class _NewProxyFormState extends State<_NewProxyForm> {
  ProxyType _type = ProxyType.socks5;
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '1080');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_type.requiresHostPort) {
      return _hostCtrl.text.trim().isNotEmpty &&
          int.tryParse(_portCtrl.text.trim()) != null;
    }
    return true;
  }

  void _save() {
    if (!_canSave) return;
    final cfg = ProxyConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      type: _type,
      host: _type.requiresHostPort ? _hostCtrl.text.trim() : null,
      port: _type.requiresHostPort ? int.tryParse(_portCtrl.text.trim()) : null,
      username: _userCtrl.text.trim().isEmpty ? null : _userCtrl.text.trim(),
    );
    widget.onSave(cfg);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = TermexColorScheme.dark();
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        left: TermexSpacing.md,
        right: TermexSpacing.md,
        bottom: TermexSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TermexSpacing.md),
            child: Text(
              l10n.proxyNewTitle,
              style: TermexTypography.heading3.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          TermexTextField(
            controller: _nameCtrl,
            label: l10n.connectionProxyName,
            placeholder: l10n.proxyNamePlaceholder,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TermexSpacing.sm),
          TermexSegmented(
            items: ProxyType.values.map((t) => t.label).toList(),
            selectedIndex: ProxyType.values.indexOf(_type),
            onChanged: (i) => setState(() => _type = ProxyType.values[i]),
          ),
          if (_type.requiresHostPort) ...[
            const SizedBox(height: TermexSpacing.sm),
            TermexTextField(
              controller: _hostCtrl,
              label: l10n.connectionHost,
              placeholder: '127.0.0.1',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: TermexSpacing.sm),
            TermexTextField(
              controller: _portCtrl,
              label: l10n.connectionPort,
              placeholder: '1080',
              keyboardType: const TextInputType.numberWithOptions(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: TermexSpacing.sm),
            TermexTextField(
              controller: _userCtrl,
              label: l10n.proxyUsernameOptional,
              placeholder: '',
            ),
            const SizedBox(height: TermexSpacing.sm),
            TermexTextField(
              controller: _passCtrl,
              label: l10n.proxyPasswordOptional,
              placeholder: '',
              obscureText: true,
            ),
          ],
          if (_type == ProxyType.cloudflareWarp || _type == ProxyType.tor) ...[
            const SizedBox(height: TermexSpacing.sm),
            Text(
              _type == ProxyType.cloudflareWarp
                  ? l10n.proxyWarpHint
                  : l10n.proxyTorHint,
              style: TermexTypography.bodySmall.copyWith(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: TermexSpacing.md),
          TermexButton(
            label: l10n.proxySave,
            variant: ButtonVariant.primary,
            onPressed: _canSave ? _save : null,
          ),
        ],
      ),
    );
  }
}

class _ChevronIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(
      const IconData(0xe5cc, fontFamily: 'MaterialIcons'),
      size: 18,
      color: context.colors.textMuted,
    );
  }
}
