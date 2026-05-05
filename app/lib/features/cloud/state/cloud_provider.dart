import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CloudProviderType { k8s, aws, aliyun }

class K8sContext {
  final String name;
  final String cluster;
  final String namespace;
  final bool isActive;

  const K8sContext({
    required this.name,
    required this.cluster,
    required this.namespace,
    this.isActive = false,
  });
}

class K8sPod {
  final String name;
  final String namespace;
  final String status;
  final int restarts;
  final String age;
  final String image;

  const K8sPod({
    required this.name,
    required this.namespace,
    required this.status,
    required this.restarts,
    required this.age,
    required this.image,
  });
}

class SsmInstance {
  final String instanceId;
  final String name;
  final String region;
  final String status;
  final String platform;

  const SsmInstance({
    required this.instanceId,
    required this.name,
    required this.region,
    required this.status,
    required this.platform,
  });
}

class EcsFavorite {
  final String id;
  final String instanceId;
  final String name;
  final String region;
  final String ip;

  const EcsFavorite({
    required this.id,
    required this.instanceId,
    required this.name,
    required this.region,
    required this.ip,
  });
}

class CloudState {
  final List<K8sContext> k8sContexts;
  final List<SsmInstance> ssmInstances;
  final List<EcsFavorite> ecsFavorites;
  final List<K8sPod> k8sPods;
  final bool isLoading;
  final String? error;
  final String? activeContextName;

  const CloudState({
    this.k8sContexts = const [],
    this.ssmInstances = const [],
    this.ecsFavorites = const [],
    this.k8sPods = const [],
    this.isLoading = false,
    this.error,
    this.activeContextName,
  });

  CloudState copyWith({
    List<K8sContext>? k8sContexts,
    List<SsmInstance>? ssmInstances,
    List<EcsFavorite>? ecsFavorites,
    List<K8sPod>? k8sPods,
    bool? isLoading,
    String? error,
    String? activeContextName,
  }) => CloudState(
        k8sContexts: k8sContexts ?? this.k8sContexts,
        ssmInstances: ssmInstances ?? this.ssmInstances,
        ecsFavorites: ecsFavorites ?? this.ecsFavorites,
        k8sPods: k8sPods ?? this.k8sPods,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        activeContextName: activeContextName ?? this.activeContextName,
      );
}

class CloudNotifier extends Notifier<CloudState> {
  @override
  CloudState build() => const CloudState();

  Future<void> loadK8sContexts() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(
      isLoading: false,
      k8sContexts: const [
        K8sContext(name: 'prod-cluster', cluster: 'prod.k8s.example.com', namespace: 'default', isActive: true),
        K8sContext(name: 'staging-cluster', cluster: 'staging.k8s.example.com', namespace: 'staging'),
      ],
      activeContextName: 'prod-cluster',
    );
  }

  Future<void> switchContext(String name) async {
    final contexts = state.k8sContexts.map((c) => K8sContext(
          name: c.name,
          cluster: c.cluster,
          namespace: c.namespace,
          isActive: c.name == name,
        )).toList();
    state = state.copyWith(k8sContexts: contexts, activeContextName: name);
  }

  Future<void> loadPods(String contextName, String namespace) async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 400));
    state = state.copyWith(
      isLoading: false,
      k8sPods: [
        K8sPod(name: 'api-7d8b9c-xkzlp', namespace: namespace, status: 'Running', restarts: 0, age: '2d', image: 'api:v1.2.3'),
        K8sPod(name: 'worker-5f6b7-mnpqr', namespace: namespace, status: 'Running', restarts: 1, age: '5d', image: 'worker:v1.2.0'),
        K8sPod(name: 'db-migrate-abc12', namespace: namespace, status: 'Completed', restarts: 0, age: '1h', image: 'db:latest'),
      ],
    );
  }

  Future<void> loadSsmInstances() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(
      isLoading: false,
      ssmInstances: const [
        SsmInstance(instanceId: 'i-0abc123', name: 'prod-web-1', region: 'us-east-1', status: 'Online', platform: 'Amazon Linux 2'),
        SsmInstance(instanceId: 'i-0def456', name: 'prod-worker-1', region: 'us-east-1', status: 'Online', platform: 'Amazon Linux 2'),
      ],
    );
  }

  Future<void> loadEcsFavorites() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 200));
    state = state.copyWith(
      isLoading: false,
      ecsFavorites: const [
        EcsFavorite(id: 'fav-1', instanceId: 'i-bp0abc123', name: '生产服务器', region: 'cn-hangzhou', ip: '10.0.0.1'),
      ],
    );
  }

  Future<void> addEcsFavorite(String instanceId, String name, String region, String ip) async {
    final fav = EcsFavorite(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      instanceId: instanceId,
      name: name,
      region: region,
      ip: ip,
    );
    state = state.copyWith(ecsFavorites: [...state.ecsFavorites, fav]);
  }

  Future<void> removeEcsFavorite(String id) async {
    state = state.copyWith(ecsFavorites: state.ecsFavorites.where((f) => f.id != id).toList());
  }
}

final cloudProvider = NotifierProvider<CloudNotifier, CloudState>(CloudNotifier.new);
