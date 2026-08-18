import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../widgets/bottom_sheet.dart';
import '../../../widgets/list_item.dart';
import '../../../widgets/loading.dart';
import '../state/server_provider.dart';

/// Displays the currently selected jump host and lets the user pick a
/// different one via a BottomSheet server picker.
///
/// v1 limitation: single hop only. Multi-hop chains set from the desktop
/// are displayed as read-only beyond the first entry.
class JumpHostPicker extends ConsumerWidget {
  final String? selectedJumpHostId;

  /// The server being edited — excluded from the picker to prevent loops.
  final String? excludeServerId;

  final ValueChanged<String?> onChanged;

  const JumpHostPicker({
    super.key,
    required this.selectedJumpHostId,
    required this.excludeServerId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(serverListProvider);
    final selectedServer = serversAsync.valueOrNull
        ?.where((s) => s.id == selectedJumpHostId)
        .firstOrNull;

    final subtitleText = selectedJumpHostId == null
        ? '直连（无跳板机）'
        : selectedServer?.name ?? '加载中…';

    return TermexListItem(
      title: '跳板机',
      subtitle: subtitleText,
      trailing: _ChevronIcon(),
      onTap: () async {
        final picked = await showTermexBottomSheet<String?>(
          context: context,
          child: _JumpHostPickerSheet(
            excludeServerId: excludeServerId,
            currentId: selectedJumpHostId,
            onPick: (id) => Navigator.of(context, rootNavigator: true).pop(id),
          ),
        );
        if (picked != null || picked == null && selectedJumpHostId != null) {
          onChanged(picked);
        }
      },
    );
  }
}

class _JumpHostPickerSheet extends ConsumerWidget {
  final String? excludeServerId;
  final String? currentId;
  final ValueChanged<String?> onPick;

  const _JumpHostPickerSheet({
    required this.excludeServerId,
    required this.currentId,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = TermexColorScheme.dark();
    final serversAsync = ref.watch(serverListProvider);

    return Padding(
      padding: const EdgeInsets.only(
        left: TermexSpacing.md,
        right: TermexSpacing.md,
        bottom: TermexSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TermexSpacing.md),
            child: Text(
              '选择跳板机',
              style: TermexTypography.heading3.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          TermexListItem(
            title: '直连（无跳板机）',
            selected: currentId == null,
            onTap: () => onPick(null),
          ),
          const SizedBox(height: TermexSpacing.xs),
          serversAsync.when(
            data: (servers) {
              final candidates = servers
                  .where((s) => s.id != excludeServerId)
                  .toList();
              if (candidates.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(TermexSpacing.md),
                  child: Text(
                    '暂无可用服务器',
                    style: TermexTypography.body.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: candidates.map((s) => TermexListItem(
                  title: s.name,
                  subtitle: '${s.username}@${s.host}:${s.port}',
                  selected: s.id == currentId,
                  onTap: () => onPick(s.id),
                )).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(TermexSpacing.lg),
                child: TermexLoading(size: 24),
              ),
            ),
            error: (e, _) => Text(
              e.toString(),
              style: TermexTypography.body.copyWith(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChevronIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(
      const IconData(0xe5cc, fontFamily: 'MaterialIcons'),
      size: 18,
      color: context.colors.textMuted,
    );
  }
}
