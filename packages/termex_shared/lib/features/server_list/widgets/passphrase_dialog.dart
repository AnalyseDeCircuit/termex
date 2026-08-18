/// Modal dialog that asks the user for the passphrase of an encrypted
/// private key. Used by the SSH connection flow when keychain has no
/// stored passphrase but auth fails with an "encrypted key" indicator.
library;

import 'package:flutter/material.dart';

import '../../../design/colors.dart';

/// Result returned by [showPassphraseDialog].
class PassphraseResult {
  final String passphrase;

  /// When true, the caller should persist the passphrase to the OS keychain
  /// so subsequent connects skip this prompt.
  final bool remember;

  const PassphraseResult({required this.passphrase, required this.remember});
}

/// Shows the passphrase prompt. Returns null when the user cancels.
Future<PassphraseResult?> showPassphraseDialog(
  BuildContext context, {
  required String serverName,
  String? keyPath,
}) {
  return showDialog<PassphraseResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PassphraseDialog(
      serverName: serverName,
      keyPath: keyPath,
    ),
  );
}

class _PassphraseDialog extends StatefulWidget {
  final String serverName;
  final String? keyPath;

  const _PassphraseDialog({required this.serverName, this.keyPath});

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _controller = TextEditingController();
  bool _remember = true;
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) return;
    Navigator.of(context).pop(
      PassphraseResult(
        passphrase: _controller.text,
        remember: _remember,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.backgroundSecondary,
      title: Text(
        '私钥已加密',
        style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '为「${widget.serverName}」输入私钥口令以完成连接。',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (widget.keyPath != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.keyPath!,
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: _obscure,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: '私钥口令',
                hintStyle: TextStyle(color: context.colors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                    color: context.colors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  splashRadius: 16,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.colors.primary),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                Text(
                  '记住此口令（存储到系统 Keychain）',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            '连接',
            style: TextStyle(color: context.colors.primary),
          ),
        ),
      ],
    );
  }
}
