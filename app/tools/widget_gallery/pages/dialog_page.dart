import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';
import 'package:termex/widgets/button.dart';
import 'package:termex/widgets/dialog.dart';
import 'package:termex/widgets/toast.dart';

class DialogPage extends StatelessWidget {
  const DialogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return TermexToastOverlay(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dialog',
              style: TermexTypography.heading3.copyWith(
                color: TermexColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            _Section(
              title: 'Normal Dialog',
              child: TermexButton(
                label: 'Open Dialog',
                onPressed: () => _showNormalDialog(context),
              ),
            ),
            const SizedBox(height: 32),
            _Section(
              title: 'Confirm Dialog',
              child: TermexButton(
                label: 'Open Confirm',
                variant: ButtonVariant.secondary,
                onPressed: () => _showConfirmDialog(context),
              ),
            ),
            const SizedBox(height: 32),
            _Section(
              title: 'Danger Confirm Dialog',
              child: TermexButton(
                label: 'Open Danger Confirm',
                variant: ButtonVariant.danger,
                onPressed: () => _showDangerDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNormalDialog(BuildContext context) {
    showTermexDialog(
      context: context,
      title: 'Server Details',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This is a normal dialog with arbitrary body content. You can place any widget here.',
            style: TermexTypography.body.copyWith(
              color: TermexColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Host: 192.168.1.100',
            style: TermexTypography.bodySmall.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          Text(
            'Port: 22',
            style: TermexTypography.bodySmall.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (ctx) => TermexButton(
            label: 'Close',
            variant: ButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
          ),
        ),
        Builder(
          builder: (ctx) => TermexButton(
            label: 'Connect',
            onPressed: () {
              Navigator.of(ctx, rootNavigator: true).pop();
              ToastController.success('Connected successfully');
            },
          ),
        ),
      ],
    );
  }

  void _showConfirmDialog(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Disconnect Session',
      message: 'Are you sure you want to disconnect the current session?',
      confirmLabel: 'Disconnect',
      cancelLabel: 'Cancel',
    );
    if (confirmed == true) {
      ToastController.success('Session disconnected');
    }
  }

  void _showDangerDialog(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete Server',
      message:
          'This will permanently delete the server and all associated data. This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (confirmed == true) {
      ToastController.success('Server deleted');
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TermexTypography.heading4.copyWith(
            color: TermexColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
