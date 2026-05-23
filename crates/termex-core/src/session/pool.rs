//! ProxySessionPool — refcounted registry for shared upstream transports.

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use tokio::sync::RwLock;

/// Protocol class of the pooled transport. Stored as a discriminant on the
/// key so two configs with the same host/port but different schemes don't
/// collide.
#[derive(Debug, Clone, Copy, Hash, Eq, PartialEq)]
pub enum ProxyTypeId {
    Socks5,
    Socks4,
    Http,
    Tor,
    SshJump,
}

impl ProxyTypeId {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Socks5 => "socks5",
            Self::Socks4 => "socks4",
            Self::Http => "http",
            Self::Tor => "tor",
            Self::SshJump => "ssh-jump",
        }
    }
}

/// Composite key. Same `(type, host, port, username)` → same pooled session.
#[derive(Debug, Clone, Hash, Eq, PartialEq)]
pub struct ProxyKey {
    pub proxy_type: ProxyTypeId,
    pub host: String,
    pub port: u16,
    pub username: Option<String>,
}

impl ProxyKey {
    pub fn new(
        proxy_type: ProxyTypeId,
        host: impl Into<String>,
        port: u16,
        username: Option<String>,
    ) -> Self {
        Self {
            proxy_type,
            host: host.into(),
            port,
            username,
        }
    }
}

/// Opaque handle to a shared upstream transport. Concrete impls (SOCKS5
/// stream, SSH-jump client handle) are stored as type-erased trait objects
/// so the pool can be reused across protocols.
///
/// `bytes_transferred` is updated by the consumer of the session via the
/// `record_bytes` method so the debug stats reflect actual traffic.
pub struct SharedProxySession {
    /// Type-erased connection. Future SSH-jump work will downcast through
    /// a typed wrapper; SOCKS5/HTTP today wrap the connected `tokio::net`
    /// stream pair.
    inner: Arc<dyn std::any::Any + Send + Sync>,
    bytes_transferred: AtomicU64,
    connected_since: i64,
}

impl SharedProxySession {
    pub fn new<T: Send + Sync + 'static>(inner: T) -> Self {
        let since = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);
        Self {
            inner: Arc::new(inner),
            bytes_transferred: AtomicU64::new(0),
            connected_since: since,
        }
    }

    pub fn record_bytes(&self, n: u64) {
        self.bytes_transferred.fetch_add(n, Ordering::Relaxed);
    }

    pub fn bytes_transferred(&self) -> u64 {
        self.bytes_transferred.load(Ordering::Relaxed)
    }

    pub fn connected_since(&self) -> i64 {
        self.connected_since
    }

    /// Downcast helper for callers that know the concrete type they put in.
    pub fn inner<T: Send + Sync + 'static>(&self) -> Option<Arc<T>> {
        Arc::clone(&self.inner).downcast::<T>().ok()
    }
}

/// Snapshot row exposed to the Flutter debug panel via the bridge.
#[derive(Debug, Clone)]
pub struct PoolStat {
    pub proxy_type: String,
    pub host: String,
    pub port: u16,
    pub username: Option<String>,
    pub ref_count: usize,
    pub connected_since: i64,
    pub bytes_transferred: u64,
}

#[derive(Default)]
struct Inner {
    sessions: HashMap<ProxyKey, Arc<SharedProxySession>>,
    ref_counts: HashMap<ProxyKey, usize>,
}

/// Refcounted pool. `acquire` is idempotent w.r.t. the underlying transport:
/// the second caller with the same key bumps the count and gets the same
/// `Arc`. `release` decrements; on zero the session is dropped (the
/// concrete `Send + Sync` payload owns its own cleanup logic).
pub struct ProxySessionPool {
    inner: RwLock<Inner>,
}

impl Default for ProxySessionPool {
    fn default() -> Self {
        Self::new()
    }
}

impl ProxySessionPool {
    pub fn new() -> Self {
        Self {
            inner: RwLock::new(Inner::default()),
        }
    }

    /// Returns the existing entry for `key`, or `None` if the caller must
    /// build a fresh transport. The returned `Arc` already has its
    /// refcount bumped on the pool side. Pair with [`release`] when done.
    pub async fn acquire_existing(&self, key: &ProxyKey) -> Option<Arc<SharedProxySession>> {
        let mut inner = self.inner.write().await;
        let session = inner.sessions.get(key).cloned()?;
        let count = inner.ref_counts.entry(key.clone()).or_insert(0);
        *count += 1;
        Some(session)
    }

    /// Inserts a freshly-built transport into the pool. If a session
    /// already exists for `key` (race during concurrent acquire), the new
    /// one is dropped and the existing one's refcount is bumped instead —
    /// preventing two TCP connections in flight for the same key.
    pub async fn acquire_or_insert(
        &self,
        key: ProxyKey,
        builder: impl FnOnce() -> Arc<SharedProxySession>,
    ) -> Arc<SharedProxySession> {
        let mut inner = self.inner.write().await;
        if let Some(existing) = inner.sessions.get(&key).cloned() {
            *inner.ref_counts.entry(key).or_insert(0) += 1;
            return existing;
        }
        let session = builder();
        inner.sessions.insert(key.clone(), session.clone());
        inner.ref_counts.insert(key, 1);
        session
    }

