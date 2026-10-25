package com.talkmile.talkmile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingNotificationPermission: MethodChannel.Result? = null

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
                    result.success(mapOf("microphone" to microphone,
                        "notification" to notification))
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

    override fun onDestroy() {
        pendingNotificationPermission?.error("ACTIVITY_CLOSED", "Activity closed", null)
        pendingNotificationPermission = null
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
