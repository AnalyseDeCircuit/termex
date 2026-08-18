/// Dialog for editing the three user-facing cost caps. Pure
/// stateless edit-form callback; the caller persists the result.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../widgets/clickable.dart';
import '../model/cost_view_model.dart';

/// Renders three labelled rows + a save/cancel pair. The host
/// surface should overlay this on its own modal scaffold (no
/// Material AlertDialog dependency).
class CostCapDialog extends StatefulWidget {
  final UserCostCapVM initial;
  final void Function(UserCostCapVM updated) onSave;
  final VoidCallback onCancel;

  const CostCapDialog({
    super.key,
    required this.initial,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<CostCapDialog> createState() => _CostCapDialogState();
}

class _CostCapDialogState extends State<CostCapDialog> {
  late double? _monthly;
  late double? _single;
  late double? _perServer;

  @override
  void initState() {
    super.initState();
    _monthly = widget.initial.monthlyUsd;
    _single = widget.initial.singleTaskUsd;
    _perServer = widget.initial.perServerUsd;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending caps',
            style: TermexTypography.heading3.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: TermexSpacing.xs),
          Text(
            'Leave a field blank for no limit.',
            style: TermexTypography.caption.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: TermexSpacing.md),
          _CapRow(
            label: 'Monthly cap (USD)',
            initial: _monthly,
            onChanged: (v) => setState(() => _monthly = v),
          ),
          const SizedBox(height: TermexSpacing.sm),
          _CapRow(
            label: 'Per single task',
            initial: _single,
            onChanged: (v) => setState(() => _single = v),
          ),
          const SizedBox(height: TermexSpacing.sm),
          _CapRow(
            label: 'Per server',
            initial: _perServer,
            onChanged: (v) => setState(() => _perServer = v),
          ),
          const SizedBox(height: TermexSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _DialogButton(
                label: 'Cancel',
                color: context.colors.textSecondary,
                onPressed: widget.onCancel,
              ),
              const SizedBox(width: TermexSpacing.sm),
              _DialogButton(
                label: 'Save',
                color: context.colors.primary,
                onPressed: () => widget.onSave(UserCostCapVM(
                  monthlyUsd: _monthly,
                  singleTaskUsd: _single,
                  perServerUsd: _perServer,
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapRow extends StatefulWidget {
  final String label;
  final double? initial;
  final void Function(double? value) onChanged;
  const _CapRow({
    required this.label,
    required this.initial,
    required this.onChanged,
  });
  @override
  State<_CapRow> createState() => _CapRowState();
}

class _CapRowState extends State<_CapRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initial == null ? '' : widget.initial!.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 160,
          child: Text(
            widget.label,
            style: TermexTypography.body.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: TermexSpacing.sm),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.backgroundSecondary,
              border: Border.all(color: context.colors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.sm),
            child: EditableText(
              controller: _controller,
              focusNode: FocusNode(),
              style: TermexTypography.monospace.copyWith(
                color: context.colors.textPrimary,
              ),
              cursorColor: context.colors.primary,
              backgroundCursorColor: context.colors.border,
              onChanged: (s) {
                final t = s.trim();
                if (t.isEmpty) {
                  widget.onChanged(null);
                  return;
                }
                final parsed = double.tryParse(t);
                widget.onChanged(parsed);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _DialogButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.lg,
          vertical: TermexSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TermexTypography.body.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
