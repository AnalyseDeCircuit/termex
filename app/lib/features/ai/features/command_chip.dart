import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/tokens.dart';
import 'command_extractor.dart';

/// Inline chip showing an extracted command with risk indicator and action buttons.
class CommandChip extends StatefulWidget {
  final ExtractedCommand command;
  final VoidCallback? onRun;

  const CommandChip({
    super.key,
    required this.command,
    this.onRun,
  });

  @override
  State<CommandChip> createState() => _CommandChipState();
}

class _CommandChipState extends State<CommandChip> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.command.command));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final risk = widget.command.risk;
    final borderColor = switch (risk) {
      CommandRisk.dangerous => TermexColors.danger,
      CommandRisk.caution => TermexColors.warning,
      CommandRisk.safe => TermexColors.border,
    };
    final bgColor = switch (risk) {
      CommandRisk.dangerous => TermexColors.danger.withOpacity(0.06),
      CommandRisk.caution => TermexColors.warning.withOpacity(0.06),
      CommandRisk.safe => TermexColors.backgroundTertiary,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (risk != CommandRisk.safe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                risk == CommandRisk.dangerous
                    ? Icons.dangerous_outlined
                    : Icons.warning_amber_rounded,
                size: 14,
                color: risk == CommandRisk.dangerous
                    ? TermexColors.danger
                    : TermexColors.warning,
              ),
            ),
          Expanded(
            child: Text(
              widget.command.command,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: TermexColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            icon: _copied ? Icons.check : Icons.copy_rounded,
            onTap: _copy,
          ),
          if (widget.onRun != null) ...[
            const SizedBox(width: 4),
            _ActionBtn(
              icon: Icons.play_arrow_rounded,
              onTap: risk == CommandRisk.dangerous ? null : widget.onRun,
              color: risk == CommandRisk.dangerous ? null : TermexColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _ActionBtn({required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.3 : 1.0,
        child: Icon(
          icon,
          size: 15,
          color: color ?? TermexColors.textSecondary,
        ),
      ),
    );
  }
}
