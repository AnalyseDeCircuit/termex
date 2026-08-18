import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server_list/widgets/server_search_bar.dart';
import '../sidebar_search.dart';

import '../../design/tokens.dart';
import '../../widgets/clickable.dart';
import 'state/proxy_provider.dart';

/// Proxy configuration panel — list proxies, add/delete, set default, test.
class ProxyPanel extends ConsumerStatefulWidget {
  const ProxyPanel({super.key});

  @override
  ConsumerState<ProxyPanel> createState() => _ProxyPanelState();
}

class _ProxyPanelState extends ConsumerState<ProxyPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(proxyProvider.notifier).loadProxies();
    });
  }

  /// Filter text. Local to the panel — proxies had no search at all before,
  /// so there is no provider-side query to reuse.
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(proxyProvider);

    ref.listen<bool>(
      sidebarSearchVisibleProvider(SidebarSearchPanel.proxies),
      (_, visible) {
        // Hiding the field drops the filter too, so rows never stay missing
        // without a visible reason.
        if (!visible && _query.isNotEmpty) setState(() => _query = '');
      },
    );

    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? state.proxies
        : state.proxies
            .where((p) =>
                p.host.toLowerCase().contains(q) ||
                p.address.toLowerCase().contains(q) ||
                (p.username ?? '').toLowerCase().contains(q) ||
                p.proxyType.name.toLowerCase().contains(q))
            .toList(growable: false);

    return Container(
      color: TermexColors.backgroundPrimary,
      child: Column(
        children: [
          // v0.79.59: the inline "Proxy + Add Proxy" header was removed —
          // the host shell (mobile `_TerminalTabHeader`, desktop sidebar
          // section header) already paints a title bar with a top-right
          // "+" button. Keeping a second header inside the panel
          // duplicated the title and pushed the proxy list down ~50px.
          // Callers that need to open the add dialog imperatively can
          // call [AddProxyDialog.show].
          if (ref.watch(
              sidebarSearchVisibleProvider(SidebarSearchPanel.proxies)))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: ServerSearchBar(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          if (state.error != null) _ErrorBanner(message: state.error!),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : visible.isEmpty
                    ? _EmptyState()
                    : _ProxyList(
                        proxies: visible, testingId: state.testingId),
          ),
        ],
      ),
    );
  }
}

/// Opens the "Add Proxy" dialog. Public so host shells can wire their
/// own top-bar "+" button to it (mobile `_TerminalTabHeader`, desktop
/// sidebar) instead of bundling the trigger inside [ProxyPanel].
class AddProxyDialog {
  AddProxyDialog._();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const _AddProxyDialog(),
    );
  }
}

// ─── Proxy List ───────────────────────────────────────────────────────────────

class _ProxyList extends StatelessWidget {
  final List<ProxyConfig> proxies;
  final String? testingId;

  const _ProxyList({required this.proxies, this.testingId});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: proxies.length,
      itemBuilder: (_, i) => _ProxyRow(
        proxy: proxies[i],
        isTesting: proxies[i].id == testingId,
      ),
    );
  }
}

class _ProxyRow extends ConsumerWidget {
  final ProxyConfig proxy;
  final bool isTesting;

