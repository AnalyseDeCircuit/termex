import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/spacing.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/features/cloud/cloud_panel.dart';
import 'package:termex_shared/features/proxy/proxy_panel.dart';
import 'package:termex_shared/features/recording/recording_list_panel.dart';
import 'package:termex_shared/features/server_list/widgets/server_form_dialog.dart';
import 'package:termex_shared/features/server_list/widgets/server_tree.dart';
import 'package:termex_shared/features/sidebar_search.dart';
import 'package:termex_shared/features/server_list/widgets/import_ssh_config_dialog.dart';
import 'package:termex_shared/features/server_list/models/group_dto.dart';
import 'package:termex_shared/features/server_list/state/group_provider.dart';
import 'package:termex_shared/features/settings/settings_page.dart';
import 'package:termex_shared/features/snippet/snippet_library.dart';
import 'package:termex_shared/features/snippet/widgets/snippet_category_filter.dart';
import 'package:termex_shared/icons/termex_icons.dart';
import 'package:termex_shared/widgets/button.dart';
import 'package:termex_shared/widgets/dialog.dart';
import 'package:termex_shared/widgets/text_field.dart';
import 'sidebar_termex_menu.dart';

/// Sidebar pane categories. v0.77.0 PC final parity restored `recordings`
/// and `cloud` to match the legacy Tauri/Vue baseline — both ship in OSS
/// (recording is fully functional; cloud surfaces ECS favourites plus
/// empty-state hints for k8s/SSM, which match the legacy OSS behaviour
/// where heavy integrations are gated behind the `private` Cargo feature).
enum SidebarCategory { servers, proxies, snippets, recordings, cloud }

final sidebarCategoryProvider =
    StateProvider<SidebarCategory>((_) => SidebarCategory.servers);

/// Left sidebar — header (Termex dropdown + 5 view tabs in one row) + content.
///
/// Layout matches Tauri's `Sidebar.vue`:
///   ┌──────────────────────────────────────────────┐
///   │ [ Termex ▾ ]   ▤   ⊕  ⟨⟩  ⏺  ☁              │ 36px
///   ├──────────────────────────────────────────────┤
///   │  search…                                      │
///   │  ▾ Group                                       │
///   │    server                                      │
///   └──────────────────────────────────────────────┘
class DesktopSidebar extends ConsumerWidget {
  /// Called when the user activates a server in the tree (double-click).
  final void Function(String serverId)? onConnectServer;

  /// Called when the user selects "打开 SFTP" from the server context menu.
  final void Function(String serverId)? onConnectServerWithSftp;

  const DesktopSidebar({
    super.key,
    this.onConnectServer,
    this.onConnectServerWithSftp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = ref.watch(sidebarCategoryProvider);
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border(right: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        children: [
          _SidebarHeader(
            active: cat,
            onSelect: (c) =>
                ref.read(sidebarCategoryProvider.notifier).state = c,
          ),
          // v0.79.59 alignment with mobile: ProxyPanel + SnippetLibrary
          // removed their inline "+ Add" affordances expecting the host
          // shell to paint a title + add button. Mobile's
          // `_TerminalTabHeader` did this; the desktop sidebar didn't.
          // This `_CategorySectionHeader` closes the gap so servers /
          // proxies / snippets all have a discoverable "+" trigger.
          _CategorySectionHeader(
            category: cat,
            onAdd: () => _runCategoryAdd(context, ref, cat),
          ),
          Expanded(
            child: switch (cat) {
              SidebarCategory.servers => ServerTree(
                  onServerConnect: onConnectServer,
                  onServerOpenSftp: onConnectServerWithSftp,
                ),
              SidebarCategory.proxies => const ProxyPanel(),
              SidebarCategory.snippets => const SnippetLibrary(),
              SidebarCategory.recordings => const RecordingListPanel(),
              SidebarCategory.cloud => const CloudPanel(),
            },
          ),
        ],
      ),
    );
  }
}

// ─── Header (single row: Termex dropdown + 5 view tabs) ────────────────────

class _SidebarHeader extends ConsumerStatefulWidget {
  final SidebarCategory active;
  final void Function(SidebarCategory) onSelect;

  const _SidebarHeader({required this.active, required this.onSelect});

  @override
  ConsumerState<_SidebarHeader> createState() => _SidebarHeaderState();
}

