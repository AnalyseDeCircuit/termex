import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/clickable.dart';
import '../state/settings_provider.dart';

/// Settings → Highlights tab. Mirrors `HighlightsTab.vue`:
/// list of keyword rules with pattern, regex/case-sensitive/enabled toggles,
/// foreground + background color pickers, and per-row delete.
///
/// The full rule list lives inside `AppSettings.keywordRulesJson` as a single
/// JSON-encoded string — that keeps the FRB schema simple while still
/// surfacing all of Tauri's existing rule fields.
class HighlightsTab extends ConsumerStatefulWidget {
  const HighlightsTab({super.key});

  @override
  ConsumerState<HighlightsTab> createState() => _HighlightsTabState();
}

class _HighlightsTabState extends ConsumerState<HighlightsTab> {
  List<KeywordRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _loadFromState();
  }

  void _loadFromState() {
    final json = ref.read(settingsProvider).settings.keywordRulesJson;
    _rules = KeywordRule.decodeList(json);
  }

  void _persist() {
    final encoded = KeywordRule.encodeList(_rules);
    final notifier = ref.read(settingsProvider.notifier);
    notifier.update(ref
        .read(settingsProvider)
        .settings
        .copyWith(keywordRulesJson: encoded));
  }

  void _addRule() {
    setState(() {
      _rules = [
        ..._rules,
        KeywordRule(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          pattern: '',
          isRegex: false,
          caseSensitive: false,
          foregroundColor: '',
          backgroundColor: '#6366F1',
          enabled: true,
        ),
      ];
    });
    _persist();
  }

  void _loadPresets() {
    setState(() {
      // De-dupe by pattern so re-clicks are idempotent.
      final byPattern = {for (final r in _rules) r.pattern: r};
      for (final p in _kPresetRules) {
        byPattern.putIfAbsent(p.pattern, () => p);
      }
      _rules = byPattern.values.toList();
    });
    _persist();
  }

  void _updateRule(KeywordRule rule, KeywordRule updated) {
    setState(() {
      _rules = _rules.map((r) => r.id == rule.id ? updated : r).toList();
    });
    _persist();
  }

  void _deleteRule(KeywordRule rule) {
    setState(() {
      _rules = _rules.where((r) => r.id != rule.id).toList();
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    // Re-read current rules so reset-to-defaults / external edits show up.
    final json = ref.watch(settingsProvider
        .select((s) => s.settings.keywordRulesJson));
    final external = KeywordRule.decodeList(json);
    if (!_listEqualsById(_rules, external)) {
      _rules = external;
    }

    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                l10n.settingsHighlightsTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: TermexColors.textPrimary,
                ),
              ),
              const Spacer(),
              _SecondaryButton(
                  label: l10n.settingsHighlightsLoadPresets,
                  onTap: _loadPresets),
              const SizedBox(width: 8),
              _PrimaryButton(
                  label: l10n.settingsHighlightsAddRule, onTap: _addRule),
            ],
          ),
        ),
        if (_rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                l10n.settingsHighlightsEmpty,
                style: const TextStyle(
                  fontSize: 12,
                  color: TermexColors.textMuted,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) => _RuleRow(
                rule: _rules[i],
                onChanged: (u) => _updateRule(_rules[i], u),
                onDelete: () => _deleteRule(_rules[i]),
              ),
            ),
          ),
      ],
    );
  }

  static bool _listEqualsById(List<KeywordRule> a, List<KeywordRule> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i] != b[i]) return false;
    }
    return true;
  }
}

// ─── Rule model ────────────────────────────────────────────────────────────

class KeywordRule {
  final String id;
  final String pattern;
  final bool isRegex;
  final bool caseSensitive;
  final String foregroundColor; // empty string = use theme default
  final String backgroundColor;
  final bool enabled;

  const KeywordRule({
    required this.id,
    required this.pattern,
    required this.isRegex,
    required this.caseSensitive,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.enabled,
  });

  KeywordRule copyWith({
    String? pattern,
    bool? isRegex,
    bool? caseSensitive,
    String? foregroundColor,
    String? backgroundColor,
    bool? enabled,
  }) =>
      KeywordRule(
        id: id,
        pattern: pattern ?? this.pattern,
        isRegex: isRegex ?? this.isRegex,
        caseSensitive: caseSensitive ?? this.caseSensitive,
        foregroundColor: foregroundColor ?? this.foregroundColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'pattern': pattern,
        'isRegex': isRegex,
        'caseSensitive': caseSensitive,
        'foregroundColor': foregroundColor,
        'backgroundColor': backgroundColor,
        'enabled': enabled,
      };

