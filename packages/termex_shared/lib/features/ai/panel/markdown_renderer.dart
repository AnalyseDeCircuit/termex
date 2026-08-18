import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import 'code_block.dart';

/// Lightweight Markdown renderer that handles:
/// - Fenced code blocks (``` ... ```)
/// - Inline code (` ... `)
/// - Bold (**text**)
/// - Headers (# / ## / ###)
/// - Bullet lists (- / * / +)
/// - Plain text with line breaks
///
/// Uses no external dependency; for richer rendering add `flutter_markdown`
/// when the package size budget allows.
class MarkdownRenderer extends StatelessWidget {
  final String text;
  final VoidCallback? Function(String command)? onRunCommand;

  const MarkdownRenderer({super.key, required this.text, this.onRunCommand});

  @override
  Widget build(BuildContext context) {
    final blocks = _parse(context, text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  List<Widget> _parse(BuildContext context, String src) {
    final widgets = <Widget>[];
    final lines = src.split('\n');
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];

      // Fenced code block
      if (line.trimLeft().startsWith('```')) {
        final lang = line.trimLeft().substring(3).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        final code = codeLines.join('\n');
        final isShell = lang.isEmpty ||
            lang == 'sh' ||
            lang == 'bash' ||
            lang == 'shell' ||
            lang == 'zsh';
        widgets.add(CodeBlock(
          code: code,
          language: lang.isEmpty ? null : lang,
          onRunCommand: isShell && onRunCommand != null
              ? onRunCommand!(code)
              : null,
        ));
        i++;
        continue;
      }

      // Heading
      if (line.startsWith('### ')) {
        widgets.add(_heading(context, line.substring(4), 14));
        i++;
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(_heading(context, line.substring(3), 16));
        i++;
        continue;
      }
      if (line.startsWith('# ')) {
        widgets.add(_heading(context, line.substring(2), 18));
        i++;
        continue;
      }

      // Bullet list item
      if (line.startsWith('- ') || line.startsWith('* ') || line.startsWith('+ ')) {
        widgets.add(_bullet(context, line.substring(2)));
        i++;
        continue;
      }

      // Empty line → spacing
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        i++;
        continue;
      }

      // Plain paragraph with inline formatting
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _inlineText(context, line),
      ));
      i++;
    }
    return widgets;
  }

  Widget _heading(BuildContext context, String text, double size) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
      );

  Widget _bullet(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            Expanded(child: _inlineText(context, text)),
          ],
        ),
      );

  Widget _inlineText(BuildContext context, String src) {
    final hasInline = RegExp(r'`[^`]+`|\*\*[^*]+\*\*|\*[^*]+\*').hasMatch(src);
    if (!hasInline) {
      return Text(
        src,
        style: TextStyle(
          fontSize: 13,
          height: 1.55,
          color: context.colors.textPrimary,
        ),
      );
    }
    final spans = _buildSpans(context, src);
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          height: 1.55,
          color: context.colors.textPrimary,
        ),
        children: spans,
      ),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context, String src) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'`([^`]+)`|\*\*([^*]+)\*\*|\*([^*]+)\*');
    var last = 0;
    for (final match in pattern.allMatches(src)) {
      if (match.start > last) {
        spans.add(TextSpan(text: src.substring(last, match.start)));
      }
      if (match.group(1) != null) {
        // Inline code
        spans.add(WidgetSpan(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: context.colors.backgroundTertiary,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: context.colors.border),
            ),
            child: Text(
              match.group(1)!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ));
      } else if (match.group(2) != null) {
        // Bold
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ));
      } else if (match.group(3) != null) {
        // Italic
        spans.add(TextSpan(
          text: match.group(3),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }
      last = match.end;
    }
    if (last < src.length) {
      spans.add(TextSpan(text: src.substring(last)));
    }
    return spans;
  }
}