class _SidebarHeaderState extends ConsumerState<_SidebarHeader> {
  final LayerLink _termexLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _menuEntry?.remove();
    super.dispose();
  }

  void _openTermexMenu() {
    if (_menuEntry != null) return;
    _menuEntry = OverlayEntry(
      builder: (ctx) => SidebarTermexMenu(
        layerLink: _termexLink,
        onCommand: _runCommand,
        onDismiss: _closeMenu,
      ),
    );
    Overlay.of(context).insert(_menuEntry!);
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  Future<void> _runCommand(SidebarTermexCommand cmd) async {
    _closeMenu();
    switch (cmd) {
      case SidebarTermexCommand.newConnection:
        await ServerFormDialog.show(context);
        break;
      case SidebarTermexCommand.newGroup:
        await _showNewGroupDialog();
        break;
      case SidebarTermexCommand.importConfig:
        // TODO: full import — for now route to SSH config import.
        await ImportSshConfigDialog.show(context);
        break;
      case SidebarTermexCommand.exportConfig:
        // TODO: surface export action.
        break;
      case SidebarTermexCommand.importSshConfig:
        await ImportSshConfigDialog.show(context);
        break;
      case SidebarTermexCommand.settings:
        _openSettingsDialog(context);
        break;
    }
  }

  Future<void> _showNewGroupDialog() async {
    final controller = TextEditingController();
    final ok = await showTermexDialog<bool>(
      context: context,
      title: '新建分组',
      size: DialogSize.small,
      body: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请输入分组名称',
              style: TermexTypography.body.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: TermexSpacing.sm),
            TermexTextField(
              controller: controller,
              autofocus: true,
              placeholder: '例如：生产环境',
            ),
          ],
        ),
      ),
      actions: [
        Builder(
          builder: (ctx) => TermexButton(
            label: '取消',
            variant: ButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
          ),
        ),
        Builder(
          builder: (ctx) => TermexButton(
            label: '保存',
            variant: ButtonVariant.primary,
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
          ),
        ),
      ],
    );
    final name = controller.text.trim();
    if (ok == true && name.isNotEmpty) {
      await ref.read(groupListProvider.notifier).createGroup(GroupInput(
            name: name,
            color: '#3B82F6',
            icon: 'folder',
            sortOrder: 0,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.xs),
      child: Row(
        children: [
          // Termex dropdown trigger (pill button on the left)
          CompositedTransformTarget(
            link: _termexLink,
            child: _TermexPillButton(onTap: _openTermexMenu),
          ),
          const Spacer(),
          // 5 view tabs (right) — flat, mutually exclusive, underline-active
          _ViewTabButton(
            tooltip: 'Servers',
            painter: const _ServersIconPainter(),
            active: widget.active == SidebarCategory.servers,
            onTap: () => widget.onSelect(SidebarCategory.servers),
          ),
          _ViewTabButton(
            tooltip: 'Proxies',
            painter: const _ProxiesIconPainter(),
            active: widget.active == SidebarCategory.proxies,
            onTap: () => widget.onSelect(SidebarCategory.proxies),
          ),
          _ViewTabButton(
            tooltip: 'Snippets',
            painter: const _SnippetsIconPainter(),
            active: widget.active == SidebarCategory.snippets,
            onTap: () => widget.onSelect(SidebarCategory.snippets),
          ),
          _ViewTabButton(
            tooltip: 'Recordings',
            painter: const _RecordingsIconPainter(),
            active: widget.active == SidebarCategory.recordings,
            onTap: () => widget.onSelect(SidebarCategory.recordings),
          ),
          _ViewTabButton(
            tooltip: 'Cloud',
            painter: const _CloudIconPainter(),
            active: widget.active == SidebarCategory.cloud,
            onTap: () => widget.onSelect(SidebarCategory.cloud),
          ),
        ],
      ),
    );
  }
}

/// Dispatch the section-header "+" button to the right "add" flow for
/// each category. Mirrors mobile's `_TerminalTabHeader` onAdd switch.
/// Recordings + Cloud have no add action (read-only / Pro-stub).
void _runCategoryAdd(
  BuildContext context,
  WidgetRef ref,
  SidebarCategory category,
) {
  switch (category) {
    case SidebarCategory.servers:
      ServerFormDialog.show(context);
      break;
    case SidebarCategory.proxies:
      AddProxyDialog.show(context);
      break;
    case SidebarCategory.snippets:
      SnippetLibrary.startNew(context);
      break;
    case SidebarCategory.recordings:
    case SidebarCategory.cloud:
      // No add action — sections render their own (or are stubbed).
      break;
  }
}

