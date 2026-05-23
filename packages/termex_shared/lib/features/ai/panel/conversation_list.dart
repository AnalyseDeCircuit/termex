import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../state/conversation_provider.dart';
import '../state/provider_config_provider.dart';

/// Sidebar list of all stored conversations with New / Delete actions.
class ConversationList extends ConsumerWidget {
  const ConversationList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationProvider);
    final config = ref.watch(providerConfigProvider).activeConfig;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          onNew: () => ref.read(conversationProvider.notifier).createConversation(
                provider: config.provider,
                model: config.model,
              ),
        ),
        Expanded(
          child: state.conversations.isEmpty
              ? _EmptyState()
              : ListView.builder(
                  itemCount: state.conversations.length,
                  itemBuilder: (_, i) {
                    final conv = state.conversations[i];
                    return _ConversationRow(
                      conversation: conv,
                      isActive: conv.id == state.activeConversationId,
                      onSelect: () => ref
                          .read(conversationProvider.notifier)
                          .selectConversation(conv.id),
                      onDelete: () => ref
                          .read(conversationProvider.notifier)
                          .deleteConversation(conv.id),
                      onRename: () => _promptRename(context, ref, conv),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _promptRename(
    BuildContext context,
    WidgetRef ref,
    Conversation conv,
  ) async {
    final controller =
        TextEditingController(text: conv.title ?? '');
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: const Text('重命名对话',
            style: TextStyle(color: TermexColors.textPrimary, fontSize: 14)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          style: const TextStyle(color: TermexColors.textPrimary, fontSize: 13),
          decoration: const InputDecoration(
            hintText: '输入新标题',
            counterText: '',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await ref
          .read(conversationProvider.notifier)
          .renameConversation(conv.id, newTitle);
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onNew;
  const _Header({required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          const Text(
            '对话',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TermexColors.textSecondary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onNew,
            child: const Icon(Icons.add, size: 16, color: TermexColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final Conversation conversation;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _ConversationRow({
    required this.conversation,
    required this.isActive,
    required this.onSelect,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      onLongPress: onRename,
      onSecondaryTap: onRename,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? TermexColors.primary.withOpacity(0.08) : null,
          border: Border(
            left: BorderSide(
              color: isActive ? TermexColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 13,
              color: isActive ? TermexColors.primary : TermexColors.textSecondary,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                conversation.title ?? _defaultTitle(conversation),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive
                      ? TermexColors.textPrimary
                      : TermexColors.textSecondary,
                  fontWeight:
                      isActive ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Opacity(
                opacity: 0.5,
                child:
                    Icon(Icons.close, size: 13, color: TermexColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _defaultTitle(Conversation conv) {
    final label = switch (conv.provider) {
      AiProvider.claude => 'Claude',
      AiProvider.openAi => 'OpenAI',
      AiProvider.ollama => 'Ollama',
      AiProvider.localLlama => 'Local AI',
    };
    final d = conv.createdAt;
    return '$label · ${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '点击 + 开始新对话',
        style: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
      ),
    );
  }
}
