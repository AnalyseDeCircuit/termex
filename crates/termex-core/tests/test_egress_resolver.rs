//! Tests for the v0.74.0 runtime resolver — server →
//! egress_profile_id → ChainConnectConfig assembly.

use rusqlite::Connection;

use termex_core::egress::resolver::{resolve_chain_for_server, resolve_profile};
use termex_core::egress::storage::{bind_server, ensure_schema, save};
use termex_core::egress::{EgressProfile, HopRef};

fn db() -> Connection {
    let c = Connection::open_in_memory().unwrap();
    ensure_schema(&c).unwrap();
    // The resolver needs the full server columns; bind_server only
    // creates a minimal table, so build the v1 shape ourselves.
    c.execute_batch(
        "DROP TABLE IF EXISTS servers;
         CREATE TABLE servers (
             id TEXT PRIMARY KEY,
             name TEXT NOT NULL,
             host TEXT NOT NULL,
             port INTEGER DEFAULT 22,
             egress_profile_id TEXT
         );",
    )
    .unwrap();
    c
}

fn add_server(conn: &Connection, id: &str, name: &str, host: &str, port: u16) {
    conn.execute(
        "INSERT INTO servers (id, name, host, port) VALUES (?1, ?2, ?3, ?4)",
        rusqlite::params![id, name, host, port as i64],
    )
    .unwrap();
}

fn profile_with_hops(name: &str, hops: Vec<HopRef>) -> EgressProfile {
    let mut p = EgressProfile::new(name.into(), None);
    p.chain_hops = hops;
    p
}

fn ssh_hop(position: u32, hop_id: &str) -> HopRef {
    HopRef {
        position,
        hop_type: "ssh".into(),
        hop_id: hop_id.into(),
    }
}

// ── resolve_chain_for_server ────────────────────────────────────────

#[test]
fn unbound_server_returns_none() {
    let c = db();
    add_server(&c, "srv1", "home-dev", "1.2.3.4", 22);
    assert!(resolve_chain_for_server(&c, "srv1").unwrap().is_none());
}

#[test]
fn nonexistent_server_returns_none() {
    let c = db();
    assert!(resolve_chain_for_server(&c, "ghost").unwrap().is_none());
}

#[test]
fn bound_profile_with_two_hops_builds_chain() {
    let c = db();
    add_server(&c, "bastion-a", "Bastion A", "10.0.0.1", 22);
    add_server(&c, "bastion-b", "Bastion B", "10.0.0.2", 2222);
    add_server(&c, "srv1", "home-dev", "10.0.0.99", 22);

    let p = profile_with_hops(
        "office",
        vec![ssh_hop(0, "bastion-a"), ssh_hop(1, "bastion-b")],
    );
    save(&c, &p).unwrap();
    bind_server(&c, "srv1", Some(&p.id)).unwrap();

    let chain = resolve_chain_for_server(&c, "srv1").unwrap().unwrap();
    assert_eq!(chain.hops.len(), 2);
    assert_eq!(chain.hops[0].host, "10.0.0.1");
    assert_eq!(chain.hops[0].port, 22);
    assert_eq!(chain.hops[1].host, "10.0.0.2");
    assert_eq!(chain.hops[1].port, 2222);
}

#[test]
fn hops_returned_in_position_order() {
    let c = db();
    add_server(&c, "a", "A", "10.0.0.1", 22);
    add_server(&c, "b", "B", "10.0.0.2", 22);
    add_server(&c, "c", "C", "10.0.0.3", 22);
    add_server(&c, "srv1", "target", "10.0.0.99", 22);

    // Insert hops in scrambled position order; resolver must sort.
    let p = profile_with_hops(
        "office",
        vec![
            ssh_hop(2, "c"),
            ssh_hop(0, "a"),
            ssh_hop(1, "b"),
        ],
    );
    save(&c, &p).unwrap();
    bind_server(&c, "srv1", Some(&p.id)).unwrap();

    let chain = resolve_chain_for_server(&c, "srv1").unwrap().unwrap();
    let ids: Vec<&str> = chain.hops.iter().map(|h| h.hop_id.as_str()).collect();
    assert_eq!(ids, vec!["a", "b", "c"]);
}

#[test]
fn dangling_profile_id_returns_none() {
    // server points at a profile_id that doesn't exist (e.g. left
    // over from a delete that missed the cascade).
    let c = db();
    add_server(&c, "srv1", "home-dev", "10.0.0.99", 22);
    c.execute(
        "UPDATE servers SET egress_profile_id = 'ghost-profile' WHERE id = 'srv1'",
        [],
    )
    .unwrap();
    assert!(resolve_chain_for_server(&c, "srv1").unwrap().is_none());
}

#[test]
fn profile_with_missing_hop_aborts_chain() {
    let c = db();
    add_server(&c, "real", "Real", "10.0.0.1", 22);
    add_server(&c, "srv1", "target", "10.0.0.99", 22);
    let p = profile_with_hops(
        "office",
        vec![ssh_hop(0, "real"), ssh_hop(1, "ghost-hop")],
    );
    save(&c, &p).unwrap();
    bind_server(&c, "srv1", Some(&p.id)).unwrap();
    assert!(resolve_chain_for_server(&c, "srv1").unwrap().is_none());
}

#[test]
fn unsupported_hop_type_aborts_chain() {
    let c = db();
    add_server(&c, "real", "Real", "10.0.0.1", 22);
    add_server(&c, "srv1", "target", "10.0.0.99", 22);
    let p = profile_with_hops(
        "office",
        vec![HopRef {
            position: 0,
            hop_type: "socks-rendezvous".into(),
            hop_id: "real".into(),
        }],
    );
    save(&c, &p).unwrap();
    bind_server(&c, "srv1", Some(&p.id)).unwrap();
    assert!(resolve_chain_for_server(&c, "srv1").unwrap().is_none());
}

#[test]
fn empty_hops_profile_returns_none() {
    let c = db();
    add_server(&c, "srv1", "target", "10.0.0.99", 22);
    let p = profile_with_hops("plain", vec![]);
    save(&c, &p).unwrap();
    bind_server(&c, "srv1", Some(&p.id)).unwrap();
    assert!(resolve_chain_for_server(&c, "srv1").unwrap().is_none());
}

// ── resolve_profile (direct profile -> chain) ─────────────────────

#[test]
fn resolve_profile_direct_skips_server_lookup() {
    let c = db();
    add_server(&c, "h1", "Hop1", "1.1.1.1", 22);
    let p = profile_with_hops("p", vec![ssh_hop(0, "h1")]);
    let chain = resolve_profile(&c, &p).unwrap().unwrap();
    assert_eq!(chain.hops.len(), 1);
    assert_eq!(chain.hops[0].host, "1.1.1.1");
}

// ── chain config sanity ─────────────────────────────────────────────

#[test]
fn resolved_chain_uses_default_retry_policy() {
    let c = db();
    add_server(&c, "h1", "Hop", "1.1.1.1", 22);
    add_server(&c, "srv1", "target", "9.9.9.9", 22);
    let p = profile_with_hops("p", vec![ssh_hop(0, "h1")]);
    save(&c, &p).unwrap();
    bind_server(&c, "srv1", Some(&p.id)).unwrap();
    let chain = resolve_chain_for_server(&c, "srv1").unwrap().unwrap();
    // ChainConnectConfig::new defaults; assert that we got sane
    // values rather than zeros (would silently disable retries).
    assert!(chain.max_retries_per_hop >= 1);
    assert!(chain.backoff_base_ms > 0);
    assert!(chain.backoff_max_ms >= chain.backoff_base_ms);
}