/// Section header (~28 px) sitting between the category-tab row and the
/// active panel. Shows the category's ZH label on the left and a "+"
/// Add button on the right when the category supports adding new
/// entities. v0.79.59 aligned mobile + desktop both painting host-side
/// add affordances; this widget closes the desktop gap.
class _CategorySectionHeader extends ConsumerWidget {
  final SidebarCategory category;
  final VoidCallback onAdd;

  const _CategorySectionHeader({
    required this.category,
    required this.onAdd,
  });

  String get _label => switch (category) {
        SidebarCategory.servers => '服务器',
        SidebarCategory.proxies => '代理',
        SidebarCategory.snippets => 'Snippet',
        SidebarCategory.recordings => '会话录制',
        SidebarCategory.cloud => '云端',
      };

  bool get _hasAdd =>
      category == SidebarCategory.servers ||
      category == SidebarCategory.proxies ||
      category == SidebarCategory.snippets;

  /// Panel key for the shared search-visibility state, or null for
  /// categories with nothing to filter. Cloud is a sectioned status view
  /// rather than a list of user-owned entries, so it has no search.
  String? get _searchPanel => switch (category) {
        SidebarCategory.servers => SidebarSearchPanel.servers,
        SidebarCategory.proxies => SidebarSearchPanel.proxies,
        SidebarCategory.snippets => SidebarSearchPanel.snippets,
        SidebarCategory.recordings => SidebarSearchPanel.recordings,
        SidebarCategory.cloud => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = _searchPanel;
    final searchVisible =
        panel != null && ref.watch(sidebarSearchVisibleProvider(panel));

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          Text(
            _label,
            style: TermexTypography.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          // Snippet categories sit right after the title instead of on a
          // dedicated chip row inside the panel. Renders nothing until at
          // least one snippet is tagged.
          if (category == SidebarCategory.snippets) ...[
            const SizedBox(width: 8),
            const Flexible(child: SnippetCategoryFilter()),
          ],
          const Spacer(),
          if (panel != null)
            _SectionIconButton(
              icon: TermexIcons.search,
              tooltip: searchVisible ? '关闭搜索' : '搜索',
              active: searchVisible,
              onTap: () => ref
                  .read(sidebarSearchVisibleProvider(panel).notifier)
                  .update((v) => !v),
            ),
          if (panel != null && _hasAdd) const SizedBox(width: 2),
          if (_hasAdd)
            _SectionIconButton(
              icon: TermexIcons.add,
              tooltip: '新建',
              onTap: onAdd,
            ),
        ],
      ),
    );
  }
}

/// Small icon affordance reused by [_CategorySectionHeader]. Sized to
/// sit naturally inside a 28-px header without dominating it.
class _SectionIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Renders in the accent colour regardless of hover — used by the search
  /// toggle so an open search field stays visibly the reason the list is
  /// filtered.
  final bool active;

  const _SectionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  State<_SectionIconButton> createState() => _SectionIconButtonState();
}

