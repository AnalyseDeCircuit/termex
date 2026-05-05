import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import 'package:flutter/material.dart' show Color;

enum TeamRole { owner, admin, member, viewer }

class TeamMember {
  final String id;
  final String email;
  final TeamRole role;
  final String joinedAt;
  final bool isOnline;

  const TeamMember({
    required this.id,
    required this.email,
    required this.role,
    required this.joinedAt,
    this.isOnline = false,
  });

  String get roleLabel => switch (role) {
        TeamRole.owner => 'Owner',
        TeamRole.admin => 'Admin',
        TeamRole.member => 'Member',
        TeamRole.viewer => 'Viewer',
      };
}

class TeamInvite {
  final String code;
  final String email;
  final TeamRole role;
  final String expiresAt;

  const TeamInvite({
    required this.code,
    required this.email,
    required this.role,
    required this.expiresAt,
  });
}

class TeamConflict {
  final String id;
  final String resourceType;
  final String resourceName;
  final String localVersion;
  final String remoteVersion;
  final String conflictedAt;

  const TeamConflict({
    required this.id,
    required this.resourceType,
    required this.resourceName,
    required this.localVersion,
    required this.remoteVersion,
    required this.conflictedAt,
  });
}

class TeamState {
  final List<TeamMember> members;
  final List<TeamInvite> pendingInvites;
  final List<TeamConflict> conflicts;
  final bool isLoading;
  final String? error;
  final bool isSyncing;
  final String? lastSyncAt;
  final bool passphraseUnlocked;

  const TeamState({
    this.members = const [],
    this.pendingInvites = const [],
    this.conflicts = const [],
    this.isLoading = false,
    this.error,
    this.isSyncing = false,
    this.lastSyncAt,
    this.passphraseUnlocked = false,
  });

  TeamState copyWith({
    List<TeamMember>? members,
    List<TeamInvite>? pendingInvites,
    List<TeamConflict>? conflicts,
    bool? isLoading,
    String? error,
    bool? isSyncing,
    String? lastSyncAt,
    bool? passphraseUnlocked,
  }) => TeamState(
        members: members ?? this.members,
        pendingInvites: pendingInvites ?? this.pendingInvites,
        conflicts: conflicts ?? this.conflicts,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isSyncing: isSyncing ?? this.isSyncing,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        passphraseUnlocked: passphraseUnlocked ?? this.passphraseUnlocked,
      );
}

class TeamNotifier extends Notifier<TeamState> {
  @override
  TeamState build() => const TeamState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 400));
    state = state.copyWith(
      isLoading: false,
      members: const [
        TeamMember(
          id: 'u1',
          email: 'alice@example.com',
          role: TeamRole.owner,
          joinedAt: '2025-01-01T00:00:00Z',
          isOnline: true,
        ),
        TeamMember(
          id: 'u2',
          email: 'bob@example.com',
          role: TeamRole.admin,
          joinedAt: '2025-02-01T00:00:00Z',
        ),
        TeamMember(
          id: 'u3',
          email: 'carol@example.com',
          role: TeamRole.member,
          joinedAt: '2025-03-01T00:00:00Z',
          isOnline: true,
        ),
      ],
    );
  }

  Future<String> generateInvite(String email, TeamRole role) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final code = 'TRX-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
    final invite = TeamInvite(
      code: code,
      email: email,
      role: role,
      expiresAt: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    );
    state = state.copyWith(pendingInvites: [...state.pendingInvites, invite]);
    return code;
  }

  Future<void> revokeInvite(String code) async {
    state = state.copyWith(
      pendingInvites: state.pendingInvites.where((i) => i.code != code).toList(),
    );
  }

  Future<void> changeRole(String memberId, TeamRole newRole) async {
    final updated = state.members.map((m) {
      if (m.id == memberId) {
        return TeamMember(
          id: m.id,
          email: m.email,
          role: newRole,
          joinedAt: m.joinedAt,
          isOnline: m.isOnline,
        );
      }
      return m;
    }).toList();
    state = state.copyWith(members: updated);
  }

  Future<void> removeMember(String memberId) async {
    state = state.copyWith(
      members: state.members.where((m) => m.id != memberId).toList(),
    );
  }

  Future<bool> unlockPassphrase(String passphrase) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (passphrase.length >= 8) {
      state = state.copyWith(passphraseUnlocked: true);
      return true;
    }
    return false;
  }

  Future<void> sync() async {
    state = state.copyWith(isSyncing: true);
    await Future.delayed(const Duration(seconds: 1));
    state = state.copyWith(
      isSyncing: false,
      lastSyncAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> resolveConflict(String conflictId, bool useLocal) async {
    state = state.copyWith(
      conflicts: state.conflicts.where((c) => c.id != conflictId).toList(),
    );
  }
}

final teamProvider = NotifierProvider<TeamNotifier, TeamState>(TeamNotifier.new);

Color roleColor(TeamRole role) => switch (role) {
      TeamRole.owner => TermexColors.primary,
      TeamRole.admin => TermexColors.warning,
      TeamRole.member => TermexColors.success,
      TeamRole.viewer => TermexColors.textSecondary,
    };
