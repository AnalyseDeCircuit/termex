/// Chain-progress reconnect banner (v0.68.0 G3).
///
/// Shown above the terminal pane while a chained SSH connection is
/// establishing (or recovering from a hop failure). Pulls live state from
/// `ConnectionState.currentHop / totalHops / hopName / hopAttempt`.
library;

import 'dart:async';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../server_list/state/connection_provider.dart';

/// Renders a thin banner above the terminal while the chain is mid-connect
/// or mid-retry. Returns SizedBox.shrink when no chain is active.
class ReconnectBanner extends ConsumerWidget {
  final String tabId;

  const ReconnectBanner({super.key, required this.tabId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(connectionProvider(tabId));

    // Hide unless a multi-hop chain is in progress or retrying.
    final isInteresting = c.totalHops > 1 &&
        (c.status == ReconnectStatus.connecting ||
            c.status == ReconnectStatus.reconnecting ||
            (c.status == ReconnectStatus.failed && c.hopAttempt > 0));
    if (!isInteresting) return const SizedBox.shrink();

    final (icon, color, text) = _composeMessage(c, context.colors);
    return Material(
      color: color.withValues(alpha: 0.12),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: color.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (c.nextAttemptInMs > 0)
              _Countdown(initialMs: c.nextAttemptInMs, color: color),
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _composeMessage(
    ConnectionState c,
    TermexColorScheme colors,
  ) {
    final hop = '${c.currentHop}/${c.totalHops}';
    if (c.status == ReconnectStatus.failed) {
      return (
        Icons.error_outline,
        colors.danger,
        '链式连接失败 · hop $hop (${c.hopName}) — ${c.lastError ?? "未知错误"}',
      );
    }
    if (c.hopAttempt > 0) {
      return (
        Icons.sync_problem,
        colors.warning,
        '重试 hop $hop (${c.hopName})· 第 ${c.hopAttempt} 次尝试',
      );
    }
    return (
      Icons.cable,
      colors.primary,
      '正在连接 hop $hop (${c.hopName})…',
    );
  }
}

/// Decrementing timer text showing seconds until the next attempt.
class _Countdown extends StatefulWidget {
  final int initialMs;
  final Color color;

  const _Countdown({required this.initialMs, required this.color});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late int _remainingMs;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _remainingMs = widget.initialMs;
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (t) {
      setState(() {
        _remainingMs = (_remainingMs - 200).clamp(0, 1 << 31);
      });
      if (_remainingMs == 0) t.cancel();
    });
  }

  @override
  void didUpdateWidget(covariant _Countdown old) {
    super.didUpdateWidget(old);
    if (old.initialMs != widget.initialMs) {
      _remainingMs = widget.initialMs;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingMs <= 0) return const SizedBox.shrink();
    final seconds = (_remainingMs / 1000).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '${seconds}s 后重试',
        style: TextStyle(
            fontSize: 10, color: widget.color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
