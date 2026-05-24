/// Real FRB-generated bindings (was stub-only before v0.51.x codegen).
///
/// Original hand-written stubs preserved in api.dart.pre-codegen.bak
/// for reference during the transition.
export 'package:termex/src/frb_generated/frb_generated.dart';
export 'package:termex/src/frb_generated/api/ai.dart';
export 'package:termex/src/frb_generated/api/app.dart';
export 'package:termex/src/frb_generated/api/audit_catalogue.dart';
export 'package:termex/src/frb_generated/api/backup.dart';
export 'package:termex/src/frb_generated/api/cloud.dart';
export 'package:termex/src/frb_generated/api/cost.dart';
export 'package:termex/src/frb_generated/api/crypto.dart';
export 'package:termex/src/frb_generated/api/daemon.dart';
export 'package:termex/src/frb_generated/api/desktop_probe.dart';
export 'package:termex/src/frb_generated/api/external_tools.dart';
export 'package:termex/src/frb_generated/api/git_sync.dart';
export 'package:termex/src/frb_generated/api/group.dart';
export 'package:termex/src/frb_generated/api/handoff.dart';
export 'package:termex/src/frb_generated/api/keybindings.dart';
export 'package:termex/src/frb_generated/api/local_ai.dart';
export 'package:termex/src/frb_generated/api/local_fs.dart';
export 'package:termex/src/frb_generated/api/local_pty.dart' show openLocalPty;
export 'package:termex/src/frb_generated/api/monitor.dart';
export 'package:termex/src/frb_generated/api/plugin.dart';
export 'package:termex/src/frb_generated/api/port_forward.dart' hide testClearRegistry;
export 'package:termex/src/frb_generated/api/proxy.dart' hide testClearRegistry;
export 'package:termex/src/frb_generated/api/recording.dart' hide testClearRegistry;
export 'package:termex/src/frb_generated/api/reliability.dart';
export 'package:termex/src/frb_generated/api/security.dart';
export 'package:termex/src/frb_generated/api/server.dart';
export 'package:termex/src/frb_generated/api/settings.dart';
export 'package:termex/src/frb_generated/api/sftp.dart' hide testClearRegistry;
export 'package:termex/src/frb_generated/api/snippet.dart';
export 'package:termex/src/frb_generated/api/ssh.dart';
export 'package:termex/src/frb_generated/api/ssh_config.dart';
export 'package:termex/src/frb_generated/api/system.dart';
export 'package:termex/src/frb_generated/api/team.dart';
export 'package:termex/src/frb_generated/api/team_permissions.dart';
export 'package:termex/src/frb_generated/api/theme.dart';
export 'package:termex/src/frb_generated/api/update.dart';
// ── Mobile-only API surface ────────────────────────────────────────────────
// Compiled into the bridge cdylib on every platform; PC builds ship the
// generated wrappers but the desktop UI never invokes them. Mobile UI in
// termex-mobile/app uses them via this same bridge package.
export 'package:termex/src/frb_generated/api/mobile.dart';
export 'package:termex/src/frb_generated/api/mobile_auth.dart';
export 'package:termex/src/frb_generated/api/push.dart';
export 'package:termex/src/frb_generated/api/team_mobile.dart';
export 'package:termex/src/frb_generated/frb_chain_emitter.dart';
