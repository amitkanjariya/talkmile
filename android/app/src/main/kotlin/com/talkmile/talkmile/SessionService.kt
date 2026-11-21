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
    private var recognitionAttempt = 0
    private var restartCount = 0
    private val mainHandler = Handler(Looper.getMainLooper())
    private var listeningTimeout: Runnable? = null

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
        restartCount = 0
        pendingListenResult = result
        startListeningAttempt()
    }

    fun recoverSpeechRecognizer() {
        if (pendingListenResult != null) restartListening(0L)
    }

    private fun startListeningAttempt() {
        if (pendingListenResult == null) return
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED) {
            finishListening(errorCode = SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS,
                message = "Microphone permission is required.")
            return
        }

        val attempt = ++recognitionAttempt
        try {
            val recognizer = SpeechRecognizer.createSpeechRecognizer(applicationContext)
            speechRecognizer = recognizer
            recognizer.setRecognitionListener(object : RecognitionListener {
                private fun isCurrent() = speechRecognizer === recognizer &&
                    recognitionAttempt == attempt && pendingListenResult != null

                override fun onReadyForSpeech(params: Bundle?) {
                    if (isCurrent()) restartCount = 0
                }
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = Unit

                override fun onError(error: Int) {
                    if (!isCurrent()) return
                    if (partialTranscript.isNotBlank()) {
                        finishListening(partialTranscript)
                    } else {
                        restartListening()
                    }
                }

                override fun onResults(results: Bundle?) {
                    if (!isCurrent()) return
                    val transcript = bestTranscript(results).ifBlank { partialTranscript }
                    if (transcript.isNotBlank()) finishListening(transcript)
                    else restartListening()
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    if (!isCurrent()) return
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
            recognizer.startListening(intent)

            val timeout = Runnable {
                if (speechRecognizer !== recognizer || recognitionAttempt != attempt ||
                    pendingListenResult == null) return@Runnable
                if (partialTranscript.isNotBlank()) finishListening(partialTranscript)
                else restartListening()
            }
            listeningTimeout = timeout
            mainHandler.postDelayed(timeout, 55_000L)
        } catch (_: Exception) {
            restartListening()
        }
    }

    private fun restartListening(delayMillis: Long? = null) {
        if (pendingListenResult == null) return
        listeningTimeout?.let(mainHandler::removeCallbacks)
        listeningTimeout = null
        recognitionAttempt++
        val oldRecognizer = speechRecognizer
        speechRecognizer = null
        oldRecognizer?.cancel()
        oldRecognizer?.destroy()

        val delay = delayMillis ?: minOf(
            500L * (1L shl minOf(restartCount++, 2)),
            2_000L,
        )
        mainHandler.postDelayed({ startListeningAttempt() }, delay)
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
        listeningTimeout?.let(mainHandler::removeCallbacks)
        listeningTimeout = null
        recognitionAttempt++
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
