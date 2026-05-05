import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the database has been unlocked with the master password.
final dbUnlockedProvider = StateProvider<bool>((ref) => false);

/// Number of failed unlock attempts in the current session.
final unlockAttemptsProvider = StateProvider<int>((ref) => 0);

/// Whether the unlock UI is rate-limited (too many failed attempts).
final unlockRateLimitProvider = StateProvider<bool>((ref) => false);

/// Whether the app is still loading initial state.
final appLoadingProvider = StateProvider<bool>((ref) => true);
