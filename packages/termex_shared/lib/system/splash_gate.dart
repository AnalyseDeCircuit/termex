/// Cold-start brand splash + bootstrap gate.
///
/// Solves the gap that exists on macOS / Windows / Linux where Flutter
/// has no native splash mechanism (unlike iOS LaunchScreen.storyboard
/// and Android launch_background.xml). The gate renders immediately
/// with the brand logo on a dark background, then runs the supplied
/// async `bootstrap` callback. When bootstrap resolves, the gate
/// hands control to `builder` which returns the real app tree
/// (typically a ProviderScope wrapping the root app widget).
///
/// On iOS / Android the OS splash already shows the same logo, so
/// the Dart-side splash visually continues from where the native
/// splash left off — no flicker.
library;

import 'package:flutter/widgets.dart';

import '../design/colors.dart';

/// Build the app's root widget tree from the bootstrap result.
typedef SplashGateBuilder<T> = Widget Function(BuildContext context, T result);

/// Async work that has to finish before the real app can render.
/// Typically: FRB init, app-data-dir resolution, DB unlock probe.
typedef SplashGateBootstrap<T> = Future<T> Function();

class SplashGate<T> extends StatefulWidget {
  final SplashGateBootstrap<T> bootstrap;
  final SplashGateBuilder<T> builder;

  /// Override the centered logo (defaults to the shared brand mark).
  /// Useful in tests or when a flavor build wants its own image.
  final ImageProvider? logo;

  /// Override the background colour shown behind the logo. Defaults to
  /// TermexColors.backgroundPrimary so it matches Android's
  /// launch_background.xml and the post-init MobileShell / DesktopShell.
  final Color? background;

  /// Optional builder for rendering a bootstrap failure. The default
  /// surfaces the error as monochrome text under the logo so devs
  /// notice in dev builds; production should probably override to
  /// hide stack details and offer a retry button.
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SplashGate({
    super.key,
    required this.bootstrap,
    required this.builder,
    this.logo,
    this.background,
    this.errorBuilder,
  });

  @override
  State<SplashGate<T>> createState() => _SplashGateState<T>();
}

class _SplashGateState<T> extends State<SplashGate<T>> {
  late final Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return widget.builder(context, snapshot.data as T);
        }
        if (snapshot.hasError) {
          return _SplashChrome(
            background: widget.background,
            logo: widget.logo,
            child: (widget.errorBuilder ?? _defaultErrorBuilder)(
              context,
              snapshot.error!,
              snapshot.stackTrace,
            ),
          );
        }
        return _SplashChrome(
          background: widget.background,
          logo: widget.logo,
        );
      },
    );
  }
}

class _SplashChrome extends StatelessWidget {
  final Color? background;
  final ImageProvider? logo;
  final Widget? child;
  const _SplashChrome({this.background, this.logo, this.child});

  @override
  Widget build(BuildContext context) {
    final bg = background ?? TermexColors.backgroundPrimary;
    final image = logo ??
        const AssetImage(
          'assets/logo/logo.png',
          package: 'termex_shared',
        );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: bg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 128,
                height: 128,
                child: Image(image: image, fit: BoxFit.contain),
              ),
              if (child != null) ...[
                const SizedBox(height: 24),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _defaultErrorBuilder(BuildContext context, Object error, StackTrace? _) {
  return Text(
    'Startup failed: $error',
    style: const TextStyle(
      color: Color(0xFFF85149),
      fontSize: 14,
      decoration: TextDecoration.none,
    ),
    textAlign: TextAlign.center,
  );
}
