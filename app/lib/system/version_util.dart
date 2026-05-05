/// Pure-Dart mirror of `crates/termex-flutter-bridge/src/api/update.rs`
/// version comparison + minimal Sparkle appcast parsing.
///
/// Kept in Dart so Flutter tests and the About-panel UI work without the
/// native bridge.  The Rust implementation remains authoritative — if the
/// two drift, the Rust test `test_api_update.rs` is the oracle.
library;

class AppcastEntry {
  final String version;
  final String? downloadUrl;
  final int? sizeBytes;
  final String? changelogUrl;
  final String? deltaFrom;
  final String? deltaUrl;

  const AppcastEntry({
    required this.version,
    this.downloadUrl,
    this.sizeBytes,
    this.changelogUrl,
    this.deltaFrom,
    this.deltaUrl,
  });
}

/// Compare two semver strings.  Returns 1 if [a] > [b], -1 if <, 0 if equal.
/// Pre-release (`-beta.1`) is considered lower than the release per semver §11.
int compareVersions(String a, String b) {
  (List<int>, String?) split(String s) {
    String? pre;
    var core = s;
    final dash = s.indexOf('-');
    if (dash >= 0) {
      pre = s.substring(dash + 1);
      core = s.substring(0, dash);
    }
    final parts = core
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList(growable: false);
    return (parts, pre);
  }

  final (av, ap) = split(a);
  final (bv, bp) = split(b);
  final n = av.length > bv.length ? av.length : bv.length;
  for (var i = 0; i < n; i++) {
    final x = i < av.length ? av[i] : 0;
    final y = i < bv.length ? bv[i] : 0;
    if (x > y) return 1;
    if (x < y) return -1;
  }
  if (ap == null && bp == null) return 0;
  if (ap == null) return 1;
  if (bp == null) return -1;
  return ap.compareTo(bp);
}

bool isUpdateAvailable(String current, String remote) =>
    compareVersions(remote, current) > 0;

/// Parse minimal Sparkle-style appcast.  Returns the highest entry newer
/// than [currentVersion], or null if none.
AppcastEntry? parseAppcast(String xml, String currentVersion) {
  AppcastEntry? best;

  String? findTag(String src, String tag) {
    final open = '<$tag>';
    final close = '</$tag>';
    final s = src.indexOf(open);
    if (s < 0) return null;
    final after = s + open.length;
    final e = src.indexOf(close, after);
    if (e < 0) return null;
    return src.substring(after, e).trim();
  }

  String? findAttr(String src, String tag, String attr) {
    final needle = '<$tag ';
    final s = src.indexOf(needle);
    if (s < 0) return null;
    final tagStart = s + needle.length;
    final tagEnd = src.indexOf('>', tagStart);
    if (tagEnd < 0) return null;
    final slice = src.substring(tagStart, tagEnd);
    final key = '$attr="';
    final k = slice.indexOf(key);
    if (k < 0) return null;
    final rest = slice.substring(k + key.length);
    final e = rest.indexOf('"');
    if (e < 0) return null;
    return rest.substring(0, e);
  }

  final items = xml.split('<item>');
  for (var i = 1; i < items.length; i++) {
    final end = items[i].indexOf('</item>');
    final chunk = end >= 0 ? items[i].substring(0, end) : items[i];

    final version = findTag(chunk, 'sparkle:version') ??
        findTag(chunk, 'sparkle:shortVersionString');
    if (version == null) continue;
    if (!isUpdateAvailable(currentVersion, version)) continue;
    if (best != null && compareVersions(version, best.version) <= 0) continue;

    final deltaBlock = findTag(chunk, 'sparkle:deltas');
    best = AppcastEntry(
      version: version,
      downloadUrl: findAttr(chunk, 'enclosure', 'url'),
      sizeBytes: int.tryParse(findAttr(chunk, 'enclosure', 'length') ?? ''),
      changelogUrl: findTag(chunk, 'sparkle:releaseNotesLink'),
      deltaFrom: deltaBlock == null
          ? null
          : findAttr(deltaBlock, 'enclosure', 'sparkle:deltaFrom'),
      deltaUrl:
          deltaBlock == null ? null : findAttr(deltaBlock, 'enclosure', 'url'),
    );
  }
  return best;
}

String appcastUrl(String baseUrl, String channel) =>
    '$baseUrl/$channel/appcast.xml';
