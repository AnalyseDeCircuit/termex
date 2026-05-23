/// Pure state machine for the v0.72.2 screen-wake policy.
///
/// Decides whether `wakelock_plus` should be enabled based on
/// (foreground × running-task × user-preference × charging). The
/// platform-side `WakelockPlus.toggle` call is the caller's job —
/// this module is sync, deterministic, and testable.
library;

class ScreenWakeInputs {
  /// True when the user has enabled "keep screen on" in Settings.
  final bool userPreference;

  /// True when at least one task is in `Running` state.
  final bool hasRunningTask;

  /// True when the app is in the resumed foreground state.
  final bool appInForeground;

  /// True when the device is plugged in. When enabled together with
  /// [keepOnWhileCharging], it overrides `userPreference == false`
  /// so long-overnight tasks aren't dropped just because the user
  /// forgot to flip a toggle.
  final bool charging;

  /// True iff the optional "also keep on while charging" sub-toggle
  /// is enabled. Defaults to true since the iteration designs
  /// recommend it for the long-running task scenario.
  final bool keepOnWhileCharging;

  const ScreenWakeInputs({
    this.userPreference = true,
    this.hasRunningTask = false,
    this.appInForeground = false,
    this.charging = false,
    this.keepOnWhileCharging = true,
  });
}

class ScreenWakeManager {
  /// Decides the wakelock target state for the given inputs.
  /// Returns true → caller should call `WakelockPlus.enable()`.
  static bool shouldEnable(ScreenWakeInputs i) {
    if (!i.appInForeground) return false;
    if (!i.hasRunningTask) return false;
    if (i.userPreference) return true;
    if (i.charging && i.keepOnWhileCharging) return true;
    return false;
  }

  /// Human-readable reason for the current state — surfaced in
  /// Settings dev mode + log lines.
  static String reason(ScreenWakeInputs i) {
    if (!i.appInForeground) return 'app backgrounded';
    if (!i.hasRunningTask) return 'no running task';
    if (i.userPreference) return 'user preference';
    if (i.charging && i.keepOnWhileCharging) return 'charging extra';
    return 'user opted out';
  }
}
