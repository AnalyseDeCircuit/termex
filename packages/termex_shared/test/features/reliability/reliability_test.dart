import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/reliability/model/task_metrics_vm.dart';
import 'package:termex_shared/features/reliability/widgets/reconnect_banner.dart';
import 'package:termex_shared/features/reliability/widgets/reliability_footer.dart';

Widget host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 700)),
        child: child,
      ),
    );

void main() {
  group('formatDurationMs', () {
    test('ms under 1s', () {
      expect(formatDurationMs(350), '350ms');
    });
    test('s under 1 minute', () {
      expect(formatDurationMs(5400), '5.4s');
    });
    test('m s for under 1 hour', () {
      expect(formatDurationMs(134000), '2m 14s');
    });
    test('h m for hours', () {
      expect(formatDurationMs(5400000), '1h 30m');
    });
  });

  group('TaskMetricsVM.empty', () {
    test('initializes counters to zero', () {
      final m = TaskMetricsVM.empty('t1', now: DateTime.utc(2026, 5, 23));
      expect(m.wsUptimeMs, 0);
      expect(m.reconnectCount, 0);
      expect(m.bgDurationMs, 0);
      expect(m.pushLatencyMs, isNull);
      expect(m.handoffCount, 0);
    });
  });

  group('ReconnectBanner', () {
    testWidgets('hides when every attempt is connected', (tester) async {
      await tester.pumpWidget(host(const ReconnectBanner(
        attempts: [
          ReconnectAttemptVM(
            serverId: 's1',
            serverLabel: 'home-dev',
            status: ReconnectStatusVM.connected,
          ),
        ],
      )));
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('shows reconnecting label per server', (tester) async {
      await tester.pumpWidget(host(const ReconnectBanner(
        attempts: [
          ReconnectAttemptVM(
            serverId: 's1',
            serverLabel: 'home-dev',
            status: ReconnectStatusVM.reconnecting,
          ),
        ],
      )));
      expect(find.text('Reconnecting to home-dev…'), findsOneWidget);
    });

    testWidgets('shows lost label + retry on failed entries', (tester) async {
      String? retried;
      await tester.pumpWidget(host(ReconnectBanner(
        attempts: const [
          ReconnectAttemptVM(
            serverId: 's1',
            serverLabel: 'prod-edge',
            status: ReconnectStatusVM.failed,
            note: 'host unreachable',
          ),
        ],
        onRetry: (id) => retried = id,
      )));
      expect(find.text('Lost connection to prod-edge'), findsOneWidget);
      expect(find.text('host unreachable'), findsOneWidget);
      await tester.tap(find.text('Retry now'));
      expect(retried, 's1');
    });

    testWidgets('mixes reconnecting + failed entries in one banner',
        (tester) async {
      await tester.pumpWidget(host(const ReconnectBanner(
        attempts: [
          ReconnectAttemptVM(
            serverId: 's1',
            serverLabel: 'home-dev',
            status: ReconnectStatusVM.reconnecting,
          ),
          ReconnectAttemptVM(
            serverId: 's2',
            serverLabel: 'prod-edge',
            status: ReconnectStatusVM.failed,
          ),
        ],
      )));
      expect(find.textContaining('home-dev'), findsOneWidget);
      expect(find.textContaining('prod-edge'), findsOneWidget);
    });
  });

  group('ReliabilityFooter', () {
    testWidgets('hidden when visible=false', (tester) async {
      await tester.pumpWidget(host(const ReliabilityFooter(
        metrics: null,
        visible: false,
      )));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('placeholder when metrics is null', (tester) async {
      await tester.pumpWidget(host(const ReliabilityFooter(
        metrics: null,
      )));
      expect(find.text('No metrics recorded yet.'), findsOneWidget);
    });

    testWidgets('renders the full counter line when metrics populated',
        (tester) async {
      final m = TaskMetricsVM(
        taskId: 't1',
        wsUptimeMs: 5400,
        reconnectCount: 2,
        bgDurationMs: 134000,
        pushLatencyMs: 220,
        handoffCount: 1,
        updatedAt: DateTime.utc(2026, 5, 23),
      );
      await tester.pumpWidget(host(ReliabilityFooter(metrics: m)));
      expect(find.textContaining('WS 5.4s'), findsOneWidget);
      expect(find.textContaining('Reconnects 2'), findsOneWidget);
      expect(find.textContaining('BG 2m 14s'), findsOneWidget);
      expect(find.textContaining('Push 220ms'), findsOneWidget);
      expect(find.textContaining('Handoffs 1'), findsOneWidget);
    });

    testWidgets('push dash when no push latency observed', (tester) async {
      final m = TaskMetricsVM(
        taskId: 't1',
        wsUptimeMs: 0,
        reconnectCount: 0,
        bgDurationMs: 0,
        pushLatencyMs: null,
        handoffCount: 0,
        updatedAt: DateTime.utc(2026, 5, 23),
      );
      await tester.pumpWidget(host(ReliabilityFooter(metrics: m)));
      expect(find.textContaining('Push —'), findsOneWidget);
    });
  });
}
