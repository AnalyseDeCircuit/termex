import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/design/tokens.dart';

Widget wrapWidget(Widget child, {TermexThemeData? theme}) {
  final themeData = theme ?? TermexThemeData.dark();
  return ProviderScope(
    child: TermexThemeScope(
      theme: themeData,
      child: WidgetsApp(
        color: themeData.colors.background,
        pageRouteBuilder: <T>(RouteSettings s, WidgetBuilder b) =>
            PageRouteBuilder<T>(settings: s, pageBuilder: (c, _, __) => b(c)),
        home: child,
      ),
    ),
  );
}

PageRoute<T> pageRoute<T>(RouteSettings s, WidgetBuilder b) =>
    PageRouteBuilder<T>(settings: s, pageBuilder: (c, _, __) => b(c));
