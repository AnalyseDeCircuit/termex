import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/toast.dart';

import 'test_helpers.dart';

Widget _withOverlay(Widget child) {
  return wrapWidget(
    TermexToastOverlay(child: child),
  );
}

void main() {
  group('ToastController', () {
    testWidgets('ToastController.success shows toast', (tester) async {
      await tester.pumpWidget(
        _withOverlay(const SizedBox.shrink()),
      );
      ToastController.success('Connected successfully');
      await tester.pump();
      expect(find.text('Connected successfully'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('ToastController.error shows toast', (tester) async {
      await tester.pumpWidget(
        _withOverlay(const SizedBox.shrink()),
      );
      ToastController.error('Connection refused');
      await tester.pump();
      expect(find.text('Connection refused'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });
  });
}
