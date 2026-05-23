//! Bridge-side singleton owning the v0.68.0 G2 ProxySessionPool.
//!
//! Today the pool is wired only for stats — actual `acquire` / `release`
//! integration with the proxy connect path lands when SSH-jump
//! multiplexing arrives (tracked in v0.69+). The pool instance is exposed
//! here so future call sites (and the unit-tested integration tests) can
//! share one global registry.

use once_cell::sync::Lazy;
use std::sync::Arc;
use termex_core::session::pool::ProxySessionPool;

static POOL: Lazy<Arc<ProxySessionPool>> = Lazy::new(|| Arc::new(ProxySessionPool::new()));

/// Returns the cloneable handle to the global proxy pool.
pub fn pool() -> Arc<ProxySessionPool> {
    POOL.clone()
}
