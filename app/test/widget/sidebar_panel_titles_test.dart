/// The sidebar draws one section header per category (`_CategorySectionHeader`
/// in `desktop_sidebar.dart`). Two panels also painted their *own* title row
/// on top of it, so the user saw the title twice — "会话录制 / 会话录制" and
/// "云端 / 云端资源" — and in both cases the second row existed only to carry a
/// refresh button. Both rows are gone; refresh moved to the right-click menu.
///
/// A source check rather than a widget test on purpose: both panels call FRB
/// (`recordingListFull`, `cloudK8SListContexts`) in `initState`, so pumping
/// them needs a live bridge. This catches the specific regression — a panel
/// reintroducing its own title row — and nothing more; it cannot catch a
/// duplicate title spelled some other way.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _repoRoot() {
  var dir = Directory.current;
  while (!(Directory('${dir.path}/app/lib').existsSync() &&
      Directory('${dir.path}/packages/termex_shared/lib').existsSync())) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('could not locate the repo root from ${Directory.current.path}');
    }
    dir = parent;
  }
  return dir;
}

/// Sidebar panel sources, and the title text the host header already shows
/// for that category — which the panel must therefore not render itself.
const _panels = <String, List<String>>{
  'packages/termex_shared/lib/features/recording/recording_list_panel.dart': [
    '会话录制',
  ],
  'packages/termex_shared/lib/features/cloud/cloud_panel.dart': [
    '云端',
    '云端资源',
  ],
};

void main() {
  final root = _repoRoot();

  group('sidebar panels do not repeat the section header title', () {
    _panels.forEach((rel, titles) {
      test(rel.split('/').last, () {
        final src = File('${root.path}/$rel').readAsStringSync();

        for (final title in titles) {
          expect(
            src.contains("'$title'"),
            isFalse,
            reason: '$rel renders "$title" itself, but the sidebar section '
                'header above it already shows that title. Drop the panel\'s '
                'own header row.',
          );
        }

        // Both offenders used the same shape: a private `_Header` widget with
        // an icon, the title, and a lone action button.
        expect(
          RegExp(r'class\s+_Header\b').hasMatch(src),
          isFalse,
          reason: '$rel declares a private _Header row. Panel-level actions '
              'belong in the right-click menu; the title belongs to the host '
              'section header.',
        );
      });
    });
  });

  test('both panels expose refresh through the right-click menu', () {
    for (final rel in _panels.keys) {
      final src = File('${root.path}/$rel').readAsStringSync();
      expect(src.contains('onSecondaryTapUp'), isTrue,
          reason: '$rel lost its right-click handler, so refresh is now '
              'unreachable — the header button it replaced is gone.');
      expect(src.contains('showContextMenu'), isTrue, reason: rel);
      // Blank space below the last row must respond too, which is what
      // opaque hit-testing on the wrapping detector provides.
      expect(src.contains('HitTestBehavior.opaque'), isTrue, reason: rel);
    }
  });
}
