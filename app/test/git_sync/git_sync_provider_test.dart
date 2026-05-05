import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:termex/features/git_sync/state/git_sync_provider.dart';

ProviderContainer _container() => ProviderContainer();

void main() {
  group('GitSyncMode', () {
    test('parse/asString roundtrip', () {
      for (final m in GitSyncMode.values) {
        expect(GitSyncModeLabel.parse(m.asString), equals(m));
      }
    });

    test('parse returns notify for unknown value', () {
      expect(GitSyncModeLabel.parse('bogus'), equals(GitSyncMode.notify));
    });

    test('label is non-empty for all modes', () {
      for (final m in GitSyncMode.values) {
        expect(m.label, isNotEmpty);
      }
    });
  });

  group('GitSyncStatusNotifier', () {
    test('initial state is disabled', () {
      final c = _container();
      addTearDown(c.dispose);
      final s = c.read(gitSyncStatusProvider('srv-1'));
      expect(s.enabled, isFalse);
      expect(s.health, equals(GitSyncHealth.disabled));
    });

    test('enable flips flag and sets health to synced', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c
          .read(gitSyncStatusProvider('srv-1').notifier)
          .enable('git@host:r.git', '/tmp/r');
      final s = c.read(gitSyncStatusProvider('srv-1'));
      expect(s.enabled, isTrue);
      expect(s.health, equals(GitSyncHealth.synced));
      expect(s.remoteUrl, equals('git@host:r.git'));
      expect(s.localPath, equals('/tmp/r'));
    });

    test('disable reverts health to disabled', () async {
      final c = _container();
      addTearDown(c.dispose);
      final n = c.read(gitSyncStatusProvider('srv-1').notifier);
      await n.enable('r', '/tmp/r');
      await n.disable();
      expect(c.read(gitSyncStatusProvider('srv-1')).health,
          equals(GitSyncHealth.disabled));
    });

    test('trigger updates lastSyncAt when enabled', () async {
      final c = _container();
      addTearDown(c.dispose);
      final n = c.read(gitSyncStatusProvider('srv-1').notifier);
      await n.enable('r', '/tmp/r');
      await n.trigger();
      expect(c.read(gitSyncStatusProvider('srv-1')).lastSyncAt, isNotNull);
    });

    test('trigger is no-op when disabled', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(gitSyncStatusProvider('srv-1').notifier).trigger();
      expect(c.read(gitSyncStatusProvider('srv-1')).lastSyncAt, isNull);
    });

    test('markConflict sets conflict health + file list', () {
      final c = _container();
      addTearDown(c.dispose);
      c
          .read(gitSyncStatusProvider('srv-1').notifier)
          .markConflict(['a.rs', 'b.rs']);
      final s = c.read(gitSyncStatusProvider('srv-1'));
      expect(s.health, equals(GitSyncHealth.conflict));
      expect(s.conflicts.length, equals(2));
    });

    test('family isolation: different serverIds have independent state',
        () async {
      final c = _container();
      addTearDown(c.dispose);
      await c
          .read(gitSyncStatusProvider('A').notifier)
          .enable('ra', '/ra');
      final a = c.read(gitSyncStatusProvider('A'));
      final b = c.read(gitSyncStatusProvider('B'));
      expect(a.enabled, isTrue);
      expect(b.enabled, isFalse);
    });
  });

  group('GitSyncReposNotifier', () {
    test('initial state is empty list', () {
      final c = _container();
      addTearDown(c.dispose);
      expect(c.read(gitSyncReposProvider('s')).repos, isEmpty);
    });

    test('addRepo appends and returns id', () async {
      final c = _container();
      addTearDown(c.dispose);
      final id = await c
          .read(gitSyncReposProvider('s').notifier)
          .addRepo(localPath: '/tmp/r', remoteUrl: 'r');
      expect(id, isNotEmpty);
      expect(c.read(gitSyncReposProvider('s')).repos.length, equals(1));
      expect(c.read(gitSyncReposProvider('s')).repos.first.id, equals(id));
    });

    test('removeRepo deletes the entry', () async {
      final c = _container();
      addTearDown(c.dispose);
      final id = await c
          .read(gitSyncReposProvider('s').notifier)
          .addRepo(localPath: '/r', remoteUrl: 'r');
      await c.read(gitSyncReposProvider('s').notifier).removeRepo(id);
      expect(c.read(gitSyncReposProvider('s')).repos, isEmpty);
    });

    test('updateMode changes sync mode', () async {
      final c = _container();
      addTearDown(c.dispose);
      final id = await c.read(gitSyncReposProvider('s').notifier).addRepo(
          localPath: '/r', remoteUrl: 'r', mode: GitSyncMode.notify);
      await c
          .read(gitSyncReposProvider('s').notifier)
          .updateMode(id, GitSyncMode.auto);
      expect(c.read(gitSyncReposProvider('s')).repos.first.syncMode,
          equals(GitSyncMode.auto));
    });

    test('recordResult updates lastSyncAt and lastError', () async {
      final c = _container();
      addTearDown(c.dispose);
      final id = await c
          .read(gitSyncReposProvider('s').notifier)
          .addRepo(localPath: '/r', remoteUrl: 'r');
      await c
          .read(gitSyncReposProvider('s').notifier)
          .recordResult(id, error: 'timeout');
      final repo = c.read(gitSyncReposProvider('s')).repos.first;
      expect(repo.lastSyncAt, isNotNull);
      expect(repo.lastError, equals('timeout'));
    });

    test('multiple repos coexist per server', () async {
      final c = _container();
      addTearDown(c.dispose);
      final n = c.read(gitSyncReposProvider('s').notifier);
      await n.addRepo(localPath: '/a', remoteUrl: 'a');
      await n.addRepo(localPath: '/b', remoteUrl: 'b');
      await n.addRepo(localPath: '/c', remoteUrl: 'c');
      expect(c.read(gitSyncReposProvider('s')).repos.length, equals(3));
    });
  });
}
