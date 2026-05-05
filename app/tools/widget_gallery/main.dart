import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex/design/tokens.dart';
import 'pages/gallery_home.dart';

void main() {
  runApp(
    ProviderScope(
      child: Consumer(builder: (ctx, ref, _) {
        final theme = ref.watch(themeDataProvider);
        return TermexThemeScope(
          theme: theme,
          child: WidgetsApp(
            color: theme.colors.background,
            pageRouteBuilder: <T>(s, b) => PageRouteBuilder<T>(
              settings: s,
              pageBuilder: (c, _, __) => b(c),
            ),
            home: const GalleryHome(),
          ),
        );
      }),
    ),
  );
}
