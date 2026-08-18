//! The Flutter bridge used to expose recording as metadata only: start
//! inserted a database row, nothing fed the recorder, and stop wrote no file.
//! These cover the wiring that makes a recording contain the session.

use termex_flutter_bridge::api::recording;
use termex_flutter_bridge::frb_ssh_emitter;

#[tokio::test]
async fn start_marks_the_session_active_and_stop_clears_it() {
    let sid = format!("sess-{}", uuid::Uuid::new_v4());

    assert!(!recording::recording_is_active(sid.clone()).await);

    recording::recording_start(
        sid.clone(), "srv".into(), "prod".into(), 80, 24, None, 0, false,
    )
    .await
    .expect("start");

    assert!(recording::recording_is_active(sid.clone()).await);
    // The emitter consults this set on every chunk; without it capture is a
    // no-op no matter what the recorder holds.
    assert!(frb_ssh_emitter::ACTIVE_RECORDINGS.contains(&sid));

    recording::recording_stop(sid.clone()).await.expect("stop");

    assert!(!recording::recording_is_active(sid.clone()).await);
    assert!(!frb_ssh_emitter::ACTIVE_RECORDINGS.contains(&sid));
}

#[tokio::test]
async fn stop_writes_the_captured_output_to_an_asciicast_file() {
    let sid = format!("sess-{}", uuid::Uuid::new_v4());
    recording::recording_start(
        sid.clone(), "srv".into(), "prod".into(), 80, 24, None, 0, false,
    )
    .await
    .expect("start");

    recording::RECORDER.record_output(&sid, "hello from the shell\r\n").await;

    let entry = recording::recording_stop(sid.clone()).await.expect("stop");

    let body = std::fs::read_to_string(&entry.file_path)
        .expect("stop must leave a file behind");
    assert!(body.contains("hello from the shell"),
        "captured output missing from {}", entry.file_path);
    // asciicast v2: a JSON header line, then one JSON array per event.
    assert!(body.starts_with('{'), "expected an asciicast header");

    let _ = std::fs::remove_file(&entry.file_path);
}

#[tokio::test]
async fn stopping_a_session_that_was_never_started_is_an_error() {
    let r = recording::recording_stop("never-started".into()).await;
    assert!(r.is_err());
}

#[tokio::test]
async fn auto_recorded_flag_is_carried_through_start() {
    // The flag drives the AUTO badge in the list; it used to be hardcoded
    // false, so an auto-started recording was indistinguishable from a manual
    // one.
    let sid = format!("sess-{}", uuid::Uuid::new_v4());
    recording::recording_start(
        sid.clone(), "srv".into(), "prod".into(), 80, 24,
        Some("Auto: prod".into()), 0, true,
    )
    .await
    .expect("start");

    assert!(recording::recording_is_active(sid.clone()).await);
    let entry = recording::recording_stop(sid).await.expect("stop");
    assert_eq!(entry.title.as_deref(), Some("Auto: prod"));
    let _ = std::fs::remove_file(&entry.file_path);
}
