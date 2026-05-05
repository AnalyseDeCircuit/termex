import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:termex/features/team/state/team_provider.dart';

void main() {
  group('TeamNotifier', () {
    test('initial state is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(teamProvider);
      expect(state.members, isEmpty);
      expect(state.pendingInvites, isEmpty);
      expect(state.passphraseUnlocked, isFalse);
    });

    test('unlockPassphrase with short passphrase returns false', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ok = await container.read(teamProvider.notifier).unlockPassphrase('short');
      expect(ok, isFalse);
      expect(container.read(teamProvider).passphraseUnlocked, isFalse);
    });

    test('unlockPassphrase with valid passphrase returns true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ok = await container.read(teamProvider.notifier).unlockPassphrase('validPass123');
      expect(ok, isTrue);
      expect(container.read(teamProvider).passphraseUnlocked, isTrue);
    });

    test('load populates members', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(teamProvider.notifier).load();
      expect(container.read(teamProvider).members, isNotEmpty);
    });

    test('generateInvite adds to pendingInvites', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final code = await container.read(teamProvider.notifier).generateInvite('new@test.com', TeamRole.member);
      expect(code, isNotEmpty);
      expect(container.read(teamProvider).pendingInvites.length, equals(1));
      expect(container.read(teamProvider).pendingInvites.first.email, equals('new@test.com'));
    });

    test('revokeInvite removes invite', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final code = await container.read(teamProvider.notifier).generateInvite('x@x.com', TeamRole.viewer);
      await container.read(teamProvider.notifier).revokeInvite(code);
      expect(container.read(teamProvider).pendingInvites, isEmpty);
    });

    test('changeRole updates member role', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(teamProvider.notifier).load();
      final members = container.read(teamProvider).members;
      final nonOwner = members.firstWhere((m) => m.role != TeamRole.owner);
      await container.read(teamProvider.notifier).changeRole(nonOwner.id, TeamRole.viewer);
      final updated = container.read(teamProvider).members.firstWhere((m) => m.id == nonOwner.id);
      expect(updated.role, equals(TeamRole.viewer));
    });

    test('removeMember reduces count', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(teamProvider.notifier).load();
      final members = container.read(teamProvider).members;
      final nonOwner = members.firstWhere((m) => m.role != TeamRole.owner);
      await container.read(teamProvider.notifier).removeMember(nonOwner.id);
      expect(container.read(teamProvider).members.length, equals(members.length - 1));
    });

    test('sync sets lastSyncAt', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(teamProvider.notifier).sync();
      expect(container.read(teamProvider).lastSyncAt, isNotNull);
      expect(container.read(teamProvider).isSyncing, isFalse);
    });
  });
}
