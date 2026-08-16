/// chmod (file permissions) dialog for SFTP.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/colors.dart';
import '../../../l10n/app_localizations.dart';

/// Result of the chmod/chown dialog. `mode` is the octal permission string
/// (e.g. "755"). `uid`/`gid` are the numeric owner/group; they are non-null
/// only when the user changed them from their initial values, so the caller
/// can skip a redundant chown call.
class ChmodResult {
  final String mode;
  final int? uid;
  final int? gid;
  const ChmodResult({required this.mode, this.uid, this.gid});
}

/// Shows the chmod/chown dialog and returns a [ChmodResult], or `null` if
/// the user cancels. GitHub issue #24: extended from permissions-only to
/// also edit numeric owner (UID) / group (GID) via SFTP SETSTAT.
Future<ChmodResult?> showChmodDialog(
  BuildContext context, {
  required String fileName,
  String initialPermissions = '644',
  int? initialUid,
  int? initialGid,
}) {
  return showDialog<ChmodResult>(
    context: context,
    builder: (_) => ChmodDialog(
      fileName: fileName,
      initialPermissions: initialPermissions,
      initialUid: initialUid,
      initialGid: initialGid,
    ),
  );
}

class ChmodDialog extends StatefulWidget {
  final String fileName;
  final String initialPermissions;
  final int? initialUid;
  final int? initialGid;

  const ChmodDialog({
    super.key,
    required this.fileName,
    required this.initialPermissions,
    this.initialUid,
    this.initialGid,
  });

  @override
  State<ChmodDialog> createState() => _ChmodDialogState();
}

class _ChmodDialogState extends State<ChmodDialog> {
  // Each bit: owner-r, owner-w, owner-x, group-r, group-w, group-x, other-r, other-w, other-x
  late List<bool> _bits;
  late TextEditingController _octalCtrl;
  late TextEditingController _uidCtrl;
  late TextEditingController _gidCtrl;

  @override
  void initState() {
    super.initState();
    _bits = _octalToBits(widget.initialPermissions);
    _octalCtrl = TextEditingController(text: _bitsToOctal(_bits));
    _uidCtrl = TextEditingController(
        text: widget.initialUid?.toString() ?? '');
    _gidCtrl = TextEditingController(
        text: widget.initialGid?.toString() ?? '');
  }

  @override
  void dispose() {
    _octalCtrl.dispose();
    _uidCtrl.dispose();
    _gidCtrl.dispose();
    super.dispose();
  }

  /// Builds the result; uid/gid are included only when the user changed
  /// them from the initial values, so an unchanged owner triggers no chown.
  ChmodResult _buildResult() {
    final uid = int.tryParse(_uidCtrl.text.trim());
    final gid = int.tryParse(_gidCtrl.text.trim());
    final uidChanged = uid != null && uid != widget.initialUid;
    final gidChanged = gid != null && gid != widget.initialGid;
    return ChmodResult(
      mode: _octalCtrl.text,
      uid: (uidChanged || gidChanged) ? (uid ?? widget.initialUid) : null,
      gid: (uidChanged || gidChanged) ? (gid ?? widget.initialGid) : null,
    );
  }

  void _toggleBit(int index) {
    setState(() {
      _bits[index] = !_bits[index];
      _octalCtrl.text = _bitsToOctal(_bits);
    });
  }

  void _onOctalChanged(String value) {
    if (value.length == 3 && RegExp(r'^[0-7]{3}$').hasMatch(value)) {
      setState(() => _bits = _octalToBits(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: TermexColors.backgroundSecondary,
      title: Text(
        l10n.sftpChmodTitleNamed(widget.fileName),
        style: const TextStyle(
            color: TermexColors.textPrimary, fontSize: 15),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PermGroup(
                label: l10n.sftpChmodOwner,
                bits: _bits,
                offset: 0,
                onToggle: _toggleBit),
            const SizedBox(height: 8),
            _PermGroup(
                label: l10n.sftpChmodGroup,
                bits: _bits,
                offset: 3,
                onToggle: _toggleBit),
            const SizedBox(height: 8),
            _PermGroup(
                label: l10n.sftpChmodOthers,
                bits: _bits,
                offset: 6,
                onToggle: _toggleBit),
            const SizedBox(height: 16),
            // Octal input
            Row(
              children: [
                Text(l10n.sftpChmodOctalShort,
                    style: const TextStyle(
                        color: TermexColors.textSecondary)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _octalCtrl,
                    style: const TextStyle(
                        color: TermexColors.textPrimary, fontSize: 16),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onOctalChanged,
                    maxLength: 3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Ownership (chown) — numeric UID / GID. GitHub issue #24.
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.sftpChmodOwnershipSection,
                  style: const TextStyle(
                      fontSize: 11, color: TermexColors.textSecondary)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: l10n.sftpChmodOwner,
                    controller: _uidCtrl,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    label: l10n.sftpChmodGroup,
                    controller: _gidCtrl,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_buildResult()),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }

  static List<bool> _octalToBits(String octal) {
    if (octal.length < 3) octal = octal.padLeft(3, '0');
    return octal.split('').take(3).expand((ch) {
      final n = int.tryParse(ch) ?? 0;
      return [n & 4 != 0, n & 2 != 0, n & 1 != 0];
    }).toList();
  }

  static String _bitsToOctal(List<bool> bits) {
    String digit(int i) {
      int v = 0;
      if (bits[i]) v += 4;
      if (bits[i + 1]) v += 2;
      if (bits[i + 2]) v += 1;
      return '$v';
    }
    return '${digit(0)}${digit(3)}${digit(6)}';
  }
}

/// Compact labelled numeric field for the owner (UID) / group (GID) inputs.
class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _NumberField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: TermexColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              color: TermexColors.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _PermGroup extends StatelessWidget {
  final String label;
  final List<bool> bits;
  final int offset;
  final ValueChanged<int> onToggle;

  const _PermGroup({
    required this.label,
    required this.bits,
    required this.offset,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final permLabels = [
      l10n.sftpChmodRead,
      l10n.sftpChmodWrite,
      l10n.sftpChmodExec,
    ];
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: const TextStyle(
                  color: TermexColors.textSecondary, fontSize: 13)),
        ),
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilterChip(
              label: Text(permLabels[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: bits[offset + i]
                        ? TermexColors.textPrimary
                        : TermexColors.textMuted,
                  )),
              selected: bits[offset + i],
              onSelected: (_) => onToggle(offset + i),
              selectedColor: TermexColors.primary.withOpacity(0.3),
              backgroundColor: TermexColors.backgroundTertiary,
              side: BorderSide(
                color: bits[offset + i]
                    ? TermexColors.primary
                    : TermexColors.border,
              ),
            ),
          ),
      ],
    );
  }
}
