import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/spacing.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialog.dart';
import '../../../widgets/text_field.dart';
import '../../../widgets/select.dart';
import '../../../widgets/form_validators.dart';
import '../models/server_dto.dart';
import '../state/server_provider.dart';
import '../state/group_provider.dart';

/// Auth type options for the select widget.
const _kAuthTypes = [
  SelectOption(value: 'password', label: 'Password'),
  SelectOption(value: 'key', label: 'SSH Key'),
  SelectOption(value: 'agent', label: 'SSH Agent'),
  SelectOption(value: 'interactive', label: 'Interactive'),
];

/// Dialog for creating or editing a server.
///
/// Pass [editId] to open in edit mode.
class ServerFormDialog extends ConsumerStatefulWidget {
  final String? editId;

  const ServerFormDialog({super.key, this.editId});

  /// Convenience helper — shows the dialog and returns true when saved.
  static Future<bool> show(BuildContext context, {String? editId}) async {
    final result = await showTermexDialog<bool>(
      context: context,
      title: editId == null ? 'Add Server' : 'Edit Server',
      size: DialogSize.medium,
      body: ServerFormDialog(editId: editId),
    );
    return result ?? false;
  }

  @override
  ConsumerState<ServerFormDialog> createState() => _ServerFormDialogState();
}

class _ServerFormDialogState extends ConsumerState<ServerFormDialog> {
  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _keyPathCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String _authType = 'password';
  String? _groupId;
  bool _saving = false;
  String? _portError;

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _keyPathCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _loadExisting() {
    final server = ref.read(serverByIdProvider(widget.editId!));
    if (server == null) return;
    _nameCtrl.text = server.name;
    _hostCtrl.text = server.host;
    _portCtrl.text = server.port.toString();
    _usernameCtrl.text = server.username;
    _keyPathCtrl.text = server.keyPath ?? '';
    _tagsCtrl.text = server.tags.join(', ');
    setState(() {
      _authType = server.authType;
      _groupId = server.groupId;
    });
  }

  bool _validate() {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_hostCtrl.text.trim().isEmpty) return false;
    if (_usernameCtrl.text.trim().isEmpty) return false;
    final port = int.tryParse(_portCtrl.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() => _portError = 'Must be 1–65535');
      return false;
    }
    setState(() => _portError = null);
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final input = ServerInput(
      name: _nameCtrl.text.trim(),
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      username: _usernameCtrl.text.trim(),
      authType: _authType,
      password: _authType == 'password' ? _passwordCtrl.text : null,
      keyPath: _authType == 'key' ? _keyPathCtrl.text.trim() : null,
      groupId: _groupId,
      tags: tags,
    );

    try {
      final notifier = ref.read(serverListProvider.notifier);
      if (widget.editId == null) {
        await notifier.createServer(input);
      } else {
        await notifier.updateServer(widget.editId!, input);
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop(true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupListProvider).valueOrNull ?? [];
    final groupOptions = [
      const SelectOption<String?>(value: null, label: 'None'),
      ...groups.map((g) => SelectOption<String?>(value: g.id, label: g.name)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TermexTextField(
          controller: _nameCtrl,
          label: 'Name',
          placeholder: 'My Production Server',
          validators: [Validators.required(message: 'Name is required')],
        ),
        const SizedBox(height: TermexSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TermexTextField(
                controller: _hostCtrl,
                label: 'Host',
                placeholder: 'example.com',
                validators: [Validators.required(message: 'Host is required')],
              ),
            ),
            const SizedBox(width: TermexSpacing.md),
            SizedBox(
              width: 90,
              child: TermexTextField(
                controller: _portCtrl,
                label: 'Port',
                placeholder: '22',
                keyboardType: TextInputType.number,
                errorText: _portError,
              ),
            ),
          ],
        ),
        const SizedBox(height: TermexSpacing.md),
        TermexTextField(
          controller: _usernameCtrl,
          label: 'Username',
          placeholder: 'root',
          validators: [Validators.required(message: 'Username is required')],
        ),
        const SizedBox(height: TermexSpacing.md),
        _LabeledField(
          label: 'Auth Type',
          child: TermexSelect<String>(
            options: _kAuthTypes,
            value: _authType,
            onChanged: (v) => setState(() => _authType = v),
          ),
        ),
        if (_authType == 'password') ...[
          const SizedBox(height: TermexSpacing.md),
          TermexTextField(
            controller: _passwordCtrl,
            label: 'Password',
            placeholder: '••••••••',
            obscureText: true,
          ),
        ],
        if (_authType == 'key') ...[
          const SizedBox(height: TermexSpacing.md),
          TermexTextField(
            controller: _keyPathCtrl,
            label: 'Key Path',
            placeholder: '~/.ssh/id_rsa',
          ),
        ],
        const SizedBox(height: TermexSpacing.md),
        _LabeledField(
          label: 'Group',
          child: TermexSelect<String?>(
            options: groupOptions,
            value: _groupId,
            onChanged: (v) => setState(() => _groupId = v),
            placeholder: 'None',
          ),
        ),
        const SizedBox(height: TermexSpacing.md),
        TermexTextField(
          controller: _tagsCtrl,
          label: 'Tags',
          placeholder: 'production, linux (comma separated)',
        ),
        const SizedBox(height: TermexSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TermexButton(
              label: 'Cancel',
              variant: ButtonVariant.ghost,
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
            ),
            const SizedBox(width: TermexSpacing.sm),
            TermexButton(
              label: widget.editId == null ? 'Add Server' : 'Save Changes',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ],
    );
  }
}

/// Helper that adds a label above an arbitrary child widget.
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TermexTypography.bodySmall.copyWith(
            color: TermexColors.textSecondary,
          ),
        ),
        const SizedBox(height: TermexSpacing.xs),
        child,
      ],
    );
  }
}
