import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TabStatus { connecting, connected, disconnected, error }

int _tabIdCounter = 0;
String _nextTabId() {
  _tabIdCounter += 1;
  return '${DateTime.now().microsecondsSinceEpoch}-$_tabIdCounter';
}

class TabEntry {
  final String id;
  final String serverId;
  final String title;
  final TabStatus status;

  const TabEntry({
    required this.id,
    required this.serverId,
    required this.title,
    required this.status,
  });

  TabEntry copyWith({String? id, String? serverId, String? title, TabStatus? status}) {
    return TabEntry(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      status: status ?? this.status,
    );
  }
}

class TabListNotifier extends Notifier<List<TabEntry>> {
  @override
  List<TabEntry> build() => const [];

  String openTab(String serverId, String serverName) {
    final id = _nextTabId();
    state = [...state, TabEntry(id: id, serverId: serverId, title: serverName, status: TabStatus.connecting)];
    ref.read(activeTabIdProvider.notifier).state = id;
    return id;
  }

  void cloneTab(String tabId) {
    final source = state.where((t) => t.id == tabId).firstOrNull;
    if (source == null) return;
    final newId = _nextTabId();
    state = [...state, TabEntry(id: newId, serverId: source.serverId, title: source.title, status: TabStatus.connecting)];
  }

  void closeTab(String tabId) {
    final remaining = state.where((t) => t.id != tabId).toList();
    state = remaining;
    final active = ref.read(activeTabIdProvider);
    if (active == tabId) {
      ref.read(activeTabIdProvider.notifier).state =
          remaining.isNotEmpty ? remaining.last.id : null;
    }
  }

  void updateStatus(String tabId, TabStatus status) {
    state = state.map((t) => t.id == tabId ? t.copyWith(status: status) : t).toList();
  }

  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final list = [...state];
    final item = list.removeAt(oldIndex);
    final insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    list.insert(insertIndex, item);
    state = list;
  }
}

final tabListProvider = NotifierProvider<TabListNotifier, List<TabEntry>>(
  TabListNotifier.new,
);

final activeTabIdProvider = StateProvider<String?>((ref) => null);

final activeTabProvider = Provider<TabEntry?>((ref) {
  final activeId = ref.watch(activeTabIdProvider);
  if (activeId == null) return null;
  return ref.watch(tabListProvider).where((t) => t.id == activeId).firstOrNull;
});
