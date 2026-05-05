/// Backward-compat re-export of generated DTOs.
///
/// Hand-written stubs preserved in `models.dart.pre-codegen.bak`
/// (used as contract reference during the transition).
///
/// Post v0.51.x codegen, DTOs live alongside their API functions
/// inside `package:termex/src/frb_generated/api/*.dart`. This file simply
/// re-exports everything so existing `bridge_models.XxxDto` imports keep
/// compiling without per-file changes.
export 'api.dart';
