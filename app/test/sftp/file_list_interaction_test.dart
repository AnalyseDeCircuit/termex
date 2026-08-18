import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/sftp/widgets/file_list.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

const _entries = [
  FileRowData(name: 'alpha.txt', isDirectory: false, sizeBytes: 10),
  FileRowData(name: 'beta.txt', isDirectory: false, sizeBytes: 20),
];

Widget _host({
  required Set<String> selected,
  ValueChanged<String>? onSelectOnly,
  ValueChanged<String>? onToggleSelect,
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FileList(
          entries: _entries,
          selectedNames: selected,
          isLoading: false,
          onToggleSelect: onToggleSelect ?? (_) {},
          onSelectOnly: onSelectOnly ?? (_) {},
          onSelectAll: () {},
          onRefresh: () {},
          onOpen: (_) {},
          onAction: (_, __) {},
        ),
      ),
    );

void main() {
  group('selection', () {
    // A plain click used to call onToggleSelect, which accumulated: every
    // click added another row with no way back to a single selection.
    testWidgets('a plain click replaces the selection', (tester) async {
      final selectedOnly = <String>[];
      final toggled = <String>[];

      await tester.pumpWidget(_host(
        selected: const {'alpha.txt'},
        onSelectOnly: selectedOnly.add,
        onToggleSelect: toggled.add,
      ));

      await tester.tap(find.text('beta.txt'));
      // The row registers onDoubleTap too, so the recogniser holds the tap
      // until the double-tap window lapses.
      await tester.pump(const Duration(milliseconds: 400));

      expect(selectedOnly, ['beta.txt']);
      expect(toggled, isEmpty, reason: 'plain click must not accumulate');
    });
  });

  group('context menu', () {
    // The menu was anchored to the list origin plus `index * rowHeight`,
    // ignoring scroll offset, so it could open far from the pointer — or
    // off-screen, which read as "there is no context menu".
    testWidgets('right-click opens the menu with the legacy actions',
        (tester) async {
      await tester.pumpWidget(_host(selected: const {}));

      await tester.tap(find.text('alpha.txt'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
          tester.element(find.byType(FileList)));
      for (final label in [
        l10n.sftpActionDownload,
        l10n.sftpActionEdit,
        l10n.sftpActionRename,
        l10n.sftpActionDelete,
        l10n.sftpActionCopyPath,
        l10n.sftpActionNewFolder,
        l10n.sftpActionSelectAll,
        l10n.sftpActionProperties,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('right-clicking an unselected row selects it first',
        (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(
          _host(selected: const {}, onSelectOnly: picked.add));

      await tester.tap(find.text('beta.txt'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(picked, ['beta.txt']);
    });
  });
}
