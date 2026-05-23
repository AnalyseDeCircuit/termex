//! Cross-protocol session infrastructure (v0.68.0 G2).
//!
//! Today this module hosts the `ProxySessionPool` — a refcounted registry
//! for upstream transport connections (HTTP/SOCKS5/SSH-jump). The pool
//! itself is decoupled from the actual TCP connect; callers wrap their
//! freshly-built session in `SharedProxySession`, hand it to `acquire`, and
//! the next caller with the same `ProxyKey` gets the same `Arc` back.
//!
//! Active integration into `session_registry` lands when the SSH-jump
//! multiplex path arrives (v0.69+). Until then the pool is exercised by
//! its unit tests and surfaces in the Flutter debug panel via
//! `session_pool_stats`.

pub mod pool;

pub use pool::{PoolStat, ProxyKey, ProxySessionPool, ProxyTypeId, SharedProxySession};
