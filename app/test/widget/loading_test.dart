import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/widgets/loading.dart';

import 'test_helpers.dart';

void main() {
  group('TermexLoading', () {
    testWidgets('spinner renders without error', (tester) async {
      await tester.pumpWidget(wrapWidget(const TermexLoading()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with message in row', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexLoading(message: '连接中'),
      ));
      expect(find.text('连接中'), findsOneWidget);
    });

    testWidgets('spinner variant shows no overlay', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexLoading(variant: LoadingVariant.spinner),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('overlay variant renders over content', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexLoading.overlay(message: '加载中'),
      ));
      expect(find.text('加载中'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('animation runs without error after pump', (tester) async {
      await tester.pumpWidget(wrapWidget(const TermexLoading()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('custom size is applied', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexLoading(size: 48),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
