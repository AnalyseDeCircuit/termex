/// Mobile local-notification primitive (v0.79.21).
///
/// Wraps the `flutter_local_notifications` plugin in a thin singleton that:
///   1. Initialises iOS + Android channels once at app startup.
///   2. Requests notification permission lazily — the first
///      `notifyTaskComplete(...)` call triggers the OS prompt on iOS 10+ /
///      Android 13+. Older OS versions auto-grant.
///   3. Exposes a single `notifyTaskComplete(...)` entry point that callers
///      use when an AI task transitions to a terminal state.
///
/// **Trigger sources are NOT wired up in v0.79.21.** This iteration ships the
/// notification primitive only; v0.79.22 will hook `daemon_drain_events`'
/// `TaskStatus` events to fire notifications.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'task_detail_page.dart';
import 'task_event_bus.dart';

/// Singleton handle. Call [MobileTaskNotifier.instance.init] from `main.dart`
/// before runApp — initialisation is idempotent and cheap.
class MobileTaskNotifier {
  MobileTaskNotifier._();
  static final MobileTaskNotifier instance = MobileTaskNotifier._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionRequested = false;
  StreamSubscription<TaskEvent>? _busSubscription;

  /// Global navigator key exposed to `WidgetsApp.navigatorKey` so the
  /// notification tap handler can push routes from outside the widget
  /// tree (the plugin callback fires before any user gesture).
  final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'termex-mobile-notif-nav');

  /// Cold-start payload buffer. Populated by [init] when the app was
  /// launched via a notification tap and no Navigator was alive yet to
  /// receive the route. [_routeToTask] flushes it on the first frame.
  String? _pendingDeepLinkTaskId;

  /// Channel ID used on Android. Importance is "default" — silent enough to
  /// not interrupt active terminal work but loud enough that the user notices
  /// when they backgrounded the app waiting for a long-running task.
  static const _androidChannelId = 'termex_tasks';
  static const _androidChannelName = 'AI Task Updates';
  static const _androidChannelDescription =
      'Notifications when long-running AI tasks complete.';

  /// Initialises the underlying plugin. Safe to call multiple times — only
  /// the first call has side effects. Returns early on desktop platforms
  /// since v0.79.21 scopes this to iOS + Android.
  Future<void> init() async {
    if (_initialized) return;
    if (!Platform.isIOS && !Platform.isAndroid) {
      _initialized = true;
      return;
    }
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      // Request permissions lazily via [_ensurePermission] instead — keeps
      // the launch path silent. iOS shows the system prompt on the first
      // `show()` call when permissions haven't been granted yet.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // v0.79.23: cold-start handler — if the user tapped a notification
    // while the app was terminated, the OS hands the payload to us via
    // `getNotificationAppLaunchDetails`. We buffer the taskId so the
    // first frame after Navigator is mounted can flush the route.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final payload = launch?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _pendingDeepLinkTaskId = payload;
        // Defer the actual push to after first frame — runApp hasn't
        // attached the Navigator to the GlobalKey yet at this point.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _flushPendingDeepLink();
        });
      }
    }

    // v0.79.22: auto-subscribe to the TaskEventBus so any source that
    // publishes a terminal event triggers a notification, no extra wiring
    // needed at the call site. Sources still must `publish()` themselves.
    _busSubscription ??= TaskEventBus.instance.stream.listen(_onBusEvent);

    // Android 8+ requires the channel to exist before `show()` is called.
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: _androidChannelDescription,
          importance: Importance.defaultImportance,
        ),
      );
    }
    _initialized = true;
  }

  /// Requests OS notification permission. Idempotent — only triggers the
  /// system prompt the first time. Safe to await before [notifyTaskComplete]
  /// (callers that want to surface UX before a denial should `await` first).
  Future<bool> ensurePermission() async {
    if (_permissionRequested) return true;
    _permissionRequested = true;
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      return granted;
    }
    return false;
  }

  /// Bus subscriber. Only fires a notification when the event reaches a
  /// terminal state — running / pending events stay in-app only.
  ///
  /// v0.79.29: respects [TaskEvent.notify]. When the sink chain marks an
  /// event as below the "interrupt the user" threshold (eg. a sub-MB
  /// fast-finished SFTP upload), the history still records it but the OS
  /// notification is suppressed.
  Future<void> _onBusEvent(TaskEvent event) async {
    if (!event.status.isTerminal) return;
    if (!event.notify) return;
    await notifyTaskComplete(
      taskId: event.taskId,
      title: event.title,
      body: event.summary,
      success: event.status == TaskEventStatus.succeeded,
    );
  }

  /// Foreground-tap handler. Fires when the user taps a notification
  /// while the app is alive (foreground or backgrounded). [payload] is
  /// whatever we passed to `_plugin.show(..., payload: taskId)`.
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _routeToTask(payload);
  }

  /// Pushes [MobileTaskDetailPage] onto the global navigator. If the
  /// navigator isn't mounted yet (cold-start race), the request is
  /// silently dropped — the cold-start flush in [init] retries from a
  /// PostFrame callback.
  void _routeToTask(String taskId) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      // Save for next-frame retry — happens during launch ordering.
      _pendingDeepLinkTaskId = taskId;
      return;
    }
    nav.push(PageRouteBuilder<void>(
      pageBuilder: (ctx, _, __) => MobileTaskDetailPage(taskId: taskId),
    ));
  }

  void _flushPendingDeepLink() {
    final taskId = _pendingDeepLinkTaskId;
    if (taskId == null) return;
    final nav = navigatorKey.currentState;
    if (nav == null) {
      // Navigator still not ready; retry next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _flushPendingDeepLink();
      });
      return;
    }
    _pendingDeepLinkTaskId = null;
    _routeToTask(taskId);
  }

  /// Surfaces a "task complete" notification. Pass [success] = false for
  /// failed/cancelled tasks so the body can be styled differently in the
  /// future (today both render the same notification).
  ///
  /// [taskId] is included in the notification payload so a future deep-link
  /// handler can route taps into the task detail page.
  Future<void> notifyTaskComplete({
    required String taskId,
    required String title,
    required String body,
    bool success = true,
  }) async {
    if (!_initialized) await init();
    if (!Platform.isIOS && !Platform.isAndroid) return;
    await ensurePermission();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    // Notification ID derived from taskId hash — collisions are tolerable
    // (the OS replaces the prior notification with the new one).
    final notificationId = taskId.hashCode & 0x7fffffff;
    try {
      await _plugin.show(notificationId, title, body, details, payload: taskId);
    } catch (e, st) {
      // Notification failures are non-fatal — the in-app banner / task list
      // remains the source of truth. Log so QA can find the underlying issue.
      debugPrint('MobileTaskNotifier.notifyTaskComplete failed: $e\n$st');
    }
  }
}
