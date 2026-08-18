import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
// ignore: implementation_imports
import 'package:termex_bridge/api.dart' as frb;

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/button.dart';
import '../../../widgets/checkbox.dart';
import '../../../widgets/clickable.dart';
import '../../../widgets/dialog.dart';
import '../../../widgets/divider.dart';
import '../../../widgets/text_field.dart';
import '../../../widgets/select.dart';
import '../../../widgets/form_validators.dart';
import '../../port_forward/port_forward_panel.dart';
import '../../proxy/state/proxy_provider.dart' as proxy_state;
import '../models/server_dto.dart';
import '../state/server_provider.dart';
import '../state/group_provider.dart';

/// Builds the localized auth-type dropdown options. Called from the form
/// body — the const list it replaced bound English labels at build time
/// and couldn't be translated.
List<SelectOption<String>> _authTypeOptions(AppLocalizations l10n) => [
      SelectOption(value: 'password', label: l10n.connectionAuthTypePassword),
      SelectOption(value: 'key', label: l10n.connectionAuthTypeKey),
      SelectOption(value: 'agent', label: l10n.connectionSshAgent),
      SelectOption(value: 'interactive', label: l10n.connectionAuthTypeInteractive),
    ];

/// Tabs within the form. Mirrors legacy PC `ConnectModal.vue` 4-tab layout.
/// On mobile the `sync` and `forwarding` tabs may render as no-ops or be
/// hidden; the desktop ServerForm uses all four.
enum _FormTab { auth, chain, sync, forwarding }

/// Toggle between providing a private key as a file path or by pasting the
/// raw content into the form. Paste mode is persisted by writing the bytes
/// to `<appSupport>/keys/` and storing that managed path.
enum _KeySource { path, paste }

/// Dialog for creating or editing a server.
///
/// Pass [editId] to open in edit mode.
class ServerFormDialog extends ConsumerStatefulWidget {
  final String? editId;

  const ServerFormDialog({super.key, this.editId});

  /// Convenience helper — shows the dialog and returns true when saved.
  static Future<bool> show(BuildContext context, {String? editId}) async {
    final l10n = AppLocalizations.of(context);
    final result = await showTermexDialog<bool>(
      context: context,
      title: editId == null
          ? l10n.connectionAddServer
          : l10n.connectionEditServer,
      size: DialogSize.medium,
      body: ServerFormDialog(editId: editId),
    );
    return result ?? false;
  }

  @override
  ConsumerState<ServerFormDialog> createState() => _ServerFormDialogState();
}

class _ServerFormDialogState extends ConsumerState<ServerFormDialog> {
  /// Rebuild hook for the tab bodies, which are separate widgets holding a
  /// reference to this state. They used to call `state.setState` directly —
  /// setState is protected, and reaching across the class boundary for it is
  /// what the analyzer was flagging.
  void rebuild(VoidCallback fn) => setState(fn);

  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passphraseCtrl = TextEditingController();
  final _keyPathCtrl = TextEditingController();
  final _keyDataCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _gitSyncRemoteCtrl = TextEditingController();
  final _gitSyncLocalCtrl = TextEditingController();

  String _authType = 'password';
  _KeySource _keySource = _KeySource.path;
  String? _groupId;
  bool _saving = false;
  bool _testing = false;
  String? _portError;
  ({bool ok, String message})? _testResult;

  _FormTab _tab = _FormTab.auth;


  String? _bastionId;
  String? _proxyId;

  // v0.79.67 — sync tab state. Defaults mirror the SQL column defaults
  // (migration v8). `_shared` is loaded from ServerDto on edit; switching
  // it triggers `teamShareServer / teamUnshareServer` on save (Phase D).
  String _tmuxMode = 'disabled';
  String _tmuxCloseAction = 'detach';
  bool _gitSyncEnabled = false;
  // Auto-record lives on its own bridge accessors rather than ServerDto —
  // no list view surfaces it, so it is loaded and saved separately.
  bool _autoRecord = false;
  final _maxRecordingMbCtrl = TextEditingController(text: '50');
  String _gitSyncMode = 'notify';
  bool _shared = false;
  bool _initialShared = false;

