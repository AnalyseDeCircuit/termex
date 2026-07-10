/// Mobile-flavoured settings.
///
/// v0.79.55: notifications promoted to a builtin SettingsTab in shared
/// (PC parity — desktop now sees the same Notifications sidebar entry
/// + thresholds UI). The mobile-only test-buttons row passes through
/// `notificationsHeader:` so it still renders above the cross-platform
/// thresholds on iOS / Android.
///
/// v0.79.11 banner (kept): the always-visible Background keep-alive
/// card from v0.79.5 was replaced by a slim one-line banner that:
///   - only renders on Android when Termex is NOT on the
///     battery-optimisation whitelist
///   - exposes a one-tap "Settings" action to open the system intent
///   - is dismissible; the dismissal persists in shared_preferences
///   - never appears on iOS (no equivalent setting; the 30s background
///     limit is documented in v0.79.5 + acceptance checklist instead)
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/features/settings/settings_page.dart';
import 'package:termex_shared/icons/termex_icons.dart';

import 'background_service.dart';
import 'notifications_test_row.dart';

class MobileSettingsPage extends ConsumerStatefulWidget {
  /// v0.79.56: deep-link entry — when set, the embedded SettingsPage
  /// opens directly on this tab. Used by the AI onboarding CTA to land
  /// the user on `SettingsTab.ai` after a tap.
  final SettingsTab? initialTab;
  const MobileSettingsPage({super.key, this.initialTab});

  @override
  ConsumerState<MobileSettingsPage> createState() =>
      _MobileSettingsPageState();
}

class _MobileSettingsPageState extends ConsumerState<MobileSettingsPage>
    with WidgetsBindingObserver {
  /// `null` until the platform / preference probe finishes. `false`
  /// means "show the banner"; `true` means "hide".
  bool? _bannerHidden;
  bool _busy = false;

  // Separate from MobileBatteryNag's flag — that one tracks the
  // one-shot first-connect dialog (v0.79.7); this one tracks the
  // slim banner inside the Settings tab. Independent dismiss state.
  static const _kDismissKey = 'mobile.battery_banner.dismissed_v2';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_resolveVisibility());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-poll on resume — user may have just whitelisted us from the
  /// system Settings app, in which case the banner should disappear
  /// without requiring a tab switch.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resolveVisibility());
    }
  }

  Future<void> _resolveVisibility() async {
    if (!Platform.isAndroid) {
      if (mounted) setState(() => _bannerHidden = true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kDismissKey) ?? false) {
      if (mounted) setState(() => _bannerHidden = true);
      return;
    }
    final whitelisted =
        await MobileBackgroundService.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() => _bannerHidden = whitelisted);
  }

  Future<void> _onOpenSettings() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await MobileBackgroundService.requestIgnoreBatteryOptimizations();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onDismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDismissKey, true);
    if (mounted) setState(() => _bannerHidden = true);
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = _bannerHidden == false;
    return Container(
      color: TermexColors.backgroundPrimary,
      child: Column(
        children: [
          if (showBanner)
            _BatteryBanner(
              onOpenSettings: _onOpenSettings,
              onDismiss: _onDismiss,
              busy: _busy,
            ),
          Expanded(
            child: SettingsPage(
              embedded: true,
              notificationsHeader: const NotificationsTestRow(),
              initialTab: widget.initialTab,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single-row reminder: title + action + dismiss. Renders only on
/// Android when we know the user is not on the battery-optimisation
/// whitelist and hasn't already dismissed.
class _BatteryBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;
  final bool busy;

  const _BatteryBanner({
    required this.onOpenSettings,
    required this.onDismiss,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFF0B132),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Termex may be killed in the background',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TermexTypography.body.copyWith(
                color: TermexColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: busy ? null : onOpenSettings,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                busy ? 'Opening…' : 'Fix',
                style: TermexTypography.body.copyWith(
                  color: TermexColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Container(
              width: 32,
              height: 44,
              alignment: Alignment.center,
              child: const Icon(
                TermexIcons.close,
                size: 18,
                color: TermexColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
