package com.talkmile.talkmile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingNotificationPermission: MethodChannel.Result? = null
    private var pendingBatteryPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "talkmile/session")
        sessionChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "permissionStatus" -> {
                    val microphone = checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                        PackageManager.PERMISSION_GRANTED
                    val notification = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                        PackageManager.PERMISSION_GRANTED
                    val batteryOptimization = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                        getSystemService(PowerManager::class.java)
                            .isIgnoringBatteryOptimizations(packageName)
                    result.success(mapOf("microphone" to microphone,
                        "notification" to notification,
                        "batteryOptimization" to batteryOptimization))
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                        PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else if (pendingNotificationPermission != null) {
                        result.error("PERMISSION_PENDING", "Notification request is active", null)
                    } else {
                        pendingNotificationPermission = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4301)
                    }
                }
                "openAppSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName"))
                    startActivity(intent)
                    result.success(null)
                }
                "requestBackgroundBatteryAccess" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                        getSystemService(PowerManager::class.java)
                            .isIgnoringBatteryOptimizations(packageName)) {
                        result.success(true)
                    } else if (pendingBatteryPermission != null) {
                        result.error("PERMISSION_PENDING", "Battery access request is active", null)
                    } else {
                        pendingBatteryPermission = result
                        try {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName"),
                            )
                            startActivityForResult(intent, 4302)
                        } catch (error: Exception) {
                            pendingBatteryPermission = null
                            result.error("BATTERY_SETTINGS", error.message, null)
                        }
                    }
                }
                "start" -> {
                    try {
                        val intent = Intent(this, SessionService::class.java)
                            .setAction(SessionService.ACTION_START)
                        startForegroundService(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("SERVICE_START", error.message, null)
                    }
                }
                "listen" -> {
                    val sessionService = SessionService.activeInstance
                    if (sessionService == null) {
                        result.error("SESSION_NOT_ACTIVE", "The microphone session is not active.", null)
                    } else {
                        sessionService.listen(result)
                    }
                }
                "recoverRecognizer" -> {
                    SessionService.activeInstance?.recoverSpeechRecognizer()
                    result.success(null)
                }
                "stop" -> {
                    val intent = Intent(this, SessionService::class.java)
                        .setAction(SessionService.ACTION_STOP)
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int,
        permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4301) {
            pendingNotificationPermission?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            pendingNotificationPermission = null
        }
    }

    override fun onResume() {
        super.onResume()
        // Some system battery pages don't report an activity result. Resolve
        // the pending Flutter call when the user returns to TalkMile.
        pendingBatteryPermission?.let { pending ->
            pending.success(
                getSystemService(PowerManager::class.java)
                    .isIgnoringBatteryOptimizations(packageName),
            )
            pendingBatteryPermission = null
        }
    }

    @Deprecated("Deprecated in Android, retained for the battery settings result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 4302) {
            pendingBatteryPermission?.success(
                getSystemService(PowerManager::class.java)
                    .isIgnoringBatteryOptimizations(packageName),
            )
            pendingBatteryPermission = null
        }
    }

    override fun onDestroy() {
        pendingNotificationPermission?.error("ACTIVITY_CLOSED", "Activity closed", null)
        pendingNotificationPermission = null
        pendingBatteryPermission?.error("ACTIVITY_CLOSED", "Activity closed", null)
        pendingBatteryPermission = null
        sessionChannel = null
        super.onDestroy()
    }

    companion object {
        private var sessionChannel: MethodChannel? = null
        fun notifyNotificationStop() {
            sessionChannel?.invokeMethod("notificationStop", null)
        }
    }
}
