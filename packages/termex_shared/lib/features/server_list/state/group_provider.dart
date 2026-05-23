import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:termex_bridge/src/models.dart' as bridge_models;

import '../models/group_dto.dart';

GroupDto _fromBridge(bridge_models.GroupDto b) => GroupDto(
      id: b.id,
      name: b.name,
      color: b.color,
      icon: b.icon,
      parentId: b.parentId,
      sortOrder: b.sortOrder,
      createdAt: b.createdAt,
      updatedAt: b.updatedAt,
    );

bridge_models.GroupInput _toBridgeInput(GroupInput g) => bridge_models.GroupInput(
      name: g.name,
      color: g.color,
      icon: g.icon,
      parentId: g.parentId,
      sortOrder: g.sortOrder,
    );

Future<List<GroupDto>> _fetchAll() async {
  try {
    final remote = await bridge.listGroups();
    return remote.map(_fromBridge).toList();
  } catch (_) {
    return const <GroupDto>[];
  }
}

class GroupListNotifier extends AsyncNotifier<List<GroupDto>> {
  @override
  Future<List<GroupDto>> build() => _fetchAll();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchAll);
  }

  Future<void> createGroup(GroupInput input) async {
    await bridge.createGroup(input: _toBridgeInput(input));
    await reload();
  }

  Future<void> updateGroup(String id, GroupInput input) async {
    await bridge.updateGroup(id: id, input: _toBridgeInput(input));
    await reload();
  }

  Future<void> deleteGroup(String id) async {
    await bridge.deleteGroup(id: id);
    await reload();
  }

  Future<void> reorder(List<String> ids) async {
    await bridge.reorderGroups(ids: ids);
    await reload();
  }
}

final groupListProvider = AsyncNotifierProvider<GroupListNotifier, List<GroupDto>>(
  GroupListNotifier.new,
);
