/// AI assistant panel — single-column chat surface; the conversation
/// history list is presented as a floating popover anchored to the panel's
/// left edge so it never squeezes the chat area.
///
/// v0.79.56: when no provider is configured (`hasAnyConfigured == false`),
/// the panel renders an onboarding gate instead of the chat surface.
/// Previously the default `activeProvider = claude` made the panel look
/// operational with no API key set, so the first user message would hit
/// a cryptic "API key missing" error at the bridge. Now: explicit gate
/// with a "Go to Settings" CTA wired through [onConfigureAi].
///
/// v0.77.0 (PC final parity): replaced the inline 180px sidebar with an
/// overlay popover. User feedback: "希望能浮动在AI面板的左侧外边框浮出
/// 显示，不能干扰AI对话框的显示区域".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/clickable.dart';
import '../provider/provider_switcher.dart';
import '../state/provider_config_provider.dart';
import 'ai_input.dart';
import 'conversation_list.dart';
import 'conversation_view.dart';

class AiPanel extends ConsumerStatefulWidget {
  /// Terminal scrollback context passed to AI prompts.
  final String? terminalContext;
  /// Called when user asks to run a command extracted from AI output.
  final void Function(String command)? onRunCommand;
  /// v0.79.56: invoked from the onboarding gate's primary CTA. Shells
  /// wire this to whatever navigation gets the user into Settings → AI
  /// (mobile: `setState(() => _index = settingsTabIndex)`; desktop:
  /// open the settings modal). When `null`, the CTA renders as a static
  /// instruction so the user still knows where to go.
  final VoidCallback? onConfigureAi;

  const AiPanel({
    super.key,
    this.terminalContext,
    this.onRunCommand,
    this.onConfigureAi,
  });

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  /// LayerLink anchored to the panel's left edge so the conversation list
  /// popover can position itself outside the panel without measuring the
  /// global screen rect (which would drift on window-resize / split-view).
  final LayerLink _historyAnchor = LayerLink();
  OverlayEntry? _historyEntry;

  @override
  void dispose() {
    // v0.79.62: only remove the overlay entry directly; never call
    // `_closeHistory` here. `_closeHistory` calls `setState`, but by
    // the time `dispose` runs the Element has entered the `defunct`
    // lifecycle and `setState` asserts (`_lifecycleState !=
    // _ElementLifecycle.defunct`). Surfaced when MobileShell switched
    // from rebuild-on-tab-change to IndexedStack — AiPanel is now
    // always built, so widget-test teardown trips this dispose path.
    _historyEntry?.remove();
    _historyEntry = null;
    super.dispose();
  }

  bool get _historyOpen => _historyEntry != null;

  void _toggleHistory() {
    if (_historyOpen) {
      _closeHistory();
    } else {
      _openHistory();
    }
  }

  void _openHistory() {
    _historyEntry = OverlayEntry(
      builder: (_) => _HistoryPopover(
        anchor: _historyAnchor,
        onDismiss: _closeHistory,
      ),
    );
    Overlay.of(context).insert(_historyEntry!);
    setState(() {});
  }

  void _closeHistory() {
    _historyEntry?.remove();
    _historyEntry = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyConfigured =
        ref.watch(providerConfigProvider).hasAnyConfigured;
    return CompositedTransformTarget(
      link: _historyAnchor,
      child: Container(
        color: context.colors.backgroundPrimary,
        child: Column(
          children: [
            _Toolbar(
              historyOpen: _historyOpen,
              onToggleHistory: _toggleHistory,
              showProviderSwitcher: hasAnyConfigured,
            ),
            Expanded(
              child: hasAnyConfigured
                  ? Column(
                      children: [
                        Expanded(
                          child: ConversationView(
                            onRunCommand: widget.onRunCommand,
                          ),
                        ),
                        AiInput(terminalContext: widget.terminalContext),
                      ],
                    )
                  : _AiOnboardingGate(onConfigure: widget.onConfigureAi),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rendered in place of the chat surface when no AI provider is
/// configured. Centered single card with brain icon + headline + body +
/// primary CTA. The CTA falls back to a static instruction when no
/// [onConfigure] callback is wired so the user still knows where to go.
class _AiOnboardingGate extends StatelessWidget {
  final VoidCallback? onConfigure;
  const _AiOnboardingGate({this.onConfigure});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 48,
                color: context.colors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.aiOnboardingHeadline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.aiOnboardingBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              if (onConfigure != null)
                Clickable(
                  behavior: HitTestBehavior.opaque,
                  onTap: onConfigure,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.aiOnboardingCta,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.backgroundSecondary,
                    border: Border.all(color: context.colors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l10n.aiOnboardingFallbackHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating popover that renders the [ConversationList] hanging off the
/// AI panel's left edge. Tapping outside dismisses; the list itself
/// dismisses after the user picks a conversation.
class _HistoryPopover extends StatelessWidget {
  final LayerLink anchor;
  final VoidCallback onDismiss;

  const _HistoryPopover({required this.anchor, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Click-outside scrim — invisible, full-screen, dismiss on tap.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        // Popover panel — 220×360 hung off the AI panel's top-left corner,
        // shifted left so it visually "pops out" of the left border.
        CompositedTransformFollower(
          link: anchor,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.topRight,
          offset: const Offset(-4, 36),
          child: Material(
            color: const Color(0x00000000),
            child: Container(
              width: 220,
              height: 360,
              decoration: BoxDecoration(
                color: context.colors.backgroundSecondary,
                border: Border.all(color: context.colors.border),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 12,
                    offset: Offset(-2, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: ConversationList(onSelect: onDismiss),
            ),
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  final bool historyOpen;
  final VoidCallback onToggleHistory;
  final bool showProviderSwitcher;

  const _Toolbar({
    required this.historyOpen,
    required this.onToggleHistory,
    this.showProviderSwitcher = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          // History trigger — opens the conversation popover to the left
          // of the panel. Icon flips between bulleted list (closed) and
          // a filled-bar indicator (open) for visual continuity.
          Tooltip(
            message: '历史对话',
            child: Clickable(
              onTap: onToggleHistory,
              child: Icon(
                historyOpen
                    ? Icons.view_sidebar
                    : Icons.format_list_bulleted,
                size: 16,
                color: historyOpen
                    ? context.colors.primary
                    : context.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AI 助手',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          const Spacer(),
          if (showProviderSwitcher) const ProviderSwitcher(),
        ],
      ),
    );
  }
}
