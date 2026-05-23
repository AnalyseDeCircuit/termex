import 'dart:async';

import 'package:battery_plus/battery_plus.dart';

/// Emits battery level (0-100) whenever the battery state changes.
/// Suitable for wiring to [MonitorScheduler.onBatteryLevel].
class BatteryMonitor {
  final Battery _battery;

  BatteryMonitor({Battery? battery}) : _battery = battery ?? Battery();

  /// Stream of battery levels triggered by state-change events.
  Stream<int> get batteryLevelStream {
    return _battery.onBatteryStateChanged.asyncMap((_) async {
      return _battery.batteryLevel;
    });
  }

  Future<int> currentLevel() => _battery.batteryLevel;

  /// Returns `true` when the battery level is below [threshold].
  Future<bool> isLow({int threshold = 20}) async {
    final level = await currentLevel();
    return level < threshold;
  }
}
