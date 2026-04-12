import { defineStore } from "pinia";
import { ref } from "vue";
import { tauriInvoke, tauriListen } from "@/utils/tauri";
import type {
  AiProvider,
  AiMessage,
  AiChunk,
  ChatMessage,
  ChatConversation,
  ExtractedCommand,
  DangerResult,
  ProviderInput,
} from "@/types/ai";
import type { TerminalContext } from "@/types/aiContext";

export const useAiStore = defineStore("ai", () => {
  const providers = ref<AiProvider[]>([]);
  const messages = ref<AiMessage[]>([]);
  const explaining = ref(false);

  /** Loads all AI providers from the database. */
  async function loadProviders(): Promise<void> {
    providers.value = await tauriInvoke<AiProvider[]>("ai_provider_list");
  }

  /** Adds a new AI provider. */
  async function addProvider(input: ProviderInput): Promise<AiProvider> {
    const provider = await tauriInvoke<AiProvider>("ai_provider_add", { input });
    providers.value.push(provider);
    return provider;
  }

  /** Updates an AI provider. */
  async function updateProvider(
    id: string,
    input: ProviderInput,
  ): Promise<void> {
    await tauriInvoke("ai_provider_update", { id, input });
    await loadProviders();
  }

  /** Deletes an AI provider. */
  async function deleteProvider(id: string): Promise<void> {
    await tauriInvoke("ai_provider_delete", { id });
    providers.value = providers.value.filter((p) => p.id !== id);
  }

  /** Sets a provider as the default. */
  async function setDefault(id: string): Promise<void> {
    await tauriInvoke("ai_provider_set_default", { id });
    providers.value.forEach((p) => (p.isDefault = p.id === id));
  }

  /** Checks a command for dangerous patterns (local regex). */
  async function checkDanger(command: string): Promise<DangerResult> {
    return tauriInvoke<DangerResult>("ai_check_danger", { command });
  }

  /** Explains a command using the default AI provider. */
  async function explainCommand(command: string): Promise<void> {
    const requestId = crypto.randomUUID();
    explaining.value = true;

    const msg: AiMessage = {
      id: requestId,
      role: "assistant",
      content: "",
      timestamp: new Date().toISOString(),
    };
    messages.value.push(msg);

    const unlisten = await tauriListen<{ text: string; done: boolean }>(
      `ai://explain/${requestId}`,
      (chunk) => {
        const target = messages.value.find((m) => m.id === requestId);
        if (target) {
          target.content += chunk.text;
        }
        if (chunk.done) {
          explaining.value = false;
        }
      },
    );

    try {
      await tauriInvoke("ai_explain_command", { command, requestId });
    } catch (err) {
      msg.content = String(err);
      explaining.value = false;
    }

    unlisten();
  }

  /** Clears the message history. */
  function clearMessages(): void {
    messages.value = [];
  }

  /** Global semaphore: only 1 autocomplete request at a time across all tabs. */
  const autocompleteInFlight = ref(false);

  // ── Multi-turn Chat ──────────────────────────────────────
  const conversations = ref<Map<string, ChatConversation>>(new Map());

  /** Gets or creates a conversation for a session. */
  function getConversation(sessionId: string): ChatConversation {
    let conv = conversations.value.get(sessionId);
    if (!conv) {
      conv = { sessionId, messages: [], createdAt: new Date().toISOString() };
      conversations.value.set(sessionId, conv);
    }
    return conv;
  }

  /** Sends a chat message with optional terminal context. */
  async function sendChat(
    sessionId: string,
    message: string,
    context: TerminalContext | null,
  ): Promise<void> {
    const conv = getConversation(sessionId);
    const requestId = crypto.randomUUID();

    // Add user message
    conv.messages.push({
      id: crypto.randomUUID(),
      role: "user",
      content: message,
      timestamp: new Date().toISOString(),
    });

    // Add context marker if provided
    if (context) {
      conv.messages.push({
        id: crypto.randomUUID(),
        role: "context",
        content: "Terminal context attached",
        timestamp: new Date().toISOString(),
        context,
      });
    }

    // Add streaming assistant placeholder
    const assistantMsg: ChatMessage = {
      id: requestId,
      role: "assistant",
      content: "",
      timestamp: new Date().toISOString(),
      streaming: true,
      commands: [],
    };
    conv.messages.push(assistantMsg);

    // Build history (last 10 turns)
    const history = conv.messages
      .filter((m) => m.role === "user" || m.role === "assistant")
      .slice(-10)
      .map((m) => ({ role: m.role, content: m.content }));

    const unlisten = await tauriListen<AiChunk>(
      `ai://chat/${requestId}`,
      (chunk) => {
        const target = conv.messages.find((m) => m.id === requestId);
        if (target) {
          target.content += chunk.text;
          if (chunk.done) {
            target.streaming = false;
            target.commands = extractCommands(target.content);
          }
        }
      },
    );

    try {
      await tauriInvoke("ai_chat", {
        input: {
          sessionId,
          message,
          includeContext: !!context,
          context,
          history: history.slice(0, -1),
        },
        requestId,
      });
    } catch (err) {
      assistantMsg.content = String(err);
      assistantMsg.streaming = false;
    }

    unlisten();
  }

  /** Extracts bash commands from AI markdown response. */
  function extractCommands(content: string): ExtractedCommand[] {
    const commands: ExtractedCommand[] = [];
    const regex = /```(?:bash|sh|shell)?\n([\s\S]*?)```/g;
    let match: RegExpExecArray | null;
    while ((match = regex.exec(content)) !== null) {
      const cmd = match[1].trim();
      if (cmd) {
        commands.push({ command: cmd, description: "", dangerous: false });
      }
    }
    return commands;
  }

  /** Clears conversation for a session. */
  function clearConversation(sessionId: string): void {
    conversations.value.delete(sessionId);
  }

  /** Generates a session summary report. */
  async function summarizeSession(
    sessionId: string,
    terminalBuffer: string,
    context: TerminalContext | null,
  ): Promise<void> {
    const conv = getConversation(sessionId);
    const requestId = crypto.randomUUID();

    const summaryMsg: ChatMessage = {
      id: requestId,
      role: "assistant",
      content: "",
      timestamp: new Date().toISOString(),
      streaming: true,
    };
    conv.messages.push(summaryMsg);

    const unlisten = await tauriListen<AiChunk>(
      `ai://summary/${requestId}`,
      (chunk) => {
        const target = conv.messages.find((m) => m.id === requestId);
        if (target) {
          target.content += chunk.text;
          if (chunk.done) target.streaming = false;
        }
      },
    );

    try {
      await tauriInvoke("ai_session_summary", {
        terminalBuffer,
        context,
        requestId,
      });
    } catch (err) {
      summaryMsg.content = String(err);
      summaryMsg.streaming = false;
    }

    unlisten();
  }

  return {
    providers,
    messages,
    explaining,
    autocompleteInFlight,
    conversations,
    loadProviders,
    addProvider,
    updateProvider,
    deleteProvider,
    setDefault,
    checkDanger,
    explainCommand,
    clearMessages,
    getConversation,
    sendChat,
    extractCommands,
    clearConversation,
    summarizeSession,
  };
});
