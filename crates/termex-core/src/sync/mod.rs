/// mDNS device discovery trait + Noop default impl.
///
/// Real mDNS implementation is provided by the closed-source companion
/// crate `termex-core-private`; OSS builds only ship the trait + no-op
/// fallback so the FRB bridge can compile.
pub mod discovery;
/// Protocol data types (DTOs, pairing, payloads).
///
/// These remain in OSS so the FRB-generated Dart bindings keep stable
/// shapes regardless of whether the consumer enables the `private` feature.
pub mod protocol;

pub use discovery::{DeviceDiscovery, NoopDiscovery};
pub use protocol::*;
