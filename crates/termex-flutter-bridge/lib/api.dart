/// Public entry point for the bridge's API surface.
///
/// Call sites used to reach straight into `src/api.dart`, which is another
/// package's implementation directory — the analyzer flags that, and it left
/// the package free to move its internals out from under every importer.
/// This re-export is the supported name; `src/` stays private.
library;

export 'src/api.dart';
