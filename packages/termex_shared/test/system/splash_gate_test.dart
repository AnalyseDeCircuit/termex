import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/system/splash_gate.dart';

void main() {
  testWidgets('renders splash while bootstrap pending, then builder result',
      (tester) async {
    final completer = Completer<String>();
    await tester.pumpWidget(SplashGate<String>(
      bootstrap: () => completer.future,
      // Skip the asset image so tests don't need the bundle attached.
      logo: const _TestLogo(),
      builder: (context, value) => Directionality(
        textDirection: TextDirection.ltr,
        child: Text(value),
      ),
    ));

    // Before bootstrap resolves: builder hasn't fired, so the user text
    // is absent.
    expect(find.text('ready'), findsNothing);

    completer.complete('ready');
    await tester.pumpAndSettle();
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('default error builder shows monochrome error label',
      (tester) async {
    await tester.pumpWidget(SplashGate<String>(
      bootstrap: () async => throw StateError('init blew up'),
      logo: const _TestLogo(),
      builder: (context, value) => Text(value),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Startup failed'), findsOneWidget);
    expect(find.textContaining('init blew up'), findsOneWidget);
  });

  testWidgets('errorBuilder override replaces the default panel',
      (tester) async {
    await tester.pumpWidget(SplashGate<String>(
      bootstrap: () async => throw StateError('boom'),
      logo: const _TestLogo(),
      builder: (context, value) => Text(value),
      errorBuilder: (context, error, _) => const Text('custom!',
          textDirection: TextDirection.ltr,
          style: TextStyle(color: Color(0xFFFFFFFF), decoration: TextDecoration.none)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('custom!'), findsOneWidget);
    expect(find.textContaining('Startup failed'), findsNothing);
  });

  testWidgets('background colour override paints behind the splash',
      (tester) async {
    final completer = Completer<int>();
    await tester.pumpWidget(SplashGate<int>(
      bootstrap: () => completer.future,
      logo: const _TestLogo(),
      background: const Color(0xFFFF00FF),
      builder: (context, v) => const SizedBox.shrink(),
    ));
    final box = tester.widget<ColoredBox>(find.byType(ColoredBox));
    expect(box.color, const Color(0xFFFF00FF));
  });
}

/// Test-only ImageProvider that returns a 1×1 transparent PNG without
/// touching the asset bundle, so SplashGate widget tests don't need
/// the package's asset registered with a TestWidgetsFlutterBinding.
class _TestLogo extends ImageProvider<_TestLogo> {
  const _TestLogo();
  @override
  Future<_TestLogo> obtainKey(ImageConfiguration configuration) =>
      Future.value(this);
  @override
  ImageStreamCompleter loadImage(_TestLogo key, ImageDecoderCallback decode) {
    // Synthesize a 1×1 transparent codec so the framework's image
    // pipeline doesn't crash on null bytes.
    return OneFrameImageStreamCompleter(_oneByOneFrame());
  }

  static Future<ImageInfo> _oneByOneFrame() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder);
    final pic = recorder.endRecording();
    final img = await pic.toImage(1, 1);
    return ImageInfo(image: img);
  }
}
