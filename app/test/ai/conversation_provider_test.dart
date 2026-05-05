import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/ai/state/conversation_provider.dart';

void main() {
  group('ConversationNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state is empty', () {
      final state = container.read(conversationProvider);
      expect(state.conversations, isEmpty);
      expect(state.activeConversationId, isNull);
    });

    test('createConversation adds to list and sets active', () {
      container.read(conversationProvider.notifier).createConversation(
            provider: AiProvider.claude,
            model: 'claude-opus-4-7',
          );
      final state = container.read(conversationProvider);
      expect(state.conversations, hasLength(1));
      expect(state.activeConversationId, isNotNull);
    });

    test('selectConversation changes active', () {
      final id1 = container.read(conversationProvider.notifier).createConversation(
            provider: AiProvider.claude,
            model: 'claude-opus-4-7',
          );
      container.read(conversationProvider.notifier).createConversation(
            provider: AiProvider.openAi,
            model: 'gpt-4o',
          );
      container.read(conversationProvider.notifier).selectConversation(id1);
      expect(container.read(conversationProvider).activeConversationId, id1);
    });

    test('deleteConversation removes from list', () {
      final id = container.read(conversationProvider.notifier).createConversation(
            provider: AiProvider.claude,
            model: 'claude-opus-4-7',
          );
      container.read(conversationProvider.notifier).deleteConversation(id);
      final state = container.read(conversationProvider);
      expect(state.conversations, isEmpty);
      expect(state.activeConversationId, isNull);
    });

    test('addUserMessage appends to active conversation', () {
      container.read(conversationProvider.notifier).createConversation(
            provider: AiProvider.claude,
            model: 'claude-opus-4-7',
          );
      container.read(conversationProvider.notifier).addUserMessage('hello');
      final state = container.read(conversationProvider);
      expect(state.activeMessages, hasLength(1));
      expect(state.activeMessages.first.role, MessageRole.user);
      expect(state.activeMessages.first.content, 'hello');
    });

    test('appendDelta grows assistant message content', () {
      container.read(conversationProvider.notifier).createConversation(
            provider: AiProvider.claude,
            model: 'claude-opus-4-7',
          );
      final msgId =
          container.read(conversationProvider.notifier).beginAssistantReply();
      container.read(conversationProvider.notifier).appendDelta(msgId, 'Hello');
      container.read(conversationProvider.notifier).appendDelta(msgId, ' world');
      final state = container.read(conversationProvider);
      final msg = state.activeMessages.last;
      expect(msg.content, 'Hello world');
    });

    test('finalizeReply sets token counts', () {
      container.read(conversationProvider.notifier).createConversation(
            provider: AiProvider.claude,
            model: 'claude-opus-4-7',
          );
      final msgId =
          container.read(conversationProvider.notifier).beginAssistantReply();
      container.read(conversationProvider.notifier).finalizeReply(
            msgId,
            tokensIn: 100,
            tokensOut: 42,
          );
      final msg = container.read(conversationProvider).activeMessages.last;
      expect(msg.tokensIn, 100);
      expect(msg.tokensOut, 42);
    });
  });
}
