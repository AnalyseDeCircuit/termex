import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'theme_provider.dart';

class TermexThemeScope extends InheritedWidget {
  final TermexThemeData theme;

  const TermexThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  /// The active theme, registering [context] as a dependent so a theme
  /// switch rebuilds it.
  ///
  /// Falls back to the dark theme rather than asserting when no scope is
  /// present. The app always installs one above `WidgetsApp` (see
  /// `main.dart`), but widget tests routinely pump a bare `MaterialApp`,
  /// and a widget that resolves colours through `context.colors` must not
  /// crash there — it should just render in the default palette, exactly
  /// as it did when it read the `TermexColors` constants directly.
  static TermexThemeData of(BuildContext context) =>
      maybeOf(context) ?? TermexThemeData.dark();

  /// As [of], but returns null when there is no enclosing scope.
  static TermexThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TermexThemeScope>()?.theme;

  @override
  bool updateShouldNotify(TermexThemeScope old) => theme != old.theme;
}

class TermexThemeProvider extends ConsumerWidget {
  final Widget child;

  const TermexThemeProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = ref.watch(themeDataProvider);
    return TermexThemeScope(theme: themeData, child: child);
  }
}
