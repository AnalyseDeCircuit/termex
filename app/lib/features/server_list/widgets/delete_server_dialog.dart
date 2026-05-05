import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/spacing.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialog.dart';
import '../state/server_provider.dart';

/// Confirmation dialog for deleting a server.
///
/// Shows the server name and two actions: Cancel and Delete (danger styling).
class DeleteServerDialog extends ConsumerStatefulWidget {
  final String serverId;
  final String serverName;

  const DeleteServerDialog({
    super.key,
    required this.serverId,
    required this.serverName,
  });

  /// Show the delete confirmation.  Returns [true] if the server was deleted.
  static Future<bool> show(
    BuildContext context, {
    required String serverId,
    required String serverName,
  }) async {
    final result = await showTermexDialog<bool>(
      context: context,
      title: 'Delete Server',
      size: DialogSize.small,
      body: DeleteServerDialog(serverId: serverId, serverName: serverName),
    );
    return result ?? false;
  }

  @override
  ConsumerState<DeleteServerDialog> createState() => _DeleteServerDialogState();
}

class _DeleteServerDialogState extends ConsumerState<DeleteServerDialog> {
  bool _deleting = false;

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await ref.read(serverListProvider.notifier).deleteServer(widget.serverId);
      if (mounted) Navigator.of(context, rootNavigator: true).pop(true);
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichText(
          text: TextSpan(
            style: TermexTypography.body.copyWith(
              color: TermexColors.textSecondary,
            ),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: widget.serverName,
                style: TermexTypography.body.copyWith(
                  color: TermexColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(
                text:
                    '? This action cannot be undone and all saved credentials for this server will be removed.',
              ),
            ],
          ),
        ),
        const SizedBox(height: TermexSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TermexButton(
              label: 'Cancel',
              variant: ButtonVariant.ghost,
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
            ),
            const SizedBox(width: TermexSpacing.sm),
            TermexButton(
              label: 'Delete',
              variant: ButtonVariant.danger,
              loading: _deleting,
              onPressed: _delete,
            ),
          ],
        ),
      ],
    );
  }
}
