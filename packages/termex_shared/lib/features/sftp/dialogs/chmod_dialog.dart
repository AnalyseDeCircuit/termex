/// chmod (file permissions) dialog for SFTP.
library;

import 'package:flutter/material.dart';

import '../../../design/colors.dart';
import '../../../l10n/app_localizations.dart';

/// Shows the chmod dialog and returns the new octal permission string (e.g.
/// "755"), or `null` if the user cancels.
Future<String?> showChmodDialog(
  BuildContext context, {
  required String fileName,
  String initialPermissions = '644',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => ChmodDialog(
      fileName: fileName,
      initialPermissions: initialPermissions,
    ),
  );
}

class ChmodDialog extends StatefulWidget {
  final String fileName;
  final String initialPermissions;

  const ChmodDialog({
    super.key,
    required this.fileName,
    required this.initialPermissions,
  });

  @override
  State<ChmodDialog> createState() => _ChmodDialogState();
}

class _ChmodDialogState extends State<ChmodDialog> {
  // Each bit: owner-r, owner-w, owner-x, group-r, group-w, group-x, other-r, other-w, other-x
  late List<bool> _bits;
  late TextEditingController _octalCtrl;

  @override
  void initState() {
    super.initState();
    _bits = _octalToBits(widget.initialPermissions);
    _octalCtrl = TextEditingController(text: _bitsToOctal(_bits));
  }

  @override
  void dispose() {
    _octalCtrl.dispose();
    super.dispose();
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_octalCtrl.text),
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
