import 'package:flutter/widgets.dart';

// Detects IME candidate bar height on iOS/Android.
// On iOS, the candidate bar sits between the keyboard and the content area.
// We track it via viewInsets.bottom changes after the keyboard is fully shown.
//
// Usage: wrap your scaffold body with CandidateBarDetector.

const double _kTypicalKeyboardHeight = 250.0;
const double _kCandidateBarHeight = 45.0;

double estimateCandidateBarHeight(BuildContext context) {
  final insets = MediaQuery.viewInsetsOf(context);
  final keyboardHeight = insets.bottom;
  if (keyboardHeight <= 0) return 0.0;
  // When the keyboard is showing AND the inset is larger than a typical
  // keyboard, the extra height is likely the candidate bar.
  if (keyboardHeight > _kTypicalKeyboardHeight + _kCandidateBarHeight) {
    return keyboardHeight - _kTypicalKeyboardHeight;
  }
  return 0.0;
}

// Returns the safe bottom padding accounting for candidate bar.
double safeBottomWithIme(BuildContext context) {
  final insets = MediaQuery.viewInsetsOf(context);
  final safeArea = MediaQuery.paddingOf(context).bottom;
  return insets.bottom > 0 ? insets.bottom : safeArea;
}

class CandidateBarDetector extends StatefulWidget {
  final Widget Function(BuildContext context, double candidateBarHeight) builder;

  const CandidateBarDetector({super.key, required this.builder});

  @override
  State<CandidateBarDetector> createState() => _CandidateBarDetectorState();
}

class _CandidateBarDetectorState extends State<CandidateBarDetector>
    with WidgetsBindingObserver {
  double _candidateBarHeight = 0.0;
  double _prevKeyboardHeight = 0.0;
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final view = View.of(context);
      final insets = view.viewInsets;
      final pixelRatio = view.devicePixelRatio;
      final keyboardHeight = insets.bottom / pixelRatio;

      if (!_keyboardVisible && keyboardHeight > 0) {
        _keyboardVisible = true;
        _prevKeyboardHeight = keyboardHeight;
      } else if (_keyboardVisible && keyboardHeight > _prevKeyboardHeight + 20) {
        // Inset grew after keyboard appeared — candidate bar likely shown.
        final extra = keyboardHeight - _prevKeyboardHeight;
        setState(() => _candidateBarHeight = extra);
      } else if (_keyboardVisible && keyboardHeight < _prevKeyboardHeight - 20) {
        // Inset shrank — candidate bar dismissed.
        setState(() => _candidateBarHeight = 0.0);
        _prevKeyboardHeight = keyboardHeight;
      }

      if (keyboardHeight <= 0) {
        _keyboardVisible = false;
        _prevKeyboardHeight = 0;
        if (_candidateBarHeight != 0) {
          setState(() => _candidateBarHeight = 0.0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _candidateBarHeight);
}