  static KeywordRule fromJson(Map<String, dynamic> j) => KeywordRule(
        id: j['id']?.toString() ?? '',
        pattern: j['pattern']?.toString() ?? '',
        isRegex: j['isRegex'] == true,
        caseSensitive: j['caseSensitive'] == true,
        foregroundColor: j['foregroundColor']?.toString() ?? '',
        backgroundColor: j['backgroundColor']?.toString() ?? '#6366F1',
        enabled: j['enabled'] != false,
      );

  static List<KeywordRule> decodeList(String json) {
    if (json.isEmpty) return const [];
    try {
      final raw = jsonDecode(json);
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((m) => fromJson(m.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static String encodeList(List<KeywordRule> rules) =>
      jsonEncode(rules.map((r) => r.toJson()).toList());

  @override
  bool operator ==(Object other) =>
      other is KeywordRule &&
      id == other.id &&
      pattern == other.pattern &&
      isRegex == other.isRegex &&
      caseSensitive == other.caseSensitive &&
      foregroundColor == other.foregroundColor &&
      backgroundColor == other.backgroundColor &&
      enabled == other.enabled;

  @override
  int get hashCode => Object.hash(id, pattern, isRegex, caseSensitive,
      foregroundColor, backgroundColor, enabled);
}

const _kPresetRules = [
  KeywordRule(
    id: 'preset-error',
    pattern: 'error|fatal|panic',
    isRegex: true,
    caseSensitive: false,
    foregroundColor: '#FFFFFF',
    backgroundColor: '#DC2626',
    enabled: true,
  ),
  KeywordRule(
    id: 'preset-warning',
    pattern: 'warn|warning',
    isRegex: true,
    caseSensitive: false,
    foregroundColor: '',
    backgroundColor: '#F59E0B',
    enabled: true,
  ),
  KeywordRule(
    id: 'preset-info',
    pattern: 'info|notice',
    isRegex: true,
    caseSensitive: false,
    foregroundColor: '',
    backgroundColor: '#0EA5E9',
    enabled: true,
  ),
];

// ─── Row widget ────────────────────────────────────────────────────────────

class _RuleRow extends StatefulWidget {
  final KeywordRule rule;
  final ValueChanged<KeywordRule> onChanged;
  final VoidCallback onDelete;

  const _RuleRow({
    required this.rule,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_RuleRow> createState() => _RuleRowState();
}

class _RuleRowState extends State<_RuleRow> {
  late TextEditingController _patternCtrl;

  @override
  void initState() {
    super.initState();
    _patternCtrl = TextEditingController(text: widget.rule.pattern);
  }

  @override
  void didUpdateWidget(_RuleRow old) {
    super.didUpdateWidget(old);
    if (old.rule.pattern != widget.rule.pattern &&
        _patternCtrl.text != widget.rule.pattern) {
      _patternCtrl.text = widget.rule.pattern;
    }
  }

  @override
  void dispose() {
    _patternCtrl.dispose();
    super.dispose();
  }

  void _commitPattern() {
    if (_patternCtrl.text != widget.rule.pattern) {
      widget.onChanged(widget.rule.copyWith(pattern: _patternCtrl.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = widget.rule;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: TermexColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Pattern
          Expanded(
            child: TextField(
              controller: _patternCtrl,
              onSubmitted: (_) => _commitPattern(),
              onTapOutside: (_) => _commitPattern(),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.settingsHighlightsPatternHint,
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: TermexColors.textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: TermexColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: TermexColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: TermexColors.primary),
                ),
              ),
              style: const TextStyle(
                fontSize: 12,
                color: TermexColors.textPrimary,
                fontFamily: 'SF Mono, ui-monospace, monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MiniToggle(
            label: l10n.settingsHighlightsRegex,
            value: r.isRegex,
            onChanged: (v) => widget.onChanged(r.copyWith(isRegex: v)),
          ),
          _MiniToggle(
            label: 'Aa',
            tooltip: l10n.settingsHighlightsCaseSensitive,
            value: r.caseSensitive,
            onChanged: (v) =>
                widget.onChanged(r.copyWith(caseSensitive: v)),
          ),
          const SizedBox(width: 4),
          _ColorSwatch(
            tooltip: l10n.settingsHighlightsBgColor,
            color: r.backgroundColor,
            onChanged: (c) =>
                widget.onChanged(r.copyWith(backgroundColor: c)),
          ),
          _ColorSwatch(
            tooltip: l10n.settingsHighlightsFgColor,
            color: r.foregroundColor,
            allowEmpty: true,
            onChanged: (c) =>
                widget.onChanged(r.copyWith(foregroundColor: c)),
          ),
          const SizedBox(width: 4),
          _MiniToggle(
            label: l10n.settingsHighlightsEnabled,
            value: r.enabled,
            onChanged: (v) => widget.onChanged(r.copyWith(enabled: v)),
          ),
          IconButton(
            tooltip: l10n.commonDelete,
            icon: const Icon(Icons.delete_outline,
                size: 16, color: TermexColors.textMuted),
            visualDensity: VisualDensity.compact,
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final String label;
  final String? tooltip;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MiniToggle({
    required this.label,
    this.tooltip,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tip = tooltip ?? label;
    return Tooltip(
      message: tip,
      child: Clickable(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: value
                  ? TermexColors.primary.withOpacity(0.15)
                  : TermexColors.backgroundSecondary,
              border: Border.all(
                color: value
                    ? TermexColors.primary
                    : TermexColors.border,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: value
                    ? TermexColors.primary
                    : TermexColors.textSecondary,
                fontWeight: value ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String color;
  final String tooltip;
  final bool allowEmpty;
  final ValueChanged<String> onChanged;

  const _ColorSwatch({
    required this.color,
    required this.tooltip,
    this.allowEmpty = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hex = color.isEmpty ? null : _parseHex(color);
    return Tooltip(
      message: tooltip,
      child: Clickable(
        onTap: () => _pickColor(context),
        child: Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: hex ?? const Color(0x00000000),
            border: Border.all(color: TermexColors.border),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.center,
          child: hex == null
              ? const Icon(Icons.format_color_reset,
                  size: 12, color: TermexColors.textMuted)
              : null,
        ),
      ),
    );
  }

  Color? _parseHex(String s) {
    var v = s.trim();
    if (v.startsWith('#')) v = v.substring(1);
    if (v.length == 6) v = 'FF$v';
    if (v.length != 8) return null;
    try {
      return Color(int.parse(v, radix: 16));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickColor(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: color);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: Text(tooltip,
            style:
                const TextStyle(fontSize: 14, color: TermexColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsHighlightsColorInputHint,
              style: const TextStyle(
                  fontSize: 11, color: TermexColors.textMuted),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
              ],
              decoration: const InputDecoration(
                isDense: true,
                hintText: '#RRGGBB',
              ),
              style: const TextStyle(
                fontFamily: 'SF Mono, ui-monospace, monospace',
                fontSize: 12,
                color: TermexColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _kSwatchPresets.map((c) {
                return Clickable(
                  onTap: () => ctrl.text = c,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _parseHex(c) ?? const Color(0xFF000000),
                      border: Border.all(color: TermexColors.border),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          if (allowEmpty)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: Text(l10n.settingsHighlightsColorClear,
                  style: const TextStyle(
                      color: TermexColors.textSecondary)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.commonCancel,
                style: const TextStyle(color: TermexColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: TermexColors.primary,
              foregroundColor: const Color(0xFFFFFFFF),
            ),
            child: Text(l10n.settingsHighlightsColorConfirm),
          ),
        ],
      ),
    );
    if (result != null) onChanged(result);
  }
}

const _kSwatchPresets = [
  '#DC2626', '#F59E0B', '#10B981', '#0EA5E9', '#6366F1', '#8B5CF6',
  '#EC4899', '#64748B', '#F43F5E', '#84CC16', '#06B6D4', '#A855F7',
];

// ─── Buttons ───────────────────────────────────────────────────────────────

class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: TermexColors.primary
                .withOpacity(_hovered ? 0.25 : 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 12,
              color: TermexColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: TermexColors.border),
            borderRadius: BorderRadius.circular(4),
            color: _hovered ? TermexColors.backgroundTertiary : null,
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 12,
              color: TermexColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
