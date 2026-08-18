/// Modal sheet shown when termexd has flagged a task as
/// PendingConfirmation (risk == High / Critical, or policy ==
/// AlwaysConfirm).
///
/// v0.72.1 surfaces the structured risk reasons + matched patterns;
/// the actual biometric / decision wiring lives in the mobile shell
/// (which has access to `local_auth`).
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../widgets/clickable.dart';
import '../model/risk_assessment.dart';

enum ConfirmationDecision { approve, deny }

typedef ConfirmationCallback = Future<void> Function(ConfirmationDecision);

class PendingConfirmationSheet extends StatelessWidget {
  final String taskId;
  final RiskAssessment risk;
  final String serverName;
  final String prompt;
  final String aiCliDisplayName;
  final ConfirmationCallback onDecide;

  /// When true, the Approve button label hints that biometric auth
  /// will be requested by the caller. v0.72.1 mobile shell wires
  /// this to `local_auth`; widgets here only render the hint.
  final bool requiresBiometric;

  const PendingConfirmationSheet({
    super.key,
    required this.taskId,
    required this.risk,
    required this.serverName,
    required this.prompt,
    required this.aiCliDisplayName,
    required this.onDecide,
    this.requiresBiometric = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(risk.level, context.colors);
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(level: risk.level, accent: accent),
          const SizedBox(height: TermexSpacing.md),
          _LabeledRow(label: 'Server', value: serverName),
          _LabeledRow(label: 'AI CLI', value: aiCliDisplayName),
          const SizedBox(height: TermexSpacing.md),
          Text(
            'Prompt:',
            style: TermexTypography.caption.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: TermexSpacing.xs),
          Container(
            padding: const EdgeInsets.all(TermexSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.backgroundTertiary,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.colors.border),
            ),
            child: Text(
              risk.preview.isEmpty ? prompt : risk.preview,
              style: TermexTypography.monospace.copyWith(
                color: context.colors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          if (risk.reasons.isNotEmpty) ...[
            const SizedBox(height: TermexSpacing.md),
            Text(
              'Reasons:',
              style: TermexTypography.caption.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: TermexSpacing.xs),
            for (final r in risk.reasons)
              Padding(
                padding: const EdgeInsets.only(
                  left: TermexSpacing.sm,
                  bottom: 2,
                ),
                child: Text(
                  '• $r',
                  style: TermexTypography.body.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
          ],
          const SizedBox(height: TermexSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _SheetButton(
                label: 'Deny',
                color: context.colors.danger,
                onPressed: () => onDecide(ConfirmationDecision.deny),
              ),
              const SizedBox(width: TermexSpacing.sm),
              _SheetButton(
                label: requiresBiometric ? 'Approve (Touch ID)' : 'Approve',
                color: accent,
                filled: true,
                onPressed: () => onDecide(ConfirmationDecision.approve),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _accentFor(RiskLevel l, TermexColorScheme colors) {
    switch (l) {
      case RiskLevel.critical:
        return colors.danger;
      case RiskLevel.high:
        return colors.warning;
      case RiskLevel.medium:
        return colors.primary;
      case RiskLevel.low:
        return colors.success;
    }
  }
}

class _Header extends StatelessWidget {
  final RiskLevel level;
  final Color accent;

  const _Header({required this.level, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: accent),
          ),
          alignment: Alignment.center,
          child: Text(
            '!',
            style: TermexTypography.body.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: TermexSpacing.sm),
        Expanded(
          child: Text(
            'Confirmation required — ${level.displayName} risk',
            style: TermexTypography.heading3.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final String value;
  const _LabeledRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TermexTypography.caption.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TermexTypography.body.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onPressed;

  const _SheetButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.md,
          vertical: TermexSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TermexTypography.body.copyWith(
            color: filled ? context.colors.textPrimary : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
