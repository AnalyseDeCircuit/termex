import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/recording_provider.dart';

/// Session recording management panel — list + start/stop/export controls.
class RecordingPanel extends ConsumerStatefulWidget {
  final String sessionId;

  const RecordingPanel({super.key, required this.sessionId});

  @override
  ConsumerState<RecordingPanel> createState() => _RecordingPanelState();
}

class _RecordingPanelState extends ConsumerState<RecordingPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordingProvider.notifier).loadRecordings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingProvider);

    return Container(
      color: TermexColors.backgroundPrimary,
      child: Column(
        children: [
          _Header(state: state, sessionId: widget.sessionId),
          if (state.error != null)
            _ErrorBanner(message: state.error!),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : state.recordings.isEmpty
                    ? _EmptyState(
                        sessionId: widget.sessionId,
                        isRecording: state.isRecording)
                    : _RecordingList(
                        recordings: state.recordings,
                        activeId: state.activeRecordingId),
          ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final RecordingState state;
  final String sessionId;

  const _Header({required this.state, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(recordingProvider.notifier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record,
              size: 16, color: TermexColors.danger),
          const SizedBox(width: 8),
          const Text('Recordings',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: TermexColors.textPrimary)),
          const Spacer(),
          if (state.isRecording)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: TermexColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Recording',
                    style: TextStyle(
                        fontSize: 11, color: TermexColors.danger)),
                const SizedBox(width: 12),
                _Btn(
                  label: 'Stop',
                  color: TermexColors.danger,
                  onTap: () => n.stopRecording(),
                ),
              ],
            )
          else
            _Btn(
              label: 'Record',
              icon: Icons.fiber_manual_record,
              color: TermexColors.danger,
              onTap: () => _startDialog(context, ref),
            ),
        ],
      ),
    );
  }

  void _startDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: const Text('New Recording',
            style: TextStyle(color: TermexColors.textPrimary, fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: TermexColors.textPrimary, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Optional title…',
            hintStyle: TextStyle(color: TermexColors.textMuted),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: TermexColors.border)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: TermexColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: TermexColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(recordingProvider.notifier).startRecording(
                    sessionId,
                    title: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
                  );
            },
            child: const Text('Start',
                style: TextStyle(color: TermexColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ─── Recording List ───────────────────────────────────────────────────────────

class _RecordingList extends StatelessWidget {
  final List<RecordingEntry> recordings;
  final String? activeId;

  const _RecordingList({required this.recordings, this.activeId});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: recordings.length,
      itemBuilder: (_, i) => _RecordingRow(
        entry: recordings[i],
        isActive: recordings[i].id == activeId,
      ),
    );
  }
}

class _RecordingRow extends ConsumerWidget {
  final RecordingEntry entry;
  final bool isActive;

  const _RecordingRow({required this.entry, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? TermexColors.danger : TermexColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.radio_button_on : Icons.play_circle_outline,
            size: 20,
            color: isActive ? TermexColors.danger : TermexColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.displayTitle,
                    style: const TextStyle(
                        fontSize: 13, color: TermexColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${entry.durationLabel}  •  ${entry.sizeLabel}  •  ${_fmtDate(entry.createdAt)}',
                  style: const TextStyle(
                      fontSize: 11, color: TermexColors.textSecondary),
                ),
              ],
            ),
          ),
          if (!isActive) ...[
            _IconBtn(
              icon: Icons.file_download_outlined,
              tooltip: 'Export',
              onTap: () => _export(context, ref),
            ),
            const SizedBox(width: 4),
            _IconBtn(
              icon: Icons.delete_outline,
              tooltip: 'Delete',
              color: TermexColors.danger,
              onTap: () => _delete(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  String _p(int v) => v.toString().padLeft(2, '0');

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final destPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export recording',
      fileName: '${entry.displayTitle.replaceAll(RegExp(r"\s+"), "_")}.cast',
      type: FileType.custom,
      allowedExtensions: const ['cast'],
    );
    if (destPath == null) return;
    await ref.read(recordingProvider.notifier).exportRecording(entry.id, destPath);
  }

  void _delete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: const Text('Delete Recording',
            style: TextStyle(color: TermexColors.textPrimary, fontSize: 14)),
        content: Text(
          'Delete "${entry.displayTitle}"? This cannot be undone.',
          style: const TextStyle(
              color: TermexColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: TermexColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(recordingProvider.notifier).deleteRecording(entry.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: TermexColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends ConsumerWidget {
  final String sessionId;
  final bool isRecording;

  const _EmptyState({required this.sessionId, required this.isRecording});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined,
              size: 36, color: TermexColors.textMuted),
          const SizedBox(height: 12),
          const Text('No recordings yet',
              style: TextStyle(
                  color: TermexColors.textSecondary, fontSize: 13)),
          if (!isRecording) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => ref
                  .read(recordingProvider.notifier)
                  .startRecording(sessionId),
              icon: const Icon(Icons.fiber_manual_record, size: 14),
              label: const Text('Start recording'),
              style: TextButton.styleFrom(foregroundColor: TermexColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared ───────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: TermexColors.danger.withOpacity(0.15),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 14, color: TermexColors.danger),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12, color: TermexColors.danger))),
        ]),
      );
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;

  const _Btn(
      {required this.label,
      this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12),
              const SizedBox(width: 4),
            ],
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    this.color = TermexColors.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );
}
