import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/ai/features/command_extractor.dart';

void main() {
  late CommandExtractor extractor;

  setUp(() => extractor = CommandExtractor());

  group('CommandExtractor', () {
    test('extracts command from bash fenced block', () {
      const text = '```bash\nls -la /tmp\n```';
      final cmds = extractor.extract(text);
      expect(cmds, hasLength(1));
      expect(cmds.first.command, 'ls -la /tmp');
      expect(cmds.first.risk, CommandRisk.safe);
    });

    test('flags rm -rf as dangerous', () {
      const text = '```\nrm -rf /important\n```';
      final cmds = extractor.extract(text);
      expect(cmds.first.risk, CommandRisk.dangerous);
    });

    test('flags sudo as caution', () {
      const text = '```sh\nsudo apt update\n```';
      final cmds = extractor.extract(text);
      expect(cmds.first.risk, CommandRisk.caution);
    });

    test('strips shell prompt prefix', () {
      const text = '```\n\$ echo hello\n```';
      final cmds = extractor.extract(text);
      expect(cmds.first.command, 'echo hello');
    });

    test('returns empty list for text with no code blocks', () {
      const text = 'Just some prose, no commands here.';
      final cmds = extractor.extract(text);
      expect(cmds, isEmpty);
    });

    test('extracts multiple commands from multi-line block', () {
      const text = '```bash\ncd /tmp\nls\npwd\n```';
      final cmds = extractor.extract(text);
      expect(cmds, hasLength(3));
    });
  });
}
