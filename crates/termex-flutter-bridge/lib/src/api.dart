/// Real FRB-generated bindings (was stub-only before v0.51.x codegen).
///
/// The generated tree lives inside this package. It used to sit in the app
/// (`package:termex/src/frb_generated`), which made every consumer of the
/// bridge depend on the app: termex_shared -> termex_bridge -> app ->
/// termex_shared. That cycle is why termex_shared could not be analysed on
/// its own — every bridge symbol came back undefined.
///
/// Original hand-written stubs preserved in api.dart.pre-codegen.bak
/// for reference during the transition.
export 'generated/frb_generated.dart';
export 'generated/api/ai.dart';
export 'generated/api/app.dart';
export 'generated/api/audit_catalogue.dart';
export 'generated/api/backup.dart';
export 'generated/api/chain.dart';
export 'generated/api/cloud.dart';
export 'generated/api/cost.dart';
export 'generated/api/crypto.dart';
export 'generated/api/daemon.dart';
export 'generated/api/desktop_probe.dart';
export 'generated/api/external_tools.dart';
export 'generated/api/git_sync.dart';
export 'generated/api/group.dart';
export 'generated/api/handoff.dart';
export 'generated/api/keybindings.dart';
export 'generated/api/local_ai.dart';
export 'generated/api/local_fs.dart';
export 'generated/api/local_pty.dart' show openLocalPty;
export 'generated/api/monitor.dart';
export 'generated/api/plugin.dart';
export 'generated/api/port_forward.dart' hide testClearRegistry;
export 'generated/api/proxy.dart' hide testClearRegistry;
export 'generated/api/recording.dart' hide testClearRegistry;
export 'generated/api/reliability.dart';
export 'generated/api/security.dart';
export 'generated/api/server.dart';
export 'generated/api/settings.dart';
export 'generated/api/sftp.dart' hide testClearRegistry;
export 'generated/api/snippet.dart';
export 'generated/api/ssh.dart';
export 'generated/api/ssh_config.dart';
export 'generated/api/system.dart';
export 'generated/api/team.dart';
export 'generated/api/team_permissions.dart';
export 'generated/api/theme.dart';
export 'generated/api/update.dart';
// ── Mobile-only API surface ────────────────────────────────────────────────
// Compiled into the bridge cdylib on every platform; PC builds ship the
// generated wrappers but the desktop UI never invokes them. Mobile UI in
// termex-mobile/app uses them via this same bridge package.
export 'generated/api/mobile.dart';
export 'generated/api/mobile_auth.dart';
export 'generated/api/push.dart';
export 'generated/api/team_mobile.dart';
export 'generated/frb_chain_emitter.dart';
