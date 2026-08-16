/// Git Sync conflict resolver dialog (v0.47 spec §7.3).
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

enum ConflictResolution { keepLocal, useRemote, terminalMergeTool }

Future<ConflictResolution?> showConflictResolver(
  BuildContext context,
  List<String> conflicts,
) {
  final l10n = AppLocalizations.of(context);
  return showDialog<ConflictResolution>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.gitConflictTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.gitConflictFilesLabel,
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: conflicts.length,
                itemBuilder: (ctx, i) => Text('  • ${conflicts[i]}',
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'monospace')),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.gitConflictStrategyLabel,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.commonCancel),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(ctx, ConflictResolution.terminalMergeTool),
          child: Text(l10n.gitConflictResolveInTerminal),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, ConflictResolution.useRemote),
          child: Text(l10n.gitConflictUseRemote),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, ConflictResolution.keepLocal),
          child: Text(l10n.gitConflictKeepLocal),
        ),
      ],
    ),
  );
}
