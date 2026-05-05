import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/team_provider.dart';

Future<bool> showTeamPassphraseDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _PassphraseDialog(),
      ) ??
      false;
}

class _PassphraseDialog extends ConsumerStatefulWidget {
  const _PassphraseDialog();

  @override
  ConsumerState<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends ConsumerState<_PassphraseDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await ref.read(teamProvider.notifier).unlockPassphrase(_ctrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _loading = false;
        _error = '口令不正确，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TermexColors.backgroundSecondary,
      title: Row(
        children: [
          Icon(Icons.group_outlined, size: 18, color: TermexColors.primary),
          const SizedBox(width: 8),
          Text(
            '解锁团队协作',
            style: TextStyle(fontSize: 15, color: TermexColors.textPrimary),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请输入团队共享口令以解锁团队协作功能。',
              style: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              obscureText: _obscure,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '团队口令',
                hintStyle: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
                errorText: _error,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                    color: TermexColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: TermexColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: TermexColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              style: TextStyle(fontSize: 13, color: TermexColors.textPrimary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('取消', style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: TermexColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 32),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: _loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('解锁'),
        ),
      ],
    );
  }
}