  @override
  void initState() {
    super.initState();
    // Proxy list isn't auto-loaded by the notifier on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(proxy_state.proxyProvider.notifier).loadProxies();
    });
    if (widget.editId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  @override
  void dispose() {
    _maxRecordingMbCtrl.dispose();
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _passphraseCtrl.dispose();
    _keyPathCtrl.dispose();
    _keyDataCtrl.dispose();
    _tagsCtrl.dispose();
    _gitSyncRemoteCtrl.dispose();
    _gitSyncLocalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final server = ref.read(serverByIdProvider(widget.editId!));
    if (server != null) {
      _nameCtrl.text = server.name;
      _hostCtrl.text = server.host;
      _portCtrl.text = server.port.toString();
      _usernameCtrl.text = server.username;
      _keyPathCtrl.text = server.keyPath ?? '';
      _tagsCtrl.text = server.tags.join(', ');
      _gitSyncRemoteCtrl.text = server.gitSyncRemotePath ?? '';
      _gitSyncLocalCtrl.text = server.gitSyncLocalPath ?? '';
      setState(() {
        _authType = server.authType;
        _groupId = server.groupId;
        _tmuxMode = server.tmuxMode;
        _tmuxCloseAction = server.tmuxCloseAction;
        _gitSyncEnabled = server.gitSyncEnabled;
        _loadAutoRecord(server.id);
        _gitSyncMode = server.gitSyncMode;
        _shared = server.shared;
        _initialShared = server.shared;
      });
    }
    // Load the persisted chain so Tab 2 reflects what's already saved.
    try {
      final hops =
          await frb.chainListForServer(serverId: widget.editId!);
      String? bastion;
      String? proxy;
      for (final h in hops.where((h) => h.phase == 'pre')) {
        if (h.hopType == 'ssh' && bastion == null) bastion = h.hopId;
        if (h.hopType == 'proxy' && proxy == null) proxy = h.hopId;
      }
      if (mounted) {
        setState(() {
          _bastionId = bastion;
          _proxyId = proxy;
        });
      }
    } catch (_) {
      // Best-effort: a missing chain just means direct connect.
    }
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

  /// v0.79.47: opens the platform file picker so the user can pick a
  /// private key file instead of typing the path. The selected absolute
  /// path is written back into [_keyPathCtrl]. Silently no-ops if the
  /// user cancels or the picker reports no path (e.g. iOS sandbox copy
  /// failure — file_picker copies the file into the app sandbox and
  /// returns the copy's path).
  Future<void> _pickKeyFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null) return;
      final picked = result.files.singleOrNull?.path;
      if (picked == null || picked.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _keyPathCtrl.text = picked;
      });
    } catch (_) {
      // Best-effort: failures (permission denied, plugin error on
      // weird platforms) leave the existing path untouched. The user
      // can always type manually.
    }
  }

  /// Writes pasted key content to `<appSupport>/keys/<name>.key` with `0600`
  /// perms and returns the absolute path. Throws if the dir cannot be
  /// created or the file cannot be written.
  Future<String> _persistPastedKey(String content) async {
    final base = await getApplicationSupportDirectory();
    final keysDir = Directory('${base.path}/keys');
    if (!keysDir.existsSync()) {
      keysDir.createSync(recursive: true);
    }
    final stem =
        _nameCtrl.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = stem.isEmpty ? 'key_$stamp.pem' : '${stem}_$stamp.pem';
    final file = File('${keysDir.path}/$fileName');
    await file.writeAsString(content, flush: true);
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', file.path]);
      } catch (_) {
        // Non-fatal — file is still written; SSH may still accept it.
      }
    }
    return file.path;
  }

  Future<void> _test() async {
    if (!_validate()) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    String? keyPath;
    String? keyData;
    if (_authType == 'key') {
      if (_keySource == _KeySource.paste) {
        keyData = _keyDataCtrl.text;
      } else {
        keyPath = _keyPathCtrl.text.trim();
      }
    }
    final l10n = AppLocalizations.of(context);
    try {
      await frb.testSshConnection(
        params: frb.SshConnectionTestParams(
          host: _hostCtrl.text.trim(),
          port: int.parse(_portCtrl.text.trim()),
          username: _usernameCtrl.text.trim(),
          authType: _authType,
          password: _authType == 'password' ? _passwordCtrl.text : null,
          keyPath: keyPath,
          keyData: keyData,
          // v0.79.66: in Edit mode the password / passphrase fields stay
          // blank because we never seed secrets into the UI from the OS
          // keychain. Pass the server id so Rust can fall back to the
          // saved keychain credential when the user just wants to test
          // the existing creds without re-typing them.
          existingServerId: widget.editId,
        ),
      );
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = (ok: true, message: l10n.connectionTestSuccess);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult =
              (ok: false, message: '${l10n.connectionTestFailed}: $e');
        });
      }
    }
  }

  /// Builds the chain hop list to persist alongside the server. Position
  /// order: network proxy first, then SSH bastion — matches PC chain engine
  /// expectations (proxy is the outermost transport).
  List<frb.ChainHopInputDto> _buildChainHops() {
    final hops = <frb.ChainHopInputDto>[];
    if (_proxyId != null) {
      hops.add(frb.ChainHopInputDto(
        hopType: 'proxy',
        hopId: _proxyId!,
        phase: 'pre',
      ));
    }
    if (_bastionId != null) {
      hops.add(frb.ChainHopInputDto(
        hopType: 'ssh',
        hopId: _bastionId!,
        phase: 'pre',
      ));
    }
    return hops;
  }

  /// Reads the per-server auto-record settings, which live outside ServerDto.
  Future<void> _loadAutoRecord(String serverId) async {
    try {
      final cfg = await frb.getAutoRecord(serverId: serverId);
      if (!mounted) return;
      setState(() {
        _autoRecord = cfg.enabled;
        _maxRecordingMbCtrl.text = cfg.maxRecordingMb.toString();
      });
    } catch (_) {
      // Legacy row or locked DB — leave the defaults.
    }
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    String? keyPath;
    if (_authType == 'key') {
      if (_keySource == _KeySource.paste &&
          _keyDataCtrl.text.trim().isNotEmpty) {
        try {
          keyPath = await _persistPastedKey(_keyDataCtrl.text);
        } catch (e) {
          if (mounted) {
            setState(() {
              _saving = false;
              _testResult = (ok: false, message: e.toString());
            });
          }
          return;
        }
      } else {
        keyPath = _keyPathCtrl.text.trim();
      }
    }

    final input = ServerInput(
      name: _nameCtrl.text.trim(),
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      username: _usernameCtrl.text.trim(),
      authType: _authType,
      password: _authType == 'password' ? _passwordCtrl.text : null,
      // Send the passphrase only in key mode. Empty string is treated by
      // the Rust side as "leave existing keychain entry untouched".
      passphrase: _authType == 'key' ? _passphraseCtrl.text : null,
      keyPath: keyPath,
      groupId: _groupId,
      tags: tags,
      tmuxMode: _tmuxMode,
      tmuxCloseAction: _tmuxCloseAction,
      gitSyncEnabled: _gitSyncEnabled,
      gitSyncRemotePath: _gitSyncRemoteCtrl.text.trim().isEmpty
          ? null
          : _gitSyncRemoteCtrl.text.trim(),
      gitSyncLocalPath: _gitSyncLocalCtrl.text.trim().isEmpty
          ? null
          : _gitSyncLocalCtrl.text.trim(),
      gitSyncMode: _gitSyncMode,
    );

    try {
      final notifier = ref.read(serverListProvider.notifier);
      final String serverId;
      if (widget.editId == null) {
        serverId = await notifier.createServer(input);
      } else {
        serverId = widget.editId!;
        await notifier.updateServer(serverId, input);
      }
      // Auto-record settings, persisted after the row exists so a newly
      // created server has an id to attach them to.
      try {
        await frb.setAutoRecord(
          serverId: serverId,
          enabled: _autoRecord,
          maxRecordingMb:
              int.tryParse(_maxRecordingMbCtrl.text.trim()) ?? 50,
        );
      } catch (_) {
        // Non-fatal: the server itself is saved.
      }
      // Persist chain on top of the saved server — empty list clears.
      try {
        await frb.chainSaveForServer(
          serverId: serverId,
          hops: _buildChainHops(),
        );
      } catch (_) {
        // Server is saved either way; chain failure is non-fatal.
      }
      // Reconcile the team-share state. We only fire the bridge call when
      // the user changed the toggle — repeat calls would either no-op or
      // surface a "not in a team" error to a user who never touched the
      // switch.
      if (_shared != _initialShared) {
        try {
          if (_shared) {
            await frb.teamShareServer(serverId: serverId);
          } else {
            await frb.teamUnshareServer(serverId: serverId);
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _saving = false;
              _testResult = (ok: false, message: e.toString());
            });
          }
          return;
        }
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop(true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormTabBar(
          value: _tab,
          onChanged: (v) => setState(() => _tab = v),
          authLabel: l10n.connectionAuthorizationInfo,
          chainLabel:
              '${l10n.connectionSshTunnel} + ${l10n.connectionProxy}',
          syncLabel: l10n.connectionSync,
          forwardingLabel: l10n.connectionForwarding,
          // Port-forwarding requires an existing server id; Tauri's
          // ConnectModal disables the tab in Add mode for the same reason.
          forwardingDisabled: widget.editId == null,
        ),
        const SizedBox(height: TermexSpacing.md),
        if (_tab == _FormTab.auth)
          _AuthTabBody(state: this, l10n: l10n)
        else if (_tab == _FormTab.chain)
          _ChainTabBody(state: this, l10n: l10n)
        else if (_tab == _FormTab.sync)
          _SyncTabBody(state: this, l10n: l10n)
        else
          _ForwardingTabBody(state: this, l10n: l10n),
        if (_testResult != null || _testing) ...[
          const SizedBox(height: TermexSpacing.md),
          _TestStatus(
            testing: _testing,
            result: _testResult,
            testingText: l10n.connectionTesting,
          ),
        ],
        const SizedBox(height: TermexSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TermexButton(
              label: l10n.commonCancel,
              variant: ButtonVariant.ghost,
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
            ),
            const SizedBox(width: TermexSpacing.sm),
            TermexButton(
              label: l10n.connectionTest,
              variant: ButtonVariant.secondary,
              loading: _testing,
              onPressed: _test,
            ),
            const SizedBox(width: TermexSpacing.sm),
            TermexButton(
              label: widget.editId == null
                  ? l10n.connectionAddServer
                  : l10n.commonSave,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Tab bar ─────────────────────────────────────────────────────────────────

class _FormTabBar extends StatelessWidget {
  const _FormTabBar({
    required this.value,
    required this.onChanged,
    required this.authLabel,
    required this.chainLabel,
    required this.syncLabel,
    required this.forwardingLabel,
    this.forwardingDisabled = false,
  });

  final _FormTab value;
  final ValueChanged<_FormTab> onChanged;
  final String authLabel;
  final String chainLabel;
  final String syncLabel;
  final String forwardingLabel;
  final bool forwardingDisabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.border),
        ),
      ),
      child: Row(
        children: [
          _tab(context, authLabel, _FormTab.auth),
          _tab(context, chainLabel, _FormTab.chain),
          _tab(context, syncLabel, _FormTab.sync),
          _tab(context, forwardingLabel, _FormTab.forwarding,
              disabled: forwardingDisabled),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, _FormTab tab,
      {bool disabled = false}) {
    final active = value == tab;
    return Clickable(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : () => onChanged(tab),
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active && !disabled
                    ? context.colors.primary
                    : kTransparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TermexTypography.body.copyWith(
              color: disabled
                  ? context.colors.textMuted
                  : active
                      ? context.colors.primary
                      : context.colors.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// Convenience — `Colors.transparent` lives in material/, but the dialog
// stays in widgets/. Inline the value to keep this file Material-free.
const Color kTransparent = Color(0x00000000);

// ─── Tab body: Auth ──────────────────────────────────────────────────────────

class _AuthTabBody extends ConsumerWidget {
  const _AuthTabBody({required this.state, required this.l10n});

  final _ServerFormDialogState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          controller: state._nameCtrl,
          label: l10n.connectionName,
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
                controller: state._hostCtrl,
                label: l10n.connectionHost,
                placeholder: 'example.com',
                validators: [
                  Validators.required(message: 'Host is required'),
                ],
              ),
            ),
            const SizedBox(width: TermexSpacing.md),
            SizedBox(
              width: 90,
              child: TermexTextField(
                controller: state._portCtrl,
                label: l10n.connectionPort,
                placeholder: '22',
                keyboardType: TextInputType.number,
                errorText: state._portError,
              ),
            ),
          ],
        ),
        const SizedBox(height: TermexSpacing.md),
        TermexTextField(
          controller: state._usernameCtrl,
          label: l10n.connectionUsername,
          placeholder: 'root',
          validators: [Validators.required(message: 'Username is required')],
        ),
        const SizedBox(height: TermexSpacing.md),
        _LabeledField(
          label: l10n.connectionAuthType,
          child: TermexSelect<String>(
            options: _authTypeOptions(l10n),
            value: state._authType,
            onChanged: (v) => state.rebuild(() => state._authType = v),
          ),
        ),
        if (state._authType == 'password') ...[
          const SizedBox(height: TermexSpacing.md),
          TermexTextField(
            controller: state._passwordCtrl,
            label: l10n.connectionPassword,
            placeholder: '••••••••',
            obscureText: true,
          ),
        ],
        if (state._authType == 'key') ...[
          const SizedBox(height: TermexSpacing.md),
          _KeySourceTabs(
            value: state._keySource,
            onChanged: (v) => state.rebuild(() => state._keySource = v),
            pathLabel: l10n.connectionKeySourcePath,
            pasteLabel: l10n.connectionKeySourcePaste,
          ),
          const SizedBox(height: TermexSpacing.sm),
          if (state._keySource == _KeySource.path)
            TermexTextField(
              controller: state._keyPathCtrl,
              label: l10n.connectionPrivateKey,
              placeholder: '~/.ssh/id_rsa',
              // v0.79.47: tap-to-pick file. Saves 30+ char manual typing
              // on mobile keyboards. file_picker copies the file into
              // the app sandbox on iOS (sandboxing) and returns that
              // copy's path — we pass it straight to keychain SSH auth.
              trailing: Clickable(
                behavior: HitTestBehavior.opaque,
                onTap: state._pickKeyFile,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    l10n.connectionBrowseKey,
                    style: TermexTypography.bodySmall.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          else
            TermexTextField(
              controller: state._keyDataCtrl,
              label: l10n.connectionKeyContent,
              placeholder: l10n.connectionKeyContentPlaceholder,
              maxLines: 6,
            ),
          const SizedBox(height: TermexSpacing.md),
          // v0.79.67 §B.4: empty passphrase = "do not change" in edit mode.
          TermexTextField(
            controller: state._passphraseCtrl,
            label: l10n.connectionPassphrase,
            obscureText: true,
          ),
        ],
        const SizedBox(height: TermexSpacing.md),
        _LabeledField(
          label: l10n.connectionGroup,
          child: TermexSelect<String?>(
            options: groupOptions,
            value: state._groupId,
            onChanged: (v) => state.rebuild(() => state._groupId = v),
            placeholder: l10n.connectionGroupNone,
          ),
        ),
        const SizedBox(height: TermexSpacing.md),
        TermexTextField(
          controller: state._tagsCtrl,
          label: l10n.connectionTags,
          placeholder: l10n.connectionTagsHint,
        ),
      ],
    );
  }
}

// ─── Tab body: Chain (bastion + proxy) ───────────────────────────────────────

class _ChainTabBody extends ConsumerWidget {
  const _ChainTabBody({required this.state, required this.l10n});

  final _ServerFormDialogState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serverListProvider).valueOrNull ?? [];
    final proxies = ref.watch(proxy_state.proxyProvider).proxies;

    final bastionOptions = <SelectOption<String?>>[
      SelectOption<String?>(
        value: null,
        label: l10n.connectionNoProxyConfigured,
      ),
      // Exclude the server being edited so a server can't bastion itself.
      ...servers
          .where((s) => s.id != state.widget.editId)
          .map((s) => SelectOption<String?>(
                value: s.id,
                label: '${s.name} (${s.username}@${s.host})',
              )),
    ];

    final proxyOptions = <SelectOption<String?>>[
      SelectOption<String?>(
        value: null,
        label: l10n.connectionProxyNone,
      ),
      ...proxies.map((p) => SelectOption<String?>(
            value: p.id,
            label: '${p.proxyType.label} — ${p.address}',
          )),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabeledField(
          label: l10n.connectionBastion,
          child: TermexSelect<String?>(
            options: bastionOptions,
            value: state._bastionId,
            onChanged: (v) => state.rebuild(() => state._bastionId = v),
            placeholder: l10n.connectionNoProxyConfigured,
          ),
        ),
        const SizedBox(height: TermexSpacing.xs),
        Text(
          l10n.connectionBastionHint,
          style: TermexTypography.caption.copyWith(
            color: context.colors.textMuted,
          ),
        ),
        const SizedBox(height: TermexSpacing.lg),
        _LabeledField(
          label: l10n.connectionNetworkProxy,
          child: TermexSelect<String?>(
            options: proxyOptions,
            value: state._proxyId,
            onChanged: (v) => state.rebuild(() => state._proxyId = v),
            placeholder: l10n.connectionProxyNone,
          ),
        ),
        const SizedBox(height: TermexSpacing.xs),
        Text(
          l10n.connectionNetworkProxyHint,
          style: TermexTypography.caption.copyWith(
            color: context.colors.textMuted,
          ),
        ),
        // Connection-path preview — only renders when the chain actually
        // contains a non-target hop (proxy or bastion). Mirrors the legacy
        // ConnectModal's "Connection Path" footer bar.
        if (state._proxyId != null || state._bastionId != null) ...[
          const SizedBox(height: TermexSpacing.lg),
          _ConnectionPathBar(
            label: l10n.connectionConnectionPath,
            proxyName: state._proxyId == null
                ? null
                : proxies
                    .firstWhere(
                      (p) => p.id == state._proxyId,
                      orElse: () => proxies.first,
                    )
                    .address,
            bastionName: state._bastionId == null
                ? null
                : servers
                    .firstWhere(
                      (s) => s.id == state._bastionId,
                      orElse: () => servers.first,
                    )
                    .name,
            targetName: state._nameCtrl.text.trim().isEmpty
                ? state._hostCtrl.text.trim()
                : state._nameCtrl.text.trim(),
          ),
        ],
      ],
    );
  }
}

