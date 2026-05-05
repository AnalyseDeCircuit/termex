import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:termex/plugins/state/plugin_provider.dart';

PluginInfo _makePlugin(String id, {List<String>? permissions}) => PluginInfo(
      id: id,
      name: '$id Plugin',
      version: '1.0.0',
      description: 'A test plugin',
      state: PluginState.enabled,
      permissions: permissions ?? ['terminal_read', 'network'],
      grantedPermissions: [],
      installPath: '/plugins/$id',
    );

ProviderContainer _container() => ProviderContainer();

void main() {
  group('PluginsNotifier', () {
    test('initial state is empty', () {
      final c = _container();
      addTearDown(c.dispose);
      expect(c.read(pluginsProvider).plugins, isEmpty);
      expect(c.read(pluginsProvider).developerMode, isFalse);
    });

    test('add appends plugin', () {
      final c = _container();
      addTearDown(c.dispose);
      c.read(pluginsProvider.notifier).add(_makePlugin('echo'));
      expect(c.read(pluginsProvider).plugins.length, equals(1));
    });

    test('remove deletes plugin', () {
      final c = _container();
      addTearDown(c.dispose);
      c.read(pluginsProvider.notifier).add(_makePlugin('rm'));
      c.read(pluginsProvider.notifier).remove('rm');
      expect(c.read(pluginsProvider).plugins, isEmpty);
    });

    test('enable / disable toggle state', () {
      final c = _container();
      addTearDown(c.dispose);
      c.read(pluginsProvider.notifier).add(_makePlugin('tog'));
      c.read(pluginsProvider.notifier).disable('tog');
      expect(c.read(pluginsProvider).plugins.first.state,
          equals(PluginState.disabled));
      c.read(pluginsProvider.notifier).enable('tog');
      expect(c.read(pluginsProvider).plugins.first.state,
          equals(PluginState.enabled));
    });

    test('grantPermission adds to granted list', () {
      final c = _container();
      addTearDown(c.dispose);
      c.read(pluginsProvider.notifier).add(_makePlugin('perm'));
      c.read(pluginsProvider.notifier).grantPermission('perm', 'terminal_read');
      expect(
          c.read(pluginsProvider).plugins.first.grantedPermissions,
          contains('terminal_read'));
    });

    test('grantPermission is no-op for undeclared permission', () {
      final c = _container();
      addTearDown(c.dispose);
      c.read(pluginsProvider.notifier).add(_makePlugin('perm2'));
      // 'clipboard' is not in the default permissions list.
      c.read(pluginsProvider.notifier).grantPermission('perm2', 'clipboard');
      expect(
          c.read(pluginsProvider).plugins.first.grantedPermissions, isEmpty);
    });

    test('revokePermission removes from granted list', () {
      final c = _container();
      addTearDown(c.dispose);
      c.read(pluginsProvider.notifier).add(_makePlugin('rev'));
      c.read(pluginsProvider.notifier).grantPermission('rev', 'network');
      c.read(pluginsProvider.notifier).revokePermission('rev', 'network');
      expect(
          c.read(pluginsProvider).plugins.first.grantedPermissions,
          isNot(contains('network')));
    });

    test('hasPermission returns correct value', () {
      final c = _container();
      addTearDown(c.dispose);
      c.read(pluginsProvider.notifier).add(_makePlugin('hasperm'));
      c.read(pluginsProvider.notifier).grantPermission('hasperm', 'network');
      expect(
          c.read(pluginsProvider.notifier).hasPermission('hasperm', 'network'),
          isTrue);
      expect(
          c.read(pluginsProvider.notifier)
              .hasPermission('hasperm', 'terminal_read'),
          isFalse);
    });

    test('setDeveloperMode toggles flag', () {
      final c = _container();
      addTearDown(c.dispose);
      c.read(pluginsProvider.notifier).setDeveloperMode(true);
      expect(c.read(pluginsProvider).developerMode, isTrue);
      c.read(pluginsProvider.notifier).setDeveloperMode(false);
      expect(c.read(pluginsProvider).developerMode, isFalse);
    });

    test('multiple plugins are independent', () {
      final c = _container();
      addTearDown(c.dispose);
      c.read(pluginsProvider.notifier).add(_makePlugin('p1'));
      c.read(pluginsProvider.notifier).add(_makePlugin('p2'));
      c.read(pluginsProvider.notifier).disable('p1');
      final p2 = c.read(pluginsProvider).plugins.firstWhere((p) => p.id == 'p2');
      expect(p2.state, equals(PluginState.enabled));
    });
  });
}
