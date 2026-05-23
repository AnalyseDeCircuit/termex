import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// Detects whether a hardware (external) keyboard is connected.
// On iOS/Android, Flutter exposes hardware key events via HardwareKeyboard.
// We detect connection by listening for key events that can only originate
// from a hardware keyboard (non-software key events).
//
// Note: Flutter does not expose a direct "keyboard connected" API on mobile.
// We use a heuristic: a hardware keyboard event updates the detected state.

class HardwareKeyboardDetector extends StatefulWidget {
  final Widget Function(BuildContext context, bool isConnected) builder;

  const HardwareKeyboardDetector({super.key, required this.builder});

  @override
  State<HardwareKeyboardDetector> createState() =>
      _HardwareKeyboardDetectorState();
}

class _HardwareKeyboardDetectorState extends State<HardwareKeyboardDetector> {
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (!_isConnected) {
      setState(() => _isConnected = true);
    }
    return false; // don't consume the event
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _isConnected);
}

// Lightweight notifier for components that need to react to keyboard state.
class HardwareKeyboardNotifier extends ChangeNotifier {
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  late final _handler = _handleKey;

  HardwareKeyboardNotifier() {
    HardwareKeyboard.instance.addHandler(_handler);
  }

  bool _handleKey(KeyEvent event) {
    if (!_isConnected) {
      _isConnected = true;
      notifyListeners();
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handler);
    super.dispose();
  }
}
