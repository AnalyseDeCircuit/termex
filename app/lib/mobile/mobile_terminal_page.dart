import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/mobile_tokens.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/features/server_list/models/server_dto.dart';
import 'package:termex_shared/icons/termex_icons.dart';
import 'package:termex_shared/widgets/clickable.dart';
import 'package:xterm/core.dart' show TerminalKey;
import 'package:xterm/xterm.dart' as xt;

import 'background_service.dart';
import 'battery_nag.dart';

/// Full-screen terminal view for mobile. Opens an SSH session against
/// [server], pumps the FRB event queue, and renders the output through
/// the xterm package's terminal widget.
///
/// v0.77.1 scope: connect / disconnect / type / view scrollback. No
/// pinch-to-zoom, no broadcast, no NL2Cmd — those land in v0.78.x.
class MobileTerminalPage extends ConsumerStatefulWidget {
  final ServerDto server;
  const MobileTerminalPage({super.key, required this.server});

  @override
  ConsumerState<MobileTerminalPage> createState() =>
      _MobileTerminalPageState();
}

enum _SessionStatus { connecting, connected, disconnected, failed }

class _MobileTerminalPageState extends ConsumerState<MobileTerminalPage> {
  late final xt.Terminal _terminal;
  Timer? _pollTimer;
  String? _sessionId;
  _SessionStatus _status = _SessionStatus.connecting;
  String? _errorMessage;

  // Hand-coded initial size; the autoResize=true on TerminalView will
  // re-send a resize once the widget measures itself.
  static const int _initialCols = 80;
  static const int _initialRows = 24;

  // ── Pinch-to-zoom font size state ─────────────────────────────────────────
  static const double _minFontSize = 8;
  static const double _maxFontSize = 28;
  static const double _defaultFontSize = 14;
  double _fontSize = _defaultFontSize;
  // Baseline captured at gesture start so each new pinch scales from the
  // current size rather than compounding.
  double _fontSizeAtGestureStart = _defaultFontSize;

  // ── Sticky Ctrl modifier state ────────────────────────────────────────────
  /// When true, the next toolbar character button (or arrow tap that maps
  /// to a letter) emits the Ctrl-X variant, then auto-releases.
  bool _ctrlArmed = false;

  @override
  void initState() {
    super.initState();
    _terminal = xt.Terminal(maxLines: 10000);
    _terminal.onOutput = (data) {
      final sid = _sessionId;
      if (sid == null) return;
      // Sticky Ctrl: when armed, the next emitted character is rewritten
      // to its Ctrl-X equivalent (ASCII 0x01-0x1A for 'a'-'z' / 'A'-'Z'),
      // then the modifier auto-releases. Multi-byte output (escape
      // sequences from arrow keys etc.) is left alone — those already
      // carry their own meaning.
      List<int> bytes;
      if (_ctrlArmed && data.length == 1) {
        final code = data.codeUnitAt(0);
        int? ctrl;
        if (code >= 0x61 && code <= 0x7A) {
          ctrl = code - 0x60; // 'a' -> 0x01
        } else if (code >= 0x41 && code <= 0x5A) {
          ctrl = code - 0x40; // 'A' -> 0x01
        }
        if (ctrl != null) {
          bytes = [ctrl];
          // Drop the sticky state — no double-Ctrl. setState is safe even
          // while building because we're inside an output callback that
          // runs between frames.
          setState(() => _ctrlArmed = false);
        } else {
          bytes = utf8.encode(data);
        }
      } else {
        bytes = utf8.encode(data);
      }
      bridge.writeStdin(sessionId: sid, data: bytes);
    };
    _terminal.onResize = (cols, rows, _, __) {
      final sid = _sessionId;
      if (sid == null) return;
      bridge.resizeTerminal(sessionId: sid, cols: cols, rows: rows);
    };
    unawaited(_openSession());
  }

