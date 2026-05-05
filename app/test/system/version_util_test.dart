import 'package:flutter_test/flutter_test.dart';

import 'package:termex/system/version_util.dart';

void main() {
  group('compareVersions', () {
    test('same version → 0', () {
      expect(compareVersions('0.49.0', '0.49.0'), 0);
    });

    test('higher → 1', () {
      expect(compareVersions('0.49.0', '0.48.9'), 1);
      expect(compareVersions('1.0.0', '0.99.99'), 1);
      expect(compareVersions('0.49.1', '0.49.0'), 1);
    });

    test('lower → -1', () {
      expect(compareVersions('0.48.9', '0.49.0'), -1);
    });

    test('prerelease is lower than release', () {
      expect(compareVersions('0.49.0-beta.1', '0.49.0'), -1);
      expect(compareVersions('0.49.0', '0.49.0-beta.1'), 1);
    });

    test('prerelease ordering is lexicographic', () {
      expect(compareVersions('0.49.0-beta.2', '0.49.0-beta.1'), greaterThan(0));
    });
  });

  group('isUpdateAvailable', () {
    test('newer remote → true', () {
      expect(isUpdateAvailable('0.48.0', '0.49.0'), isTrue);
    });
    test('equal → false', () {
      expect(isUpdateAvailable('0.49.0', '0.49.0'), isFalse);
    });
    test('older remote → false', () {
      expect(isUpdateAvailable('0.49.0', '0.48.0'), isFalse);
    });
  });

  group('parseAppcast', () {
    test('extracts version and download URL', () {
      const xml = '''
        <rss><channel><item>
          <sparkle:version>0.49.0</sparkle:version>
          <sparkle:releaseNotesLink>https://termex.app/r/0.49.0</sparkle:releaseNotesLink>
          <enclosure url="https://termex.app/dl/Termex-0.49.0.dmg" length="45678901"/>
        </item></channel></rss>''';
      final entry = parseAppcast(xml, '0.48.0');
      expect(entry, isNotNull);
      expect(entry!.version, '0.49.0');
      expect(entry.downloadUrl, 'https://termex.app/dl/Termex-0.49.0.dmg');
      expect(entry.sizeBytes, 45678901);
      expect(entry.changelogUrl, 'https://termex.app/r/0.49.0');
    });

    test('returns null when current is newer', () {
      const xml = '''
        <rss><channel><item>
          <sparkle:version>0.48.0</sparkle:version>
          <enclosure url="u" length="1"/>
        </item></channel></rss>''';
      expect(parseAppcast(xml, '0.49.0'), isNull);
    });

    test('picks highest among multiple items', () {
      const xml = '''
        <rss><channel>
          <item><sparkle:version>0.49.0</sparkle:version><enclosure url="a" length="1"/></item>
          <item><sparkle:version>0.49.2</sparkle:version><enclosure url="b" length="1"/></item>
          <item><sparkle:version>0.49.1</sparkle:version><enclosure url="c" length="1"/></item>
        </channel></rss>''';
      final entry = parseAppcast(xml, '0.48.0');
      expect(entry?.version, '0.49.2');
      expect(entry?.downloadUrl, 'b');
    });

    test('extracts delta block when present', () {
      const xml = '''
        <rss><channel><item>
          <sparkle:version>0.49.0</sparkle:version>
          <enclosure url="full" length="10000"/>
          <sparkle:deltas>
            <enclosure url="delta-048" sparkle:deltaFrom="0.48.0" length="1000"/>
          </sparkle:deltas>
        </item></channel></rss>''';
      final entry = parseAppcast(xml, '0.48.0');
      expect(entry?.deltaFrom, '0.48.0');
      expect(entry?.deltaUrl, 'delta-048');
    });

    test('empty channel → null', () {
      const xml = '<rss><channel></channel></rss>';
      expect(parseAppcast(xml, '0.48.0'), isNull);
    });
  });

  group('appcastUrl', () {
    test('joins base + channel', () {
      expect(
        appcastUrl('https://termex.app/updates', 'stable'),
        'https://termex.app/updates/stable/appcast.xml',
      );
    });
  });
}
