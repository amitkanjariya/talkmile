package com.talkmile.talkmile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.UUID

/** Visible session lifetime and microphone recognition owner. Recognition is
 * restarted per turn while this foreground service remains active.
 */
class SessionService : Service() {
    private var sessionWakeLock: PowerManager.WakeLock? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingListenResult: MethodChannel.Result? = null
    private var partialTranscript = ""
    private var preferOnDeviceRecognizer = false
    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false
    private var pendingSpeech: PendingSpeech? = null
    private var speechPlayer: MediaPlayer? = null
    private var speechFile: File? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val listeningTimeout = Runnable { finishListening(partialTranscript) }
    private val speechTimeout = Runnable {
        if (pendingSpeech != null) {
            Log.e(TAG, "Speech synthesis or playback timed out; restarting TTS")
            failPendingSpeech("Speech was interrupted. Retrying.")
            restartTextToSpeech()
        }
    }

    private data class PendingSpeech(
        val text: String,
        val rate: Float,
        val pitch: Float,
        val voiceName: String?,
        val locale: String?,
        val result: MethodChannel.Result,
        val utteranceId: String = UUID.randomUUID().toString(),
    )

    companion object {
        const val ACTION_START = "com.talkmile.talkmile.START"
        const val ACTION_STOP = "com.talkmile.talkmile.STOP"
        private const val CHANNEL_ID = "talkmile_conversation"
        private const val NOTIFICATION_ID = 1001
        private const val TAG = "TalkMileSession"

        @Volatile
        var activeInstance: SessionService? = null
            private set
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        activeInstance = this
        preferOnDeviceRecognizer = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(applicationContext)
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(
            CHANNEL_ID, "Active conversation", NotificationManager.IMPORTANCE_LOW))
        initializeTextToSpeech()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            finishListening(errorCode = SpeechRecognizer.ERROR_CLIENT)
            stopSpeech()
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
            val recognizer = createRecognizer()
            speechRecognizer = recognizer
            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) = Unit
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = Unit

                override fun onError(error: Int) {
                    Log.w(TAG, "Speech recognizer error: $error")
                    if (preferOnDeviceRecognizer &&
                        (error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ||
                            error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE)) {
                        preferOnDeviceRecognizer = false
                    }
                    if (error == SpeechRecognizer.ERROR_NO_MATCH ||
                        error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                        finishListening(partialTranscript)
                    } else {
                        finishListening(errorCode = error)
                    }
                }

                override fun onResults(results: Bundle?) {
                    val transcript = bestTranscript(results).ifBlank { partialTranscript }
                    finishListening(transcript)
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
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            }
            recognizer.startListening(intent)
            mainHandler.postDelayed(listeningTimeout, 55_000L)
            Log.i(TAG, "Started ${if (preferOnDeviceRecognizer) "on-device" else "system"} recognition turn")
        } catch (error: Exception) {
            Log.e(TAG, "Could not start speech recognition", error)
            finishListening(errorCode = SpeechRecognizer.ERROR_CLIENT,
                message = error.message ?: "Could not start speech recognition.")
        }
    }

    fun recoverSpeechRecognizer() {
        if (pendingListenResult != null) {
            finishListening(errorCode = SpeechRecognizer.ERROR_CLIENT,
                message = "Speech recognition timed out and is restarting.")
        }
    }

    /** Synthesize to a file, then play it from this foreground service. The
     * Google TTS engine's own background audio track is muted on some devices;
     * playing the synthesized file under TalkMile's mediaPlayback FGS avoids
     * that separate-UID background playback restriction.
     */
    fun speak(
        text: String,
        rate: Double,
        voiceName: String?,
        locale: String?,
        pitch: Double,
        result: MethodChannel.Result,
    ) {
        if (text.isBlank()) {
            result.success(null)
            return
        }
        if (pendingSpeech != null || speechPlayer != null) {
            result.error("TTS_BUSY", "TalkMile is already speaking.", null)
            return
        }
        val request = PendingSpeech(
            text = text,
            rate = rate.toFloat().coerceIn(0.1f, 2.0f),
            pitch = pitch.toFloat().coerceIn(0.5f, 2.0f),
            voiceName = voiceName,
            locale = locale,
            result = result,
        )
        pendingSpeech = request
        scheduleSpeechTimeout(45_000L)
        if (ttsReady) synthesize(request)
    }

    fun recoverSpeech() {
        pendingSpeech?.let { failPendingSpeech("Speech was interrupted. Retrying.") }
        restartTextToSpeech()
    }

    private fun restartTextToSpeech() {
        mainHandler.removeCallbacks(speechTimeout)
        ttsReady = false
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        initializeTextToSpeech()
    }

    private fun scheduleSpeechTimeout(delayMs: Long) {
        mainHandler.removeCallbacks(speechTimeout)
        mainHandler.postDelayed(speechTimeout, delayMs)
    }

    private fun initializeTextToSpeech() {
        textToSpeech = TextToSpeech(applicationContext) { status ->
            if (status != TextToSpeech.SUCCESS) {
                ttsReady = false
                Log.e(TAG, "Text-to-speech initialization failed: $status")
                failPendingSpeech("Text-to-speech could not be initialized.")
                return@TextToSpeech
            }
            val tts = textToSpeech ?: return@TextToSpeech
            tts.setLanguage(Locale("en", "IN"))
            tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) = Unit

                override fun onDone(utteranceId: String?) {
                    if (utteranceId != pendingSpeech?.utteranceId) return
                    Log.i(TAG, "Speech synthesis completed; starting foreground playback")
                    scheduleSpeechTimeout(60_000L)
                    mainHandler.post { playPendingSpeechFile() }
                }

                @Deprecated("Deprecated in Android, retained for TTS engine compatibility")
                override fun onError(utteranceId: String?) {
                    if (utteranceId == pendingSpeech?.utteranceId) {
                        mainHandler.post { failPendingSpeech("Speech synthesis failed.") }
                    }
                }

                override fun onError(utteranceId: String?, errorCode: Int) {
                    if (utteranceId == pendingSpeech?.utteranceId) {
                        mainHandler.post { failPendingSpeech("Speech synthesis failed ($errorCode).") }
                    }
                }
            })
            ttsReady = true
            pendingSpeech?.let(::synthesize)
        }
    }

    private fun synthesize(request: PendingSpeech) {
        if (pendingSpeech !== request) return
        val tts = textToSpeech ?: run {
            failPendingSpeech("Text-to-speech is unavailable.")
            return
        }
        request.locale?.let { rawLocale ->
            val locale = Locale.forLanguageTag(rawLocale.replace('_', '-'))
            if (locale.language.isNotEmpty()) tts.setLanguage(locale)
        }
        request.voiceName?.let { requestedName ->
            tts.voices?.firstOrNull { it.name == requestedName }?.let(tts::setVoice)
        }
        tts.setPitch(request.pitch)
        tts.setSpeechRate(request.rate)
        val file = File(cacheDir, "talkmile-${request.utteranceId}.wav")
        speechFile = file
        val params = Bundle().apply {
            putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, request.utteranceId)
        }
        val result = tts.synthesizeToFile(request.text, params, file, request.utteranceId)
        if (result != TextToSpeech.SUCCESS) {
            failPendingSpeech("Text-to-speech could not create audio ($result).")
        }
    }

    private fun playPendingSpeechFile() {
        val request = pendingSpeech ?: return
        val file = speechFile ?: run {
            failPendingSpeech("Speech audio was not created.")
            return
        }
        if (!file.isFile || file.length() == 0L) {
            failPendingSpeech("Speech audio is empty.")
            return
        }
        try {
            val player = MediaPlayer()
            speechPlayer = player
            player.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build())
            player.setDataSource(file.absolutePath)
            player.setOnPreparedListener { prepared ->
                if (pendingSpeech === request) {
                    scheduleSpeechTimeout(
                        (prepared.duration.toLong() + 20_000L).coerceIn(30_000L, 300_000L),
                    )
                    prepared.start()
                    Log.i(TAG, "Foreground reply playback started")
                }
            }
            player.setOnCompletionListener {
                releaseSpeechPlayer()
                pendingSpeech = null
                Log.i(TAG, "Foreground reply playback completed")
                request.result.success(null)
            }
            player.setOnErrorListener { _, what, extra ->
                failPendingSpeech("Speech audio playback failed ($what/$extra).")
                true
            }
            player.prepareAsync()
        } catch (error: Exception) {
            Log.e(TAG, "Could not play synthesized speech", error)
            failPendingSpeech("Speech audio playback failed.")
        }
    }

    private fun releaseSpeechPlayer() {
        mainHandler.removeCallbacks(speechTimeout)
        speechPlayer?.let { player ->
            try { player.stop() } catch (_: IllegalStateException) {}
            player.reset()
            player.release()
        }
        speechPlayer = null
        speechFile?.delete()
        speechFile = null
    }

    private fun failPendingSpeech(message: String) {
        val request = pendingSpeech ?: return
        mainHandler.removeCallbacks(speechTimeout)
        pendingSpeech = null
        releaseSpeechPlayer()
        request.result.error("TTS_FAILED", message, null)
    }

    private fun stopSpeech() {
        mainHandler.removeCallbacks(speechTimeout)
        val request = pendingSpeech
        pendingSpeech = null
        textToSpeech?.stop()
        releaseSpeechPlayer()
        request?.result?.success(null)
    }

    private fun createRecognizer(): SpeechRecognizer {
        if (preferOnDeviceRecognizer) {
            try {
                return SpeechRecognizer.createOnDeviceSpeechRecognizer(applicationContext)
            } catch (error: UnsupportedOperationException) {
                Log.w(TAG, "On-device recognition unavailable; using system recognizer", error)
                preferOnDeviceRecognizer = false
            }
        }
        return SpeechRecognizer.createSpeechRecognizer(applicationContext)
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
        if (errorCode == null) {
            Log.i(TAG, "Recognition turn completed: ${if (transcript.isBlank()) "no speech" else "speech received"}")
            result.success(transcript.takeIf { it.isNotBlank() })
        }
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
        stopSpeech()
        textToSpeech?.shutdown()
        textToSpeech = null
        ttsReady = false
        releaseSessionWakeLock()
        if (activeInstance === this) activeInstance = null
        super.onDestroy()
    }
}
