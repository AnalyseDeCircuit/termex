import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../../design/colors.dart';
import '../../../design/radius.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../icons/termex_icons.dart';
import '../../../widgets/button.dart';
import '../../../widgets/text_field.dart';
import '../state/app_state_provider.dart';

/// Full-screen master-password unlock overlay.
///
/// Shown at launch when the OS-keychain auto-unlock fails.  The dialog is
/// non-dismissible — the user **must** either unlock or quit the app.
///
/// Calls [verifyMasterPassword] (FRB stub) and updates [dbUnlockedProvider]
/// on success.  After 5 failed attempts the unlock button is rate-limited for
/// [_lockoutDuration].
class MasterPasswordDialog extends ConsumerStatefulWidget {
  const MasterPasswordDialog({super.key});

  @override
  ConsumerState<MasterPasswordDialog> createState() =>
      _MasterPasswordDialogState();
}

class _MasterPasswordDialogState extends ConsumerState<MasterPasswordDialog> {
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);

  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = false;
  String? _errorText;
  int _attempts = 0;
  bool _lockedOut = false;
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startLockout() {
    _lockoutSecondsRemaining = _lockoutDuration.inSeconds;
    _lockedOut = true;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _lockoutSecondsRemaining--;
        if (_lockoutSecondsRemaining <= 0) {
          _lockedOut = false;
          _attempts = 0;
          t.cancel();
        }
      });
    });
  }

  Future<void> _unlock() async {
    final password = _ctrl.text;
    if (password.isEmpty) {
      setState(() => _errorText = 'Please enter your master password.');
      return;
    }
    if (_lockedOut) return;

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final ok = await bridge.verifyMasterPassword(password: password);

      if (!mounted) return;

      if (ok) {
        ref.read(dbUnlockedProvider.notifier).state = true;
        ref.read(unlockAttemptsProvider.notifier).state = 0;
      } else {
        _attempts++;
        ref.read(unlockAttemptsProvider.notifier).state = _attempts;

        final remaining = _maxAttempts - _attempts;
        if (remaining <= 0) {
          _startLockout();
          setState(() {
            _loading = false;
            _errorText = null;
            _ctrl.clear();
          });
        } else {
          setState(() {
            _loading = false;
            _errorText =
                'Incorrect password. $remaining attempt${remaining == 1 ? '' : 's'} remaining.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = 'Unlock failed: ${e.toString()}';
        });
      }
    }
  }

  String _formatLockout() {
    final m = _lockoutSecondsRemaining ~/ 60;
    final s = _lockoutSecondsRemaining % 60;
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TermexColors.backgroundPrimary,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(TermexSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo / app name
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: TermexColors.primary.withOpacity(0.12),
                          borderRadius: TermexRadius.lg,
                        ),
                        child: Center(
                          child: TermexIconWidget(
                            TermexIcons.lock,
                            size: 28,
                            color: TermexColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: TermexSpacing.md),
                      Text(
                        'Termex',
                        style: TermexTypography.heading2.copyWith(
                          color: TermexColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: TermexSpacing.xs),
                      Text(
                        'Enter your master password to unlock the database.',
                        style: TermexTypography.bodySmall.copyWith(
                          color: TermexColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TermexSpacing.xl),

                // Password field
                TermexTextField(
                  label: 'Master password',
                  controller: _ctrl,
                  placeholder: 'Enter master password',
                  obscureText: true,
                  disabled: _lockedOut || _loading,
                  errorText:
                      _lockedOut ? null : _errorText,
                  onSubmitted: _unlock,
                ),

                // Lockout banner
                if (_lockedOut) ...[
                  const SizedBox(height: TermexSpacing.md),
                  _LockoutBanner(timeLeft: _formatLockout()),
                ] else if (_errorText != null &&
                    _attempts >= _maxAttempts - 1) ...[
                  const SizedBox(height: TermexSpacing.sm),
                  _AttemptsWarning(attemptsLeft: _maxAttempts - _attempts),
                ],

                const SizedBox(height: TermexSpacing.xl),

                // Unlock button
                TermexButton(
                  label: _lockedOut
                      ? 'Too many attempts — wait ${_formatLockout()}'
                      : 'Unlock',
                  variant: ButtonVariant.primary,
                  loading: _loading,
                  disabled: _lockedOut,
                  onPressed: _unlock,
                ),

                const SizedBox(height: TermexSpacing.md),

                // Forgot password (destructive — leads to data wipe flow)
                Center(
                  child: GestureDetector(
                    onTap: () => _showForgotPasswordInfo(context),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        'Forgot password?',
                        style: TermexTypography.bodySmall.copyWith(
                          color: TermexColors.textMuted,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordInfo(BuildContext context) {
    // v0.46 will add a proper "wipe & reset" flow.  For now show an info note.
    showDialog<void>(
      context: context,
      builder: (ctx) => _ForgotPasswordInfoDialog(
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

class _LockoutBanner extends StatelessWidget {
  final String timeLeft;
  const _LockoutBanner({required this.timeLeft});

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
        'Too many failed attempts. Please wait $timeLeft before trying again.',
        style: TermexTypography.bodySmall.copyWith(color: TermexColors.danger),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _AttemptsWarning extends StatelessWidget {
  final int attemptsLeft;
  const _AttemptsWarning({required this.attemptsLeft});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$attemptsLeft attempt${attemptsLeft == 1 ? '' : 's'} remaining before lockout.',
      style: TermexTypography.bodySmall.copyWith(color: TermexColors.warning),
      textAlign: TextAlign.center,
    );
  }
}

class _ForgotPasswordInfoDialog extends StatelessWidget {
  final VoidCallback onClose;
  const _ForgotPasswordInfoDialog({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          margin: const EdgeInsets.all(TermexSpacing.xl),
          padding: const EdgeInsets.all(TermexSpacing.xl),
          decoration: BoxDecoration(
            color: TermexColors.backgroundSecondary,
            borderRadius: TermexRadius.lg,
            border: Border.all(color: TermexColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Forgot Master Password',
                style: TermexTypography.heading3.copyWith(
                  color: TermexColors.textPrimary,
                ),
              ),
              const SizedBox(height: TermexSpacing.md),
              Text(
                'The master password cannot be recovered — it is the encryption key '
                'for your local database.\n\n'
                'To reset, you must delete the database file and re-enter all servers. '
                'A "Wipe & Reset" option will be available in Settings (v0.46).',
                style: TermexTypography.body.copyWith(
                  color: TermexColors.textSecondary,
                ),
              ),
              const SizedBox(height: TermexSpacing.xl),
              Align(
                alignment: Alignment.centerRight,
                child: TermexButton(
                  label: 'OK',
                  variant: ButtonVariant.ghost,
                  onPressed: onClose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
