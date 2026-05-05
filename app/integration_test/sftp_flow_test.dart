/// Integration test: SFTP dual-pane flow.
///
/// Prerequisites:
///   - SSH/SFTP server at 127.0.0.1:2222
///   - Test credentials seeded in the test DB
///   - Local temp dir writable
///
/// Set env-var TERMEX_INTEGRATION=1 to enable these tests in CI.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final runIntegration = Platform.environment.containsKey('TERMEX_INTEGRATION');

  group('SFTP flow', () {
    testWidgets('SFTP panel opens after connecting', (tester) async {
      if (!runIntegration) return;
      // TODO: connect to server, click SFTP button, verify SftpPanel renders.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('remote pane lists directory entries', (tester) async {
      if (!runIntegration) return;
      // TODO: open SFTP, verify remote pane shows at least one FileRow.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('local pane breadcrumb navigation works', (tester) async {
      if (!runIntegration) return;
      // TODO: tap a path segment in local PathBar, verify dir changes.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('double-tap remote file triggers download', (tester) async {
      if (!runIntegration) return;
      // TODO: double-tap a file row in remote pane, verify transfer item
      //       appears in TransferProgressOverlay with status completed.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('right-click upload from local pane', (tester) async {
      if (!runIntegration) return;
      // TODO: right-click a local file, choose "上传", verify remote list
      //       refreshes and contains the uploaded file.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('cancel transfer stops progress', (tester) async {
      if (!runIntegration) return;
      // TODO: start a large download, tap cancel, verify status = cancelled.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('chmod dialog changes permissions', (tester) async {
      if (!runIntegration) return;
      // TODO: right-click file → 权限, set 755, verify remote stat reflects change.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('rename dialog updates file name in list', (tester) async {
      if (!runIntegration) return;
      // TODO: right-click → 重命名, enter new name, verify list updated.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });
  });
}