/// Renders "Client → [proxy] → [bastion] → Target" inline as a chip row.
class _ConnectionPathBar extends StatelessWidget {
  const _ConnectionPathBar({
    required this.label,
    this.proxyName,
    this.bastionName,
    required this.targetName,
  });

  final String label;
  final String? proxyName;
  final String? bastionName;
  final String targetName;

  @override
  Widget build(BuildContext context) {
    final hops = <String>[
      'Client',
      if (proxyName != null && proxyName!.isNotEmpty) proxyName!,
      if (bastionName != null && bastionName!.isNotEmpty) bastionName!,
      targetName.isEmpty ? '?' : targetName,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.md,
        vertical: TermexSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TermexTypography.caption.copyWith(
              color: context.colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: TermexSpacing.xs),
          Wrap(
            spacing: TermexSpacing.xs,
            runSpacing: TermexSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < hops.length; i++) ...[
                if (i > 0)
                  Text(
                    '→',
                    style: TermexTypography.body.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TermexSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.backgroundTertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hops[i],
                    style: TermexTypography.caption.copyWith(
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tab body: Sync (tmux + Git Auto Sync + team share) ──────────────────────

class _SyncTabBody extends ConsumerWidget {
  const _SyncTabBody({required this.state, required this.l10n});

  final _ServerFormDialogState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tmuxOptions = <SelectOption<String>>[
      SelectOption(value: 'disabled', label: l10n.connectionTmuxDisabled),
      SelectOption(value: 'auto', label: l10n.connectionTmuxAuto),
      SelectOption(value: 'always', label: l10n.connectionTmuxAlways),
    ];

    final tmuxCloseOptions = <SelectOption<String>>[
      SelectOption(value: 'detach', label: l10n.connectionTmuxDetach),
      SelectOption(value: 'kill', label: l10n.connectionTmuxKill),
    ];

    final gitSyncModeOptions = <SelectOption<String>>[
      SelectOption(value: 'notify', label: l10n.connectionGitSyncNotify),
      SelectOption(value: 'auto_pull', label: l10n.connectionGitSyncAutoPull),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── tmux ───────────────────────────────────────────────────────────
        _LabeledField(
          label: l10n.connectionTmuxMode,
          child: TermexSelect<String>(
            options: tmuxOptions,
            value: state._tmuxMode,
            onChanged: (v) => state.rebuild(() => state._tmuxMode = v),
          ),
        ),
        if (state._tmuxMode != 'disabled') ...[
          const SizedBox(height: TermexSpacing.md),
          _LabeledField(
            label: l10n.connectionTmuxCloseAction,
            child: TermexSelect<String>(
              options: tmuxCloseOptions,
              value: state._tmuxCloseAction,
              onChanged: (v) =>
                  state.rebuild(() => state._tmuxCloseAction = v),
            ),
          ),
        ],

        const SizedBox(height: TermexSpacing.lg),
        const TermexDivider(),
        const SizedBox(height: TermexSpacing.md),

        // ── Session recording ──────────────────────────────────────────────
        // Per-server, matching the Tauri build: `servers.auto_record` arms it
        // and `max_recording_mb` caps the file. api::ssh checks the flag right
        // after the shell opens.
        TermexCheckbox(
          value: state._autoRecord,
          label: l10n.connectionAutoRecord,
          onChanged: (v) => state.rebuild(() => state._autoRecord = v ?? false),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 24, top: 2),
          child: Text(
            l10n.connectionAutoRecordDesc,
            style: TextStyle(
                fontSize: 11, color: context.colors.textMuted),
          ),
        ),
        if (state._autoRecord) ...[
          const SizedBox(height: TermexSpacing.md),
          TermexTextField(
            controller: state._maxRecordingMbCtrl,
            label: l10n.connectionMaxRecordingMb,
            placeholder: '50',
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: TermexSpacing.md),
        const TermexDivider(),
        const SizedBox(height: TermexSpacing.md),

        // ── Git Auto Sync ──────────────────────────────────────────────────
        TermexCheckbox(
          value: state._gitSyncEnabled,
          label: l10n.connectionGitSyncEnable,
          onChanged: (v) =>
              state.rebuild(() => state._gitSyncEnabled = v ?? false),
        ),
        if (state._gitSyncEnabled) ...[
          const SizedBox(height: TermexSpacing.md),
          TermexTextField(
            controller: state._gitSyncRemoteCtrl,
            label: l10n.connectionGitSyncRemotePath,
            placeholder: '/home/user/project',
          ),
          const SizedBox(height: TermexSpacing.md),
          TermexTextField(
            controller: state._gitSyncLocalCtrl,
            label: l10n.connectionGitSyncLocalPath,
            placeholder: '/Users/me/project',
          ),
          const SizedBox(height: TermexSpacing.md),
          _LabeledField(
            label: l10n.connectionGitSyncMode,
            child: TermexSelect<String>(
              options: gitSyncModeOptions,
              value: state._gitSyncMode,
              onChanged: (v) =>
                  state.rebuild(() => state._gitSyncMode = v),
            ),
          ),
          const SizedBox(height: TermexSpacing.xs),
          Text(
            l10n.connectionGitSyncHint,
            style: TermexTypography.caption.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ],

        // Team-share switch. Visible unconditionally — the underlying
        // teamShareServer call fails fast when the user isn't in a team,
        // which we surface inline so the user knows to join first. A
        // future iteration can hide the row entirely behind a team-joined
        // provider once one exists.
        const SizedBox(height: TermexSpacing.lg),
        const TermexDivider(),
        const SizedBox(height: TermexSpacing.md),
        TermexCheckbox(
          value: state._shared,
          label: l10n.teamShareServer,
          onChanged: (v) =>
              state.rebuild(() => state._shared = v ?? false),
        ),
        const SizedBox(height: TermexSpacing.xs),
        Text(
          l10n.teamShareServerHint,
          style: TermexTypography.caption.copyWith(
            color: context.colors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ─── Tab body: Forwarding (port forward rules — edit mode only) ──────────────
//
// Embeds the standalone PortForwardPanel using the server id as the lookup
// key. port_forward_list / port_forward_start_ex both query the
// `port_forwards` table by `server_id`, so passing the server id here yields
// the per-server rule set the legacy Tauri ConnectModal showed.

class _ForwardingTabBody extends ConsumerWidget {
  const _ForwardingTabBody({required this.state, required this.l10n});

  final _ServerFormDialogState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editId = state.widget.editId;
    if (editId == null) {
      // _FormTabBar disables this tab in Add mode, but render a guard so
      // a future code path that opens the tab directly can't crash.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: TermexSpacing.xl),
        child: Center(
          child: Text(
            l10n.connectionForwardNone,
            style: TermexTypography.body.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 320,
      child: PortForwardPanel(sessionId: editId),
    );
  }
}

// ─── Auxiliary widgets ───────────────────────────────────────────────────────

class _KeySourceTabs extends StatelessWidget {
  const _KeySourceTabs({
    required this.value,
    required this.onChanged,
    required this.pathLabel,
    required this.pasteLabel,
  });

  final _KeySource value;
  final ValueChanged<_KeySource> onChanged;
  final String pathLabel;
  final String pasteLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tab(context, pathLabel, _KeySource.path),
        const SizedBox(width: TermexSpacing.xs),
        _tab(context, pasteLabel, _KeySource.paste),
      ],
    );
  }

  Widget _tab(BuildContext context, String label, _KeySource source) {
    final active = value == source;
    return Clickable(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(source),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              active ? context.colors.primary : context.colors.backgroundTertiary,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TermexTypography.bodySmall.copyWith(
            color:
                active ? const Color(0xFFFFFFFF) : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TestStatus extends StatelessWidget {
  const _TestStatus({
    required this.testing,
    required this.result,
    required this.testingText,
  });

  final bool testing;
  final ({bool ok, String message})? result;
  final String testingText;

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    if (testing) {
      color = context.colors.textSecondary;
      text = testingText;
    } else if (result != null) {
      color = result!.ok ? context.colors.success : context.colors.danger;
      text = result!.message;
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TermexTypography.bodySmall.copyWith(color: color),
      ),
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
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: TermexSpacing.xs),
        child,
      ],
    );
  }
}
