package com.example.termex

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Foreground service that keeps the Flutter / Rust process alive while
 * Termex has at least one active SSH session.
 *
 * Without this service, Android will pause the Flutter isolate within
 * seconds of the user backgrounding the app, severing every live SSH
 * connection. With the foreground notification + partial wake lock,
 * the OS treats Termex as a user-initiated long-running task and keeps
 * the process scheduled until the service is explicitly stopped.
 *
 * Started / stopped via a MethodChannel from Dart — see
 * `MainActivity.configureFlutterEngine` and
 * `app/lib/mobile/background_service.dart`.
 */
class TermexBackgroundService : Service() {

    companion object {
        const val CHANNEL_ID = "termex_ssh_session"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.example.termex.START_SESSION"
        const val ACTION_STOP = "com.example.termex.STOP_SESSION"
        const val EXTRA_SESSION_COUNT = "session_count"
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var sessionCount: Int = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                sessionCount = intent.getIntExtra(EXTRA_SESSION_COUNT, 1)
                startForeground(NOTIFICATION_ID, buildNotification(sessionCount))
                acquireWakeLock()
            }
            ACTION_STOP -> {
                releaseWakeLock()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> {
                // Defensive: if Android restarts us with a null intent
                // (rare on modern versions) treat it as a fresh start.
                sessionCount = 1
                startForeground(NOTIFICATION_ID, buildNotification(sessionCount))
                acquireWakeLock()
            }
        }
        // START_STICKY so the OS will try to restart us if killed under
        // memory pressure — the user wants their session back as soon as
        // resources free up.
        return START_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SSH session",
            // LOW: silent, no sound / vibration, but still visible in
            // the status bar so the user can dismiss the session.
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Indicates that Termex has an active SSH session" +
                " running in the background."
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(count: Int): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pendingFlags =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            else
                PendingIntent.FLAG_UPDATE_CURRENT
        val contentIntent = PendingIntent.getActivity(
            this, 0, launchIntent, pendingFlags,
        )

        val title = if (count == 1) {
            "Termex — 1 active session"
        } else {
            "Termex — $count active sessions"
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle(title)
            .setContentText("Tap to return to Termex.")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    // ── Wake lock ─────────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Termex::SshSessionWakelock",
        ).apply {
            // No timeout — released explicitly when the service stops.
            // Battery cost is bounded by the foreground notification
            // which the user can dismiss to end the session.
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }
}
