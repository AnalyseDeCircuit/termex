import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../state/conversation_provider.dart';
import 'message_bubble.dart';

/// Scrollable list of messages for the active conversation.
class ConversationView extends ConsumerStatefulWidget {
  /// Called when the user taps "Run" on a code block.
  final void Function(String command)? onRunCommand;

  const ConversationView({super.key, this.onRunCommand});

  @override
  ConsumerState<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends ConsumerState<ConversationView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationProvider);
    final messages = state.activeMessages;

    // Auto-scroll when messages are appended
    ref.listen(conversationProvider, (_, __) => _scrollToBottom());

    if (state.activeConversationId == null) {
      return _WelcomeScreen();
    }

    if (messages.isEmpty) {
      return _EmptyConversation();
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (_, i) => MessageBubble(
        message: messages[i],
        onRunCommand: widget.onRunCommand,
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 48,
            color: TermexColors.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'AI 助手',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '选择或创建对话开始',
            style:
                TextStyle(fontSize: 13, color: TermexColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 36,
            color: TermexColors.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Text(
            '发送消息开始对话',
            style:
                TextStyle(fontSize: 13, color: TermexColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
