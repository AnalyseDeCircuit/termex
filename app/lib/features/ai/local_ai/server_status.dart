import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens.dart';
import '../state/local_ai_provider.dart';

/// Compact status indicator shown at the top of the local AI panel.
class LocalAiServerStatus extends ConsumerWidget {
  const LocalAiServerStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localAiProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TermexColors.backgroundTertiary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          _StatusDot(status: state.status),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusLabel(state.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TermexColors.textPrimary,
                  ),
                ),
                if (state.loadedModelId != null)
                  Text(
                    state.loadedModelId!,
                    style: TextStyle(
                        fontSize: 10, color: TermexColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (state.memoryMb != null)
            Text(
              '${state.memoryMb} MB',
              style: TextStyle(fontSize: 10, color: TermexColors.textSecondary),
            ),
          const SizedBox(width: 8),
          if (state.isRunning)
            _StopButton(
              onTap: () => ref.read(localAiProvider.notifier).stopServer(),
            ),
        ],
      ),
    );
  }

  String _statusLabel(LocalAiStatus s) => switch (s) {
        LocalAiStatus.stopped => '已停止',
        LocalAiStatus.starting => '启动中…',
        LocalAiStatus.running => '运行中',
        LocalAiStatus.error => '错误',
      };
}

class _StatusDot extends StatelessWidget {
  final LocalAiStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      LocalAiStatus.stopped => TermexColors.textSecondary,
      LocalAiStatus.starting => TermexColors.warning,
      LocalAiStatus.running => TermexColors.success,
      LocalAiStatus.error => TermexColors.danger,
    };
    final isAnimating = status == LocalAiStatus.starting;

    return isAnimating
        ? _PulsingDot(color: color)
        : Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.3 + _ctrl.value * 0.7,
        child: Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: widget.color),
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: TermexColors.danger.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '停止',
          style: TextStyle(fontSize: 11, color: TermexColors.danger),
        ),
      ),
    );
  }
}
