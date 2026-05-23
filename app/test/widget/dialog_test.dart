import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/widgets/dialog.dart';

import 'test_helpers.dart';

void main() {
  group('showTermexDialog', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showTermexDialog(
              context: ctx,
              title: '新建连接',
              body: const SizedBox.shrink(),
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('新建连接'), findsOneWidget);
    });

    testWidgets('renders body widget', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showTermexDialog(
              context: ctx,
              title: '标题',
              body: const Text('Dialog Body'),
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Dialog Body'), findsOneWidget);
    });

    testWidgets('renders action buttons when provided', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showTermexDialog(
              context: ctx,
              title: '标题',
              body: const SizedBox.shrink(),
              actions: [
                const Text('取消'),
                const Text('确认'),
              ],
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
    });

    testWidgets('close button (×) dismisses dialog', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showTermexDialog(
              context: ctx,
              title: '确认删除',
              body: const SizedBox.shrink(),
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('确认删除'), findsOneWidget);

      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();
      expect(find.text('确认删除'), findsNothing);
    });

    testWidgets('tapping barrier dismisses when barrierDismissible=true',
        (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showTermexDialog(
              context: ctx,
              title: '关闭测试',
              body: const SizedBox.shrink(),
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('关闭测试'), findsOneWidget);

      // Tap barrier (top-left corner, outside the centered dialog).
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('关闭测试'), findsNothing);
    });

    testWidgets('barrierDismissible=false keeps dialog open on barrier tap',
        (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showTermexDialog(
              context: ctx,
              title: '不可关闭',
              body: const SizedBox.shrink(),
              barrierDismissible: false,
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      // Dialog should still be visible.
      expect(find.text('不可关闭'), findsOneWidget);
    });

    testWidgets('dialog renders without exception', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showTermexDialog(
              context: ctx,
              title: '设置',
              body: const Text('内容'),
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('showConfirmDialog', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showConfirmDialog(
              context: ctx,
              title: '删除服务器',
              message: '此操作不可撤销',
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('删除服务器'), findsOneWidget);
      expect(find.text('此操作不可撤销'), findsOneWidget);
    });

    testWidgets('renders default confirm and cancel labels', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showConfirmDialog(
              context: ctx,
              title: '标题',
              message: '消息',
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('确认'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('renders custom labels', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showConfirmDialog(
              context: ctx,
              title: '标题',
              message: '消息',
              confirmLabel: '删除',
              cancelLabel: '保留',
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('删除'), findsOneWidget);
      expect(find.text('保留'), findsOneWidget);
    });

    testWidgets('cancel button returns false', (tester) async {
      bool? result;
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () async {
              result = await showConfirmDialog(
                context: ctx,
                title: '标题',
                message: '消息',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('confirm button returns true', (tester) async {
      bool? result;
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () async {
              result = await showConfirmDialog(
                context: ctx,
                title: '标题',
                message: '消息',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('renders without exception', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showConfirmDialog(
              context: ctx,
              title: '标题',
              message: '消息',
              destructive: true,
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('DialogSize', () {
    test('has 3 values', () {
      expect(DialogSize.values.length, 3);
    });

    test('contains small, medium, large', () {
      expect(DialogSize.values, contains(DialogSize.small));
      expect(DialogSize.values, contains(DialogSize.medium));
      expect(DialogSize.values, contains(DialogSize.large));
    });
  });
}
