import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../state/ai_stream_provider.dart';
import '../state/conversation_provider.dart' show AiProvider;
import '../state/provider_config_provider.dart';

/// Multi-line text input for AI messages.
///
/// Send on Enter, Shift+Enter inserts newline. Shows character count and
/// cancel button during generation.
class AiInput extends ConsumerStatefulWidget {
  final String? terminalContext;
  const AiInput({super.key, this.terminalContext});

  @override
  ConsumerState<AiInput> createState() => _AiInputState();
}

class _AiInputState extends ConsumerState<AiInput> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _hasText = false);
    await ref.read(aiStreamProvider.notifier).send(
          userContent: text,
          terminalContext: widget.terminalContext,
        );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final streamState = ref.watch(aiStreamProvider);
    final config = ref.watch(providerConfigProvider).activeConfig;
    final isGenerating = streamState.isGenerating;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(top: BorderSide(color: TermexColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rate limit warning
          if (streamState.rateLimitRetryAfterSeconds != null)
            _RateLimitBanner(
              seconds: streamState.rateLimitRetryAfterSeconds!,
              onRetry: () => ref
                  .read(aiStreamProvider.notifier)
                  .retry(terminalContext: widget.terminalContext),
            ),
          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: KeyboardListener(
                  focusNode: FocusNode(skipTraversal: true),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed &&
                        !isGenerating) {
                      _send();
                    }
                  },
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    enabled: !isGenerating,
                    maxLines: 6,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: '询问 AI… (Enter 发送，Shift+Enter 换行)',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: TermexColors.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: TermexColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: TermexColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: TermexColors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: TermexColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isGenerating)
                _CancelButton(
                  onTap: () => ref.read(aiStreamProvider.notifier).cancel(),
                )
              else
                _SendButton(enabled: _hasText, onTap: _send),
            ],
          ),
          const SizedBox(height: 4),
          // Footer: model label
          Text(
            '${_providerLabel(config.provider)} · ${config.model} · 上下文 ${config.contextLines} 行',
            style:
                TextStyle(fontSize: 10, color: TermexColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _providerLabel(AiProvider p) => switch (p) {
        AiProvider.claude => 'Claude',
        AiProvider.openAi => 'OpenAI',
        AiProvider.ollama => 'Ollama',
        AiProvider.localLlama => 'Local AI',
      };
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _SendButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? TermexColors.primary : TermexColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.send_rounded,
          size: 18,
          color: enabled ? Colors.white : TermexColors.textSecondary,
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: TermexColors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TermexColors.danger.withOpacity(0.4)),
        ),
        child: Icon(
          Icons.stop_rounded,
          size: 20,
          color: TermexColors.danger,
        ),
      ),
    );
  }
}

class _RateLimitBanner extends StatelessWidget {
  final int seconds;
  final VoidCallback onRetry;
  const _RateLimitBanner({required this.seconds, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TermexColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TermexColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 14, color: TermexColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '达到速率限制，请 $seconds 秒后重试',
              style: TextStyle(fontSize: 12, color: TermexColors.warning),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              '重试',
              style: TextStyle(
                fontSize: 12,
                color: TermexColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
