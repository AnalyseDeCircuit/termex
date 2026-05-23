/// Modal sheet for dispatching a new task — server + AI CLI + prompt.
///
/// v0.72.0 ships the keyboard path only. v0.72.2 adds a voice-input
/// widget that swaps in as the default.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../model/task_view_model.dart';

class AssignTaskRequest {
  final String serverId;
  final AiCliKind aiCli;
  final String prompt;

  const AssignTaskRequest({
    required this.serverId,
    required this.aiCli,
    required this.prompt,
  });
}

class ServerOption {
  final String id;
  final String name;
  const ServerOption({required this.id, required this.name});
}

typedef AssignSubmit = Future<void> Function(AssignTaskRequest);

class AssignTaskSheet extends StatefulWidget {
  final List<ServerOption> servers;
  final AssignSubmit onSubmit;
  final String? initialServerId;
  final AiCliKind initialAiCli;

  const AssignTaskSheet({
    super.key,
    required this.servers,
    required this.onSubmit,
    this.initialServerId,
    this.initialAiCli = AiCliKind.claudeCode,
  });

  @override
  State<AssignTaskSheet> createState() => _AssignTaskSheetState();
}

class _AssignTaskSheetState extends State<AssignTaskSheet> {
  late String? _serverId;
  late AiCliKind _aiCli;
  final TextEditingController _prompt = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _serverId = widget.initialServerId ?? widget.servers.firstOrNull?.id;
    _aiCli = widget.initialAiCli;
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _serverId != null && _prompt.text.trim().isNotEmpty && !_busy;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(AssignTaskRequest(
        serverId: _serverId!,
        aiCli: _aiCli,
        prompt: _prompt.text.trim(),
      ));
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.lg),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: TermexColors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Assign task',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: TermexSpacing.md),
          _ServerPicker(
            servers: widget.servers,
            selected: _serverId,
            onSelect: (id) => setState(() => _serverId = id),
          ),
          const SizedBox(height: TermexSpacing.md),
          _AiCliPicker(
            value: _aiCli,
            onChange: (k) => setState(() => _aiCli = k),
          ),
          const SizedBox(height: TermexSpacing.md),
          _PromptField(
            controller: _prompt,
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: TermexSpacing.sm),
            Text(
              _error!,
              style: TermexTypography.caption.copyWith(
                color: TermexColors.danger,
              ),
            ),
          ],
          const SizedBox(height: TermexSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _busy ? null : () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TermexSpacing.md,
                    vertical: TermexSpacing.sm,
                  ),
                  child: Text(
                    'Cancel',
                    style: TermexTypography.body.copyWith(
                      color: TermexColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TermexSpacing.sm),
              GestureDetector(
                onTap: _canSubmit ? _submit : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TermexSpacing.lg,
                    vertical: TermexSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: _canSubmit
                        ? TermexColors.primary
                        : TermexColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _busy ? 'Submitting…' : 'Assign ▶',
                    style: TermexTypography.body.copyWith(
                      color: TermexColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServerPicker extends StatelessWidget {
  final List<ServerOption> servers;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ServerPicker({
    required this.servers,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Server',
          style: TermexTypography.caption.copyWith(
            color: TermexColors.textSecondary,
          ),
        ),
        const SizedBox(height: TermexSpacing.xs),
        Wrap(
          spacing: TermexSpacing.sm,
          runSpacing: TermexSpacing.xs,
          children: servers.map((s) {
            final active = s.id == selected;
            return GestureDetector(
              onTap: () => onSelect(s.id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TermexSpacing.md,
                  vertical: TermexSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? TermexColors.primary.withValues(alpha: 0.2)
                      : TermexColors.backgroundTertiary,
                  border: Border.all(
                    color: active ? TermexColors.primary : TermexColors.border,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.name,
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AiCliPicker extends StatelessWidget {
  final AiCliKind value;
  final ValueChanged<AiCliKind> onChange;

  const _AiCliPicker({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'AI CLI',
          style: TermexTypography.caption.copyWith(
            color: TermexColors.textSecondary,
          ),
        ),
        const SizedBox(height: TermexSpacing.xs),
        Wrap(
          spacing: TermexSpacing.sm,
          runSpacing: TermexSpacing.xs,
          children: AiCliKind.values.map((k) {
            final active = k == value;
            return GestureDetector(
              onTap: () => onChange(k),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TermexSpacing.md,
                  vertical: TermexSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? TermexColors.primary.withValues(alpha: 0.2)
                      : TermexColors.backgroundTertiary,
                  border: Border.all(
                    color: active ? TermexColors.primary : TermexColors.border,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  k.displayName,
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PromptField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _PromptField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Prompt',
          style: TermexTypography.caption.copyWith(
            color: TermexColors.textSecondary,
          ),
        ),
        const SizedBox(height: TermexSpacing.xs),
        Container(
          padding: const EdgeInsets.all(TermexSpacing.sm),
          decoration: BoxDecoration(
            color: TermexColors.backgroundTertiary,
            border: Border.all(color: TermexColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: EditableText(
            controller: controller,
            onChanged: onChanged,
            focusNode: FocusNode(),
            style: TermexTypography.monospace.copyWith(
              color: TermexColors.textPrimary,
              fontSize: 14,
            ),
            cursorColor: TermexColors.primary,
            backgroundCursorColor: TermexColors.textMuted,
            maxLines: 6,
            minLines: 3,
          ),
        ),
      ],
    );
  }
}
