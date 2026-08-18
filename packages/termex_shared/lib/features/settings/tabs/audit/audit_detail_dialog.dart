/// Detail dialog for a single audit log entry.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../widgets/clickable.dart';
import '../../state/settings_provider.dart';

Future<void> showAuditDetailDialog(
  BuildContext context,
  AuditLogEntry entry,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AuditDetailDialog(entry: entry),
  );
}

class _AuditDetailDialog extends StatelessWidget {
  final AuditLogEntry entry;

  const _AuditDetailDialog({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: context.colors.backgroundSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(entry: entry),
            Divider(height: 1, color: context.colors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(label: 'ID', value: entry.id),
                  const SizedBox(height: 10),
                  _Field(label: l10n.auditFieldEventType, value: entry.eventType),
                  const SizedBox(height: 10),
                  _Field(
                    label: l10n.auditFieldTime,
                    value: _formatDate(entry.createdAt),
                  ),
                  const SizedBox(height: 10),
                  _DetailField(detail: entry.detail),
                ],
              ),
            ),
            Divider(height: 1, color: context.colors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: entry.detail));
                    },
                    child: Text(l10n.auditCopyDetail,
                        style: TextStyle(
                            color: context.colors.textSecondary, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonClose,
                        style: TextStyle(color: context.colors.primary, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)} '
        '${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
  }
}

class _TitleBar extends StatelessWidget {
  final AuditLogEntry entry;
  const _TitleBar({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 16, color: context.colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.auditDetailTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          Clickable(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close,
                size: 16, color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
                fontSize: 11,
                color: context.colors.textMuted,
                fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                fontSize: 12, color: context.colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _DetailField extends StatelessWidget {
  final String detail;
  const _DetailField({required this.detail});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.auditFieldDetail,
          style: TextStyle(
              fontSize: 11,
              color: context.colors.textMuted,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: context.colors.border),
          ),
          child: SelectableText(
            detail,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: context.colors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
