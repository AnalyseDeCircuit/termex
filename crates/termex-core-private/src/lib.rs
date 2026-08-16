//! Stub standing in for the closed-source `termex-core-private` crate.
//!
//! # Why this exists
//!
//! `termex-flutter-bridge` declares this crate as an *optional* path
//! dependency, gated behind the `private` feature. `optional` only controls
//! whether the crate is **compiled** — Cargo still reads the manifest of every
//! path dependency while resolving the workspace. When the path pointed at a
//! sibling directory that exists only on a maintainer's machine, every CI job
//! died before compiling anything:
//!
//! ```text
//! failed to load manifest for workspace member `crates/termex-flutter-bridge`
//!   failed to load manifest for dependency `termex-core-private`
//!   failed to read `.../termex-core-private/Cargo.toml`
//! ```
//!
//! Committing this stub keeps the OSS tree buildable by anyone, CI included,
//! with no access to the closed-source source and no extra repository secret.
//!
//! # Building with the real implementation
//!
//! The real crate replaces this one through a Cargo path override, which
//! matches on package name and version — keep both in step with the private
//! crate when it is versioned. Copy the template into place only for the
//! duration of a commercial build:
//!
//! ```sh
//! cp .cargo/config.private.toml.example .cargo/config.toml
//! cargo build -p termex_flutter_bridge --release --features private
//! rm .cargo/config.toml
//! ```
//!
//! The override must not be left in place: cargo then warns that it "altered
//! the original list of dependencies", and `flutter_rust_bridge_codegen`
//! cannot parse that output. It silently falls back to `stem: 'UNKNOWN'` in
//! `frb_generated.dart`, which the pre-commit drift check rejects.
//!
//! # Deliberately empty
//!
//! No stand-in APIs are declared here. Every call site in the bridge is
//! already behind `#[cfg(feature = "private")]` with a
//! `#[cfg(not(feature = "private"))]` arm that reports the feature is
//! unavailable, so nothing in an OSS build reaches this crate. Building with
//! `--features private` against this stub therefore fails to compile, which is
//! the intent: a missing implementation should be a build error, not a binary
//! that panics or silently degrades once it is in a user's hands.
