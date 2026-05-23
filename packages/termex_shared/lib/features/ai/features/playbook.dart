/// Multi-step command playbook — parsed from AI responses.
///
/// AI is instructed to wrap multi-step plans in a `\`\`\`playbook` fenced
/// JSON block or as a top-level object with `"type": "playbook"`. If the
/// response does not contain such a payload the parser returns null and
/// the response is rendered as plain markdown.
library;

import 'dart:convert';

/// Risk level used in [PlaybookStep].
enum PlaybookRisk { low, medium, high }

/// Execution status of a single step.
enum PlaybookStepStatus { pending, running, success, failed, skipped }

PlaybookRisk _parseRisk(String? s) {
  switch ((s ?? 'low').toLowerCase()) {
    case 'high':
      return PlaybookRisk.high;
    case 'medium':
    case 'med':
      return PlaybookRisk.medium;
    default:
      return PlaybookRisk.low;
  }
}

/// One step in a [Playbook].
class PlaybookStep {
  final String id;
  final String title;
  final String command;
  final PlaybookRisk risk;
  final List<String> requires;
  final PlaybookStepStatus status;
  final String? output;

  const PlaybookStep({
    required this.id,
    required this.title,
    required this.command,
    this.risk = PlaybookRisk.low,
    this.requires = const [],
    this.status = PlaybookStepStatus.pending,
    this.output,
  });

  PlaybookStep copyWith({
    PlaybookStepStatus? status,
    String? output,
  }) =>
      PlaybookStep(
        id: id,
        title: title,
        command: command,
        risk: risk,
        requires: requires,
        status: status ?? this.status,
        output: output ?? this.output,
      );

  factory PlaybookStep.fromJson(Map<String, dynamic> j) {
    final reqs = j['requires'];
    return PlaybookStep(
      id: (j['id'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      command: (j['command'] ?? '') as String,
      risk: _parseRisk(j['risk'] as String?),
      requires: reqs is List ? List<String>.from(reqs.map((x) => x.toString())) : const [],
    );
  }
}

/// A multi-step shell playbook returned by AI.
class Playbook {
  final String title;
  final List<PlaybookStep> steps;

  const Playbook({required this.title, required this.steps});

  /// Whether step [id] has all its `requires` satisfied (`success`).
  bool canRun(String id) {
    final step = steps.firstWhere((s) => s.id == id);
    if (step.requires.isEmpty) return true;
    return step.requires.every((req) {
      final r = steps.where((s) => s.id == req).firstOrNull;
      return r != null && r.status == PlaybookStepStatus.success;
    });
  }

  Playbook withStep(PlaybookStep updated) => Playbook(
        title: title,
        steps: steps.map((s) => s.id == updated.id ? updated : s).toList(),
      );

  factory Playbook.fromJson(Map<String, dynamic> j) {
    final stepsRaw = j['steps'];
    final steps = stepsRaw is List
        ? stepsRaw
            .whereType<Map>()
            .map((m) => PlaybookStep.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <PlaybookStep>[];
    return Playbook(
      title: (j['title'] ?? '执行序列') as String,
      steps: steps,
    );
  }

  /// Parse [aiResponse] for a playbook payload. Returns null if no playbook
  /// structure is found (caller should render as plain text in that case).
  ///
  /// Accepts two forms:
  /// 1. A fenced block ```playbook ... ``` containing JSON
  /// 2. A top-level JSON object with `"type": "playbook"`
  static Playbook? tryParse(String aiResponse) {
    // Form 1: fenced playbook block
    final fenced = RegExp(r'```playbook\s*\n([\s\S]*?)\n```');
    final fencedMatch = fenced.firstMatch(aiResponse);
    if (fencedMatch != null) {
      try {
        final json = jsonDecode(fencedMatch.group(1)!);
        if (json is Map) {
          return Playbook.fromJson(Map<String, dynamic>.from(json));
        }
      } catch (_) {
        // fall through
      }
    }

    // Form 2: any JSON object with type: "playbook"
    final braceStart = aiResponse.indexOf('{');
    if (braceStart < 0) return null;
    final candidate = aiResponse.substring(braceStart);
    try {
      final json = jsonDecode(candidate);
      if (json is Map && json['type'] == 'playbook') {
        return Playbook.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (_) {
      // not a playbook
    }
    return null;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
