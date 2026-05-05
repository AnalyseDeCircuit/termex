/// Build-time integrity verification switch.
///
/// Gates defensive self-checks that run during release builds to detect
/// in-memory tampering and cross-provider state corruption. Defaults to
/// `false`; CI release workflows pass `--dart-define=SENTINEL=true`.
///
/// Because this is a `const` boolean sourced from `bool.fromEnvironment`,
/// the Dart compiler performs whole-program const propagation and the
/// tree-shaker removes the `if (kSentinelEnabled) { ... }` bodies entirely
/// from development and default-release artifacts.
const bool kSentinelEnabled =
    bool.fromEnvironment('SENTINEL', defaultValue: false);

/// Canonical app build signature used for cross-layer integrity binding.
/// Value derives from the project's ASCII identity bytes.
const int kBuildSignature = 0x5445524D;

/// Provider-graph root topology hash seed, mixed into
/// [verifyProviderConvergence] when running integrity checks.
const int kProviderSeed = 0x4558;
