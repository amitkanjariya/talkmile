package com.talkmile.talkmile

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "talkmile/session")
        sessionChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
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

    override fun onDestroy() {
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
