/// v0.79.55: relocated to `termex_shared/features/notifications/` so the
/// desktop SettingsPage can render the same threshold UI as mobile. This
/// file remains as a re-export so the many existing `import
/// 'package:termex/mobile/notification_threshold.dart'` call sites (the
/// task completion sink, the notifier subscriber, tests) stay working
/// without a sweep of import-path edits.
library;

export 'package:termex_shared/features/notifications/notification_threshold.dart';
