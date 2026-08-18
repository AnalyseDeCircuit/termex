import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/api.dart' as bridge;

/// Session IDs whose terminal input should fan out to peers.
///
/// When more than one session is in the set, every keystroke (or paste)
/// typed into one of them is also relayed via [bridge.writeStdin] to all
/// the others. Mirrors the Vue version's `useBroadcast` composable.
class BroadcastRegistry extends ChangeNotifier {
  final Set<String> _members = <String>{};

  Set<String> get members => Set.unmodifiable(_members);
  bool get hasFanout => _members.length > 1;

  bool isMember(String sessionId) => _members.contains(sessionId);

  void enable(String sessionId) {
    if (_members.add(sessionId)) notifyListeners();
  }

  void disable(String sessionId) {
    if (_members.remove(sessionId)) notifyListeners();
  }

  void toggle(String sessionId) {
    isMember(sessionId) ? disable(sessionId) : enable(sessionId);
  }

  void clear() {
    if (_members.isEmpty) return;
    _members.clear();
    notifyListeners();
  }

  /// If [sourceSessionId] is in the registry and there are peers, writes
  /// [data] to every peer (skipping the source). Safe to call regardless
  /// of broadcast state — returns immediately when fanout is off.
  Future<void> fanout(String sourceSessionId, String data) async {
    if (_members.length <= 1) return;
    if (!_members.contains(sourceSessionId)) return;
    final encoded = utf8.encode(data);
    for (final id in _members) {
      if (id == sourceSessionId) continue;
      // Errors are swallowed: a dead session in the broadcast set should
      // not prevent the live ones from receiving input. The user can
      // notice the dead tab via its status indicator and remove it.
      bridge.writeStdin(sessionId: id, data: encoded).catchError((_) {});
    }
  }
}

final broadcastRegistryProvider =
    ChangeNotifierProvider<BroadcastRegistry>((_) => BroadcastRegistry());
