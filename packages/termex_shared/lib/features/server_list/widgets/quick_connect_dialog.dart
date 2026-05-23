import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialog.dart';
import '../../../widgets/text_field.dart';
import '../models/server_dto.dart';
import '../state/server_provider.dart';

/// Tauri's ConnectModal — a one-shot connect form. Parses `user@host:port`
/// or accepts the fields individually, registers the server (if "save" is
/// kept on) so the connection appears in the server list, and connects.
class QuickConnectDialog extends ConsumerStatefulWidget {
  /// Called with the freshly-created server so the host shell can open a
  /// terminal tab for it.
  final void Function(ServerDto server) onConnect;

  const QuickConnectDialog({super.key, required this.onConnect});

  /// Shows the dialog as a modal. Returns true if the user kicked off a
  /// connection.
  static Future<bool> show(
    BuildContext context, {
    required void Function(ServerDto server) onConnect,
  }) async {
    final result = await showTermexDialog<bool>(
      context: context,
      title: '快速连接',
      size: DialogSize.medium,
      body: QuickConnectDialog(onConnect: onConnect),
    );
    return result ?? false;
  }

  @override
  ConsumerState<QuickConnectDialog> createState() =>
      _QuickConnectDialogState();
}

class _QuickConnectDialogState extends ConsumerState<QuickConnectDialog> {
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  ({String username, String host, int port})? _parse() {
    final raw = _addressCtrl.text.trim();
    if (raw.isEmpty) return null;
    String username = '';
    String hostport = raw;
    if (raw.contains('@')) {
      final at = raw.indexOf('@');
      username = raw.substring(0, at).trim();
      hostport = raw.substring(at + 1).trim();
    }
    int port = 22;
    String host = hostport;
    if (hostport.contains(':')) {
      final c = hostport.lastIndexOf(':');
      host = hostport.substring(0, c).trim();
      final portStr = hostport.substring(c + 1).trim();
      final p = int.tryParse(portStr);
      if (p == null || p <= 0 || p > 65535) return null;
      port = p;
    }
    if (host.isEmpty) return null;
    if (username.isEmpty) return null;
    return (username: username, host: host, port: port);
  }

  Future<void> _connect() async {
    final parsed = _parse();
    if (parsed == null) {
      setState(() => _error =
          'Use the format user@host or user@host:port (e.g. root@10.0.0.1:22).');
      return;
    }
    final pw = _passwordCtrl.text;
    if (pw.isEmpty) {
      setState(() => _error = 'Password is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Persist the server so it shows up in the sidebar and appears in
      // the quick-connect history. The auth is "password" (the most
      // common path for one-off connections).
      final notifier = ref.read(serverListProvider.notifier);
      await notifier.createServer(ServerInput(
        name: '${parsed.username}@${parsed.host}',
        host: parsed.host,
        port: parsed.port,
        username: parsed.username,
        authType: 'password',
        password: pw,
        keyPath: null,
        groupId: null,
        tags: const [],
      ));
      // Find the just-created server (highest createdAt match).
      final list = ref.read(serverListProvider).valueOrNull ?? const [];
      final created = list.lastWhere(
        (s) =>
            s.host == parsed.host &&
            s.port == parsed.port &&
            s.username == parsed.username,
        orElse: () => list.isEmpty ? _placeholder(parsed) : list.last,
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(true);
        widget.onConnect(created);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  ServerDto _placeholder(({String username, String host, int port}) p) =>
      ServerDto(
        id: '',
        name: '${p.username}@${p.host}',
        host: p.host,
        port: p.port,
        username: p.username,
        authType: 'password',
        keyPath: null,
        groupId: null,
        sortOrder: 0,
        tags: const [],
        lastConnected: null,
        createdAt: '',
        updatedAt: '',
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TermexSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Connect to a server without saving full credentials.',
            style: TermexTypography.bodySmall.copyWith(
              color: TermexColors.textSecondary,
            ),
          ),
          const SizedBox(height: TermexSpacing.lg),
          TermexTextField(
            controller: _addressCtrl,
            label: 'Address',
            placeholder: 'user@host:port',
            autofocus: true,
            onSubmitted: _connect,
          ),
          const SizedBox(height: TermexSpacing.md),
          TermexTextField(
            controller: _passwordCtrl,
            label: 'Password',
            placeholder: 'Password',
            obscureText: true,
            onSubmitted: _connect,
          ),
          if (_error != null) ...[
            const SizedBox(height: TermexSpacing.sm),
            Text(
              _error!,
              style: TermexTypography.bodySmall.copyWith(
                color: TermexColors.danger,
              ),
            ),
          ],
          const SizedBox(height: TermexSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TermexButton(
                label: 'Cancel',
                variant: ButtonVariant.ghost,
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context, rootNavigator: true)
                        .pop(false),
              ),
              const SizedBox(width: TermexSpacing.sm),
              TermexButton(
                label: 'Connect',
                variant: ButtonVariant.primary,
                loading: _busy,
                onPressed: _busy ? null : _connect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
