import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

// Gesture priority order (highest to lowest):
//   Tap > LongPress (500ms) > Pan > Scale > Scroll
// Conflict resolutions:
//   SwipeToDismiss: endToStart only
//   Pinch: threshold 1.05x before recognition
//   Edge Swipe: disabled by default; force-disabled when hardware keyboard connected
//   LongPress: disables Pan for 50ms after trigger

enum GestureKind { tap, longPress, pan, scale, scroll }

// A resolved conflict rule for two competing gestures.
class GestureConflict {
  final GestureKind winner;
  final GestureKind loser;
  final String reason;

  const GestureConflict({
    required this.winner,
    required this.loser,
    required this.reason,
  });
}

// Priority table — lower index = higher priority.
const List<GestureKind> kGesturePriorityOrder = [
  GestureKind.tap,
  GestureKind.longPress,
  GestureKind.pan,
  GestureKind.scale,
  GestureKind.scroll,
];

// Returns -1 if a > b priority, 1 if b > a, 0 if equal.
int compareGesturePriority(GestureKind a, GestureKind b) {
  final ai = kGesturePriorityOrder.indexOf(a);
  final bi = kGesturePriorityOrder.indexOf(b);
  if (ai < bi) return -1;
  if (ai > bi) return 1;
  return 0;
}

GestureKind resolveConflict(GestureKind a, GestureKind b) =>
    compareGesturePriority(a, b) <= 0 ? a : b;

// Long press state machine: tracks the 50ms pan suppression window.
class LongPressPanGuard {
  static const _suppressDuration = Duration(milliseconds: 50);

  DateTime? _longPressTriggeredAt;

  void onLongPressTriggered() {
    _longPressTriggeredAt = DateTime.now();
  }

  bool get isPanSuppressed {
    final t = _longPressTriggeredAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < _suppressDuration;
  }

  void reset() => _longPressTriggeredAt = null;
}

// Pinch recognizer config: recognise scale gestures at or above the 1.05x
// threshold (and at or below 1/1.05 for pinch-in).  Inclusive comparison
// keeps the boundary case "exactly 1.05" stable across float rounding and
// matches the gesture_registry_test contract ("at threshold — recognized").
const double kPinchThreshold = 1.05;

bool isPinchRecognized(double scale) =>
    scale >= kPinchThreshold || scale <= (1.0 / kPinchThreshold);

// SwipeToDismiss: only endToStart direction is allowed.
bool isSwipeToDismissAllowed(DragUpdateDetails details) =>
    details.primaryDelta != null && details.primaryDelta! < 0;

// Edge swipe registry: tracks disabled state.
class EdgeSwipeRegistry {
  bool _hardwareKeyboardConnected = false;
  bool _userDisabled = false;

  void onHardwareKeyboardChanged(bool connected) {
    _hardwareKeyboardConnected = connected;
  }

  void setUserDisabled(bool disabled) => _userDisabled = disabled;

  bool get isEdgeSwipeEnabled => !_userDisabled && !_hardwareKeyboardConnected;
}

// Unified global gesture registry.
// Manages enabled/disabled state for each gesture kind and integrates
// the LongPressPanGuard and EdgeSwipeRegistry.
abstract final class GestureRegistry {
  static final _disabled = <GestureKind>{};
  static final _longPressPanGuard = LongPressPanGuard();
  static final _edgeSwipe = EdgeSwipeRegistry();

  static bool isEnabled(GestureKind kind) {
    if (_disabled.contains(kind)) return false;
    if (kind == GestureKind.pan && _longPressPanGuard.isPanSuppressed) {
      return false;
    }
    return true;
  }

  static void disable(GestureKind kind) => _disabled.add(kind);
  static void enable(GestureKind kind) => _disabled.remove(kind);

  // Called when a long press starts; suppresses pan for 50ms.
  static void onLongPressStart() {
    _longPressPanGuard.onLongPressTriggered();
  }

  static void onHardwareKeyboardChanged(bool connected) {
    _edgeSwipe.onHardwareKeyboardChanged(connected);
    if (connected) {
      disable(GestureKind.pan); // edge swipe uses pan
    } else {
      enable(GestureKind.pan);
    }
  }

  @visibleForTesting
  static void reset() {
    _disabled.clear();
    _longPressPanGuard.reset();
  }
}
