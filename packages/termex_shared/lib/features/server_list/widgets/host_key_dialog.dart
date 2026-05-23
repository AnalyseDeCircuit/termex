import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/radius.dart';
import '../../../design/spacing.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialog.dart';
import '../../../icons/termex_icons.dart';

/// Whether this is a first-time host trust prompt or a key-changed warning.
enum HostKeyDialogMode { newHost, keyChanged }

/// Data passed to [HostKeyDialog].
class HostKeyDialogData {
  final HostKeyDialogMode mode;
  final String host;
  final int port;
  final String fingerprint;
  final String? oldFingerprint;
  final String keyType;

  const HostKeyDialogData({
    required this.mode,
    required this.host,
    required this.port,
    required this.fingerprint,
    this.oldFingerprint,
    required this.keyType,
  });
}

/// Dialog shown when verifying a remote host key.
///
/// In [HostKeyDialogMode.newHost] mode it asks the user to trust the server.
/// In [HostKeyDialogMode.keyChanged] mode it warns about a potential MITM.
class HostKeyDialog extends StatelessWidget {
  final HostKeyDialogData data;
  final void Function(bool trusted) onResult;

  const HostKeyDialog({
    super.key,
    required this.data,
    required this.onResult,
  });

  /// Convenience — wraps the widget in [showTermexDialog] and resolves [onResult].
  static Future<bool> show(BuildContext context, HostKeyDialogData data) async {
    bool result = false;
    await showTermexDialog<void>(
      context: context,
      title: data.mode == HostKeyDialogMode.newHost
          ? 'Unknown Host'
          : 'Host Key Changed',
      size: DialogSize.medium,
      barrierDismissible: false,
      body: HostKeyDialog(
        data: data,
        onResult: (trusted) {
          result = trusted;
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = data.mode == HostKeyDialogMode.keyChanged;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header banner
        _Banner(
          isWarning: isWarning,
          host: data.host,
          port: data.port,
        ),
        const SizedBox(height: TermexSpacing.lg),
        // Key type label
        Text(
          'Key type: ${data.keyType}',
          style: TermexTypography.bodySmall.copyWith(
            color: TermexColors.textSecondary,
          ),
        ),
        const SizedBox(height: TermexSpacing.sm),
        if (isWarning && data.oldFingerprint != null) ...[
          _FingerprintRow(
            label: 'Old fingerprint',
            fingerprint: data.oldFingerprint!,
            highlight: TermexColors.danger,
          ),
          const SizedBox(height: TermexSpacing.sm),
          _FingerprintRow(
            label: 'New fingerprint',
            fingerprint: data.fingerprint,
            highlight: TermexColors.warning,
          ),
        ] else ...[
          _FingerprintRow(
            label: 'Fingerprint',
            fingerprint: data.fingerprint,
          ),
        ],
        const SizedBox(height: TermexSpacing.lg),
        if (!isWarning)
          Text(
            'Verify the fingerprint with the server administrator before connecting.',
            style: TermexTypography.bodySmall.copyWith(
              color: TermexColors.textMuted,
            ),
          )
        else
          _WarningNote(),
        const SizedBox(height: TermexSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TermexButton(
              label: 'Cancel',
              variant: ButtonVariant.ghost,
              onPressed: () => onResult(false),
            ),
            const SizedBox(width: TermexSpacing.sm),
            TermexButton(
              label: isWarning ? 'Accept New Key' : 'Trust & Connect',
              variant: isWarning ? ButtonVariant.danger : ButtonVariant.primary,
              onPressed: () => onResult(true),
            ),
          ],
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final bool isWarning;
  final String host;
  final int port;

  const _Banner({
    required this.isWarning,
    required this.host,
    required this.port,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? TermexColors.danger : TermexColors.primary;
    final bgColor = color.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.all(TermexSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: TermexRadius.md,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TermexIconWidget(
            isWarning ? TermexIcons.warning : TermexIcons.info,
            size: 16,
            color: color,
          ),
          const SizedBox(width: TermexSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWarning
                      ? 'Host key mismatch for $host:$port'
                      : 'First connection to $host:$port',
                  style: TermexTypography.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: TermexSpacing.xs),
                Text(
                  isWarning
                      ? 'The host key has changed since your last connection. '
                          'This could indicate a man-in-the-middle attack.'
                      : 'This is the first time you are connecting to this host. '
                          'Please verify the fingerprint below.',
                  style: TermexTypography.bodySmall.copyWith(
                    color: TermexColors.textSecondary,
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

class _FingerprintRow extends StatelessWidget {
  final String label;
  final String fingerprint;
  final Color? highlight;

  const _FingerprintRow({
    required this.label,
    required this.fingerprint,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TermexTypography.caption.copyWith(
            color: TermexColors.textMuted,
          ),
        ),
        const SizedBox(height: TermexSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.md,
            vertical: TermexSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: TermexColors.backgroundTertiary,
            borderRadius: TermexRadius.sm,
            border: highlight != null
                ? Border.all(color: highlight!.withOpacity(0.5))
                : Border.all(color: TermexColors.border),
          ),
          child: Text(
            fingerprint,
            style: TermexTypography.monospace.copyWith(
              fontSize: 12,
              color: highlight ?? TermexColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _WarningNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.sm),
      decoration: BoxDecoration(
        color: TermexColors.danger.withOpacity(0.08),
        borderRadius: TermexRadius.sm,
        border: Border.all(color: TermexColors.danger.withOpacity(0.3)),
      ),
      child: Text(
        'Only accept the new key if you are certain the server was legitimately re-keyed.',
        style: TermexTypography.bodySmall.copyWith(
          color: TermexColors.danger,
        ),
      ),
    );
  }
}
