import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global navigator key — lets services without a BuildContext (Riverpod
/// notifiers, lifecycle hooks, error boundaries) push dialogs onto the
/// root navigator. Mounted into [WidgetsApp.navigatorKey] in main.dart.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Async-resolved SharedPreferences instance, shared across providers.
final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

/// Stores the user's preferred UI locale code (e.g. "en", "zh"). When null
/// Flutter falls back to the system locale.
final localeProvider = StateProvider<Locale?>((ref) {
  final prefs = ref.watch(sharedPrefsProvider).valueOrNull;
  final code = prefs?.getString('app.locale');
  return code == null ? null : Locale(code);
});

/// Persists [locale] (or clears the override when null) and updates the
/// locale provider so the UI rebuilds.
Future<void> setAppLocale(WidgetRef ref, Locale? locale) async {
  final prefs = await ref.read(sharedPrefsProvider.future);
  if (locale == null) {
    await prefs.remove('app.locale');
  } else {
    await prefs.setString('app.locale', locale.languageCode);
  }
  ref.read(localeProvider.notifier).state = locale;
}