  Future<void> _openSession() async {
    try {
      final sid = await bridge.openSshSession(
        serverId: widget.server.id,
        cols: _initialCols,
        rows: _initialRows,
      );
      if (!mounted) return;
      setState(() {
        _sessionId = sid;
        _status = _SessionStatus.connected;
      });
      // Once the session is live, hand off to the Android foreground
      // service so the OS keeps the process scheduled even after the
      // user switches apps. Released in `dispose()`. No-op on iOS.
      unawaited(MobileBackgroundService.acquire());
      // One-time prompt to add Termex to Android's battery-optimisation
      // whitelist. Self-skips on iOS / when already whitelisted /
      // when previously dismissed.
      unawaited(MobileBatteryNag.maybeShow(context));
      _pollTimer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _drainEvents(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _SessionStatus.failed;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _drainEvents() async {
    final sid = _sessionId;
    if (sid == null) return;
    final events = await bridge.pollSshEvents(sessionId: sid);
    for (final ev in events) {
      _handleEvent(ev);
    }
  }

  // `event` is dynamic so we don't need to re-export the SshStreamEvent
  // class from the bridge package. Matches the desktop terminal_pane
  // pattern, see [packages/termex_shared/lib/terminal/pane/terminal_pane.dart].
  void _handleEvent(dynamic ev) {
    switch (ev.kind as String) {
      case 'stdout':
        _terminal.write(utf8.decode(ev.data, allowMalformed: true));
        break;
      case 'disconnected':
        _pollTimer?.cancel();
        if (mounted) {
          setState(() => _status = _SessionStatus.disconnected);
        }
        break;
      case 'exit':
        // Exit comes from the shell channel; remote may continue to send
        // a "disconnected" event right after. Keep the UI usable so the
        // user can read the final lines.
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    final sid = _sessionId;
    if (sid != null) {
      unawaited(bridge.closeSshSession(sessionId: sid));
      // Release the foreground-service refcount only when a session was
      // actually opened (matches the `acquire()` in `_openSession`).
      unawaited(MobileBackgroundService.release());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // v0.79.61: the `SizedBox(height: safe.top/bottom)` wrappers were
    // removed. MobileTerminalPage is always rendered inside MobileShell
    // (either pushed into `_terminalNav` for iPhone, or embedded in
    // `_TabletSplitTab` for iPad) and both layouts already consume the
    // system safe-area at the shell level. Repeating it here painted
    // a ~59pt empty band above the header and a ~34pt band below the
    // soft-keyboard toolbar — see iPhone 17 Pro screenshot in the
    // iteration doc.
    return Container(
      color: TermexColors.backgroundPrimary,
      child: Column(
        children: [
          _HeaderBar(
            title: widget.server.name,
            subtitle: _statusText,
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_status) {
      case _SessionStatus.connecting:
        return const Center(
          child: Text(
            'Connecting…',
            style: TextStyle(
              color: TermexColors.textSecondary,
              decoration: TextDecoration.none,
              fontSize: 15,
            ),
          ),
        );
      case _SessionStatus.failed:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              _errorMessage ?? 'Connection failed',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF38BA8),
                decoration: TextDecoration.none,
                fontSize: 14,
              ),
            ),
          ),
        );
      case _SessionStatus.connected:
      case _SessionStatus.disconnected:
        return Column(
          children: [
            Expanded(
              child: GestureDetector(
                // Pinch-to-zoom font size. Single-pointer events fall
                // through to TerminalView's own tap/scroll handlers; only
                // multi-pointer scale events are captured here.
                behavior: HitTestBehavior.translucent,
                onScaleStart: (_) =>
                    _fontSizeAtGestureStart = _fontSize,
                onScaleUpdate: (details) {
                  if ((details.scale - 1.0).abs() < 0.05) return;
                  final next = (_fontSizeAtGestureStart * details.scale)
                      .clamp(_minFontSize, _maxFontSize);
                  if (next != _fontSize) {
                    setState(() => _fontSize = next);
                  }
                },
                child: xt.TerminalView(
                  _terminal,
                  autofocus: true,
                  padding: const EdgeInsets.all(8),
                  textStyle: xt.TerminalStyle(
                    fontSize: _fontSize,
                    fontFamily: 'JetBrainsMono',
                  ),
                  keyboardType: TextInputType.text,
                  keyboardAppearance: Brightness.dark,
                  deleteDetection: true,
                ),
              ),
            ),
            _SoftKeyboardToolbar(
              onKey: _onToolbarKey,
              ctrlArmed: _ctrlArmed,
              onToggleCtrl: () =>
                  setState(() => _ctrlArmed = !_ctrlArmed),
            ),
          ],
        );
    }
  }

  /// Toolbar input — dispatches keys not exposed on the iOS soft keyboard
  /// (Esc, Tab, Arrows) and the three Ctrl combos most often used in a shell
  /// (Ctrl-C, Ctrl-D, Ctrl-Z). Full Ctrl-modifier toggling lands in a later
  /// iteration; the explicit buttons cover ≥90% of mobile terminal use.
  void _onToolbarKey(_ToolbarKey k) {
    final terminal = _terminal;
    switch (k) {
      case _ToolbarKey.esc:
        terminal.keyInput(TerminalKey.escape);
      case _ToolbarKey.tab:
        terminal.keyInput(TerminalKey.tab);
      case _ToolbarKey.up:
        terminal.keyInput(TerminalKey.arrowUp);
      case _ToolbarKey.down:
        terminal.keyInput(TerminalKey.arrowDown);
      case _ToolbarKey.left:
        terminal.keyInput(TerminalKey.arrowLeft);
      case _ToolbarKey.right:
        terminal.keyInput(TerminalKey.arrowRight);
      case _ToolbarKey.ctrlC:
        // Always emits Ctrl-C regardless of sticky state.
        terminal.charInput(0x63 /* 'c' */, ctrl: true);
      case _ToolbarKey.ctrlD:
        terminal.charInput(0x64 /* 'd' */, ctrl: true);
      case _ToolbarKey.ctrlZ:
        terminal.charInput(0x7A /* 'z' */, ctrl: true);
      case _ToolbarKey.pageUp:
        terminal.keyInput(TerminalKey.pageUp);
      case _ToolbarKey.pageDown:
        terminal.keyInput(TerminalKey.pageDown);
      case _ToolbarKey.home:
        terminal.keyInput(TerminalKey.home);
      case _ToolbarKey.end:
        terminal.keyInput(TerminalKey.end);
      case _ToolbarKey.del:
        terminal.keyInput(TerminalKey.delete);
      case _ToolbarKey.insert:
        terminal.keyInput(TerminalKey.insert);
    }
  }

  String get _statusText {
    switch (_status) {
      case _SessionStatus.connecting:
        return 'Connecting to ${widget.server.host}:${widget.server.port}…';
      case _SessionStatus.connected:
        return '${widget.server.username}@${widget.server.host}';
      case _SessionStatus.disconnected:
        return 'Disconnected';
      case _SessionStatus.failed:
        return 'Connection failed';
    }
  }
}

class _HeaderBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _HeaderBar({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MobileTokens.navBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          Clickable(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Container(
              width: MobileTokens.minTouchTarget,
              height: MobileTokens.minTouchTarget,
              alignment: Alignment.center,
              child: const Icon(
                TermexIcons.close,
                size: 22,
                color: TermexColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TermexTypography.caption.copyWith(
                    color: TermexColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: MobileTokens.minTouchTarget),
        ],
      ),
    );
  }
}

/// Keys surfaced by [_SoftKeyboardToolbar]. The iOS soft keyboard does not
/// expose escape, tab, arrow or Ctrl-modifier keys; the toolbar fills the gap.
enum _ToolbarKey {
  esc,
  tab,
  ctrlC,
  ctrlD,
  ctrlZ,
  up,
  down,
  left,
  right,
  // v0.78.2 additions — common edit/navigation keys missing on iOS soft keyboard.
  pageUp,
  pageDown,
  home,
  end,
  del,
  insert,
}

class _SoftKeyboardToolbar extends StatelessWidget {
  final void Function(_ToolbarKey) onKey;
  final bool ctrlArmed;
  final VoidCallback onToggleCtrl;

  const _SoftKeyboardToolbar({
    required this.onKey,
    required this.ctrlArmed,
    required this.onToggleCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(top: BorderSide(color: TermexColors.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          // Sticky Ctrl toggle — highlighted while armed; consumed on the
          // next character typed via the iOS soft keyboard. The explicit
          // ^C/^D/^Z buttons below stay for one-tap muscle-memory access.
          _ToolbarButton(
            label: 'Ctrl',
            onTap: onToggleCtrl,
            active: ctrlArmed,
          ),
          _ToolbarButton(label: 'Esc', onTap: () => onKey(_ToolbarKey.esc)),
          _ToolbarButton(label: 'Tab', onTap: () => onKey(_ToolbarKey.tab)),
          _ToolbarButton(
              label: '^C',
              onTap: () => onKey(_ToolbarKey.ctrlC),
              danger: true),
          _ToolbarButton(label: '^D', onTap: () => onKey(_ToolbarKey.ctrlD)),
          _ToolbarButton(label: '^Z', onTap: () => onKey(_ToolbarKey.ctrlZ)),
          _ToolbarButton(label: '↑', onTap: () => onKey(_ToolbarKey.up)),
          _ToolbarButton(label: '↓', onTap: () => onKey(_ToolbarKey.down)),
          _ToolbarButton(label: '←', onTap: () => onKey(_ToolbarKey.left)),
          _ToolbarButton(label: '→', onTap: () => onKey(_ToolbarKey.right)),
          _ToolbarButton(label: 'PgUp', onTap: () => onKey(_ToolbarKey.pageUp)),
          _ToolbarButton(label: 'PgDn', onTap: () => onKey(_ToolbarKey.pageDown)),
          _ToolbarButton(label: 'Home', onTap: () => onKey(_ToolbarKey.home)),
          _ToolbarButton(label: 'End', onTap: () => onKey(_ToolbarKey.end)),
          _ToolbarButton(label: 'Del', onTap: () => onKey(_ToolbarKey.del)),
          _ToolbarButton(label: 'Ins', onTap: () => onKey(_ToolbarKey.insert)),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;
  /// Stays visually highlighted (e.g. for sticky-modifier buttons such as
  /// Ctrl) until tapped again.
  final bool active;
  const _ToolbarButton({
    required this.label,
    required this.onTap,
    this.danger = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = active
        ? TermexColors.primary
        : danger
            ? const Color(0xFFF38BA8)
            : TermexColors.textPrimary;
    final Color bg = active
        ? TermexColors.primary.withValues(alpha: 0.18)
        : TermexColors.backgroundTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Clickable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? TermexColors.primary : TermexColors.border,
            ),
          ),
          child: Text(
            label,
            style: TermexTypography.body.copyWith(
              color: fg,
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
