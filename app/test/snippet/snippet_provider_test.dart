import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:termex_shared/features/snippet/state/snippet_provider.dart';

void main() {
  group('extractVariables', () {
    test('extracts named variables', () {
      final vars = extractVariables('ssh {{user}}@{{host}}');
      expect(vars.map((v) => v.name).toList(), containsAll(['user', 'host']));
    });

    test('extracts default values', () {
      final vars = extractVariables('connect {{host:example.com}}');
      expect(vars.first.defaultValue, equals('example.com'));
    });

    test('deduplicates repeated variable names', () {
      final vars = extractVariables('{{x}} and {{x}}');
      expect(vars.length, equals(1));
    });

    test('empty string yields no variables', () {
      expect(extractVariables('').isEmpty, isTrue);
    });
  });

  group('resolveSnippet', () {
    test('substitutes provided values', () {
      final result = resolveSnippet('ssh {{user}}@{{host}}', {'user': 'alice', 'host': 'server.com'});
      expect(result, equals('ssh alice@server.com'));
    });

    test('falls back to default when not provided', () {
      final result = resolveSnippet('{{host:example.com}}', {});
      expect(result, equals('example.com'));
    });

    test('overrides default when value provided', () {
      final result = resolveSnippet('{{host:example.com}}', {'host': 'other.com'});
      expect(result, equals('other.com'));
    });
  });

  group('SnippetNotifier', () {
    test('initial state is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(snippetProvider).snippets, isEmpty);
    });

    test('load populates snippets', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(snippetProvider.notifier).load();
      expect(container.read(snippetProvider).snippets, isNotEmpty);
    });

    test('create adds new snippet', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(snippetProvider.notifier).create('Test', 'echo hello', ['test']);
      expect(container.read(snippetProvider).snippets.length, equals(1));
      expect(container.read(snippetProvider).snippets.first.title, equals('Test'));
    });

    test('delete removes snippet', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final s = await container.read(snippetProvider.notifier).create('Del', 'rm', []);
      await container.read(snippetProvider.notifier).delete(s.id);
      expect(container.read(snippetProvider).snippets, isEmpty);
    });

    test('update changes title and content', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final s = await container.read(snippetProvider.notifier).create('Old', 'old cmd', []);
      await container.read(snippetProvider.notifier).update(s.id, 'New', 'new cmd', ['tag']);
      final updated = container.read(snippetProvider).snippets.firstWhere((x) => x.id == s.id);
      expect(updated.title, equals('New'));
      expect(updated.content, equals('new cmd'));
    });

    test('incrementUsage increases count', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final s = await container.read(snippetProvider.notifier).create('Use', 'cmd', []);
      container.read(snippetProvider.notifier).incrementUsage(s.id);
      final updated = container.read(snippetProvider).snippets.firstWhere((x) => x.id == s.id);
      expect(updated.usageCount, equals(1));
    });

    test('search filter works', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(snippetProvider.notifier).create('ssh connect', 'ssh cmd', ['ssh']);
      await container.read(snippetProvider.notifier).create('docker prune', 'docker cmd', ['docker']);
      container.read(snippetProvider.notifier).setSearch('ssh');
      final filtered = container.read(snippetProvider).filtered;
      expect(filtered.every((s) => s.title.contains('ssh') || s.content.contains('ssh') || s.tags.any((t) => t.contains('ssh'))), isTrue);
    });

    test('tag filter works', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(snippetProvider.notifier).create('A', 'cmd', ['tagA']);
      await container.read(snippetProvider.notifier).create('B', 'cmd', ['tagB']);
      container.read(snippetProvider.notifier).toggleTag('tagA');
      final filtered = container.read(snippetProvider).filtered;
      expect(filtered.every((s) => s.tags.contains('tagA')), isTrue);
    });

    // The header dropdown is multi-select, so ticking a second category
    // widens the result set. Intersection semantics would shrink it towards
    // empty on every extra tick, which is not what "choose categories" means.
    test('ticking two categories shows both', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(snippetProvider.notifier);
      await n.create('A', 'cmd', ['tagA']);
      await n.create('B', 'cmd', ['tagB']);
      await n.create('C', 'cmd', ['tagC']);
      n.toggleTag('tagA');
      n.toggleTag('tagB');
      final titles =
          container.read(snippetProvider).filtered.map((s) => s.title).toSet();
      expect(titles, equals({'A', 'B'}));
    });

    test('untoggling the last category clears the filter', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(snippetProvider.notifier);
      await n.create('A', 'cmd', ['tagA']);
      await n.create('B', 'cmd', ['tagB']);
      n.toggleTag('tagA');
      expect(container.read(snippetProvider).filtered.length, 1);
      n.toggleTag('tagA');
      expect(container.read(snippetProvider).filtered.length, 2);
    });

    test('clearTags resets to every snippet', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(snippetProvider.notifier);
      await n.create('A', 'cmd', ['tagA']);
      await n.create('B', 'cmd', ['tagB']);
      n.toggleTag('tagA');
      n.clearTags();
      expect(container.read(snippetProvider).selectedTags, isEmpty);
      expect(container.read(snippetProvider).filtered.length, 2);
    });

    // `copyWith` assigned selectedTag/editingId unconditionally, so any
    // unrelated update wiped them: one keystroke in the search box dropped
    // the category filter and closed an open editor.
    test('searching keeps the category filter and the open editor', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(snippetProvider.notifier);
      await n.create('alpha', 'cmd', ['tagA']);
      n.toggleTag('tagA');
      n.setEditing('some-id');
      n.setSearch('al');
      final state = container.read(snippetProvider);
      expect(state.selectedTags, equals({'tagA'}));
      expect(state.editingId, 'some-id');
    });

    test('setEditing(null) still clears the editor', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(snippetProvider.notifier);
      n.setEditing('some-id');
      n.setEditing(null);
      expect(container.read(snippetProvider).editingId, isNull);
    });

    test('allTags aggregates unique tags', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(snippetProvider.notifier).create('X', 'cmd', ['a', 'b']);
      await container.read(snippetProvider.notifier).create('Y', 'cmd', ['b', 'c']);
      final tags = container.read(snippetProvider).allTags;
      expect(tags.toSet(), equals({'a', 'b', 'c'}));
    });
  });
}
