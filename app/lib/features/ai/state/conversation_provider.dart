import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:uuid/uuid.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

enum AiProvider { claude, openAi, ollama, localLlama }

enum MessageRole { user, assistant, system }

class AiMessage {
  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final int? tokensIn;
  final int? tokensOut;
  final DateTime createdAt;

  const AiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.tokensIn,
    this.tokensOut,
    required this.createdAt,
  });

  AiMessage copyWith({String? content, int? tokensIn, int? tokensOut}) =>
      AiMessage(
        id: id,
        conversationId: conversationId,
        role: role,
        content: content ?? this.content,
        tokensIn: tokensIn ?? this.tokensIn,
        tokensOut: tokensOut ?? this.tokensOut,
        createdAt: createdAt,
      );
}

class Conversation {
  final String id;
  final AiProvider provider;
  final String model;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.provider,
    required this.model,
    this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  Conversation copyWith({String? title, DateTime? updatedAt}) => Conversation(
        id: id,
        provider: provider,
        model: model,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ─── State ────────────────────────────────────────────────────────────────────

class ConversationState {
  final List<Conversation> conversations;
  final String? activeConversationId;
  final Map<String, List<AiMessage>> messages;
  final bool isLoading;

  const ConversationState({
    this.conversations = const [],
    this.activeConversationId,
    this.messages = const {},
    this.isLoading = false,
  });

  List<AiMessage> get activeMessages =>
      activeConversationId != null ? messages[activeConversationId] ?? [] : [];

  ConversationState copyWith({
    List<Conversation>? conversations,
    String? activeConversationId,
    Map<String, List<AiMessage>>? messages,
    bool? isLoading,
    bool clearActive = false,
  }) =>
      ConversationState(
        conversations: conversations ?? this.conversations,
        activeConversationId:
            clearActive ? null : (activeConversationId ?? this.activeConversationId),
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ConversationNotifier extends Notifier<ConversationState> {
  static const _uuid = Uuid();

  @override
  ConversationState build() => const ConversationState();

  /// Create a new conversation and set it as active.
  String createConversation({
    required AiProvider provider,
    required String model,
    String? title,
  }) {
    final id = _uuid.v4();
    final now = DateTime.now();
    final conv = Conversation(
      id: id,
      provider: provider,
      model: model,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    state = state.copyWith(
      conversations: [conv, ...state.conversations],
      activeConversationId: id,
      messages: {...state.messages, id: []},
    );
    // Persist: use aiCreateConversation server-side. If available, prefer its id.
    // We keep the locally-generated id as the primary for UI continuity; the
    // Rust side uses the same id (see ai_create_conversation signature).
    return id;
  }

  void selectConversation(String id) {
    state = state.copyWith(activeConversationId: id);
  }

  void deleteConversation(String id) {
    final updated = {...state.messages}..remove(id);
    state = state.copyWith(
      conversations: state.conversations.where((c) => c.id != id).toList(),
      messages: updated,
      clearActive: state.activeConversationId == id,
    );
    try {
      bridge.aiDeleteConversation(conversationId: id).catchError((_) {});
    } catch (_) {}
  }

  /// Append a user message to the active conversation.
  AiMessage addUserMessage(String content) {
    final convId = state.activeConversationId!;
    final msg = AiMessage(
      id: _uuid.v4(),
      conversationId: convId,
      role: MessageRole.user,
      content: content,
      createdAt: DateTime.now(),
    );
    _appendMessage(msg);
    return msg;
  }

  /// Begin streaming an assistant reply — returns a placeholder message ID.
  String beginAssistantReply() {
    final convId = state.activeConversationId!;
    final id = _uuid.v4();
    final msg = AiMessage(
      id: id,
      conversationId: convId,
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );
    _appendMessage(msg);
    return id;
  }

  /// Append a delta to an in-progress assistant message.
  void appendDelta(String messageId, String delta) {
    final convId = state.activeConversationId;
    if (convId == null) return;
    final msgs = state.messages[convId] ?? [];
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    final updated = List<AiMessage>.from(msgs);
    updated[idx] = updated[idx].copyWith(content: updated[idx].content + delta);
    state = state.copyWith(messages: {...state.messages, convId: updated});
  }

  /// Finalize an assistant message with token counts.
  void finalizeReply(String messageId, {int? tokensIn, int? tokensOut}) {
    final convId = state.activeConversationId;
    if (convId == null) return;
    final msgs = state.messages[convId] ?? [];
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    final updated = List<AiMessage>.from(msgs);
    updated[idx] = updated[idx].copyWith(tokensIn: tokensIn, tokensOut: tokensOut);
    state = state.copyWith(messages: {...state.messages, convId: updated});
    try {
      bridge
          .aiPersistAssistantMessage(
            conversationId: convId,
            content: updated[idx].content,
          )
          .catchError((_) {});
    } catch (_) {}
  }

  void _appendMessage(AiMessage msg) {
    final msgs = List<AiMessage>.from(state.messages[msg.conversationId] ?? [])
      ..add(msg);
    state = state.copyWith(messages: {...state.messages, msg.conversationId: msgs});
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final conversationProvider =
    NotifierProvider<ConversationNotifier, ConversationState>(
  ConversationNotifier.new,
);
