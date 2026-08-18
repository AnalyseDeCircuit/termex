import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../design/radius.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/clickable.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final _proxiesProvider = FutureProvider<List<bridge.ProxyConfig>>((ref) async {
  return bridge.proxyList();
});

// ── Tab ──────────────────────────────────────────────────────────────────────

class ProxiesTab extends ConsumerWidget {
  const ProxiesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_proxiesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(AppLocalizations.of(context).commonLoadFailed(e.toString()),
            style: const TextStyle(color: TermexColors.danger, fontSize: 13)),
      ),
      data: (proxies) => _ProxyList(proxies: proxies),
    );
  }
}

class _ProxyList extends ConsumerWidget {
  final List<bridge.ProxyConfig> proxies;
  const _ProxyList({required this.proxies});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(TermexSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context).proxiesTitle,
                style: TermexTypography.bodySmall.copyWith(
                  color: TermexColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              _AddButton(onTap: () => _showAddDialog(context, ref)),
            ],
          ),
          const SizedBox(height: TermexSpacing.md),
          if (proxies.isEmpty)
            _EmptyState()
          else
            Expanded(
              child: ListView.separated(
                itemCount: proxies.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: TermexColors.border, height: 1),
                itemBuilder: (ctx, i) => _ProxyRow(
                  proxy: proxies[i],
                  onDelete: () async {
                    await bridge.proxyDelete(id: proxies[i].id);
                    ref.invalidate(_proxiesProvider);
                  },
                  onSetDefault: () async {
                    await bridge.proxySetDefault(id: proxies[i].id);
                    ref.invalidate(_proxiesProvider);
                  },
                  onTest: () => _testProxy(context, proxies[i].id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext ctx, WidgetRef ref) async {
    final result = await showDialog<_ProxyFormData>(
      context: ctx,
      builder: (_) => const _AddProxyDialog(),
    );
    if (result == null) return;
    final newProxy = await bridge.proxyCreateEx(
      name: result.name,
      proxyType: result.type,
      host: result.host,
      port: result.port,
      username: result.username.isEmpty ? null : result.username,
      tlsEnabled: result.tlsEnabled,
    );
    if (result.password.isNotEmpty) {
      await bridge.proxyStorePassword(
        proxyId: newProxy.id,
        password: result.password,
      );
    }
    ref.invalidate(_proxiesProvider);
  }

  Future<void> _testProxy(BuildContext ctx, String id) async {
    final l10n = AppLocalizations.of(ctx);
    try {
      final ok = await bridge.proxyTestConnection(id: id);
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(ok ? l10n.proxiesTestOk : l10n.proxiesTestFail),
          backgroundColor: ok ? TermexColors.success : TermexColors.danger,
        ),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(l10n.proxiesTestError(e.toString())),
          backgroundColor: TermexColors.danger,
        ),
      );
    }
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: TermexColors.primary.withValues(alpha: 0.12),
          borderRadius: TermexRadius.sm,
          border:
              Border.all(color: TermexColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 13, color: TermexColors.primary),
            const SizedBox(width: 4),
            Text(AppLocalizations.of(context).proxiesAddProxy,
                style: const TextStyle(
                    fontSize: 12,
                    color: TermexColors.primary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: TermexSpacing.xl),
      child: Center(
        child: Text(
          AppLocalizations.of(context).proxiesEmpty,
          textAlign: TextAlign.center,
          style: TermexTypography.body.copyWith(color: TermexColors.textMuted),
        ),
      ),
    );
  }
}

class _ProxyRow extends StatelessWidget {
  final bridge.ProxyConfig proxy;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;
  final VoidCallback onTest;

  const _ProxyRow({
    required this.proxy,
    required this.onDelete,
    required this.onSetDefault,
    required this.onTest,
  });

  String get _typeLabel => switch (proxy.proxyType) {
        bridge.ProxyType.socks5 => 'SOCKS5',
        bridge.ProxyType.http => 'HTTP',
        bridge.ProxyType.tor => 'Tor',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TermexSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: TermexColors.backgroundTertiary,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: TermexColors.border),
            ),
            child: Text(_typeLabel,
                style: const TextStyle(
                    fontSize: 10,
                    color: TermexColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: TermexSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(proxy.name,
                        style: TermexTypography.body
                            .copyWith(color: TermexColors.textPrimary)),
                    if (proxy.isDefault) ...[
                      const SizedBox(width: TermexSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: TermexColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(AppLocalizations.of(context).proxiesDefault,
                            style: TextStyle(
                                fontSize: 10,
                                color: TermexColors.success,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                Text('${proxy.host}:${proxy.port}',
                    style: TermexTypography.caption
                        .copyWith(color: TermexColors.textMuted)),
              ],
            ),
          ),
          // Actions
          _ActionIcon(icon: Icons.network_check, tooltip: AppLocalizations.of(context).proxiesTestConn, onTap: onTest),
          if (!proxy.isDefault)
            _ActionIcon(
                icon: Icons.star_outline,
                tooltip: AppLocalizations.of(context).proxiesSetDefault,
                onTap: onSetDefault),
          _ActionIcon(
              icon: Icons.delete_outline,
              tooltip: AppLocalizations.of(context).proxiesDelete,
              onTap: onDelete,
              color: TermexColors.danger),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Clickable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon,
              size: 16, color: color ?? TermexColors.textSecondary),
        ),
      ),
    );
  }
}

