import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';
import 'package:termex/widgets/button.dart';
import 'package:termex/widgets/toast.dart';

class ToastPage extends StatelessWidget {
  const ToastPage({super.key});

  @override
  Widget build(BuildContext context) {
    return TermexToastOverlay(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Toast',
              style: TermexTypography.heading3.copyWith(
                color: TermexColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            _Section(
              title: 'Toast Types',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  TermexButton(
                    label: 'Info',
                    variant: ButtonVariant.secondary,
                    onPressed: () => ToastController.info(
                      'This is an info message',
                    ),
                  ),
                  TermexButton(
                    label: 'Success',
                    variant: ButtonVariant.secondary,
                    onPressed: () => ToastController.success(
                      'Operation completed successfully',
                    ),
                  ),
                  TermexButton(
                    label: 'Warning',
                    variant: ButtonVariant.secondary,
                    onPressed: () => ToastController.warning(
                      'Please review before continuing',
                    ),
                  ),
                  TermexButton(
                    label: 'Error',
                    variant: ButtonVariant.danger,
                    onPressed: () => ToastController.error(
                      'Connection failed: timeout after 30s',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _Section(
              title: 'Custom Duration',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  TermexButton(
                    label: 'Quick (1s)',
                    variant: ButtonVariant.secondary,
                    onPressed: () => ToastController.info(
                      'Quick toast',
                      duration: const Duration(seconds: 1),
                    ),
                  ),
                  TermexButton(
                    label: 'Long (8s)',
                    variant: ButtonVariant.secondary,
                    onPressed: () => ToastController.warning(
                      'This warning stays for 8 seconds',
                      duration: const Duration(seconds: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
