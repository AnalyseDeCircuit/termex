import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../system/app_globals.dart';
import '../widgets/button.dart';
import '../widgets/dialog.dart';

/// Wraps the app and, on first launch *after* a Tauri install is detected,
/// presents a one-time "Welcome back — here's what's new in v0.62" card so
/// returning users aren't disoriented by the menu/sidebar/shortcut changes.
///
/// The detection heuristic is: the SQLCipher database file already exists
/// at the platform-specific Termex data directory before Flutter has a
/// chance to create it (i.e. AppInitState.is_first_run == false). Because
/// the bridge has already opened the DB by the time main.dart runs, we
/// instead use a "first launch of v0.62 build" flag to gate it.
class MigrationWelcomeOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const MigrationWelcomeOverlay({super.key, required this.child});

  @override
  ConsumerState<MigrationWelcomeOverlay> createState() =>
      _MigrationWelcomeOverlayState();
}

class _MigrationWelcomeOverlayState
    extends ConsumerState<MigrationWelcomeOverlay> {
  static const _kSeenKey = 'migration.welcome.v0_62.seen';
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    // Defer to first frame so a NavigatorState is available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    if (_checked || !mounted) return;
    _checked = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kSeenKey) ?? false) return;

    // Only show on desktop OSes where this matters; mobile is a fresh app.
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      await prefs.setBool(_kSeenKey, true);
      return;
    }
    // MigrationWelcomeOverlay wraps the entire widget tree including the app's
    // Navigator, so its own context has no Navigator ancestor. Use the global
    // navigator key which always points to the root navigator.
    final navCtx = rootNavigatorKey.currentContext;
    // The root navigator's context, not this widget's — so it is that
    // context's own liveness that has to hold across the awaits above.
    if (navCtx == null || !navCtx.mounted) return;

    await showTermexDialog<void>(
      context: navCtx,
      title: 'Welcome to Termex v0.62',
      size: DialogSize.medium,
      body: const _WelcomeCard(),
      actions: [
        TermexButton(
          label: 'Got it',
          variant: ButtonVariant.primary,
          onPressed: () => Navigator.of(navCtx).pop(),
        ),
      ],
    );

    await prefs.setBool(_kSeenKey, true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TermexSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your data is intact.',
            style: TermexTypography.body.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: TermexSpacing.sm),
          Text(
            'All your servers, snippets, team config, and AI providers '
            'have been carried over from the previous version. The '
            'encrypted database is unchanged.',
            style: TermexTypography.bodySmall.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: TermexSpacing.lg),
          Text(
            "What's new in this build:",
            style: TermexTypography.body.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: TermexSpacing.sm),
          const _Bullet('Native menu bar — File / View / Window / Help.'),
          const _Bullet('Cmd+, Settings · Cmd+\\ toggle sidebar · '
              'Cmd+Shift+I toggle AI panel.'),
          const _Bullet('Drag servers in the sidebar to reorder.'),
          const _Bullet('Window size and position are now remembered '
              'across launches.'),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: SizedBox(
              width: 4,
              height: 4,
              child: ColoredBox(color: context.colors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TermexTypography.bodySmall.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience: clears the one-shot flag so the welcome dialog can be
/// re-tested. Wired into a hidden Settings action; not user-facing.
Future<void> debugResetMigrationWelcome() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('migration.welcome.v0_62.seen');
}

/// Used in tests: returns the StateProvider.value-style stream of whether
/// the welcome should be shown.
final migrationWelcomeSeenProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('migration.welcome.v0_62.seen') ?? false;
});
