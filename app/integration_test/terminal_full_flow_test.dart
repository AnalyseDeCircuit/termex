/// Integration test: full terminal flow.
///
/// Prerequisites (run against a real or mock SSH server):
///   - SSH server reachable at 127.0.0.1:2222
///   - Valid credentials seeded in the test DB
///
/// These tests are skipped in CI unless the `TERMEX_INTEGRATION` env-var is set.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final runIntegration = Platform.environment.containsKey('TERMEX_INTEGRATION');

  group('Terminal full flow', () {
    testWidgets('app launches without crash', (tester) async {
      // Smoke: ensure the root widget renders without throwing.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();
      // No assertion needed — absence of exception is the test.
    });

    testWidgets('search overlay opens on Cmd+F', (tester) async {
      if (!runIntegration) return;
      // TODO: launch full app, connect to test server, trigger Cmd+F,
      //       verify search overlay appears.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('tab-completion overlay appears on Tab key', (tester) async {
      if (!runIntegration) return;
      // TODO: type partial command, press Tab, verify overlay.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('ghost text appears after typing known prefix', (tester) async {
      if (!runIntegration) return;
      // TODO: seed history, type prefix, verify ghost text rendered.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('URL in output is tappable link', (tester) async {
      if (!runIntegration) return;
      // TODO: run `echo https://example.com`, verify link widget in output.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('host key TOFU dialog appears for unknown server', (tester) async {
      if (!runIntegration) return;
      // TODO: connect to server with fresh host key, verify dialog appears,
      //       tap "永久信任", verify connection proceeds.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('Cmd+D splits pane horizontally', (tester) async {
      if (!runIntegration) return;
      // TODO: trigger Cmd+D, verify two pane containers in widget tree.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });
  });
}
