import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/task/model/risk_assessment.dart';
import 'package:termex_shared/features/task/widgets/pending_confirmation_sheet.dart';

Widget host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(375, 700)),
      child: SizedBox(width: 375, child: child),
    ),
  );
}

void main() {
  testWidgets('renders risk reasons + prompt preview + server',
      (tester) async {
    const risk = RiskAssessment(
      level: RiskLevel.high,
      reasons: ['sudo invocation', 'Server tagged as production'],
      preview: 'sudo systemctl restart nginx',
    );
    await tester.pumpWidget(host(PendingConfirmationSheet(
      taskId: 't1',
      risk: risk,
      serverName: 'home-prod',
      prompt: 'sudo systemctl restart nginx',
      aiCliDisplayName: 'Claude Code',
      onDecide: (_) async {},
    )));
    expect(find.textContaining('High risk'), findsOneWidget);
    expect(find.text('home-prod'), findsOneWidget);
    expect(find.text('Claude Code'), findsOneWidget);
    expect(find.text('sudo systemctl restart nginx'), findsOneWidget);
    expect(find.textContaining('sudo invocation'), findsOneWidget);
    expect(
        find.textContaining('Server tagged as production'), findsOneWidget);
  });

  testWidgets('approve button shows biometric hint by default',
      (tester) async {
    await tester.pumpWidget(host(PendingConfirmationSheet(
      taskId: 't1',
      risk: const RiskAssessment(level: RiskLevel.critical),
      serverName: 'srv',
      prompt: 'rm -rf /',
      aiCliDisplayName: 'Shell',
      onDecide: (_) async {},
    )));
    expect(find.textContaining('Touch ID'), findsOneWidget);
  });

  testWidgets('biometric hint hidden when requiresBiometric=false',
      (tester) async {
    await tester.pumpWidget(host(PendingConfirmationSheet(
      taskId: 't1',
      risk: const RiskAssessment(level: RiskLevel.medium),
      serverName: 'srv',
      prompt: 'UPDATE users SET active=0',
      aiCliDisplayName: 'Shell',
      onDecide: (_) async {},
      requiresBiometric: false,
    )));
    expect(find.text('Approve'), findsOneWidget);
    expect(find.textContaining('Touch ID'), findsNothing);
  });

  testWidgets('Deny / Approve route through onDecide', (tester) async {
    final decisions = <ConfirmationDecision>[];
    await tester.pumpWidget(host(PendingConfirmationSheet(
      taskId: 't1',
      risk: const RiskAssessment(level: RiskLevel.high),
      serverName: 'srv',
      prompt: 'p',
      aiCliDisplayName: 'Shell',
      onDecide: (d) async => decisions.add(d),
    )));
    await tester.tap(find.text('Deny'));
    await tester.pump();
    await tester.tap(find.textContaining('Approve'));
    await tester.pump();
    expect(decisions, [
      ConfirmationDecision.deny,
      ConfirmationDecision.approve,
    ]);
  });

  testWidgets('falls back to full prompt when preview empty', (tester) async {
    const risk = RiskAssessment(level: RiskLevel.low);
    await tester.pumpWidget(host(PendingConfirmationSheet(
      taskId: 't1',
      risk: risk,
      serverName: 'srv',
      prompt: 'echo fallback',
      aiCliDisplayName: 'Shell',
      onDecide: (_) async {},
    )));
    expect(find.text('echo fallback'), findsOneWidget);
  });
}
