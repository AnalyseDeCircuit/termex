import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/terminal/font_size_toast.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: WidgetsApp(
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(RouteSettings s, WidgetBuilder b) =>
            PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx)),
        home: child,
      ),
    );

void main() {
  // ─── Constants ──────────────────────────────────────────────────────────────

  test('kFontSizeMin is 8', () => expect(kFontSizeMin, 8.0));
  test('kFontSizeMax is 28', () => expect(kFontSizeMax, 28.0));
  test('kFontSizeDefault is 14', () => expect(kFontSizeDefault, 14.0));

  // ─── clampFontSize ──────────────────────────────────────────────────────────

  group('clampFontSize', () {
    test('value within range is returned unchanged', () async {
      expect(await clampFontSize(14.0), 14.0);
    });

    test('mid-range value preserved', () async {
      expect(await clampFontSize(20.0), 20.0);
    });

    test('value below min clamps to kFontSizeMin', () async {
      expect(await clampFontSize(4.0), kFontSizeMin);
    });

    test('value above max clamps to kFontSizeMax', () async {
      expect(await clampFontSize(40.0), kFontSizeMax);
    });

    test('exactly at min boundary returns min', () async {
      expect(await clampFontSize(kFontSizeMin), kFontSizeMin);
    });

    test('exactly at max boundary returns max', () async {
      expect(await clampFontSize(kFontSizeMax), kFontSizeMax);
    });

    test('zero clamps to min', () async {
      expect(await clampFontSize(0.0), kFontSizeMin);
    });

    test('negative value clamps to min', () async {
      expect(await clampFontSize(-5.0), kFontSizeMin);
    });
  });

  // ─── FontSizeToast widget ───────────────────────────────────────────────────

  group('FontSizeToast', () {
    testWidgets('shows correct size label for 16px', (tester) async {
      await tester.pumpWidget(
        _wrap(const FontSizeToast(fontSize: 16.0)),
      );
      await tester.pump();
      expect(find.textContaining('16'), findsOneWidget);
    });

    testWidgets('shows min size label', (tester) async {
      await tester.pumpWidget(
        _wrap(const FontSizeToast(fontSize: kFontSizeMin)),
      );
      await tester.pump();
      expect(find.textContaining('8'), findsOneWidget);
    });

    testWidgets('shows max size label', (tester) async {
      await tester.pumpWidget(
        _wrap(const FontSizeToast(fontSize: kFontSizeMax)),
      );
      await tester.pump();
      expect(find.textContaining('28'), findsOneWidget);
    });

    testWidgets('contains FadeTransition for animation', (tester) async {
      await tester.pumpWidget(
        _wrap(const FontSizeToast(fontSize: 14.0)),
      );
      expect(find.byType(FadeTransition), findsOneWidget);
    });
  });

  // ─── PinchZoomFontSize ──────────────────────────────────────────────────────

  group('PinchZoomFontSize', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PinchZoomFontSize(
            fontSize: 14.0,
            onFontSizeChange: (_) {},
            child: const Text('terminal'),
          ),
        ),
      );
      expect(find.text('terminal'), findsOneWidget);
    });

    testWidgets('toast not shown when not pinching', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PinchZoomFontSize(
            fontSize: 14.0,
            onFontSizeChange: (_) {},
            child: const Text('terminal'),
          ),
        ),
      );
      expect(find.byType(FontSizeToast), findsNothing);
    });

    testWidgets('GestureDetector is present for scale events', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PinchZoomFontSize(
            fontSize: 14.0,
            onFontSizeChange: (_) {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('onFontSizeChange not called when no pinch', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          PinchZoomFontSize(
            fontSize: 14.0,
            onFontSizeChange: (_) => called = true,
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(called, isFalse);
    });
  });
}
