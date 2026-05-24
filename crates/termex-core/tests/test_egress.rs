use rusqlite::Connection;

use termex_core::egress::storage::{
    bind_server, delete, ensure_schema, get, list, list_summaries, save, EgressError,
};
use termex_core::egress::{EgressProfile, HopRef};

fn db() -> Connection {
    let c = Connection::open_in_memory().unwrap();
    ensure_schema(&c).unwrap();
    c
}

fn sample(name: &str, owner: Option<&str>) -> EgressProfile {
    let mut p = EgressProfile::new(name.into(), owner.map(str::to_owned));
    p.chain_hops = vec![
        HopRef {
            position: 0,
            hop_type: "ssh".into(),
            hop_id: "bastion-a".into(),
        },
        HopRef {
            position: 1,
            hop_type: "ssh".into(),
            hop_id: "bastion-b".into(),
        },
    ];
    p.proxy_id = Some("corp-socks".into());
    p
}

#[test]
fn save_then_get_round_trip() {
    let c = db();
    let p = sample("office-bastion", Some("dev-a"));
    save(&c, &p).unwrap();
    let got = get(&c, &p.id).unwrap().unwrap();
    assert_eq!(got, p);
}

#[test]
fn get_unknown_id_returns_none() {
    let c = db();
    assert!(get(&c, "nope").unwrap().is_none());
}

#[test]
fn list_returns_alpha_sorted_by_name() {
    let c = db();
    save(&c, &sample("z-late", None)).unwrap();
    save(&c, &sample("a-early", None)).unwrap();
    let l = list(&c).unwrap();
    assert_eq!(l[0].name, "a-early");
    assert_eq!(l[1].name, "z-late");
}

#[test]
fn save_idempotent_upsert_on_same_id() {
    let c = db();
    let mut p = sample("home", None);
    save(&c, &p).unwrap();
    p.name = "home-renamed".into();
    p.touch();
    save(&c, &p).unwrap();
    let got = get(&c, &p.id).unwrap().unwrap();
    assert_eq!(got.name, "home-renamed");
}

#[test]
fn save_blocks_duplicate_name_within_owner_device() {
    let c = db();
    let p1 = sample("office", Some("dev-a"));
    let p2 = sample("office", Some("dev-a")); // different uuid, same name+owner
    save(&c, &p1).unwrap();
    let err = save(&c, &p2).unwrap_err();
    matches!(err, EgressError::DuplicateName(_));
}

#[test]
fn save_allows_same_name_under_different_owners() {
    let c = db();
    save(&c, &sample("office", Some("dev-a"))).unwrap();
    save(&c, &sample("office", Some("dev-b"))).unwrap();
    let l = list(&c).unwrap();
    assert_eq!(l.len(), 2);
}

#[test]
fn save_allows_same_name_with_null_owner_and_explicit_owner() {
    let c = db();
    save(&c, &sample("office", None)).unwrap();
    save(&c, &sample("office", Some("dev-a"))).unwrap();
    let l = list(&c).unwrap();
    assert_eq!(l.len(), 2);
}

#[test]
fn delete_removes_row() {
    let c = db();
    let p = sample("home", None);
    save(&c, &p).unwrap();
    delete(&c, &p.id).unwrap();
    assert!(get(&c, &p.id).unwrap().is_none());
}

#[test]
fn delete_unknown_id_errors_not_found() {
    let c = db();
    assert!(matches!(
        delete(&c, "nope"),
        Err(EgressError::NotFound(_))
    ));
}

