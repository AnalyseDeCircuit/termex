/// Riverpod provider for auto-update state (v0.49 spec §5.4).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_version.dart';
import '../auto_updater.dart';
import '../update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  throw UnimplementedError(
    'updateServiceProvider must be overridden with a ProviderScope override '
    'in main.dart (and in tests).',
  );
});

/// Channel + auto-download preferences surfaced in the About tab.
class UpdatePreferences {
  final String channel;
  final bool autoDownload;
  final int checkIntervalHours;

  const UpdatePreferences({
    this.channel = kAppChannel,
    this.autoDownload = false,
    this.checkIntervalHours = 24,
  });

  UpdatePreferences copyWith({
    String? channel,
    bool? autoDownload,
    int? checkIntervalHours,
  }) =>
      UpdatePreferences(
        channel: channel ?? this.channel,
        autoDownload: autoDownload ?? this.autoDownload,
        checkIntervalHours: checkIntervalHours ?? this.checkIntervalHours,
      );
}

final updatePreferencesProvider =
    NotifierProvider<UpdatePreferencesNotifier, UpdatePreferences>(
  UpdatePreferencesNotifier.new,
);

class UpdatePreferencesNotifier extends Notifier<UpdatePreferences> {
  @override
  UpdatePreferences build() => const UpdatePreferences();

  void setChannel(String channel) => state = state.copyWith(channel: channel);
  void setAutoDownload(bool b) => state = state.copyWith(autoDownload: b);
  void setInterval(int hours) {
    if (hours <= 0) return;
    state = state.copyWith(checkIntervalHours: hours);
  }
}

/// Streams [UpdateStatus] from the injected [UpdateService].
final updateStatusProvider = StreamProvider<UpdateStatus>((ref) {
  final svc = ref.watch(updateServiceProvider);
  return svc.statusStream();
});
