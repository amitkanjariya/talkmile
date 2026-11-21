package com.talkmile.talkmile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodChannel

/** Visible session lifetime and microphone recognition owner. Recognition is
 * restarted per turn while this foreground service remains active.
 */
class SessionService : Service() {
    private var sessionWakeLock: PowerManager.WakeLock? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingListenResult: MethodChannel.Result? = null
    private var partialTranscript = ""
    private val mainHandler = Handler(Looper.getMainLooper())
    private val listeningTimeout = Runnable { finishListening(partialTranscript) }

    companion object {
        const val ACTION_START = "com.talkmile.talkmile.START"
        const val ACTION_STOP = "com.talkmile.talkmile.STOP"
        private const val CHANNEL_ID = "talkmile_conversation"
        private const val NOTIFICATION_ID = 1001

        @Volatile
        var activeInstance: SessionService? = null
            private set
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        activeInstance = this
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(
            CHANNEL_ID, "Active conversation", NotificationManager.IMPORTANCE_LOW))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            finishListening(errorCode = SpeechRecognizer.ERROR_CLIENT)
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

    fun listen(result: MethodChannel.Result) {
        if (pendingListenResult != null) {
            result.error("RECOGNIZER_BUSY", "Speech recognition is already active.", null)
            return
        }
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED) {
            result.error("MIC_PERMISSION", "Microphone permission is required.", null)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error("NO_RECOGNIZER", "No Android speech recognizer is available.", null)
            return
        }

        partialTranscript = ""
        pendingListenResult = result
        try {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(applicationContext).apply {
                setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) = Unit
                    override fun onBeginningOfSpeech() = Unit
                    override fun onRmsChanged(rmsdB: Float) = Unit
                    override fun onBufferReceived(buffer: ByteArray?) = Unit
                    override fun onEndOfSpeech() = Unit

                    override fun onError(error: Int) {
                        if (error == SpeechRecognizer.ERROR_NO_MATCH ||
                            error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                            finishListening(partialTranscript)
                        } else {
                            finishListening(errorCode = error)
                        }
                    }

                    override fun onResults(results: Bundle?) {
                        finishListening(bestTranscript(results).ifBlank { partialTranscript })
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val latest = bestTranscript(partialResults)
                        if (latest.isNotBlank()) partialTranscript = latest
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) = Unit
                })
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                }
                startListening(intent)
            }
            mainHandler.postDelayed(listeningTimeout, 55_000L)
        } catch (error: Exception) {
            finishListening(errorCode = SpeechRecognizer.ERROR_CLIENT,
                message = error.message ?: "Could not start speech recognition.")
        }
    }

    fun recoverSpeechRecognizer() {
        finishListening(errorCode = SpeechRecognizer.ERROR_CLIENT,
            message = "Speech recognition is restarting.")
    }

    private fun bestTranscript(bundle: Bundle?): String =
        bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()?.trim().orEmpty()

    private fun finishListening(
        transcript: String = "",
        errorCode: Int? = null,
        message: String? = null,
    ) {
        val result = pendingListenResult ?: return
        pendingListenResult = null
        mainHandler.removeCallbacks(listeningTimeout)
        val recognizer = speechRecognizer
        speechRecognizer = null
        recognizer?.cancel()
        recognizer?.destroy()
        if (errorCode == null) result.success(transcript.takeIf { it.isNotBlank() })
        else result.error("SPEECH_RECOGNITION", message ?: "Speech recognition error $errorCode.", errorCode)
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
        finishListening(errorCode = SpeechRecognizer.ERROR_CLIENT,
            message = "The microphone session ended.")
        releaseSessionWakeLock()
        if (activeInstance === this) activeInstance = null
        super.onDestroy()
    }
}