// ── Add proxy dialog ──────────────────────────────────────────────────────────

class _ProxyFormData {
  final String name;
  final bridge.ProxyType type;
  final String host;
  final int port;
  final String username;
  final String password;
  final bool tlsEnabled;

  const _ProxyFormData({
    required this.name,
    required this.type,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.tlsEnabled,
  });
}

class _AddProxyDialog extends StatefulWidget {
  const _AddProxyDialog();

  @override
  State<_AddProxyDialog> createState() => _AddProxyDialogState();
}

class _AddProxyDialogState extends State<_AddProxyDialog> {
  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '1080');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bridge.ProxyType _type = bridge.ProxyType.socks5;
  bool _tls = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TermexColors.backgroundSecondary,
      title: const Text(AppLocalizations.of(context).proxiesAddProxy,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: TermexColors.textPrimary)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(label: AppLocalizations.of(context).proxiesDialogName, controller: _nameCtrl, hint: 'My Proxy'),
            const SizedBox(height: 12),
            // Type selector
            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text(AppLocalizations.of(context).proxiesDialogType,
                      style: TextStyle(
                          fontSize: 12, color: TermexColors.textSecondary)),
                ),
                DropdownButton<bridge.ProxyType>(
                  value: _type,
                  dropdownColor: TermexColors.backgroundSecondary,
                  style: const TextStyle(fontSize: 12, color: TermexColors.textPrimary),
                  onChanged: (v) => setState(() => _type = v!),
                  items: const [
                    DropdownMenuItem(
                        value: bridge.ProxyType.socks5, child: Text('SOCKS5')),
                    DropdownMenuItem(
                        value: bridge.ProxyType.http, child: Text('HTTP')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DialogField(label: AppLocalizations.of(context).proxiesDialogHost, controller: _hostCtrl, hint: '127.0.0.1'),
            const SizedBox(height: 12),
            _DialogField(
                label: AppLocalizations.of(context).proxiesDialogPort,
                controller: _portCtrl,
                hint: '1080',
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _DialogField(
                label: AppLocalizations.of(context).proxiesDialogUsername,
                controller: _userCtrl,
                hint: AppLocalizations.of(context).proxiesDialogOptional),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text(AppLocalizations.of(context).proxiesDialogPassword,
                      style: TextStyle(
                          fontSize: 12, color: TermexColors.textSecondary)),
                ),
                Expanded(
                  child: TextField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    style: const TextStyle(
                        fontSize: 12, color: TermexColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).proxiesDialogOptional,
                      hintStyle: const TextStyle(
                          fontSize: 12, color: TermexColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: TermexColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: TermexColors.border),
                      ),
                      suffixIcon: Clickable(
                        onTap: () =>
                            setState(() => _obscurePass = !_obscurePass),
                        child: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 16,
                          color: TermexColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text('TLS',
                      style: TextStyle(
                          fontSize: 12, color: TermexColors.textSecondary)),
                ),
                Switch(
                  value: _tls,
                  onChanged: (v) => setState(() => _tls = v),
                  activeThumbColor: TermexColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel,
              style: TextStyle(color: TermexColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () {
            final port = int.tryParse(_portCtrl.text) ?? 1080;
            Navigator.of(context).pop(_ProxyFormData(
              name: _nameCtrl.text.trim().isEmpty ? AppLocalizations.of(context).proxiesDefaultName : _nameCtrl.text.trim(),
              type: _type,
              host: _hostCtrl.text.trim(),
              port: port,
              username: _userCtrl.text.trim(),
              password: _passCtrl.text,
              tlsEnabled: _tls,
            ));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: TermexColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(AppLocalizations.of(context).proxiesDialogAdd),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  const _DialogField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: TermexColors.textSecondary)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 12, color: TermexColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 12, color: TermexColors.textMuted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: TermexColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: TermexColors.border),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
