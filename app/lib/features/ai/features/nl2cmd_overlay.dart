import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import 'nl2cmd_engine.dart';

/// Floating overlay for natural-language → shell command conversion.
///
/// Triggered by a keyboard shortcut or context menu item in the terminal.
class Nl2CmdOverlay extends ConsumerStatefulWidget {
  final String? currentDirectory;
  final String? osHint;
  /// Called with the generated command when the user accepts it.
  final void Function(String command)? onAccept;
  final VoidCallback onClose;

  const Nl2CmdOverlay({
    super.key,
    this.currentDirectory,
    this.osHint,
    this.onAccept,
    required this.onClose,
  });

  @override
  ConsumerState<Nl2CmdOverlay> createState() => _Nl2CmdOverlayState();
}

class _Nl2CmdOverlayState extends ConsumerState<Nl2CmdOverlay> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _isLoading = false;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });
    try {
      await ref.read(nl2cmdEngineProvider).convert(
            description: text,
            currentDirectory: widget.currentDirectory,
            osHint: widget.osHint,
          );
      // Result is in the active conversation's last message.
      // For simplicity, show a placeholder.
      setState(() {
        _result = '(已发送到 AI 对话)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TermexColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TermexColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal, size: 14, color: TermexColors.primary),
                const SizedBox(width: 6),
                Text(
                  '自然语言 → 命令',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TermexColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Icon(Icons.close, size: 14, color: TermexColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              focusNode: _focus,
              decoration: InputDecoration(
                hintText: '描述你想做什么，例如：查找大于 100MB 的文件',
                hintStyle:
                    TextStyle(fontSize: 12, color: TermexColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: TermexColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: TermexColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: TermexColors.primary),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              style: TextStyle(fontSize: 13, color: TermexColors.textPrimary),
              onSubmitted: (_) => _convert(),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TermexColors.primary,
                  ),
                ),
              )
            else if (_error != null)
              Text(
                _error!,
                style:
                    TextStyle(fontSize: 11, color: TermexColors.danger),
              )
            else if (_result != null)
              _ResultRow(
                command: _result!,
                onAccept: widget.onAccept != null
                    ? () {
                        widget.onAccept!(_result!);
                        widget.onClose();
                      }
                    : null,
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onClose,
                  child: Text('取消',
                      style:
                          TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _convert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TermexColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(64, 32),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('生成'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String command;
  final VoidCallback? onAccept;

  const _ResultRow({required this.command, this.onAccept});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TermexColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TermexColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              command,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: TermexColors.textPrimary,
              ),
            ),
          ),
          if (onAccept != null)
            GestureDetector(
              onTap: onAccept,
              child: Icon(Icons.send_rounded,
                  size: 14, color: TermexColors.primary),
            ),
        ],
      ),
    );
  }
}