    /// Drops one reference. When the count hits zero the session is
    /// removed from the pool and the underlying transport is dropped
    /// (assuming no external `Arc` clones are held).
    pub async fn release(&self, key: &ProxyKey) {
        let mut inner = self.inner.write().await;
        let Some(count) = inner.ref_counts.get_mut(key) else {
            return;
        };
        if *count > 0 {
            *count -= 1;
        }
        if *count == 0 {
            inner.ref_counts.remove(key);
            inner.sessions.remove(key);
        }
    }

    /// Reports current ref-count for `key`. `0` if not present.
    pub async fn ref_count(&self, key: &ProxyKey) -> usize {
        let inner = self.inner.read().await;
        inner.ref_counts.get(key).copied().unwrap_or(0)
    }

    /// Snapshots every active entry. Used by the bridge `session_pool_stats`.
    pub async fn stats(&self) -> Vec<PoolStat> {
        let inner = self.inner.read().await;
        inner
            .sessions
            .iter()
            .map(|(k, s)| PoolStat {
                proxy_type: k.proxy_type.as_str().to_string(),
                host: k.host.clone(),
                port: k.port,
                username: k.username.clone(),
                ref_count: inner.ref_counts.get(k).copied().unwrap_or(0),
                connected_since: s.connected_since(),
                bytes_transferred: s.bytes_transferred(),
            })
            .collect()
    }

    /// Test helper: drop every entry irrespective of refcount.
    pub async fn clear(&self) {
        let mut inner = self.inner.write().await;
        inner.sessions.clear();
        inner.ref_counts.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fake_session() -> Arc<SharedProxySession> {
        Arc::new(SharedProxySession::new(()))
    }

    fn key_a() -> ProxyKey {
        ProxyKey::new(ProxyTypeId::Socks5, "10.0.0.1", 1080, Some("alice".into()))
    }
    fn key_b() -> ProxyKey {
        ProxyKey::new(ProxyTypeId::Http, "proxy.example", 8080, None)
    }

    #[tokio::test]
    async fn insert_and_acquire_reuses_arc() {
        let pool = ProxySessionPool::new();
        let first = pool
            .acquire_or_insert(key_a(), fake_session)
            .await;
        let second = pool
            .acquire_or_insert(key_a(), fake_session)
            .await;
        assert!(Arc::ptr_eq(&first, &second), "second acquire must reuse");
        assert_eq!(pool.ref_count(&key_a()).await, 2);
    }

    #[tokio::test]
    async fn release_drops_at_zero() {
        let pool = ProxySessionPool::new();
        let _ = pool
            .acquire_or_insert(key_a(), fake_session)
            .await;
        let _ = pool
            .acquire_or_insert(key_a(), fake_session)
            .await;
        pool.release(&key_a()).await;
        assert_eq!(pool.ref_count(&key_a()).await, 1, "decrement once");
        pool.release(&key_a()).await;
        assert_eq!(pool.ref_count(&key_a()).await, 0, "fully released");
        assert!(
            pool.acquire_existing(&key_a()).await.is_none(),
            "session removed after refcount hits zero"
        );
    }

    #[tokio::test]
    async fn stats_reports_distinct_entries() {
        let pool = ProxySessionPool::new();
        let _ = pool
            .acquire_or_insert(key_a(), fake_session)
            .await;
        let _ = pool
            .acquire_or_insert(key_a(), fake_session)
            .await;
        let _ = pool
            .acquire_or_insert(key_b(), fake_session)
            .await;
        let stats = pool.stats().await;
        assert_eq!(stats.len(), 2, "two distinct keys");
        let a_stat = stats.iter().find(|s| s.host == "10.0.0.1").unwrap();
        assert_eq!(a_stat.ref_count, 2);
        assert_eq!(a_stat.proxy_type, "socks5");
        let b_stat = stats.iter().find(|s| s.host == "proxy.example").unwrap();
        assert_eq!(b_stat.ref_count, 1);
        assert_eq!(b_stat.proxy_type, "http");
    }

    #[tokio::test]
    async fn concurrent_acquires_share_a_single_session() {
        // Two simultaneous acquires of the same key should result in a
        // single underlying SharedProxySession with refcount 2 — never two
        // separate TCP connections. The RwLock serialises insertion so the
        // second call hits the existing-session fast path.
        let pool = Arc::new(ProxySessionPool::new());
        let key = key_a();
        let p1 = pool.clone();
        let p2 = pool.clone();
        let k1 = key.clone();
        let k2 = key.clone();
        let (a, b) = tokio::join!(
            tokio::spawn(async move { p1.acquire_or_insert(k1, fake_session).await }),
            tokio::spawn(async move { p2.acquire_or_insert(k2, fake_session).await }),
        );
        let a = a.unwrap();
        let b = b.unwrap();
        assert!(Arc::ptr_eq(&a, &b), "concurrent acquires must share");
        assert_eq!(pool.ref_count(&key).await, 2);
    }

    #[tokio::test]
    async fn bytes_transferred_accumulates() {
        let pool = ProxySessionPool::new();
        let session = pool
            .acquire_or_insert(key_a(), fake_session)
            .await;
        session.record_bytes(1024);
        session.record_bytes(512);
        let stats = pool.stats().await;
        assert_eq!(stats[0].bytes_transferred, 1536);
    }
}
