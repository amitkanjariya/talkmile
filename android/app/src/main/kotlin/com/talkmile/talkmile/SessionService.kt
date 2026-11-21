package com.talkmile.talkmile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/** Visible session lifetime. SpeechRecognizer itself is owned by the Flutter
 * speech adapter; therefore locked-screen recognition remains device-dependent.
 */
class SessionService : Service() {
    private var sessionWakeLock: PowerManager.WakeLock? = null
    companion object {
        const val ACTION_START = "com.talkmile.talkmile.START"
        const val ACTION_STOP = "com.talkmile.talkmile.STOP"
        private const val CHANNEL_ID = "talkmile_conversation"
        private const val NOTIFICATION_ID = 1001
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(
            CHANNEL_ID, "Active conversation", NotificationManager.IMPORTANCE_LOW))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            MainActivity.notifyNotificationStop()
            releaseSessionWakeLock()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val stopIntent = Intent(this, SessionService::class.java).setAction(ACTION_STOP)
        val stopAction = PendingIntent.getService(this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openAction = PendingIntent.getActivity(this, 2, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("TalkMile conversation")
            .setContentText("Microphone session active")
            .setContentIntent(openAction)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(
                android.R.drawable.ic_media_pause, "Stop", stopAction).build())
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val foregroundTypes = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            startForeground(NOTIFICATION_ID, notification,
                foregroundTypes)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        acquireSessionWakeLock()
        return START_NOT_STICKY
    }

    private fun acquireSessionWakeLock() {
        if (sessionWakeLock?.isHeld == true) return
        val powerManager = getSystemService(PowerManager::class.java)
        sessionWakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "$packageName:TalkMileSession",
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseSessionWakeLock() {
        sessionWakeLock?.let { if (it.isHeld) it.release() }
        sessionWakeLock = null
    }

    override fun onDestroy() {
        releaseSessionWakeLock()
        super.onDestroy()
    }
}
