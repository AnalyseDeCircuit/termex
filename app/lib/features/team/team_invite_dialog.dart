import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/team_provider.dart';

Future<void> showTeamInviteDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (_) => const _InviteDialog(),
  );
}

class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog();

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final _emailCtrl = TextEditingController();
  TeamRole _role = TeamRole.member;
  String? _generatedCode;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final code = await ref
        .read(teamProvider.notifier)
        .generateInvite(_emailCtrl.text.trim(), _role);
    if (mounted) setState(() {
      _loading = false;
      _generatedCode = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TermexColors.backgroundSecondary,
      title: Text('邀请成员', style: TextStyle(fontSize: 15, color: TermexColors.textPrimary)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label('邮箱地址'),
            const SizedBox(height: 4),
            TextField(
              controller: _emailCtrl,
              decoration: _inputDec('user@example.com'),
              style: TextStyle(fontSize: 13, color: TermexColors.textPrimary),
            ),
            const SizedBox(height: 12),
            _Label('角色'),
            const SizedBox(height: 4),
            DropdownButtonFormField<TeamRole>(
              value: _role,
              dropdownColor: TermexColors.backgroundSecondary,
              decoration: _inputDec(null).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              items: [TeamRole.admin, TeamRole.member, TeamRole.viewer]
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(
                          TeamMember(id: '', email: '', role: r, joinedAt: '').roleLabel,
                          style: TextStyle(fontSize: 13, color: TermexColors.textPrimary),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _role = v!),
            ),
            if (_generatedCode != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TermexColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: TermexColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('邀请码（7天有效）',
                              style: TextStyle(fontSize: 10, color: TermexColors.textSecondary)),
                          const SizedBox(height: 4),
                          SelectableText(
                            _generatedCode!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: TermexColors.primary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, size: 16, color: TermexColors.textSecondary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _generatedCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制邀请码')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('关闭', style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
        ),
        if (_generatedCode == null)
          ElevatedButton(
            onPressed: _loading ? null : _generate,
            style: ElevatedButton.styleFrom(
              backgroundColor: TermexColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 32),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: _loading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('生成邀请码'),
          ),
      ],
    );
  }

  InputDecoration _inputDec(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
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
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(fontSize: 11, color: TermexColors.textSecondary),
      );
}
