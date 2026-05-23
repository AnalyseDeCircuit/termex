//! Public DTOs and pure parsers for the cloud-provider integrations.
//!
//! The async implementations that invoke `kubectl`/`aws` subprocesses live
//! in the closed-source `termex-core-private` crate. OSS consumers can use
//! the types defined here for FRB bridge / Tauri command signatures even
//! when the `private` feature is not enabled.
pub mod detection;
pub mod kube;
pub mod ssm;
