/// SFTP path bar — breadcrumb navigation for the current directory.
///
/// Displays the path as clickable segments. The user can also edit the path
/// directly by tapping the edit button.
library;

import 'package:flutter/material.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';

/// Breadcrumb + quick-edit path bar.
///
/// [onNavigate] is called with an absolute path string when the user clicks
/// a segment or submits the edit field.
class PathBar extends StatefulWidget {
  final String path;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onRefresh;

  const PathBar({
    super.key,
    required this.path,
    required this.onNavigate,
    this.onRefresh,
  });

  @override
  State<PathBar> createState() => _PathBarState();
}

class _PathBarState extends State<PathBar> {
  bool _editing = false;
  late TextEditingController _editCtrl;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.path);
  }

  @override
  void didUpdateWidget(PathBar old) {
    super.didUpdateWidget(old);
    if (!_editing && old.path != widget.path) {
      _editCtrl.text = widget.path;
    }
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _editing = false);
    final path = _editCtrl.text.trim();
    if (path.isNotEmpty && path != widget.path) {
      widget.onNavigate(path);
    }
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _editCtrl.text = widget.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundTertiary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _editing ? _editField() : _breadcrumb(),
          ),
          // Refresh
          if (!_editing && widget.onRefresh != null)
            _BarBtn(
              icon: Icons.refresh,
              tooltip: '刷新',
              onTap: widget.onRefresh!,
            ),
          // Edit toggle
          _BarBtn(
            icon: _editing ? Icons.close : Icons.edit_outlined,
            tooltip: _editing ? '取消编辑' : '编辑路径',
            onTap: _editing
                ? _cancel
                : () {
                    setState(() => _editing = true);
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _focusNode.requestFocus());
                  },
          ),
        ],
      ),
    );
  }

  Widget _breadcrumb() {
    final parts = _splitPath(widget.path);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < parts.length; i++) ...[
            if (i > 0)
              const Text(
                ' / ',
                style: TextStyle(fontSize: 12, color: TermexColors.textMuted),
              ),
            GestureDetector(
              onTap: () {
                final target = _joinParts(parts.sublist(0, i + 1));
                widget.onNavigate(target);
              },
              child: Text(
                parts[i].isEmpty ? '/' : parts[i],
                style: TermexTypography.monospace.copyWith(
                  fontSize: 12,
                  color: i == parts.length - 1
                      ? TermexColors.textPrimary
                      : TermexColors.primary,
                  decoration: i == parts.length - 1
                      ? null
                      : TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _editField() {
    return TextField(
      controller: _editCtrl,
      focusNode: _focusNode,
      style: TermexTypography.monospace.copyWith(
        fontSize: 12,
        color: TermexColors.textPrimary,
      ),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 4),
        border: InputBorder.none,
      ),
      onSubmitted: (_) => _submit(),
    );
  }

  static List<String> _splitPath(String path) {
    if (path == '/' || path == '~') return [path];
    final normalized = path.startsWith('/')
        ? path
        : path.replaceFirst('~', '/home/user');
    final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
    return ['/', ...parts];
  }

  static String _joinParts(List<String> parts) {
    if (parts.isEmpty) return '/';
    if (parts.length == 1) return parts[0];
    return parts.skip(1).join('/').replaceFirst('', '/');
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _BarBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, size: 15, color: TermexColors.textSecondary),
        ),
      ),
    );
  }
}
