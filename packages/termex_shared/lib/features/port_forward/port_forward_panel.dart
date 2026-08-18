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

enum _ForwardSort { type, localPort, remote, status }

class _PortForwardPanelState extends ConsumerState<PortForwardPanel> {
  String _query = '';
  _ForwardSort _sort = _ForwardSort.type;
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(portForwardProvider.notifier).loadRules(widget.sessionId);
    });
  }

  List<ForwardRule> _applyFilter(List<ForwardRule> rules) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? rules.toList()
        : rules.where((r) {
            if (r.summary.toLowerCase().contains(q)) return true;
            if (r.remoteHost.toLowerCase().contains(q)) return true;
            if (r.localPort.toString().contains(q)) return true;
            if (r.remotePort.toString().contains(q)) return true;
            if (r.forwardType.label.toLowerCase().contains(q)) return true;
            return false;
          }).toList();
    filtered.sort((a, b) {
      int cmp;
      switch (_sort) {
        case _ForwardSort.type:
          cmp = a.forwardType.index.compareTo(b.forwardType.index);
          break;
        case _ForwardSort.localPort:
          cmp = a.localPort.compareTo(b.localPort);
          break;
        case _ForwardSort.remote:
          cmp = '${a.remoteHost}:${a.remotePort}'
              .compareTo('${b.remoteHost}:${b.remotePort}');
          break;
        case _ForwardSort.status:
          cmp = (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0);
          break;
      }
      return _ascending ? cmp : -cmp;
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portForwardProvider);
    final visible = _applyFilter(state.rules);

    return Container(
      color: context.colors.backgroundPrimary,
      child: Column(
        children: [
          _Header(sessionId: widget.sessionId),
          if (state.rules.isNotEmpty)
            _SearchSortBar(
              query: _query,
              sort: _sort,
              ascending: _ascending,
              onQueryChanged: (v) => setState(() => _query = v),
              onSortChanged: (s) => setState(() {
                if (_sort == s) {
                  _ascending = !_ascending;
                } else {
                  _sort = s;
                  _ascending = true;
                }
              }),
            ),
          if (state.error != null) _ErrorBanner(message: state.error!),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : state.rules.isEmpty
                    ? _EmptyState(sessionId: widget.sessionId)
                    : visible.isEmpty
                        ? Center(
                            child: Text('No rules match search',
                                style: TextStyle(
                                    color: context.colors.textMuted,
                                    fontSize: 12)))
                        : _RuleList(rules: visible),
          ),
        ],
      ),
    );
  }
}

class _SearchSortBar extends StatelessWidget {
  final String query;
  final _ForwardSort sort;
  final bool ascending;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_ForwardSort> onSortChanged;

  const _SearchSortBar({
    required this.query,
    required this.sort,
    required this.ascending,
    required this.onQueryChanged,
    required this.onSortChanged,
  });

  String _label(_ForwardSort s) => switch (s) {
        _ForwardSort.type => 'Type',
        _ForwardSort.localPort => 'Local Port',
        _ForwardSort.remote => 'Remote',
        _ForwardSort.status => 'Status',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 28,
              child: TextField(
                onChanged: onQueryChanged,
                style: TextStyle(
                    fontSize: 12, color: context.colors.textPrimary),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search,
                      size: 14, color: context.colors.textMuted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 28, minHeight: 20),
                  hintText: 'Search rules',
                  hintStyle: TextStyle(
                      fontSize: 12, color: context.colors.textMuted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  isDense: true,
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: context.colors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: context.colors.primary)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<_ForwardSort>(
            tooltip: 'Sort by',
            initialValue: sort,
            onSelected: onSortChanged,
            itemBuilder: (_) => _ForwardSort.values
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Icon(
                            s == sort
                                ? (ascending
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward)
                                : Icons.sort,
                            size: 12,
                            color: s == sort
                                ? context.colors.primary
                                : context.colors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(_label(s),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ))
                .toList(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12, color: context.colors.textSecondary),
                  const SizedBox(width: 4),
                  Text(_label(sort),
                      style: TextStyle(
                          fontSize: 12, color: context.colors.textPrimary)),
                ],
              ),
            ),
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
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.alt_route, size: 16, color: context.colors.primary),
          const SizedBox(width: 8),
          Text('Port Forwarding',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _AddRuleDialog(sessionId: sessionId),
            ),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('New Rule', style: TextStyle(fontSize: 12)),
            style:
                TextButton.styleFrom(foregroundColor: context.colors.primary),
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
        color: context.colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: rule.isActive ? context.colors.success.withOpacity(0.5) : context.colors.border,
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
                    style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textPrimary,
                        fontFamily: 'monospace')),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: rule.isActive
                            ? context.colors.success
                            : context.colors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rule.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                          fontSize: 10,
                          color: rule.isActive
                              ? context.colors.success
                              : context.colors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 14,
                color: context.colors.textSecondary),
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

  Color _colorOf(TermexColorScheme colors) {
    switch (type) {
      case ForwardType.local:
        return colors.primary;
      case ForwardType.remote:
        return colors.warning;
      case ForwardType.dynamic:
        return colors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(context.colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        type.label.split(' ').first, // "Local" / "Remote" / "Dynamic"
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
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
      backgroundColor: context.colors.backgroundSecondary,
      title: Text('New Port Forwarding Rule',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 14)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type',
                style: TextStyle(
                    fontSize: 11, color: context.colors.textSecondary)),
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
                      ? context.colors.primary
                      : context.colors.textSecondary,
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
                  style: TextStyle(
                      fontSize: 11, color: context.colors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: context.colors.textSecondary)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Add Rule',
              style: TextStyle(color: context.colors.primary)),
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
              style: TextStyle(
                  fontSize: 11, color: context.colors.textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
                color: context.colors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: context.colors.textMuted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.colors.border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.colors.primary)),
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
              style: TextStyle(
                  fontSize: 11, color: context.colors.textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            style: TextStyle(
                color: context.colors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: context.colors.textMuted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.colors.border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.colors.primary)),
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
            Icon(Icons.alt_route, size: 36, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text('No forwarding rules',
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _AddRuleDialog(sessionId: sessionId),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Rule'),
              style: TextButton.styleFrom(
                  foregroundColor: context.colors.primary),
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
        color: context.colors.danger.withOpacity(0.15),
        child: Row(children: [
          Icon(Icons.error_outline, size: 14, color: context.colors.danger),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                      fontSize: 12, color: context.colors.danger))),
        ]),
      );
}
