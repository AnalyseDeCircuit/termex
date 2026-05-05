/// Integration test: AI panel flow.
///
/// Prerequisites:
///   - Valid AI provider API key configured in test DB
///   - Network access to provider endpoint (or TERMEX_AI_OFFLINE=1 for local)
///
/// Set TERMEX_INTEGRATION=1 to enable these tests in CI.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final runIntegration = Platform.environment.containsKey('TERMEX_INTEGRATION');

  group('AI panel flow', () {
    testWidgets('AI panel opens from terminal toolbar', (tester) async {
      if (!runIntegration) return;
      // TODO: launch app, connect to session, tap AI button, verify AiPanel renders.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('new conversation is created on first send', (tester) async {
      if (!runIntegration) return;
      // TODO: open AI panel, type message, send, verify conversation entry appears.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('streaming response renders incrementally', (tester) async {
      if (!runIntegration) return;
      // TODO: send message, verify message bubble content grows via pumpAndSettle.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('cancel button stops generation', (tester) async {
      if (!runIntegration) return;
      // TODO: start long request, tap cancel, verify status shows cancelled.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('provider switcher changes active provider', (tester) async {
      if (!runIntegration) return;
      // TODO: tap ProviderSwitcher, select Ollama, verify toolbar label updates.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('code block run button sends command to terminal', (tester) async {
      if (!runIntegration) return;
      // TODO: AI response with code block, tap run, verify command appears in terminal.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('local AI panel shows model list', (tester) async {
      if (!runIntegration) return;
      // TODO: open Local AI panel, verify at least one ModelCard renders.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });

    testWidgets('error detector surfaces AI diagnose for error output', (tester) async {
      if (!runIntegration) return;
      // TODO: run failing command, verify diagnose sheet appears, tap AI 诊断.
      markTestSkipped('Requires TERMEX_INTEGRATION env-var');
    });
  });
}
