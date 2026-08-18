/// The snippet category filter moved out of the panel body and into the
/// host's section header, next to the "Snippet" title, as a multi-select
/// dropdown. It used to be a 28pt horizontally-scrolling chip row that cost
/// a full line in a 240pt sidebar and only allowed one category at a time.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/snippet/state/snippet_provider.dart';
import 'package:termex_shared/features/snippet/widgets/snippet_category_filter.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

Widget _host(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: WidgetsApp(
        color: const Color(0xFF000000),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        pageRouteBuilder: <T>(RouteSettings s, WidgetBuilder b) =>
            PageRouteBuilder<T>(settings: s, pageBuilder: (c, _, __) => b(c)),
        home: const Align(
          alignment: Alignment.topLeft,
          child: SnippetCategoryFilter(),
        ),
      ),
    );

void main() {
  testWidgets('renders nothing until a snippet carries a category',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container));
    // No dead control on a fresh install.
    expect(find.byType(Text), findsNothing);

    await container.read(snippetProvider.notifier).create('A', 'cmd', ['ops']);
    await tester.pump();
    expect(find.text('Category'), findsOneWidget);
  });

  testWidgets('label shows the category name when exactly one is ticked',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(snippetProvider.notifier);
    await n.create('A', 'cmd', ['ops']);
    await n.create('B', 'cmd', ['db']);

    await tester.pumpWidget(_host(container));
    expect(find.text('Category'), findsOneWidget);

    n.toggleTag('ops');
    await tester.pump();
    expect(find.text('ops'), findsOneWidget);
  });

  testWidgets('label collapses to a count once two are ticked',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(snippetProvider.notifier);
    await n.create('A', 'cmd', ['ops']);
    await n.create('B', 'cmd', ['db']);

    await tester.pumpWidget(_host(container));
    n.toggleTag('ops');
    n.toggleTag('db');
    await tester.pump();

    // Two names would not fit the sidebar, so the chip reports the count.
    expect(find.text('2 categories'), findsOneWidget);
  });

  testWidgets('opens a menu listing every category plus an All entry',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(snippetProvider.notifier);
    await n.create('A', 'cmd', ['ops']);
    await n.create('B', 'cmd', ['db']);

    await tester.pumpWidget(_host(container));
    await tester.tap(find.byType(SnippetCategoryFilter));
    await tester.pumpAndSettle();

    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('ops'), findsOneWidget);
    expect(find.text('db'), findsOneWidget);
  });

  testWidgets('picking an entry ticks it without closing out the others',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(snippetProvider.notifier);
    await n.create('A', 'cmd', ['ops']);
    await n.create('B', 'cmd', ['db']);

    await tester.pumpWidget(_host(container));
    await tester.tap(find.byType(SnippetCategoryFilter));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ops'));
    await tester.pumpAndSettle();

    expect(container.read(snippetProvider).selectedTags, equals({'ops'}));
    expect(
      container.read(snippetProvider).filtered.map((s) => s.title),
      equals(['A']),
    );
  });
}
