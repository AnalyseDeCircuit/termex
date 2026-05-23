/// Host key verification dialog (TOFU — Trust On First Use).
///
/// Shown when connecting to a server whose host key is not yet in the
/// known_hosts store.  The user can accept (store permanently), accept once
/// (this session only), or reject (abort connection).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/colors.dart';
import '../../../../design/typography.dart';

/// Result returned by [showHostKeyDialog].
enum HostKeyDecision {
  /// Store the key permanently and proceed.
  acceptAlways,

  /// Proceed this session only; do not persist.
  acceptOnce,

  /// Abort the connection attempt.
  reject,
}

/// Host key information to display to the user.
class HostKeyInfo {
  final String host;
  final int port;
  final String keyType;
  final String fingerprint;

  const HostKeyInfo({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
  });
}

/// Shows the TOFU host key dialog and returns the user's [HostKeyDecision].
///
/// Returns [HostKeyDecision.reject] if the user dismisses the dialog without
/// making a choice.
Future<HostKeyDecision> showHostKeyDialog(
  BuildContext context,
  HostKeyInfo info,
) async {
  final result = await showDialog<HostKeyDecision>(
    context: context,
    barrierDismissible: false,
    builder: (_) => HostKeyDialog(info: info),
  );
  return result ?? HostKeyDecision.reject;
}

/// The host key TOFU dialog widget.
class HostKeyDialog extends StatelessWidget {
  final HostKeyInfo info;

  const HostKeyDialog({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TermexColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: TermexColors.warning, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: TermexColors.warning, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '未知主机密钥',
                    style: TermexTypography.monospace.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: TermexColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Warning body
              Text(
                '无法验证主机 ${info.host}:${info.port} 的真实性。\n'
                '服务器的 ${info.keyType} 密钥指纹为：',
                style: const TextStyle(
                  fontSize: 13,
                  color: TermexColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              // Fingerprint block
              _FingerprintBlock(fingerprint: info.fingerprint),
              const SizedBox(height: 16),
              const Text(
                '请通过其他途径验证此指纹后再继续。若您无法验证，'
                '请选择"拒绝"以中止连接。',
                style: TextStyle(
                  fontSize: 12,
                  color: TermexColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Button(
                    label: '拒绝',
                    color: TermexColors.danger,
                    onTap: () =>
                        Navigator.of(context).pop(HostKeyDecision.reject),
                  ),
                  const SizedBox(width: 8),
                  _Button(
                    label: '仅本次接受',
                    color: TermexColors.neutral,
                    onTap: () =>
                        Navigator.of(context).pop(HostKeyDecision.acceptOnce),
                  ),
                  const SizedBox(width: 8),
                  _Button(
                    label: '永久信任',
                    color: TermexColors.primary,
                    onTap: () => Navigator.of(context)
                        .pop(HostKeyDecision.acceptAlways),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FingerprintBlock extends StatelessWidget {
  final String fingerprint;

  const _FingerprintBlock({required this.fingerprint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TermexColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TermexColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              fingerprint,
              style: TermexTypography.monospace.copyWith(
                fontSize: 12,
                color: TermexColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: '复制指纹',
            child: GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: fingerprint)),
              child: const Icon(
                Icons.copy_outlined,
                size: 15,
                color: TermexColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Button({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
