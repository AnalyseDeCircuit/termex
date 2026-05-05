import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/port_forward_provider.dart';

/// Port-forwarding rules panel — list active tunnels + create new.
class PortForwardPanel extends ConsumerStatefulWidget {
  final String sessionId;

  const PortForwardPanel({super.key, required this.sessionId});

  @override
  ConsumerState<PortForwardPanel> createState() => _PortForwardPanelState();
}

class _PortForwardPanelState extends ConsumerState<PortForwardPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(portForwardProvider.notifier).loadRules(widget.sessionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portForwardProvider);

    return Container(
      color: TermexColors.backgroundPrimary,
      child: Column(
        children: [
          _Header(sessionId: widget.sessionId),
          if (state.error != null)
            _ErrorBanner(message: state.error!),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : state.rules.isEmpty
                    ? _EmptyState(sessionId: widget.sessionId)
                    : _RuleList(rules: state.rules),
          ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String sessionId;

  const _Header({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alt_route, size: 16, color: TermexColors.primary),
          const SizedBox(width: 8),
          const Text('Port Forwarding',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: TermexColors.textPrimary)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _AddRuleDialog(sessionId: sessionId),
            ),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('New Rule', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: TermexColors.primary),
          ),
        ],
      ),
    );
  }
}

// ─── Rule List ────────────────────────────────────────────────────────────────

class _RuleList extends ConsumerWidget {
  final List<ForwardRule> rules;

  const _RuleList({required this.rules});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rules.length,
      itemBuilder: (_, i) => _RuleRow(rule: rules[i]),
    );
  }
}

class _RuleRow extends ConsumerWidget {
  final ForwardRule rule;

  const _RuleRow({required this.rule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: rule.isActive ? TermexColors.success.withOpacity(0.5) : TermexColors.border,
        ),
      ),
      child: Row(
        children: [
          _TypeBadge(type: rule.forwardType),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.summary,
                    style: const TextStyle(
                        fontSize: 12,
                        color: TermexColors.textPrimary,
                        fontFamily: 'monospace')),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: rule.isActive
                            ? TermexColors.success
                            : TermexColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rule.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                          fontSize: 10,
                          color: rule.isActive
                              ? TermexColors.success
                              : TermexColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14,
                color: TermexColors.textSecondary),
            tooltip: 'Stop',
            onPressed: () => ref
                .read(portForwardProvider.notifier)
                .removeRule(rule.id),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ForwardType type;

  const _TypeBadge({required this.type});

  Color get _color {
    switch (type) {
      case ForwardType.local:
        return TermexColors.primary;
      case ForwardType.remote:
        return TermexColors.warning;
      case ForwardType.dynamic:
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
          type.label.split(' ').first, // "Local" / "Remote" / "Dynamic"
          style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w600),
        ),
      );
}

// ─── Add Rule Dialog ──────────────────────────────────────────────────────────

class _AddRuleDialog extends ConsumerStatefulWidget {
  final String sessionId;

  const _AddRuleDialog({required this.sessionId});

  @override
  ConsumerState<_AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends ConsumerState<_AddRuleDialog> {
  final _localPort = TextEditingController();
  final _remoteHost = TextEditingController(text: 'localhost');
  final _remotePort = TextEditingController();
  ForwardType _type = ForwardType.local;
  String? _err;

  @override
  void dispose() {
    _localPort.dispose();
    _remoteHost.dispose();
    _remotePort.dispose();
    super.dispose();
  }

  void _submit() {
    final lp = int.tryParse(_localPort.text.trim());
    final rp = int.tryParse(_remotePort.text.trim());
    if (lp == null || lp < 1 || lp > 65535) {
      setState(() => _err = 'Invalid local port');
      return;
    }
    if (_type != ForwardType.dynamic) {
      if (_remoteHost.text.trim().isEmpty) {
        setState(() => _err = 'Remote host is required');
        return;
      }
      if (rp == null || rp < 1 || rp > 65535) {
        setState(() => _err = 'Invalid remote port');
        return;
      }
    }
    ref.read(portForwardProvider.notifier).addRule(
          sessionId: widget.sessionId,
          forwardType: _type,
          localPort: lp,
          remoteHost: _remoteHost.text.trim(),
          remotePort: rp ?? 0,
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TermexColors.backgroundSecondary,
      title: const Text('New Port Forwarding Rule',
          style: TextStyle(color: TermexColors.textPrimary, fontSize: 14)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type',
                style: TextStyle(fontSize: 11, color: TermexColors.textSecondary)),
            const SizedBox(height: 6),
            SegmentedButton<ForwardType>(
              segments: ForwardType.values
                  .map((t) => ButtonSegment(value: t, label: Text(t.label, style: const TextStyle(fontSize: 11))))
                  .toList(),
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? TermexColors.primary
                      : TermexColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PortField(
              label: 'Local Port',
              controller: _localPort,
              hint: '8080',
            ),
            if (_type != ForwardType.dynamic) ...[
              const SizedBox(height: 12),
              _TextField(
                label: 'Remote Host',
                controller: _remoteHost,
                hint: 'localhost',
              ),
              const SizedBox(height: 12),
              _PortField(
                label: 'Remote Port',
                controller: _remotePort,
                hint: '80',
              ),
            ],
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
          child: const Text('Add Rule',
              style: TextStyle(color: TermexColors.primary)),
        ),
      ],
    );
  }
}

class _PortField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _PortField(
      {required this.label, required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: TermexColors.textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
                color: TermexColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: TermexColors.textMuted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: TermexColors.border)),
              focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: TermexColors.primary)),
            ),
          ),
        ],
      );
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _TextField(
      {required this.label, required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: TermexColors.textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            style: const TextStyle(
                color: TermexColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: TermexColors.textMuted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: TermexColors.border)),
              focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: TermexColors.primary)),
            ),
          ),
        ],
      );
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String sessionId;

  const _EmptyState({required this.sessionId});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alt_route, size: 36, color: TermexColors.textMuted),
            const SizedBox(height: 12),
            const Text('No forwarding rules',
                style: TextStyle(
                    color: TermexColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _AddRuleDialog(sessionId: sessionId),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Rule'),
              style: TextButton.styleFrom(foregroundColor: TermexColors.primary),
            ),
          ],
        ),
      );
}

// ─── Error Banner ─────────────────────────────────────────────────────────────

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
