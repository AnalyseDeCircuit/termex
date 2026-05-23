import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../../design/tokens.dart';

/// Settings → Security tab. Mirrors `SecurityTab.vue` in the Tauri build:
/// shows the platform-keychain protection mode + cached credential count
/// + an explainer card.
class SecurityTab extends ConsumerStatefulWidget {
  const SecurityTab({super.key});

  @override
  ConsumerState<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends ConsumerState<SecurityTab> {
  bridge.SecurityStatus? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final s = await bridge.securityStatus();
      if (mounted) setState(() => _status = s);
    } catch (_) {
      if (mounted) setState(() => _status = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _platformLabel {
    if (Platform.isMacOS) return 'macOS Keychain';
    if (Platform.isWindows) return 'Windows Credential Manager';
    return 'Secret Service (GNOME / KDE)';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('加载中…',
                  style: TextStyle(
                      fontSize: 12, color: TermexColors.textMuted)),
            ),
          )
        else if (_status != null) ...[
          _ProtectionCard(
            available: _status!.keychainAvailable,
            platform: _platformLabel,
          ),
          const SizedBox(height: 12),
          _CredentialCountCard(count: _status!.keychainCredentialCount),
          const SizedBox(height: 16),
          _HowItWorksCard(),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('无法读取安全状态',
                  style: TextStyle(
                      fontSize: 12, color: TermexColors.textMuted)),
            ),
          ),
      ],
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  final bool available;
  final String platform;
  const _ProtectionCard({required this.available, required this.platform});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: TermexColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: available
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEAB308),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '密钥保护模式',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: TermexColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            available
                ? '已使用 $platform 安全存储凭据。Termex 仅在启动时读取一次主密钥条目。'
                : '系统密钥库不可用，已回退到本地加密（AES-256-GCM + Argon2id）。',
            style: const TextStyle(
              fontSize: 12,
              color: TermexColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialCountCard extends StatelessWidget {
  final int count;
  const _CredentialCountCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: TermexColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '已保存的凭据',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '包括 SSH 密码、SSH 私钥口令、AI Provider API Key',
            style: TextStyle(fontSize: 11, color: TermexColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hints = [
      '凭据从未以明文写入数据库 — 仅保存系统密钥库的引用 ID',
      '主密钥条目在每次启动时只读取一次，避免反复弹出系统密码框',
      'GDPR 数据擦除会同步清空密钥库中所有 Termex 条目',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '工作原理',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: TermexColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        for (final h in hints)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 6),
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: TermexColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    h,
                    style: const TextStyle(
                      fontSize: 11,
                      color: TermexColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
