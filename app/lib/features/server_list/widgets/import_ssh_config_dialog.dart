import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/radius.dart';
import '../../../design/spacing.dart';
import '../../../widgets/button.dart';
import '../../../widgets/checkbox.dart';
import '../../../widgets/dialog.dart';
import '../../../widgets/text_field.dart';
import '../../../widgets/toast.dart';
import '../state/server_provider.dart';

/// A single SSH config entry shown in the preview step.
class _PreviewEntry {
  final String hostAlias;
  final String hostname;
  final int port;
  final String username;
  final String? identityFile;
  bool selected;

  _PreviewEntry({
    required this.hostAlias,
    required this.hostname,
    required this.port,
    required this.username,
    this.identityFile,
    this.selected = true,
  });
}

enum _Step { path, preview, done }

/// Two-step dialog for importing servers from `~/.ssh/config`.
///
/// Step 1 — enter (or confirm) the config file path.
/// Step 2 — review the parsed entries and select which to import.
class ImportSshConfigDialog extends ConsumerStatefulWidget {
  const ImportSshConfigDialog({super.key});

  /// Convenience — shows the dialog.  Returns the number of servers imported,
  /// or `null` if the user cancelled before completing the import.
  static Future<int?> show(BuildContext context) {
    return showTermexDialog<int>(
      context: context,
      title: 'Import SSH Config',
      size: DialogSize.large,
      body: const ImportSshConfigDialog(),
    );
  }

  @override
  ConsumerState<ImportSshConfigDialog> createState() =>
      _ImportSshConfigDialogState();
}

class _ImportSshConfigDialogState
    extends ConsumerState<ImportSshConfigDialog> {
  _Step _step = _Step.path;
  final _pathCtrl = TextEditingController(text: '~/.ssh/config');
  bool _loading = false;
  String? _error;
  List<_PreviewEntry> _entries = [];

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final raw = await bridge.previewSshConfigImport(
        path: _pathCtrl.text.trim().isEmpty ? null : _pathCtrl.text.trim(),
      );
      _entries = raw
          .map((e) => _PreviewEntry(
                hostAlias: e.hostAlias,
                hostname: e.hostname,
                port: e.port,
                username: e.username,
                identityFile: e.identityFile,
              ))
          .toList();

      setState(() {
        _step = _Step.preview;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _import() async {
    final selected =
        _entries.where((e) => e.selected).map((e) => e.hostAlias).toList();
    if (selected.isEmpty) {
      Navigator.of(context, rootNavigator: true).pop(0);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await bridge.importSshConfig(
        path: _pathCtrl.text.trim().isEmpty ? null : _pathCtrl.text.trim(),
        selectedAliases: selected,
      );
      ref.invalidate(serverListProvider);
      final count = result.imported;

      if (mounted) {
        setState(() {
          _step = _Step.done;
          _loading = false;
        });
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(count);
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toggleAll(bool? checked) {
    setState(() {
      for (final e in _entries) {
        e.selected = checked ?? false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.path => _buildPathStep(),
      _Step.preview => _buildPreviewStep(),
      _Step.done => _buildDoneStep(),
    };
  }

  Widget _buildPathStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Termex will parse the SSH config file and let you choose which hosts to import.',
          style: TermexTypography.body.copyWith(
            color: TermexColors.textSecondary,
          ),
        ),
        const SizedBox(height: TermexSpacing.lg),
        TermexTextField(
          label: 'Config file path',
          controller: _pathCtrl,
          placeholder: '~/.ssh/config',
          errorText: _error,
        ),
        const SizedBox(height: TermexSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TermexButton(
              label: 'Cancel',
              variant: ButtonVariant.ghost,
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(null),
            ),
            const SizedBox(width: TermexSpacing.sm),
            TermexButton(
              label: 'Preview',
              variant: ButtonVariant.primary,
              loading: _loading,
              onPressed: _loadPreview,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    final allSelected =
        _entries.isNotEmpty && _entries.every((e) => e.selected);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TermexSpacing.xl),
            child: Center(
              child: Text(
                'No importable hosts found in ${_pathCtrl.text.trim()}.',
                style: TermexTypography.body.copyWith(
                  color: TermexColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          // Select-all header
          _EntryHeader(
            allSelected: allSelected,
            onToggleAll: _toggleAll,
            count: _entries.length,
            selectedCount: _entries.where((e) => e.selected).length,
          ),
          const SizedBox(height: TermexSpacing.sm),
          // Entries list (max 300px, scrollable)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final entry in _entries)
                    _EntryRow(
                      entry: entry,
                      onToggle: (v) =>
                          setState(() => entry.selected = v ?? entry.selected),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: TermexSpacing.sm),
          Text(
            _error!,
            style: TermexTypography.bodySmall
                .copyWith(color: TermexColors.danger),
          ),
        ],
        const SizedBox(height: TermexSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TermexButton(
              label: 'Back',
              variant: ButtonVariant.ghost,
              onPressed: () => setState(() => _step = _Step.path),
            ),
            const SizedBox(width: TermexSpacing.sm),
            TermexButton(
              label: _entries.isEmpty
                  ? 'Close'
                  : 'Import ${_entries.where((e) => e.selected).length} Selected',
              variant: ButtonVariant.primary,
              loading: _loading,
              onPressed: _entries.isEmpty
                  ? () => Navigator.of(context, rootNavigator: true).pop(0)
                  : _import,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TermexSpacing.xl),
      child: Center(
        child: Text(
          'Import complete.',
          style: TermexTypography.body.copyWith(
            color: TermexColors.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EntryHeader extends StatelessWidget {
  final bool allSelected;
  final void Function(bool?) onToggleAll;
  final int count;
  final int selectedCount;

  const _EntryHeader({
    required this.allSelected,
    required this.onToggleAll,
    required this.count,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.md,
        vertical: TermexSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: TermexColors.backgroundTertiary,
        borderRadius: TermexRadius.sm,
      ),
      child: Row(
        children: [
          TermexCheckbox(
            value: allSelected,
            onChanged: onToggleAll,
          ),
          const SizedBox(width: TermexSpacing.sm),
          Expanded(
            child: Text(
              'Host',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Connection',
            style: TermexTypography.caption.copyWith(
              color: TermexColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: TermexSpacing.xl),
          Text(
            '$selectedCount / $count',
            style: TermexTypography.caption.copyWith(
              color: TermexColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final _PreviewEntry entry;
  final void Function(bool?) onToggle;

  const _EntryRow({required this.entry, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!entry.selected),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.md,
            vertical: TermexSpacing.sm,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: TermexColors.border),
            ),
          ),
          child: Row(
            children: [
              TermexCheckbox(value: entry.selected, onChanged: onToggle),
              const SizedBox(width: TermexSpacing.sm),
              Expanded(
                child: Text(
                  entry.hostAlias,
                  style: TermexTypography.body.copyWith(
                    color: entry.selected
                        ? TermexColors.textPrimary
                        : TermexColors.textMuted,
                  ),
                ),
              ),
              Text(
                '${entry.username}@${entry.hostname}:${entry.port}',
                style: TermexTypography.bodySmall.copyWith(
                  color: TermexColors.textSecondary,
                ),
              ),
              if (entry.identityFile != null) ...[
                const SizedBox(width: TermexSpacing.sm),
                Text(
                  '🔑',
                  style: TermexTypography.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
