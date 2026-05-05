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

  static TermexThemeData of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TermexThemeScope>();
    assert(scope != null, 'No TermexThemeScope found in context');
    return scope!.theme;
  }

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