  const _ProxyRow({required this.proxy, required this.isTesting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(proxyProvider.notifier);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: proxy.isDefault
              ? TermexColors.primary.withOpacity(0.5)
              : TermexColors.border,
        ),
      ),
      child: Row(
        children: [
          _TypeBadge(type: proxy.proxyType),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(proxy.address,
                        style: const TextStyle(
                            fontSize: 13,
                            color: TermexColors.textPrimary,
                            fontFamily: 'monospace')),
                    if (proxy.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: TermexColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('Default',
                            style: TextStyle(
                                fontSize: 9,
                                color: TermexColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                if (proxy.username != null)
                  Text('User: ${proxy.username}',
                      style: const TextStyle(
                          fontSize: 11, color: TermexColors.textSecondary)),
              ],
            ),
          ),
          if (isTesting)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: TermexColors.primary),
            )
          else ...[
            if (!proxy.isDefault)
              _SmallBtn(
                label: 'Set Default',
                onTap: () => n.setDefault(proxy.id),
              ),
            const SizedBox(width: 4),
            _SmallBtn(
              label: 'Test',
              onTap: () => n.testConnection(proxy.id),
            ),
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _delete(context, ref),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline,
                    size: 14, color: TermexColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _delete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: const Text('Remove Proxy',
            style: TextStyle(color: TermexColors.textPrimary, fontSize: 14)),
        content: Text(
          'Remove proxy ${proxy.address}?',
          style: const TextStyle(
              color: TermexColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: TermexColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(proxyProvider.notifier).deleteProxy(proxy.id);
            },
            child: const Text('Remove',
                style: TextStyle(color: TermexColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ProxyType type;

  const _TypeBadge({required this.type});

  Color get _color {
    switch (type) {
      case ProxyType.socks5:
        return TermexColors.primary;
      case ProxyType.http:
        return TermexColors.warning;
      case ProxyType.tor:
        return TermexColors.success;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: _color.withOpacity(0.4)),
        ),
        child: Text(
          type.label,
          style: TextStyle(
              fontSize: 10, color: _color, fontWeight: FontWeight.w600),
        ),
      );
}

// ─── Add Proxy Dialog ─────────────────────────────────────────────────────────

class _AddProxyDialog extends ConsumerStatefulWidget {
  const _AddProxyDialog();

  @override
  ConsumerState<_AddProxyDialog> createState() => _AddProxyDialogState();
}

class _AddProxyDialogState extends ConsumerState<_AddProxyDialog> {
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  ProxyType _type = ProxyType.socks5;
  String? _err;
  bool _showPassword = false;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    if (_host.text.trim().isEmpty) {
      setState(() => _err = 'Host is required');
      return;
    }
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() => _err = 'Invalid port');
      return;
    }
    ref.read(proxyProvider.notifier).createProxy(
          proxyType: _type,
          host: _host.text.trim(),
          port: port,
          username: _user.text.trim().isEmpty ? null : _user.text.trim(),
          password: _pass.text.isEmpty ? null : _pass.text,
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TermexColors.backgroundSecondary,
      title: const Text('Add Proxy',
          style: TextStyle(color: TermexColors.textPrimary, fontSize: 14)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Protocol',
                style:
                    TextStyle(fontSize: 11, color: TermexColors.textSecondary)),
            const SizedBox(height: 6),
            // Material DropdownButton overflows the dialog on macOS — only
            // 3 protocols, render them inline as toggle chips instead.
            Row(
              children: ProxyType.values
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _ProtocolChip(
                          label: t.label,
                          active: _type == t,
                          onTap: () => setState(() => _type = t),
                        ),
                      ))
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            _FieldRow(
              label: 'Host',
              child: TextField(
                controller: _host,
                autofocus: true,
                style: const TextStyle(
                    color: TermexColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('127.0.0.1'),
              ),
            ),
            const SizedBox(height: 10),
            _FieldRow(
              label: 'Port',
              child: TextField(
                controller: _port,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                    color: TermexColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('1080'),
              ),
            ),
            const SizedBox(height: 10),
            _FieldRow(
              label: 'Username (optional)',
              child: TextField(
                controller: _user,
                style: const TextStyle(
                    color: TermexColors.textPrimary, fontSize: 13),
                decoration: _inputDeco(''),
              ),
            ),
            const SizedBox(height: 10),
            // Password is optional — SOCKS5/HTTP CONNECT support
            // unauthenticated proxies. When provided the value lands in
            // the OS keychain via `proxyStorePassword`, never in the DB.
            _FieldRow(
              label: 'Password (optional)',
              child: TextField(
                controller: _pass,
                obscureText: !_showPassword,
                style: const TextStyle(
                    color: TermexColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('').copyWith(
                  suffixIcon: Clickable(
                    onTap: () =>
                        setState(() => _showPassword = !_showPassword),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 16,
                        color: TermexColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_err != null) ...[
              const SizedBox(height: 10),
              Text(_err!,
                  style: const TextStyle(
                      fontSize: 11, color: TermexColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: TermexColors.textSecondary)),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Add',
              style: TextStyle(color: TermexColors.primary)),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: TermexColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: TermexColors.border)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: TermexColors.primary)),
      );
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: TermexColors.textSecondary)),
          const SizedBox(height: 4),
          child,
        ],
      );
}

// ─── Protocol picker chip (Add Proxy dialog) ──────────────────────────────────

class _ProtocolChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ProtocolChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Clickable(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? TermexColors.primary.withValues(alpha: 0.12)
                : TermexColors.backgroundTertiary,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: active ? TermexColors.primary : TermexColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: active ? TermexColors.primary : TermexColors.textPrimary,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security, size: 36, color: TermexColors.textMuted),
            const SizedBox(height: 12),
            const Text('No proxies configured',
                style: TextStyle(
                    color: TermexColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _AddProxyDialog(),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Proxy'),
              style: TextButton.styleFrom(foregroundColor: TermexColors.primary),
            ),
          ],
        ),
      );
}

// ─── Shared ───────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: TermexColors.danger.withOpacity(0.15),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 14, color: TermexColors.danger),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12, color: TermexColors.danger))),
        ]),
      );
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SmallBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: TermexColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      );
}
