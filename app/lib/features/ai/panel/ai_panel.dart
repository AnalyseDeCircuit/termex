/// AI assistant panel — dual-pane layout: conversation list (left) + chat (right).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../provider/provider_switcher.dart';
import 'ai_input.dart';
import 'conversation_list.dart';
import 'conversation_view.dart';

class AiPanel extends ConsumerStatefulWidget {
  /// Terminal scrollback context passed to AI prompts.
  final String? terminalContext;
  /// Called when user asks to run a command extracted from AI output.
  final void Function(String command)? onRunCommand;

  const AiPanel({
    super.key,
    this.terminalContext,
    this.onRunCommand,
  });

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  bool _showConversationList = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TermexColors.backgroundPrimary,
      child: Column(
        children: [
          _Toolbar(
            showList: _showConversationList,
            onToggleList: () =>
                setState(() => _showConversationList = !_showConversationList),
          ),
          Expanded(
            child: Row(
              children: [
                // Conversation sidebar
                if (_showConversationList)
                  SizedBox(
                    width: 180,
                    child: Container(
                      decoration: BoxDecoration(
                        border:
                            Border(right: BorderSide(color: TermexColors.border)),
                        color: TermexColors.backgroundSecondary,
                      ),
                      child: const ConversationList(),
                    ),
                  ),
                // Chat area
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: ConversationView(
                          onRunCommand: widget.onRunCommand,
                        ),
                      ),
                      AiInput(terminalContext: widget.terminalContext),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final bool showList;
  final VoidCallback onToggleList;

  const _Toolbar({required this.showList, required this.onToggleList});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleList,
            child: Icon(
              showList ? Icons.format_list_bulleted : Icons.view_sidebar_outlined,
              size: 16,
              color: TermexColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AI 助手',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: TermexColors.textPrimary,
            ),
          ),
          const Spacer(),
          const ProviderSwitcher(),
        ],
      ),
    );
  }
}
