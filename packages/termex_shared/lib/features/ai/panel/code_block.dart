import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/clickable.dart';

/// Renders a fenced code block with a copy button.
class CodeBlock extends StatefulWidget {
  final String code;
  final String? language;
  final VoidCallback? onRunCommand;

  const CodeBlock({
    super.key,
    required this.code,
    this.language,
    this.onRunCommand,
  });

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.backgroundTertiary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.backgroundSecondary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(5)),
              border:
                  Border(bottom: BorderSide(color: context.colors.border)),
            ),
            child: Row(
              children: [
                if (widget.language != null)
                  Text(
                    widget.language!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                const Spacer(),
                if (widget.onRunCommand != null)
                  _HeaderButton(
                    icon: Icons.play_arrow_rounded,
                    label: l10n.aiCodeBlockRun,
                    onTap: widget.onRunCommand!,
                  ),
                const SizedBox(width: 4),
                _HeaderButton(
                  icon: _copied ? Icons.check : Icons.copy_rounded,
                  label: _copied ? l10n.aiCopied : l10n.aiCopy,
                  onTap: _copy,
                ),
              ],
            ),
          ),
          // Code content
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.5,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.colors.textSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
