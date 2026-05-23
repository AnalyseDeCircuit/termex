import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialog.dart';

/// Static, scrollable privacy-policy display. Mirrors the Tauri
/// PrivacyDialog.vue — pulls condensed copy from docs/privacy-policy.md.
/// Triggered from the Help → Privacy Policy menu item.
class PrivacyPolicyDialog extends StatelessWidget {
  const PrivacyPolicyDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showTermexDialog<void>(
        context: context,
        title: AppLocalizations.of(context).privacyDialogTitle,
        size: DialogSize.large,
        body: const PrivacyPolicyDialog(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 680,
      height: 480,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.lg,
          vertical: TermexSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.privacyEffectiveDate,
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
              ),
            ),
            const SizedBox(height: TermexSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(
                      heading: l10n.privacySec1Heading,
                      body: l10n.privacySec1Body,
                    ),
                    _Section(
                      heading: l10n.privacySec2Heading,
                      body: l10n.privacySec2Body,
                    ),
                    _Section(
                      heading: l10n.privacySec3Heading,
                      body: l10n.privacySec3Body,
                    ),
                    _Section(
                      heading: l10n.privacySec4Heading,
                      body: l10n.privacySec4Body,
                    ),
                    _Section(
                      heading: l10n.privacySec5Heading,
                      body: l10n.privacySec5Body,
                    ),
                    _Section(
                      heading: l10n.privacySec6Heading,
                      body: l10n.privacySec6Body,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TermexSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TermexButton(
                  label: l10n.privacyClose,
                  variant: ButtonVariant.primary,
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String heading;
  final String body;
  const _Section({required this.heading, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TermexSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TermexTypography.body.copyWith(
              color: TermexColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TermexTypography.bodySmall.copyWith(
              color: TermexColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
