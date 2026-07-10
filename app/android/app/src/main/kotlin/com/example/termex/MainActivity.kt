package com.example.termex

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "termex/background"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSession" -> {
                    val count = (call.argument<Int>("count") ?: 1)
                    val intent = Intent(this, TermexBackgroundService::class.java).apply {
                        action = TermexBackgroundService.ACTION_START
                        putExtra(TermexBackgroundService.EXTRA_SESSION_COUNT, count)
                    }
                    // startForegroundService is required on Android 8+; the
                    // service must call startForeground within ~5 seconds.
                    startForegroundService(intent)
                    result.success(null)
                }
                "stopSession" -> {
                    val intent = Intent(this, TermexBackgroundService::class.java).apply {
                        action = TermexBackgroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    // SuppressLint: ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS will
    // open the system dialog with a per-app entry; lint flags it
    // because misuse triggers Play Store policy review. Termex is a
    // legitimate long-running SSH client (Play Store policy explicitly
    // lists "task automation" / "background sync" as allowed use
    // cases), so the call is safe.
    @SuppressLint("BatteryLife")
    private fun requestIgnoreBatteryOptimizations() {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
}
