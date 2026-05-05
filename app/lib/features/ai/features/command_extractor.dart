/// Extracts shell commands from AI-generated text and flags dangerous ones.

// ─── Models ───────────────────────────────────────────────────────────────────

enum CommandRisk { safe, caution, dangerous }

class ExtractedCommand {
  final String command;
  final CommandRisk risk;
  final String? warningLabel;

  const ExtractedCommand({
    required this.command,
    required this.risk,
    this.warningLabel,
  });
}

// ─── Engine ───────────────────────────────────────────────────────────────────

class CommandExtractor {
  static const _dangerPatterns = [
    r'rm\s+-[rf]',
    r'rm\s+--recursive',
    r'mkfs',
    r'dd\s+if=',
    r'>\s*/dev/',
    r':\(\)\{.*\}',
    r'chmod\s+-R\s+777',
    r'sudo\s+rm',
    r'shutdown',
    r'reboot',
    r'halt',
    r'poweroff',
  ];

  static const _cautionPatterns = [
    r'sudo\s+',
    r'chmod\s+',
    r'chown\s+',
    r'iptables\s+',
    r'systemctl\s+',
    r'service\s+',
    r'kill\s+',
    r'pkill\s+',
  ];

  final List<RegExp> _dangerRegexes =
      _dangerPatterns.map((p) => RegExp(p)).toList();
  final List<RegExp> _cautionRegexes =
      _cautionPatterns.map((p) => RegExp(p)).toList();

  /// Extract all shell commands from Markdown text.
  List<ExtractedCommand> extract(String text) {
    final commands = <ExtractedCommand>[];

    // Fenced code blocks
    final fencedRe = RegExp(r'```(?:sh|bash|shell|zsh|)?\n([\s\S]*?)```');
    for (final m in fencedRe.allMatches(text)) {
      final block = m.group(1)?.trim() ?? '';
      for (final line in block.split('\n')) {
        final cmd = _stripPrompt(line.trim());
        if (cmd.isEmpty) continue;
        commands.add(_evaluate(cmd));
      }
    }

    // Inline code (single-line commands only)
    final inlineRe = RegExp(r'`([^`\n]+)`');
    for (final m in inlineRe.allMatches(text)) {
      final cmd = m.group(1)?.trim() ?? '';
      if (_looksLikeCommand(cmd)) {
        commands.add(_evaluate(cmd));
      }
    }

    return commands;
  }

  ExtractedCommand _evaluate(String command) {
    for (final re in _dangerRegexes) {
      if (re.hasMatch(command)) {
        return ExtractedCommand(
          command: command,
          risk: CommandRisk.dangerous,
          warningLabel: '危险操作',
        );
      }
    }
    for (final re in _cautionRegexes) {
      if (re.hasMatch(command)) {
        return ExtractedCommand(
          command: command,
          risk: CommandRisk.caution,
          warningLabel: '需要注意',
        );
      }
    }
    return ExtractedCommand(command: command, risk: CommandRisk.safe);
  }

  String _stripPrompt(String line) {
    if (line.startsWith('\$ ')) return line.substring(2);
    if (line.startsWith('% ')) return line.substring(2);
    if (line.startsWith('# ') && !line.startsWith('# ')) return line.substring(2);
    return line;
  }

  bool _looksLikeCommand(String s) {
    if (s.contains(' ') && !s.contains('.')) return true;
    final commonCmds = [
      'ls', 'cd', 'cat', 'grep', 'find', 'echo', 'sudo', 'apt', 'yum',
      'brew', 'npm', 'pip', 'git', 'docker', 'kubectl', 'ssh', 'curl', 'wget',
    ];
    final first = s.split(' ').first;
    return commonCmds.contains(first);
  }
}
