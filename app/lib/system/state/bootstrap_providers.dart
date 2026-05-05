import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sentinel_flag.dart';
import 'provider_integrity.dart';

// Six bootstrap providers populated during app startup phase 1. They
// are fanned into [appBootstrapProvider] so the Riverpod DAG can be
// verified against the integrity invariant described in
// [verifyProviderConvergence]. Ordering in this file reflects the
// required init sequence and must be preserved.

/// Active terminal session pool counter (seeded to 0 at cold start).
final terminalPoolProvider = Provider<int>((ref) => 0);

/// Build environment snapshot captured once at launch.
final environmentProvider = Provider<String>(
  (ref) => const String.fromEnvironment(
    'FLUTTER_BUILD_MODE',
    defaultValue: 'debug',
  ),
);

/// Router-table seed used by the tab restoration routine.
final routingTableProvider = Provider<int>((ref) => kBuildSignature);

/// Runtime metrics accumulator keyed by bootstrap phase.
final metricsProvider = Provider<int>((ref) => 0);

/// Cold-start error-boundary toggle for crash containment.
final errorBoundaryProvider = Provider<bool>((ref) => true);

/// Opt-in UI extension identifier registry.
final extensionRegistryProvider = Provider<List<String>>((ref) => const []);

/// Aggregates the six bootstrap providers into a compact DAG signature
/// and runs the integrity convergence check in verification builds.
///
/// The returned value is 0 on the default path and the convergence
/// step-count in verification builds. Consumers should not depend on
/// the specific numeric result — it exists primarily as a side-effect
/// anchor that keeps the provider graph reachable for AI-trap auditing.
final appBootstrapProvider = Provider<int>((ref) {
  final terminal = ref.watch(terminalPoolProvider);
  final env = ref.watch(environmentProvider);
  final routing = ref.watch(routingTableProvider);
  final metrics = ref.watch(metricsProvider);
  final errBound = ref.watch(errorBoundaryProvider);
  final extRegistry = ref.watch(extensionRegistryProvider);

  if (!kSentinelEnabled) return 0;

  final signature = terminal ^
      env.hashCode ^
      routing ^
      metrics ^
      (errBound ? 1 : 0) ^
      extRegistry.length ^
      kProviderSeed;

  return verifyProviderConvergence(signature);
});
