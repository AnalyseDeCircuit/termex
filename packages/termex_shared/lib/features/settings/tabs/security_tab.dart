import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(l10n.settingsSecurityLoading,
                  style: const TextStyle(
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(l10n.settingsSecurityLoadError,
                  style: const TextStyle(
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
    final l10n = AppLocalizations.of(context);
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
              Text(
                l10n.settingsSecurityProtectionTitle,
                style: const TextStyle(
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
                ? l10n.settingsSecurityProtectionActive(platform)
                : l10n.settingsSecurityProtectionFallback,
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: TermexColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsSecuritySavedCredentials,
            style: const TextStyle(
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
          Text(
            l10n.settingsSecurityCredentialTypes,
            style: const TextStyle(fontSize: 11, color: TermexColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hints = [
      l10n.settingsSecurityHint1,
      l10n.settingsSecurityHint2,
      l10n.settingsSecurityHint3,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsSecurityHowItWorks,
          style: const TextStyle(
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