class _SectionIconButtonState extends State<_SectionIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _hovered || widget.active;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlighted
                  ? context.colors.primary.withValues(alpha: 0.15)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(3),
            ),
            child: TermexIconWidget(
              widget.icon,
              size: 12,
              color: highlighted
                  ? context.colors.primary
                  : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

void _openSettingsDialog(BuildContext context) {
  showTermexDialog<void>(
    context: context,
    title: '设置',
    size: DialogSize.large,
    body: const SizedBox(
      width: 680,
      height: 500,
      child: SettingsPage(embedded: true),
    ),
  );
}

// ─── Termex pill button ────────────────────────────────────────────────────

class _TermexPillButton extends StatefulWidget {
  final VoidCallback onTap;
  const _TermexPillButton({required this.onTap});

  @override
  State<_TermexPillButton> createState() => _TermexPillButtonState();
}

class _TermexPillButtonState extends State<_TermexPillButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? context.colors.backgroundTertiary : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Termex',
                style: TermexTypography.bodySmall.copyWith(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              TermexIconWidget(
                TermexIcons.chevronDown,
                size: 10,
                color: context.colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── View tab buttons (custom-painted icons matching Tauri SVGs) ──────────

class _ViewTabButton extends StatefulWidget {
  final String tooltip;
  final CustomPainter painter;
  final bool active;
  final VoidCallback onTap;

  const _ViewTabButton({
    required this.tooltip,
    required this.painter,
    required this.active,
    required this.onTap,
  });

  @override
  State<_ViewTabButton> createState() => _ViewTabButtonState();
}

class _ViewTabButtonState extends State<_ViewTabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? context.colors.primary
        : (_hovered ? context.colors.textPrimary : context.colors.textMuted);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: 28,
            height: 36,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CustomPaint(
                      painter: _RecolorWrapper(widget.painter, color),
                    ),
                  ),
                ),
                if (widget.active)
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: 0,
                    child: Container(height: 2, color: context.colors.primary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Wraps the icon painters so we can recolour them per-state.
class _RecolorWrapper extends CustomPainter {
  final CustomPainter inner;
  final Color color;
  _RecolorWrapper(this.inner, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    inner.paint(canvas, size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = color
        ..blendMode = BlendMode.srcIn,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RecolorWrapper old) =>
      old.color != color || old.inner != inner;
}

// ─── Icon painters (mirror Tauri Sidebar.vue SVG paths exactly) ───────────

class _ServersIconPainter extends CustomPainter {
  const _ServersIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0; // viewBox 0 0 24 24
    final stroke = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = const Color(0xFF000000);

    // Two stacked rounded rectangles (server racks).
    final rrTop = RRect.fromRectAndRadius(
      Rect.fromLTWH(2 * s, 2 * s, 20 * s, 8 * s),
      Radius.circular(2 * s),
    );
    final rrBot = RRect.fromRectAndRadius(
      Rect.fromLTWH(2 * s, 14 * s, 20 * s, 8 * s),
      Radius.circular(2 * s),
    );
    canvas.drawRRect(rrTop, stroke);
    canvas.drawRRect(rrBot, stroke);
    canvas.drawCircle(Offset(6 * s, 6 * s), 1 * s, fill);
    canvas.drawCircle(Offset(6 * s, 18 * s), 1 * s, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ProxiesIconPainter extends CustomPainter {
  const _ProxiesIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(Offset(12 * s, 12 * s), 10 * s, stroke);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(12 * s, 12 * s),
        width: 8 * s,
        height: 20 * s,
      ),
      stroke,
    );
    canvas.drawLine(Offset(2 * s, 12 * s), Offset(22 * s, 12 * s), stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _SnippetsIconPainter extends CustomPainter {
  const _SnippetsIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final right = Path()
      ..moveTo(16 * s, 18 * s)
      ..lineTo(22 * s, 12 * s)
      ..lineTo(16 * s, 6 * s);
    final left = Path()
      ..moveTo(8 * s, 6 * s)
      ..lineTo(2 * s, 12 * s)
      ..lineTo(8 * s, 18 * s);
    canvas.drawPath(right, stroke);
    canvas.drawPath(left, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Recording (filled inner dot + outer ring, matches Tauri SVG) ─────────

class _RecordingsIconPainter extends CustomPainter {
  const _RecordingsIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = const Color(0xFF000000);

    canvas.drawCircle(Offset(12 * s, 12 * s), 10 * s, stroke);
    canvas.drawCircle(Offset(12 * s, 12 * s), 4 * s, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Cloud (outline cloud, matches Tauri SVG) ─────────────────────────────

class _CloudIconPainter extends CustomPainter {
  const _CloudIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Approx Lucide "cloud" path:
    //  M17.5 19a4.5 4.5 0 0 0 1.5-8.75
    //  A6 6 0 0 0 7 8a4 4 0 0 0-2 7.5
    //  Z
    final path = Path()
      ..moveTo(17.5 * s, 19 * s)
      ..cubicTo(20 * s, 19 * s, 22 * s, 16 * s, 22 * s, 13 * s)
      ..cubicTo(22 * s, 11 * s, 20.5 * s, 9.5 * s, 19 * s, 10.25 * s)
      ..cubicTo(18.5 * s, 6 * s, 13 * s, 4.5 * s, 9.5 * s, 6.5 * s)
      ..cubicTo(7.5 * s, 7.5 * s, 6.5 * s, 9 * s, 7 * s, 11 * s)
      ..cubicTo(4.5 * s, 11 * s, 3 * s, 13.5 * s, 3.5 * s, 15.5 * s)
      ..cubicTo(4 * s, 17.5 * s, 5.5 * s, 19 * s, 8 * s, 19 * s)
      ..close();
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
