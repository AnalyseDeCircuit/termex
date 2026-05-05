import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../state/conversation_provider.dart';
import 'markdown_renderer.dart';

/// Renders a single conversation message with role-specific styling.
class MessageBubble extends StatelessWidget {
  final AiMessage message;
  /// Called when the user taps a "Run" button on a code block.
  final void Function(String command)? onRunCommand;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRunCommand,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isSystem = message.role == MessageRole.system;

    if (isSystem) return _SystemBanner(content: message.content);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _Avatar(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _Bubble(
                  isUser: isUser,
                  content: message.content,
                  onRunCommand: onRunCommand,
                ),
                if (message.tokensIn != null || message.tokensOut != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: _TokenCounter(
                      tokensIn: message.tokensIn,
                      tokensOut: message.tokensOut,
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _Avatar(isUser: true),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool isUser;
  final String content;
  final void Function(String)? onRunCommand;

  const _Bubble({
    required this.isUser,
    required this.content,
    this.onRunCommand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: isUser
            ? TermexColors.primary.withOpacity(0.12)
            : TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(isUser ? 12 : 2),
          bottomRight: Radius.circular(isUser ? 2 : 12),
        ),
        border: Border.all(
          color: isUser
              ? TermexColors.primary.withOpacity(0.3)
              : TermexColors.border,
        ),
      ),
      child: isUser
          ? SelectableText(
              content,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: TermexColors.textPrimary,
              ),
            )
          : content.isEmpty
              ? _TypingIndicator()
              : MarkdownRenderer(
                  text: content,
                  onRunCommand: onRunCommand != null
                      ? (cmd) {
                          onRunCommand!(cmd);
                          return null;
                        }
                      : null,
                ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
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
      builder: (_, __) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Opacity(
                opacity: _dotOpacity(t, i),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TermexColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _dotOpacity(double t, int index) {
    final phase = (t - index * 0.2) % 1.0;
    return phase < 0.5 ? 0.3 + phase * 1.4 : 1.0 - (phase - 0.5) * 1.4;
  }
}

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser
            ? TermexColors.primary.withOpacity(0.2)
            : TermexColors.backgroundTertiary,
        border: Border.all(color: TermexColors.border),
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
        size: 16,
        color: isUser ? TermexColors.primary : TermexColors.textSecondary,
      ),
    );
  }
}

class _TokenCounter extends StatelessWidget {
  final int? tokensIn;
  final int? tokensOut;
  const _TokenCounter({this.tokensIn, this.tokensOut});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (tokensIn != null) parts.add('↑ ${_fmt(tokensIn!)}');
    if (tokensOut != null) parts.add('↓ ${_fmt(tokensOut!)}');
    return Text(
      '${parts.join('  ')} tokens',
      style: TextStyle(fontSize: 10, color: TermexColors.textSecondary),
    );
  }

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}

class _SystemBanner extends StatelessWidget {
  final String content;
  const _SystemBanner({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: TermexColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: TermexColors.textSecondary,
        ),
      ),
    );
  }
}
