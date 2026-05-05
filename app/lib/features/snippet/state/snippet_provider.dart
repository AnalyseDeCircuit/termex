import 'package:flutter_riverpod/flutter_riverpod.dart';

class SnippetVariable {
  final String name;
  final String? defaultValue;
  final String? description;

  const SnippetVariable({required this.name, this.defaultValue, this.description});
}

class Snippet {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final List<SnippetVariable> variables;
  final String createdAt;
  final int usageCount;

  const Snippet({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    this.variables = const [],
    required this.createdAt,
    this.usageCount = 0,
  });

  Snippet copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? tags,
    List<SnippetVariable>? variables,
    String? createdAt,
    int? usageCount,
  }) => Snippet(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        tags: tags ?? this.tags,
        variables: variables ?? this.variables,
        createdAt: createdAt ?? this.createdAt,
        usageCount: usageCount ?? this.usageCount,
      );
}

List<SnippetVariable> extractVariables(String content) {
  final pattern = RegExp(r'\{\{(\w+)(?::([^}]*))?\}\}');
  final seen = <String>{};
  final vars = <SnippetVariable>[];
  for (final m in pattern.allMatches(content)) {
    final name = m.group(1)!;
    if (seen.add(name)) {
      vars.add(SnippetVariable(name: name, defaultValue: m.group(2)));
    }
  }
  return vars;
}

String resolveSnippet(String content, Map<String, String> values) {
  return content.replaceAllMapped(
    RegExp(r'\{\{(\w+)(?::([^}]*))?\}\}'),
    (m) {
      final name = m.group(1)!;
      final def = m.group(2) ?? '';
      return values[name] ?? def;
    },
  );
}

class SnippetState {
  final List<Snippet> snippets;
  final String searchQuery;
  final String? selectedTag;
  final String? editingId;
  final bool isLoading;

  const SnippetState({
    this.snippets = const [],
    this.searchQuery = '',
    this.selectedTag,
    this.editingId,
    this.isLoading = false,
  });

  List<Snippet> get filtered {
    var list = snippets;
    if (selectedTag != null) {
      list = list.where((s) => s.tags.contains(selectedTag)).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((s) =>
          s.title.toLowerCase().contains(q) ||
          s.content.toLowerCase().contains(q) ||
          s.tags.any((t) => t.toLowerCase().contains(q))).toList();
    }
    return list;
  }

  List<String> get allTags {
    final tags = <String>{};
    for (final s in snippets) {
      tags.addAll(s.tags);
    }
    return tags.toList()..sort();
  }

  SnippetState copyWith({
    List<Snippet>? snippets,
    String? searchQuery,
    String? selectedTag,
    String? editingId,
    bool? isLoading,
  }) => SnippetState(
        snippets: snippets ?? this.snippets,
        searchQuery: searchQuery ?? this.searchQuery,
        selectedTag: selectedTag,
        editingId: editingId,
        isLoading: isLoading ?? this.isLoading,
      );
}

class SnippetNotifier extends Notifier<SnippetState> {
  @override
  SnippetState build() => const SnippetState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 200));
    state = state.copyWith(
      isLoading: false,
      snippets: [
        Snippet(
          id: 's1',
          title: 'SSH 跳板机连接',
          content: 'ssh -J {{bastion:bastion.example.com}} {{user:ubuntu}}@{{target}}',
          tags: ['ssh', '常用'],
          variables: extractVariables('ssh -J {{bastion:bastion.example.com}} {{user:ubuntu}}@{{target}}'),
          createdAt: '2025-01-01T00:00:00Z',
          usageCount: 42,
        ),
        Snippet(
          id: 's2',
          title: 'Docker 清理',
          content: 'docker system prune -af --volumes',
          tags: ['docker', '清理'],
          variables: [],
          createdAt: '2025-01-10T00:00:00Z',
          usageCount: 15,
        ),
        Snippet(
          id: 's3',
          title: 'kubectl 端口转发',
          content: 'kubectl port-forward -n {{namespace:default}} svc/{{service}} {{local_port:8080}}:{{remote_port:80}}',
          tags: ['k8s', '常用'],
          variables: extractVariables('kubectl port-forward -n {{namespace:default}} svc/{{service}} {{local_port:8080}}:{{remote_port:80}}'),
          createdAt: '2025-02-01T00:00:00Z',
          usageCount: 28,
        ),
      ],
    );
  }

  Future<Snippet> create(String title, String content, List<String> tags) async {
    final s = Snippet(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      tags: tags,
      variables: extractVariables(content),
      createdAt: DateTime.now().toIso8601String(),
    );
    state = state.copyWith(snippets: [...state.snippets, s]);
    return s;
  }

  Future<void> update(String id, String title, String content, List<String> tags) async {
    state = state.copyWith(
      snippets: state.snippets.map((s) {
        if (s.id == id) {
          return s.copyWith(
            title: title,
            content: content,
            tags: tags,
            variables: extractVariables(content),
          );
        }
        return s;
      }).toList(),
    );
  }

  Future<void> delete(String id) async {
    state = state.copyWith(snippets: state.snippets.where((s) => s.id != id).toList());
  }

  void incrementUsage(String id) {
    state = state.copyWith(
      snippets: state.snippets.map((s) {
        if (s.id == id) return s.copyWith(usageCount: s.usageCount + 1);
        return s;
      }).toList(),
    );
  }

  void setSearch(String q) => state = state.copyWith(searchQuery: q);
  void setTag(String? tag) => state = state.copyWith(selectedTag: tag);
  void setEditing(String? id) => state = state.copyWith(editingId: id);
}

final snippetProvider = NotifierProvider<SnippetNotifier, SnippetState>(SnippetNotifier.new);
