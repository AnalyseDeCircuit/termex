import 'package:flutter_test/flutter_test.dart';
import 'package:termex/terminal/features/link_detect/link_detector.dart';

void main() {
  group('LinkDetector', () {
    test('detects http URL', () {
      final links = LinkDetector.detect('visit https://example.com for info');
      expect(links, hasLength(1));
      expect(links.first.href, 'https://example.com');
      expect(links.first.type, LinkType.url);
    });

    test('detects multiple URLs', () {
      final links = LinkDetector.detect(
          'see http://a.com and https://b.org/path?q=1');
      expect(links, hasLength(2));
    });

    test('detects file path with line:col', () {
      final links = LinkDetector.detect('error in src/main.rs:42:10');
      final fileLinks =
          links.where((l) => l.type == LinkType.fileWithLocation).toList();
      expect(fileLinks, isNotEmpty);
      expect(fileLinks.first.line, 42);
      expect(fileLinks.first.column, 10);
    });

    test('detects plain file path', () {
      final links = LinkDetector.detect('open /etc/hosts to edit');
      final paths =
          links.where((l) => l.type == LinkType.filePath).toList();
      expect(paths, isNotEmpty);
    });

    test('returns empty list for plain text', () {
      expect(LinkDetector.detect('just some text without links'), isEmpty);
    });

    test('deduplicates overlapping matches', () {
      // A URL that also matches the file pattern should appear only once.
      final links = LinkDetector.detect('https://example.com/path/to/file.rs:1');
      final starts = links.map((l) => l.start).toSet();
      expect(starts.length, links.length); // no duplicate start offsets
    });
  });
}
