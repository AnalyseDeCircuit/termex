/// Global cache of the current [AppLocalizations] instance (v0.79.28).
///
/// Bridges the gap between widget-tree localization (which requires
/// `BuildContext`) and emission sites that fire from notifier methods /
/// background pollers / plugin callbacks without any context.
///
/// **Usage**:
///   - A wrapper widget under MobileShell calls [update] every build —
///     so the cache tracks the user's current locale + locale-change
///     events without ceremony.
///   - Emission sites read [current] and either localize when non-null,
///     or fall back to an English string they pre-computed.
///
/// Why a singleton and not a Provider: emissions can fire from contexts
/// without a [Ref] (eg. the FlutterLocalNotifications cold-start callback,
/// daemon poller tick after the widget tree was disposed). A static
/// singleton is the smallest abstraction that survives those paths.
library;

import 'package:termex_shared/l10n/app_localizations.dart';

class MobileLocalizer {
  MobileLocalizer._();

  static AppLocalizations? _current;

  /// The most-recently cached [AppLocalizations]. Null until the wrapper
  /// widget has built at least once (rare — happens only during the very
  /// first frame of app launch, before any source has had a chance to
  /// emit).
  static AppLocalizations? get current => _current;

  /// Update the cache. The wrapper widget calls this in build(). The
  /// call is cheap — a single reference assignment — so calling on every
  /// frame is fine.
  static void update(AppLocalizations l10n) {
    _current = l10n;
  }
}