#[test]
fn delete_cascades_null_on_bound_servers() {
    let c = db();
    // Sentinel + insert two server rows that will both bind to the
    // same profile so we can verify *both* get NULLed on delete.
    let _ = bind_server(&c, "bootstrap", None);
    c.execute(
        "INSERT OR REPLACE INTO servers (id, name) VALUES ('s1', 'home-dev'),
                                                          ('s2', 'prod-edge'),
                                                          ('s3', 'unrelated')",
        [],
    )
    .unwrap();
    let p = sample("office", None);
    save(&c, &p).unwrap();
    let other = sample("home", None);
    save(&c, &other).unwrap();

    bind_server(&c, "s1", Some(&p.id)).unwrap();
    bind_server(&c, "s2", Some(&p.id)).unwrap();
    bind_server(&c, "s3", Some(&other.id)).unwrap();

    delete(&c, &p.id).unwrap();

    let check = |sid: &str| -> Option<String> {
        c.query_row(
            "SELECT egress_profile_id FROM servers WHERE id = ?1",
            rusqlite::params![sid],
            |r| r.get::<_, Option<String>>(0),
        )
        .unwrap()
    };
    assert!(check("s1").is_none(), "s1 must be unbound");
    assert!(check("s2").is_none(), "s2 must be unbound");
    assert_eq!(check("s3").as_deref(), Some(other.id.as_str()),
               "unrelated profile binding must survive");
}

#[test]
fn delete_when_servers_table_absent_does_not_error() {
    // Fresh DB with no `servers` table at all — the cascade probe
    // should detect the column's absence and just delete the profile.
    let c = db();
    let p = sample("home", None);
    save(&c, &p).unwrap();
    delete(&c, &p.id).unwrap();
    assert!(get(&c, &p.id).unwrap().is_none());
}

#[test]
fn list_summaries_reports_hop_proxy_counts() {
    let c = db();
    save(&c, &sample("office", None)).unwrap();
    let mut bare = EgressProfile::new("plain".into(), None);
    bare.proxy_id = None;
    save(&c, &bare).unwrap();
    let s = list_summaries(&c).unwrap();
    let office = s.iter().find(|x| x.name == "office").unwrap();
    let plain = s.iter().find(|x| x.name == "plain").unwrap();
    assert_eq!(office.hop_count, 2);
    assert!(office.has_proxy);
    assert_eq!(plain.hop_count, 0);
    assert!(!plain.has_proxy);
    // No servers table populated → bound_server_count is 0 for both.
    assert_eq!(office.bound_server_count, 0);
}

#[test]
fn bind_server_links_then_clears() {
    let c = db();
    // bind_server lazily creates the minimal `servers` table in
    // tests; trigger it once with a sentinel bind, then insert the
    // real row before re-binding.
    let _ = bind_server(&c, "bootstrap", None);
    c.execute(
        "INSERT OR REPLACE INTO servers (id, name) VALUES ('srv1', 'home-dev')",
        [],
    )
    .unwrap();
    let p = sample("office", None);
    save(&c, &p).unwrap();
    bind_server(&c, "srv1", Some(&p.id)).unwrap();

    let bound: Option<String> = c
        .query_row(
            "SELECT egress_profile_id FROM servers WHERE id='srv1'",
            [],
            |r| r.get(0),
        )
        .ok();
    assert_eq!(bound, Some(p.id.clone()));

    bind_server(&c, "srv1", None).unwrap();
    let cleared: Option<String> = c
        .query_row(
            "SELECT egress_profile_id FROM servers WHERE id='srv1'",
            [],
            |r| r.get(0),
        )
        .ok()
        .flatten();
    assert!(cleared.is_none());
}

#[test]
fn touch_updates_updated_at_monotonically() {
    let mut p = EgressProfile::new("home".into(), None);
    let original = p.updated_at.clone();
    // Need at least a microsecond between samples for rfc3339 to differ.
    std::thread::sleep(std::time::Duration::from_millis(10));
    p.touch();
    assert!(p.updated_at >= original);
}

#[test]
fn renumber_hops_repositions() {
    let mut p = EgressProfile::new("home".into(), None);
    p.chain_hops = vec![
        HopRef {
            position: 99,
            hop_type: "ssh".into(),
            hop_id: "a".into(),
        },
        HopRef {
            position: 99,
            hop_type: "ssh".into(),
            hop_id: "b".into(),
        },
        HopRef {
            position: 99,
            hop_type: "ssh".into(),
            hop_id: "c".into(),
        },
    ];
    p.renumber_hops();
    assert_eq!(p.chain_hops[0].position, 0);
    assert_eq!(p.chain_hops[1].position, 1);
    assert_eq!(p.chain_hops[2].position, 2);
}
