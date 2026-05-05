/// Kubernetes-specific state (separate from the generic cloud provider) —
/// tracks the active context, namespace, and pod list per v0.46 spec §6.2.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class K8sPodSummary {
  final String name;
  final String namespace;
  final String phase;
  final int readyContainers;
  final int totalContainers;
  final int restarts;
  final Duration age;

  const K8sPodSummary({
    required this.name,
    required this.namespace,
    required this.phase,
    required this.readyContainers,
    required this.totalContainers,
    required this.restarts,
    required this.age,
  });

  bool get isReady => readyContainers == totalContainers && phase == 'Running';
}

class K8sState {
  final List<String> contexts;
  final String? activeContext;
  final String activeNamespace;
  final List<K8sPodSummary> pods;
  final bool isLoading;
  final String? error;

  const K8sState({
    this.contexts = const [],
    this.activeContext,
    this.activeNamespace = 'default',
    this.pods = const [],
    this.isLoading = false,
    this.error,
  });

  K8sState copyWith({
    List<String>? contexts,
    String? activeContext,
    String? activeNamespace,
    List<K8sPodSummary>? pods,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      K8sState(
        contexts: contexts ?? this.contexts,
        activeContext: activeContext ?? this.activeContext,
        activeNamespace: activeNamespace ?? this.activeNamespace,
        pods: pods ?? this.pods,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class K8sNotifier extends Notifier<K8sState> {
  @override
  K8sState build() => const K8sState();

  Future<void> loadContexts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    // Heavy kubectl integration lands in v0.47; returning empty here keeps
    // the UI flow testable without an external dependency.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = state.copyWith(isLoading: false, contexts: const []);
  }

  void selectContext(String name) {
    state = state.copyWith(activeContext: name);
  }

  void selectNamespace(String name) {
    state = state.copyWith(activeNamespace: name);
  }

  Future<void> refreshPods() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = state.copyWith(isLoading: false, pods: const []);
  }
}

final k8sProvider = NotifierProvider<K8sNotifier, K8sState>(K8sNotifier.new);
