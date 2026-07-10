/// Bridges [notificationSettingsProvider] into the non-Riverpod
/// [NotificationThresholdConfig] singleton read by the sink callback
/// (v0.79.31).
///
/// Mirrors the `MobileLocalizer` / `_LocalizerCacheUpdater` pattern: a
/// widget pinned high in the tree subscribes to the Riverpod provider and
/// mutates a static field that lives outside any build context.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_settings_provider.dart';
import 'notification_threshold.dart';

class NotificationThresholdsListener extends ConsumerWidget {
  final Widget child;
  const NotificationThresholdsListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thresholds = ref.watch(notificationSettingsProvider);
    // Push the latest snapshot into the singleton on every rebuild — cheap
    // (a single static assignment) and idempotent.
    NotificationThresholdConfig.update(thresholds);
    return child;
  }
}
