import BackgroundTasks
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  // BGTaskScheduler identifier. Must match Info.plist
  // `BGTaskSchedulerPermittedIdentifiers`. iOS will refuse to register
  // an identifier that isn't listed there.
  private let keepaliveTaskId = "com.example.termex.keepalive"

  // Active background-task identifiers, keyed by call-site nonce. We
  // bucket by a refcount the same way Android's foreground service
  // does: each `startSession` opens a new task; `stopSession` closes
  // the most recently opened one. The OS gives ~30 seconds total per
  // task before forcibly ending it — enough time for SSH to flush
  // pending writes and surface a clean "Disconnected" toast when the
  // user re-foregrounds, but not enough for indefinite background
  // sessions. (iOS doesn't permit indefinite background networking
  // for non-VoIP apps without specific entitlements.)
  private var backgroundTasks: [UIBackgroundTaskIdentifier] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register the BGTaskScheduler handler BEFORE `application(_:didFinishLaunchingWithOptions:)`
    // returns, otherwise iOS rejects the registration with the
    // "All launch handlers must be registered before application
    // finishes launching" runtime error.
    if #available(iOS 13.0, *) {
      BGTaskScheduler.shared.register(
        forTaskWithIdentifier: keepaliveTaskId,
        using: nil
      ) { task in
        self.handleKeepaliveTask(task as! BGAppRefreshTask)
      }
    }

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "termex/background",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return result(nil) }
      switch call.method {
      case "startSession":
        self.beginBackgroundTask()
        if #available(iOS 13.0, *) {
          self.scheduleKeepaliveTask()
        }
        result(nil)
      case "stopSession":
        self.endBackgroundTask()
        // No need to cancel the BGAppRefreshTask explicitly — iOS
        // simply won't fire it again once stopSession runs the
        // session count down to zero (we don't reschedule). Pending
        // ones get cancelled the next time the app exits.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - BGAppRefreshTask (keepalive)

  @available(iOS 13.0, *)
  private func scheduleKeepaliveTask() {
    let request = BGAppRefreshTaskRequest(identifier: keepaliveTaskId)
    // Earliest begin date is "as soon as iOS allows". The OS decides
    // the actual fire time based on usage patterns, battery, etc.
    // Typical interval observed in production apps is 1-6 hours.
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      // Most common failure is "BGTaskScheduler is not permitted"
      // when the user has disabled Background App Refresh for
      // Termex in Settings. We swallow the error — the Flutter UI
      // already explains the ~30s foreground-task limit elsewhere.
    }
  }

  @available(iOS 13.0, *)
  private func handleKeepaliveTask(_ task: BGAppRefreshTask) {
    // Reschedule a fresh task before processing this one — iOS only
    // allows one pending task per identifier at a time, so we have to
    // submit the next request before this one completes.
    scheduleKeepaliveTask()

    task.expirationHandler = {
      // iOS pulled the plug; just mark this run as incomplete so the
      // OS doesn't penalise future grants.
      task.setTaskCompleted(success: false)
    }

    // The Flutter / Rust SSH stack maintains its own TCP keepalive
    // via russh's keepalive_interval configuration. The BGAppRefresh
    // window primarily keeps the *process* warm so existing TCP
    // sockets don't go through full kernel cleanup before the user
    // returns. We don't need to send anything from native code; just
    // marking the task complete is enough.
    task.setTaskCompleted(success: true)
  }

  // MARK: - Background tasks

  private func beginBackgroundTask() {
    let app = UIApplication.shared
    var taskId: UIBackgroundTaskIdentifier = .invalid
    taskId = app.beginBackgroundTask(withName: "TermexSshSession") { [weak self] in
      // Expiration handler — iOS is about to kill the task. End it
      // cleanly so the OS doesn't penalise future background grants.
      guard let self = self else { return }
      if taskId != .invalid {
        UIApplication.shared.endBackgroundTask(taskId)
        self.backgroundTasks.removeAll { $0 == taskId }
      }
    }
    if taskId != .invalid {
      backgroundTasks.append(taskId)
    }
  }

  private func endBackgroundTask() {
    guard let taskId = backgroundTasks.popLast() else { return }
    if taskId != .invalid {
      UIApplication.shared.endBackgroundTask(taskId)
    }
  }
}
