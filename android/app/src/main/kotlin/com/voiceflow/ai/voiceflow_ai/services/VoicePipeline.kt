package com.voiceflow.ai.voiceflow_ai.services

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Base64
import android.util.Log
import android.widget.Toast
import com.voiceflow.ai.voiceflow_ai.MainActivity
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Shared Voice Pipeline for Talk2Type (v2.1).
 *
 * Handles:
 * - SpeechRecognizer live session (bn-BD, partials, continuous speech with pause recovery)
 * - AI engine recording mode (AudioRecorderHelper -> Direct Gemini Audio, 2.5s silence auto-stop, 2-min hard limit)
 * - 5 tone modes (bangla/sundor, formal, support, casual, english)
 * - Code-mixing: keeps spoken English words in Latin script inside Bangla sentences
 * - Mode-independent auto language ("অটো"): outputs English if spoken entirely in English
 * - Voice commands ("নতুন লাইন", "দাঁড়ি", "কমা", "প্রশ্নবোধক", "শেষ বাক্য মুছো", "সব মুছো")
 * - Voice snippets expansion (Pro)
 * - Free / Pro gating (20 requests/day for Free users)
 * - Model discovery fallback with 404 auto-skipping
 */
class VoicePipeline(
    private val context: Context,
    private val callback: Callback
) {
    interface Callback {
        fun onStateChanged(state: String) // "idle", "recording", "processing", "success", "error"
        fun onPartial(text: String)
        fun onFinal(text: String, mode: String)
        fun onError(message: String)
        fun onVoiceCommand(action: VoiceCommandAction) {}
        fun onAudioCue(isStart: Boolean) {}
        fun onVibrate(durationMs: Long) {}
    }

    companion object {
        private const val TAG = "Talk2TypeVoicePipeline"
        private const val PREFS_NAME = "FlutterSharedPreferences"

        // Daily limit for free tier
        const val FREE_DAILY_LIMIT = 20

        // Silence detection thresholds for AI recording
        private const val SILENCE_THRESHOLD_AMPLITUDE = 1200
        private const val SILENCE_DURATION_MS = 2500L // 2.5s
        private const val HARD_LIMIT_RECORDING_MS = 120000L // 2 minutes

        // Live recognizer reliability
        private const val READY_TIMEOUT_MS = 2500L
        private const val MAX_START_RETRIES = 3
        private const val FINAL_RESULT_WAIT_MS = 1200L
        private const val ERROR_SERVER_DISCONNECTED_CODE = 11 // SpeechRecognizer.ERROR_SERVER_DISCONNECTED (API 31)
        private const val BANGLA_POLISH_BUDGET_MS = 3500L
        private const val AI_TONE_BUDGET_MS = 8000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var speechRecognizer: SpeechRecognizer? = null
    private var audioRecorderHelper: AudioRecorderHelper = AudioRecorderHelper(context)

    // Session state
    var isListening: Boolean = false
        private set
    var isContinuousSession: Boolean = false
        private set
    var currentMode: String = "sundor"
        private set

    private var isAiEngineActive: Boolean = false
    private var committedText: String = ""
    private var currentPartialText: String = ""
    private var hasShownMissingGeminiKeyToast: Boolean = false

    // Silence detection for AI engine
    private var silenceCheckRunnable: Runnable? = null
    private var hardLimitRunnable: Runnable? = null
    private var lastSpokenTimeMs: Long = 0L

    // Live recognizer reliability (v2.1 voice-fix)
    private var readyAnnounced: Boolean = false
    private var sessionRetries: Int = 0
    private var readyWatchdog: Runnable? = null
    private var awaitingFinal: Boolean = false
    private var finalFallback: Runnable? = null
    private var hasSpokenInSession: Boolean = false

    // Voice Command Types
    enum class VoiceCommandType {
        NEW_LINE,
        DARI,
        COMMA,
        QUESTION_MARK,
        DELETE_LAST_SENTENCE,
        CLEAR_SESSION
    }

    data class VoiceCommandEntry(
        val triggers: List<String>,
        val type: VoiceCommandType,
        val replacement: String? = null
    )

    sealed class VoiceCommandAction {
        data class AppendText(val text: String) : VoiceCommandAction()
        object DeleteLastSentence : VoiceCommandAction()
        object RequestClearConfirmation : VoiceCommandAction()
    }

    private val voiceCommandTable = listOf(
        VoiceCommandEntry(
            triggers = listOf("নতুন লাইন", "নতুন প্যারা", "new line", "newline"),
            type = VoiceCommandType.NEW_LINE,
            replacement = "\n"
        ),
        VoiceCommandEntry(
            triggers = listOf("দাঁড়ি", "দাড়ি", "পূর্ণচ্ছেদ", "ফুলস্টপ", "full stop", "period"),
            type = VoiceCommandType.DARI,
            replacement = "। "
        ),
        VoiceCommandEntry(
            triggers = listOf("কমা", "comma"),
            type = VoiceCommandType.COMMA,
            replacement = ", "
        ),
        VoiceCommandEntry(
            triggers = listOf("প্রশ্নবোধক", "প্রশ্নচিহ্ন", "question mark"),
            type = VoiceCommandType.QUESTION_MARK,
            replacement = "? "
        ),
        VoiceCommandEntry(
            triggers = listOf("শেষ বাক্য মুছো", "শেষ বাক্য ডিলিট", "আগের বাক্য মুছো", "delete last sentence"),
            type = VoiceCommandType.DELETE_LAST_SENTENCE
        ),
        VoiceCommandEntry(
            triggers = listOf("সব মুছো", "সব ডিলিট", "সব মুছুন", "clear all", "delete all"),
            type = VoiceCommandType.CLEAR_SESSION
        )
    )

    fun isProUser(): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.vf_is_pro", false)
    }

    fun canUseVoice(): Boolean {
        if (isProUser()) return true
        val count = getDailyUsageCount()
        return count < FREE_DAILY_LIMIT
    }

    fun getDailyUsageCount(): Int {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val savedDate = prefs.getString("flutter.vf_daily_usage_date", "")
        return if (savedDate == todayStr) {
            try {
                prefs.getInt("flutter.vf_daily_usage_count", 0)
            } catch (_: ClassCastException) {
                prefs.getLong("flutter.vf_daily_usage_count", 0L).toInt()
            }
        } else {
            0
        }
    }

    fun incrementDailyUsageCount() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val savedDate = prefs.getString("flutter.vf_daily_usage_date", "")
        val currentCount = if (savedDate == todayStr) {
            try {
                prefs.getInt("flutter.vf_daily_usage_count", 0)
            } catch (_: ClassCastException) {
                prefs.getLong("flutter.vf_daily_usage_count", 0L).toInt()
            }
        } else {
            0
        }
        val newCount = currentCount + 1
        prefs.edit()
            .putString("flutter.vf_daily_usage_date", todayStr)
            .putInt("flutter.vf_daily_usage_count", newCount)
            .apply()
    }

    private fun isAiEnginePreferred(): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val engine = prefs.getString("flutter.vf_voice_engine", "live") ?: "live"
        if (engine != "ai" && engine != "accurate") return false
        if (!isProUser()) return false

        val primaryKey = prefs.getString("flutter.vf_primary_gemini_api_key", null)
            ?: prefs.getString("flutter.vf_gemini_api_key", null)
        val backupKey = prefs.getString("flutter.vf_backup_gemini_api_key", null)
        val hasGemini = (!primaryKey.isNullOrBlank() && primaryKey.trim().length > 10) ||
                        (!backupKey.isNullOrBlank() && backupKey.trim().length > 10)

        if (!hasGemini) {
            if (!hasShownMissingGeminiKeyToast) {
                hasShownMissingGeminiKeyToast = true
                mainHandler.post {
                    Toast.makeText(
                        context,
                        "AI ইঞ্জিনের জন্য Gemini API key দিন — দ্রুত মোডে চলছে",
                        Toast.LENGTH_LONG
                    ).show()
                }
            }
            return false
        }
        return true
    }

    /**
     * Start voice session with specified tone mode.
     */
    fun startVoiceInput(mode: String = "sundor") {
        if (isListening || awaitingFinal) return

        if (!canUseVoice()) {
            callback.onError("আজকের ২০টি ফ্রি ব্যবহারের সীমা শেষ হয়েছে। সীমাহীন ব্যবহারের জন্য Pro নিন।")
            callback.onStateChanged("idle")
            return
        }

        currentMode = mode
        committedText = ""
        currentPartialText = ""
        isAiEngineActive = isAiEnginePreferred()

        isListening = true

        if (isAiEngineActive) {
            callback.onAudioCue(true)
            callback.onVibrate(40)
            callback.onStateChanged("recording")
            startAiAudioRecording()
        } else {
            // Do NOT tell the user to speak yet: Google's recognizer needs ~0.3-1 s to
            // bind and open the mic. Words spoken before onReadyForSpeech are lost, which
            // made the first attempt "not work". We show "preparing" and switch to
            // "recording" (+ vibration) only in onReadyForSpeech.
            isContinuousSession = true
            readyAnnounced = false
            sessionRetries = 0
            callback.onStateChanged("preparing")
            startContinuousSpeechRecognition()
        }
    }

    /**
     * Stop voice session and process final transcription.
     */
    fun stopVoiceInput() {
        if (!isListening) return
        isListening = false
        callback.onAudioCue(false)

        if (isAiEngineActive) {
            stopAiAudioRecording()
        } else {
            isContinuousSession = false
            stopContinuousSpeechRecognition()
        }
    }

    // =========================================================================
    // SPEECH RECOGNIZER LIVE PATH
    // =========================================================================

    private fun googleRecognizerComponent(): android.content.ComponentName? {
        return try {
            val services = context.packageManager.queryIntentServices(
                Intent(android.speech.RecognitionService.SERVICE_INTERFACE), 0
            )
            services.firstOrNull { it.serviceInfo?.packageName == "com.google.android.googlequicksearchbox" }
                ?.serviceInfo?.let { android.content.ComponentName(it.packageName, it.name) }
        } catch (_: Exception) {
            null
        }
    }

    private fun createSpeechRecognizerSafe(): SpeechRecognizer? {
        googleRecognizerComponent()?.let { comp ->
            try {
                val r = SpeechRecognizer.createSpeechRecognizer(context, comp)
                if (r != null) return r
            } catch (e: Exception) {
                Log.w(TAG, "Google recognizer create failed: ${e.message}")
            }
        }
        if (SpeechRecognizer.isRecognitionAvailable(context)) {
            try {
                val r = SpeechRecognizer.createSpeechRecognizer(context)
                if (r != null) return r
            } catch (e: Exception) {
                Log.w(TAG, "Default createSpeechRecognizer failed: ${e.message}")
            }
        }

        val candidates = listOf(
            android.content.ComponentName("com.google.android.googlequicksearchbox", "com.google.android.voicesearch.serviceapi.GoogleRecognitionService"),
            android.content.ComponentName("com.google.android.tts", "com.google.android.apps.speech.tts.googletts.service.GoogleTTSService")
        )
        for (comp in candidates) {
            try {
                val r = SpeechRecognizer.createSpeechRecognizer(context, comp)
                if (r != null) return r
            } catch (_: Exception) {}
        }

        return try {
            SpeechRecognizer.createSpeechRecognizer(context)
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Create (bind) the recognizer before the user taps the mic, so the first tap
     * starts listening immediately. Called from the keyboard's onStartInputView.
     */
    fun prewarm() {
        if (speechRecognizer != null || isListening) return
        try {
            speechRecognizer = createSpeechRecognizerSafe()
            attachRecognitionListener()
        } catch (e: Exception) {
            Log.w(TAG, "prewarm failed: ${e.message}")
            speechRecognizer = null
        }
    }

    private fun recreateRecognizer() {
        try {
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
        } catch (_: Exception) {}
        speechRecognizer = createSpeechRecognizerSafe()
        attachRecognitionListener()
    }

    private fun startContinuousSpeechRecognition() {
        // Reuse the (pre-warmed) recognizer. Destroying + recreating it on every tap made
        // the first startListening() fail with ERROR_CLIENT / ERROR_RECOGNIZER_BUSY.
        if (speechRecognizer == null) {
            speechRecognizer = createSpeechRecognizerSafe()
            attachRecognitionListener()
        }
        if (speechRecognizer == null) {
            Log.w(TAG, "SpeechRecognizer unavailable! Falling back to audio recording.")
            isAiEngineActive = true
            callback.onAudioCue(true)
            callback.onVibrate(40)
            callback.onStateChanged("recording")
            startAiAudioRecording()
            return
        }
        try { speechRecognizer?.cancel() } catch (_: Exception) {}
        startListeningLoop()
        armReadyWatchdog()
    }

    private fun attachRecognitionListener() {
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                if (isListening) markReady()
            }
            override fun onBeginningOfSpeech() {
                if (isListening) markReady()
            }
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}

            override fun onError(error: Int) {
                Log.w(TAG, "SpeechRecognizer onError: $error")
                if (!isListening && !consumeAwaitingFinal()) return
                if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                    disarmReadyWatchdog()
                    isListening = false
                    isContinuousSession = false
                    currentPartialText = ""
                    committedText = ""
                    callback.onError("মাইক্রোফোন অনুমতি দিন: Talk2Type অ্যাপ খুলে অনুমতি চালু করুন")
                    return
                }
                if (currentPartialText.isNotBlank()) {
                    val trimmed = currentPartialText.trim()
                    if (trimmed.isNotEmpty()) {
                        when (val cmd = evaluateVoiceCommand(trimmed)) {
                            is VoiceCommandAction.DeleteLastSentence -> callback.onVoiceCommand(cmd)
                            is VoiceCommandAction.RequestClearConfirmation -> callback.onVoiceCommand(cmd)
                            is VoiceCommandAction.AppendText -> {
                                if (cmd.text.isNotEmpty()) {
                                    committedText = if (committedText.isEmpty()) cmd.text else "$committedText ${cmd.text}"
                                    callback.onPartial(committedText)
                                }
                            }
                        }
                    }
                    currentPartialText = ""
                }

                if (isContinuousSession && isListening) {
                    val transient = error == SpeechRecognizer.ERROR_CLIENT ||
                            error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY ||
                            error == ERROR_SERVER_DISCONNECTED_CODE
                    if (transient && sessionRetries < MAX_START_RETRIES) {
                        sessionRetries++
                        mainHandler.postDelayed({
                            if (isContinuousSession && isListening) {
                                recreateRecognizer()
                                startListeningLoop()
                                armReadyWatchdog()
                            }
                        }, 250)
                    } else {
                        mainHandler.postDelayed({
                            if (isContinuousSession && isListening) startListeningLoop()
                        }, if (transient) 600L else 100L)
                    }
                } else {
                    finishContinuousSpeechSession()
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val partial = matches?.firstOrNull()?.trim() ?: ""
                if (partial.isNotEmpty() && isListening) {
                    markReady()
                    currentPartialText = partial
                    val liveCombined = if (committedText.isNotEmpty()) "$committedText $partial" else partial
                    callback.onPartial(liveCombined)
                }
            }

            override fun onResults(results: Bundle?) {
                if (!isListening && !consumeAwaitingFinal()) return
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val segment = matches?.firstOrNull()?.trim() ?: ""
                if (segment.isNotEmpty()) {
                    when (val cmd = evaluateVoiceCommand(segment)) {
                        is VoiceCommandAction.DeleteLastSentence -> {
                            callback.onVibrate(35)
                            callback.onVoiceCommand(cmd)
                        }
                        is VoiceCommandAction.RequestClearConfirmation -> {
                            callback.onVibrate(40)
                            callback.onVoiceCommand(cmd)
                        }
                        is VoiceCommandAction.AppendText -> {
                            val textToAppend = cmd.text
                            if (textToAppend.isNotEmpty()) {
                                committedText = if (committedText.isEmpty()) {
                                    textToAppend
                                } else if (textToAppend.startsWith("\n") || textToAppend.startsWith("।") || textToAppend.startsWith(",") || textToAppend.startsWith("?")) {
                                    "$committedText$textToAppend"
                                } else {
                                    "$committedText $textToAppend"
                                }
                                currentPartialText = ""
                                callback.onPartial(committedText)
                            }
                        }
                    }
                } else if (currentPartialText.isNotBlank()) {
                    val trimmed = currentPartialText.trim()
                    when (val cmd = evaluateVoiceCommand(trimmed)) {
                        is VoiceCommandAction.DeleteLastSentence -> callback.onVoiceCommand(cmd)
                        is VoiceCommandAction.RequestClearConfirmation -> callback.onVoiceCommand(cmd)
                        is VoiceCommandAction.AppendText -> {
                            if (cmd.text.isNotEmpty()) {
                                committedText = if (committedText.isEmpty()) cmd.text else "$committedText ${cmd.text}"
                                callback.onPartial(committedText)
                            }
                        }
                    }
                    currentPartialText = ""
                }

                if (isContinuousSession && isListening) {
                    mainHandler.postDelayed({
                        if (isContinuousSession && isListening) startListeningLoop()
                    }, 50)
                } else {
                    finishContinuousSpeechSession()
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
    }

    private fun startListeningLoop() {
        try {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                val lang = "bn-BD"
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, lang)
                putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, lang)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra("android.speech.extra.DICTATION_MODE", true)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1000L)
            }
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            Log.e(TAG, "startListeningLoop failed: ${e.message}")
            if (isContinuousSession && isListening) {
                mainHandler.postDelayed({ if (isContinuousSession && isListening) startListeningLoop() }, 200)
            }
        }
    }

    private fun stopContinuousSpeechRecognition() {
        disarmReadyWatchdog()
        if (!readyAnnounced && currentPartialText.isBlank() && committedText.isBlank()) {
            // Stopped before the mic even opened: nothing to wait for.
            try { speechRecognizer?.cancel() } catch (_: Exception) {}
            finishContinuousSpeechSession()
            return
        }
        // Ask the recognizer for its final result of the last segment; onResults/onError
        // will finish the session. Fallback if it never answers.
        awaitingFinal = true
        callback.onStateChanged("processing")
        try {
            speechRecognizer?.stopListening()
        } catch (_: Exception) {}
        val fb = Runnable {
            if (awaitingFinal) {
                awaitingFinal = false
                try { speechRecognizer?.cancel() } catch (_: Exception) {}
                finishContinuousSpeechSession()
            }
        }
        finalFallback = fb
        mainHandler.postDelayed(fb, FINAL_RESULT_WAIT_MS)
    }

    /** Called by onResults/onError after stopVoiceInput(). Returns false if the event is stale. */
    private fun consumeAwaitingFinal(): Boolean {
        if (!awaitingFinal) return false
        awaitingFinal = false
        finalFallback?.let { mainHandler.removeCallbacks(it) }
        finalFallback = null
        return true
    }

    private fun markReady() {
        disarmReadyWatchdog()
        if (!readyAnnounced && isListening) {
            readyAnnounced = true
            callback.onVibrate(40)
            callback.onStateChanged("recording")
        }
    }

    private fun armReadyWatchdog() {
        disarmReadyWatchdog()
        if (readyAnnounced) return
        val r = Runnable {
            if (!(isContinuousSession && isListening) || readyAnnounced) return@Runnable
            if (sessionRetries < MAX_START_RETRIES) {
                sessionRetries++
                Log.w(TAG, "onReadyForSpeech timeout -> recreating recognizer (retry $sessionRetries)")
                recreateRecognizer()
                startListeningLoop()
                armReadyWatchdog()
            } else {
                // Some recognizers never call onReadyForSpeech; don't leave the UI stuck.
                markReady()
            }
        }
        readyWatchdog = r
        mainHandler.postDelayed(r, READY_TIMEOUT_MS)
    }

    private fun disarmReadyWatchdog() {
        readyWatchdog?.let { mainHandler.removeCallbacks(it) }
        readyWatchdog = null
    }

    private fun finishContinuousSpeechSession() {
        val finalSpoken = if (committedText.isNotBlank()) {
            if (currentPartialText.isNotBlank()) "$committedText $currentPartialText" else committedText
        } else {
            currentPartialText
        }.trim()

        committedText = ""
        currentPartialText = ""

        if (finalSpoken.isEmpty()) {
            callback.onStateChanged("idle")
            return
        }

        // Voice snippet check (Pro)
        val snippet = checkVoiceSnippetMatch(finalSpoken)
        if (snippet != null) {
            incrementDailyUsageCount()
            callback.onFinal(snippet, "snippet")
            MainActivity.notifyTranscriptionCompleted(snippet, "snippet")
            callback.onStateChanged("success")
            mainHandler.postDelayed({ callback.onStateChanged("idle") }, 1200)
            return
        }

        callback.onStateChanged("processing")

        // Transform in background thread according to mode
        Thread {
            val mode = currentMode
            val transformed = when (mode) {
                "english" -> runWithTimeout(AI_TONE_BUDGET_MS) { translateBanglaToEnglish(finalSpoken) }
                    ?.takeIf { it.isNotBlank() } ?: finalSpoken
                "formal", "support", "casual" -> runWithTimeout(AI_TONE_BUDGET_MS) { transformWithGeminiTone(finalSpoken, mode) }
                    ?.takeIf { it.isNotBlank() } ?: formatBengaliPunctuation(finalSpoken)
                else -> runWithTimeout(BANGLA_POLISH_BUDGET_MS) { polishBanglaText(finalSpoken) }
                    ?.takeIf { it.isNotBlank() } ?: formatBengaliPunctuation(finalSpoken)
            }

            mainHandler.post {
                incrementDailyUsageCount()
                callback.onFinal(transformed, currentMode)
                MainActivity.notifyTranscriptionCompleted(transformed, currentMode)
                callback.onStateChanged("success")
                mainHandler.postDelayed({ callback.onStateChanged("idle") }, 1200)
            }
        }.start()
    }

    // =========================================================================
    // AI ENGINE DIRECT RECORDING PATH
    // =========================================================================

    private fun startAiAudioRecording() {
        val audioPath = audioRecorderHelper.startRecording()
        if (audioPath != null) {
            startSilenceDetection()
        } else {
            callback.onError("মাইক্রোফোন রেকর্ডিং শুরু করা যায়নি")
            callback.onStateChanged("idle")
            isListening = false
        }
    }

    private fun startSilenceDetection() {
        stopSilenceDetection()
        val startTime = System.currentTimeMillis()
        lastSpokenTimeMs = startTime
        hasSpokenInSession = false

        hardLimitRunnable = Runnable {
            if (isListening && isAiEngineActive) {
                Log.i(TAG, "AI recording reached 2-minute limit. Stopping.")
                stopVoiceInput()
            }
        }
        mainHandler.postDelayed(hardLimitRunnable!!, HARD_LIMIT_RECORDING_MS)

        silenceCheckRunnable = object : Runnable {
            override fun run() {
                if (!isListening || !isAiEngineActive || !audioRecorderHelper.isRecording) return
                val amp = audioRecorderHelper.getMaxAmplitude()
                val now = System.currentTimeMillis()

                if (amp > SILENCE_THRESHOLD_AMPLITUDE) {
                    hasSpokenInSession = true
                    lastSpokenTimeMs = now
                } else if (hasSpokenInSession) {
                    if (now - lastSpokenTimeMs >= SILENCE_DURATION_MS) {
                        Log.i(TAG, "Silence of 2.5s detected in AI recording. Stopping.")
                        stopVoiceInput()
                        return
                    }
                }
                mainHandler.postDelayed(this, 150)
            }
        }
        mainHandler.postDelayed(silenceCheckRunnable!!, 400)
    }

    private fun stopSilenceDetection() {
        silenceCheckRunnable?.let { mainHandler.removeCallbacks(it) }
        silenceCheckRunnable = null
        hardLimitRunnable?.let { mainHandler.removeCallbacks(it) }
        hardLimitRunnable = null
    }

    private fun stopAiAudioRecording() {
        stopSilenceDetection()
        callback.onStateChanged("processing")

        mainHandler.postDelayed({
            val audioPath = audioRecorderHelper.stopRecording()
            if (audioPath != null) {
                processAiRecordedAudio(audioPath)
            } else {
                callback.onError("কোনো শব্দ রেকর্ড হয়নি। জোরে কথা বলুন।")
                callback.onStateChanged("idle")
            }
        }, 150)
    }

    private fun processAiRecordedAudio(audioPath: String) {
        Thread {
            try {
                val file = File(audioPath)
                if (!file.exists() || file.length() == 0L) {
                    mainHandler.post {
                        callback.onError("রেকর্ডিং ফাইল পাওয়া যায়নি।")
                        callback.onStateChanged("idle")
                    }
                    return@Thread
                }

                val bytes = file.readBytes()
                val base64Audio = Base64.encodeToString(bytes, Base64.NO_WRAP)
                val ext = file.extension.lowercase()
                val mimeType = if (ext == "m4a" || ext == "mp4") "audio/mp4" else "audio/aac"

                val result = callGeminiAudioTranscription(base64Audio, mimeType, currentMode)
                mainHandler.post {
                    if (result.isNotBlank()) {
                        incrementDailyUsageCount()
                        callback.onFinal(result, currentMode)
                        MainActivity.notifyTranscriptionCompleted(result, currentMode)
                        callback.onStateChanged("success")
                        mainHandler.postDelayed({ callback.onStateChanged("idle") }, 1200)
                    } else {
                        callback.onError("AI ট্র্যান্সক্রিপশন সম্পন্ন করা যায়নি")
                        callback.onStateChanged("idle")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "processAiRecordedAudio error: ${e.message}", e)
                mainHandler.post {
                    callback.onError(e.message ?: "AI ট্র্যান্সক্রিপশন ত্রুটি")
                    callback.onStateChanged("idle")
                }
            }
        }.start()
    }

    // =========================================================================
    // GEMINI AUDIO TRANSCRIPTION & TEXT TRANSFORMATION
    // =========================================================================

    private fun getActiveGeminiModels(): List<String> {
        val defaultModels = listOf(
            "gemini-3.5-flash-lite",
            "gemini-3.8-flash",
            "gemini-3.6-flash",
            "gemini-3.1-flash-lite",
            "gemini-flash-lite-latest",
            "gemini-flash-latest",
            "gemini-2.5-flash"
        )
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val cachedJson = prefs.getString("flutter.vf_gemini_models", null)
            val candidates = mutableListOf<String>()
            if (!cachedJson.isNullOrBlank()) {
                val arr = JSONArray(cachedJson)
                for (i in 0 until arr.length()) {
                    val m = arr.optString(i)
                    if (!m.isNullOrBlank()) candidates.add(m)
                }
            }
            if (candidates.isEmpty()) candidates.addAll(defaultModels)

            val unavailJson = prefs.getString("flutter.vf_gemini_unavailable_models", null)
            val now = System.currentTimeMillis()
            val unavailMap = mutableMapOf<String, Long>()
            if (!unavailJson.isNullOrBlank()) {
                val obj = JSONObject(unavailJson)
                val it = obj.keys()
                while (it.hasNext()) {
                    val k = it.next()
                    unavailMap[k] = obj.optLong(k, 0L)
                }
            }

            val active = candidates.filter { (unavailMap[it] ?: 0L) <= now }
            return if (active.isNotEmpty()) active else defaultModels
        } catch (_: Exception) {
            return defaultModels
        }
    }

    private fun markModelUnavailable(model: String) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val unavailJson = prefs.getString("flutter.vf_gemini_unavailable_models", null)
            val obj = if (!unavailJson.isNullOrBlank()) JSONObject(unavailJson) else JSONObject()
            obj.put(model, System.currentTimeMillis() + 86400000L) // 24h
            prefs.edit().putString("flutter.vf_gemini_unavailable_models", obj.toString()).apply()
            Log.i(TAG, "Marked model $model unavailable for 24h")
        } catch (_: Exception) {}
    }

    private fun callGeminiAudioTranscription(base64Audio: String, mimeType: String, mode: String): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val primaryKey = prefs.getString("flutter.vf_primary_gemini_api_key", null)
            ?: prefs.getString("flutter.vf_gemini_api_key", null)
        val backupKey = prefs.getString("flutter.vf_backup_gemini_api_key", null)

        val keys = listOfNotNull(
            primaryKey?.trim()?.takeIf { it.isNotBlank() && it != "YOUR_TEST_GEMINI_KEY" },
            backupKey?.trim()?.takeIf { it.isNotBlank() && it != "YOUR_TEST_GEMINI_KEY" && it != primaryKey }
        )
        if (keys.isEmpty()) return ""

        val systemPrompt = buildSystemPrompt(mode)
        val userPrompt = "Transcribe exactly what was said according to the instructions. Preserve English words in English Latin script. Output ONLY the final transcription text without commentary, quotes, or markdown."

        val jsonBody = JSONObject().apply {
            put("systemInstruction", JSONObject().apply {
                put("parts", JSONArray().put(JSONObject().put("text", systemPrompt)))
            })
            put("contents", JSONArray().put(JSONObject().apply {
                put("parts", JSONArray().apply {
                    put(JSONObject().apply {
                        put("inlineData", JSONObject().apply {
                            put("mimeType", mimeType)
                            put("data", base64Audio)
                        })
                    })
                    put(JSONObject().put("text", userPrompt))
                })
            }))
            put("generationConfig", JSONObject().apply {
                put("temperature", 0.2)
                put("maxOutputTokens", 2048)
            })
        }

        val models = getActiveGeminiModels()
        for (apiKey in keys) {
            for (model in models) {
                try {
                    val url = URL("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent")
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.setRequestProperty("x-goog-api-key", apiKey)
                    conn.connectTimeout = 7000
                    conn.readTimeout = 15000
                    conn.doOutput = true

                    conn.outputStream.use { it.write(jsonBody.toString().toByteArray(Charsets.UTF_8)) }
                    if (conn.responseCode == 200) {
                        val resp = conn.inputStream.bufferedReader().use { it.readText() }
                        val text = parseGeminiTextResponse(resp)
                        if (text.isNotBlank()) return text
                    } else {
                        if (conn.responseCode == 404) markModelUnavailable(model)
                        Log.w(TAG, "Gemini audio ($model) HTTP: ${conn.responseCode}")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Gemini audio ($model) failed: ${e.message}")
                }
            }
        }
        return ""
    }

    fun rewriteText(originalText: String, rewriteMode: String): String {
        val trimmed = originalText.trim()
        if (trimmed.isEmpty()) return ""

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val primaryKey = prefs.getString("flutter.vf_primary_gemini_api_key", null)
            ?: prefs.getString("flutter.vf_gemini_api_key", null)
        val backupKey = prefs.getString("flutter.vf_backup_gemini_api_key", null)

        val keys = listOfNotNull(
            primaryKey?.trim()?.takeIf { it.isNotBlank() && it != "YOUR_TEST_GEMINI_KEY" },
            backupKey?.trim()?.takeIf { it.isNotBlank() && it != "YOUR_TEST_GEMINI_KEY" && it != primaryKey }
        )

        val systemPrompt = when (rewriteMode) {
            "sundor", "polish" -> "You are an expert Bengali editor. Improve punctuation, flow, and clarity while preserving the original meaning and English words. Output ONLY the polished Bengali text."
            "english", "translate" -> "Translate the given Bengali text into natural, fluent English. Output ONLY the English text."
            "shorten", "summarize" -> "Summarize and shorten the following text into concise, punchy Bengali while retaining all key facts. Output ONLY the shortened text."
            "formal" -> "Convert the following Bengali text into formal, polite corporate Bengali suitable for official emails and professional messaging. Output ONLY the formal text."
            "support" -> "Rewrite the following text into a polite, warm, and helpful Bengali customer support message. Output ONLY the customer reply."
            else -> "Improve the punctuation and grammar of the given text. Output ONLY the improved text."
        }

        if (keys.isNotEmpty()) {
            val models = getActiveGeminiModels()
            for (apiKey in keys) {
                for (model in models) {
                    try {
                        val res = callGeminiGenerate(trimmed, systemPrompt, model, apiKey)
                        if (res.isNotBlank()) return res
                    } catch (_: Exception) {}
                }
            }
        }

        // Rule-based fallback if no key or API failed
        return if (rewriteMode == "english") {
            translateBanglaToEnglish(trimmed)
        } else {
            polishBanglaText(trimmed)
        }
    }

    private fun transformWithGeminiTone(text: String, mode: String): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val primaryKey = prefs.getString("flutter.vf_primary_gemini_api_key", null)
            ?: prefs.getString("flutter.vf_gemini_api_key", null)
        val backupKey = prefs.getString("flutter.vf_backup_gemini_api_key", null)

        val keys = listOfNotNull(
            primaryKey?.trim()?.takeIf { it.isNotBlank() && it != "YOUR_TEST_GEMINI_KEY" },
            backupKey?.trim()?.takeIf { it.isNotBlank() && it != "YOUR_TEST_GEMINI_KEY" && it != primaryKey }
        )

        val prompt = buildSystemPrompt(mode)
        if (keys.isNotEmpty()) {
            val models = getActiveGeminiModels()
            for (apiKey in keys) {
                for (model in models) {
                    try {
                        val res = callGeminiGenerate(text, prompt, model, apiKey)
                        if (res.isNotBlank() && !res.equals(text, ignoreCase = true)) return res
                    } catch (_: Exception) {}
                }
            }
        }
        return polishBanglaText(text)
    }

    private fun callGeminiGenerate(text: String, systemPrompt: String, model: String, apiKey: String): String {
        val url = URL("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.setRequestProperty("x-goog-api-key", apiKey.trim())
        conn.connectTimeout = 4000
        conn.readTimeout = 7000
        conn.doOutput = true

        val jsonBody = JSONObject().apply {
            put("systemInstruction", JSONObject().apply {
                put("parts", JSONArray().put(JSONObject().put("text", systemPrompt)))
            })
            put("contents", JSONArray().put(JSONObject().apply {
                put("parts", JSONArray().put(JSONObject().put("text", text)))
            }))
            put("generationConfig", JSONObject().apply {
                put("temperature", 0.2)
                put("maxOutputTokens", 1024)
            })
        }

        conn.outputStream.use { it.write(jsonBody.toString().toByteArray(Charsets.UTF_8)) }
        if (conn.responseCode == 200) {
            val resp = conn.inputStream.bufferedReader().use { it.readText() }
            return parseGeminiTextResponse(resp)
        } else {
            if (conn.responseCode == 404) markModelUnavailable(model)
        }
        return ""
    }

    private fun parseGeminiTextResponse(json: String): String {
        return try {
            val root = JSONObject(json)
            val candidates = root.optJSONArray("candidates")
            val first = candidates?.optJSONObject(0)
            val content = first?.optJSONObject("content")
            val parts = content?.optJSONArray("parts")
            val res = parts?.optJSONObject(0)?.optString("text")?.trim() ?: ""
            res.replace(Regex("^```[a-zA-Z]*\\s*"), "")
                .replace(Regex("\\s*```$"), "")
                .replace(Regex("^\"|\"$"), "")
                .trim()
        } catch (_: Exception) {
            ""
        }
    }

    private fun buildSystemPrompt(mode: String): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val customPrompt = prefs.getString("flutter.vf_custom_prompt_$mode", null)
        val autoLang = prefs.getBoolean("flutter.vf_auto_language", true)

        val vocabList = mutableListOf<String>()
        val vocabJson = prefs.getString("flutter.vf_custom_vocabulary", null)
        if (!vocabJson.isNullOrBlank()) {
            try {
                val arr = JSONArray(vocabJson)
                for (i in 0 until arr.length()) {
                    val w = arr.optString(i).trim()
                    if (w.isNotEmpty()) vocabList.add(w)
                }
            } catch (_: Exception) {}
        }

        val vocabInstruction = if (vocabList.isNotEmpty()) {
            "\nPay special attention to accurately recognize and preserve these specific terms: ${vocabList.joinToString(", ")}."
        } else ""

        val codeMixInstruction = "\nCRITICAL RULE FOR CODE-MIXING: Transcribe exactly what was said. Keep spoken English words and phrases in English (Latin script) within Bengali sentences (e.g. meeting, office, file, confirm, urgent, delivery, payment, phone, laptop, message). Code-mixed speech is normal; do NOT forcefully transliterate common English words into Bengali script."

        val autoLangInstruction = if (autoLang && mode != "english") {
            "\nLANGUAGE DETECTION: The default language is Bengali. However, if the user speaks ENTIRELY in English, output the transcription directly in fluent, natural English. If the user speaks Bengali or code-mixed Bengali and English, write in Bengali while preserving English words in Latin script."
        } else ""

        val basePrompt = if (!customPrompt.isNullOrBlank()) {
            "The input below is speech that was recorded.\n" + customPrompt.trim()
        } else {
            when (mode) {
                "bangla", "guchiye", "sundor" -> "You are an expert Bengali typist and grammar specialist. Format the spoken Bengali text with precise, natural punctuation marks (দাঁড়ি '।', কমা ',', প্রশ্নবোধক '?'). Never omit spoken words, numbers, or details. Output ONLY the final punctuated text without explanations or quotes."
                "formal" -> "You are an executive Bengali communication assistant. Convert the speech into polite, elegant, professional standard Bengali suitable for corporate emails and workplace communication. Add proper punctuation (দাঁড়ি '।', কমা ',', '?'). Maintain all facts and numbers precisely. Output ONLY the final formal Bengali text without explanations or quotes."
                "support" -> "You are a polite and helpful Bengali customer support assistant for online businesses. Transform the spoken text into a courteous, friendly customer reply. Greet appropriately and provide a clear, helpful response without inventing facts. Output ONLY the final customer support reply without explanations or quotes."
                "casual" -> "You are a friendly Bengali conversational typist. Convert the text into warm, casual, colloquial Bengali as used in social chats. Remove stutters while keeping the relaxed tone. Output ONLY the final casual text without explanations or quotes."
                "english" -> "Translate the spoken Bengali into natural, fluent, grammatical English. Output ONLY the English text."
                else -> "Format the text naturally with proper punctuation. Output ONLY the final text without explanations or quotes."
            }
        }

        return basePrompt + vocabInstruction + codeMixInstruction + autoLangInstruction
    }

    private fun polishBanglaText(text: String): String {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return ""

        // 1. Try Gemini
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val primaryKey = prefs.getString("flutter.vf_primary_gemini_api_key", null)
            ?: prefs.getString("flutter.vf_gemini_api_key", null)
        val backupKey = prefs.getString("flutter.vf_backup_gemini_api_key", null)

        val keys = listOfNotNull(
            primaryKey?.trim()?.takeIf { it.isNotBlank() && it != "YOUR_TEST_GEMINI_KEY" },
            backupKey?.trim()?.takeIf { it.isNotBlank() && it != "YOUR_TEST_GEMINI_KEY" && it != primaryKey }
        )
        if (keys.isNotEmpty()) {
            val models = getActiveGeminiModels()
            for (k in keys) {
                for (m in models) {
                    try {
                        val prompt = buildSystemPrompt("sundor")
                        val res = callGeminiGenerate(trimmed, prompt, m, k)
                        if (res.isNotBlank()) return res
                    } catch (_: Exception) {}
                }
            }
        }

        // 2. Free AI polish (if enabled)
        val freeEnabled = prefs.getBoolean("flutter.vf_free_online_engine", true)
        if (freeEnabled) {
            try {
                val res = callFreeAiPunctuation(trimmed)
                if (res.isNotBlank()) return res
            } catch (_: Exception) {}
        }

        // 3. Rule-based Bengali grammar & punctuation formatter
        return formatBengaliPunctuation(trimmed)
    }

    private fun callFreeAiPunctuation(text: String): String {
        val prompt = "You are an expert Bengali editor. Add proper Bengali punctuation marks (দাঁড়ি '।', কমা ',', প্রশ্নবোধক '?') to the following spoken Bengali text. Do NOT change words. Keep the exact words. Output ONLY the properly punctuated Bengali text without any prefix, explanations, or quotes:\n\n$text"
        val url = URL("https://text.pollinations.ai/")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
        conn.setRequestProperty("User-Agent", "Talk2Type/2.1 (Android)")
        conn.connectTimeout = 2500
        conn.readTimeout = 3000
        conn.doOutput = true

        val jsonBody = JSONObject().apply {
            put("messages", JSONArray().put(JSONObject().apply {
                put("role", "user")
                put("content", prompt)
            }))
        }
        conn.outputStream.use { it.write(jsonBody.toString().toByteArray(Charsets.UTF_8)) }
        if (conn.responseCode == 200) {
            val resp = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }.trim()
            if (resp.isNotEmpty() && !resp.startsWith("{") && !resp.startsWith("Error")) {
                val cleaned = resp.replace(Regex("^```[a-zA-Z]*\\s*"), "")
                    .replace(Regex("\\s*```$"), "")
                    .replace(Regex("^\"|\"$"), "")
                    .trim()
                if (cleaned.isNotEmpty()) return cleaned
            }
        }
        return ""
    }

    private fun formatBengaliPunctuation(rawText: String): String {
        var text = rawText.replace(Regex("\\s+"), " ").trim()
        if (text.isEmpty()) return ""

        val verbEndings = listOf(
            "গেলাম", "গেছে", "গিয়েছে", "গিয়েছিল", "গিয়েছিলাম",
            "করলাম", "করল", "করেছে", "করেছিল", "করব", "করবেন", "করি", "করে",
            "হয়েছে", "হয়েছে", "হয়েছিল", "হবে", "হয়", "হয়",
            "ছিল", "ছিলাম", "ছিলেন",
            "আছেন", "আছি", "আছে",
            "বললাম", "বলল", "বলেছে", "বলেছিল",
            "যাব", "যাবেন", "যাবে",
            "পারি", "পারব", "পারবে", "পারবেন",
            "চাই", "চায়", "চান",
            "দেখলাম", "দেখেছি", "দেখব"
        )
        val questionIndicators = listOf("কি", "কী", "কেন", "কোথায়", "কোথায়", "কিভাবে", "কীভাবে", "কখন", "কবে", "কার", "কারা", "কাকে")
        val conjunctions = listOf("এবং", "কিন্তু", "তবে", "কারণ", "তাই", "অথবা", "কিংবা")

        for (conj in conjunctions) {
            text = text.replace(Regex("([^,।?!\\s])\\s+$conj\\b"), "$1, $conj")
        }

        val words = text.split(" ")
        val sb = StringBuilder()
        var sentenceHasQuestion = false

        for (i in words.indices) {
            val word = words[i].trim()
            if (word.isEmpty()) continue
            if (questionIndicators.contains(word)) sentenceHasQuestion = true
            sb.append(word)

            if (i < words.size - 1) {
                val nextWord = words[i + 1].trim()
                val isVerb = verbEndings.contains(word)
                val nextIsConjunction = conjunctions.contains(nextWord)

                if (isVerb && !nextIsConjunction && !word.endsWith("।") && !word.endsWith("?") && !word.endsWith(",")) {
                    if (sentenceHasQuestion) {
                        sb.append("? ")
                        sentenceHasQuestion = false
                    } else {
                        sb.append("। ")
                    }
                    continue
                }
            }
            sb.append(" ")
        }

        var result = sb.toString().trim()
        if (!result.endsWith("।") && !result.endsWith("?") && !result.endsWith("!")) {
            result = if (sentenceHasQuestion) "$result?" else "$result।"
        }
        return result
    }

    private fun translateBanglaToEnglish(text: String): String {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return ""

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val primaryKey = prefs.getString("flutter.vf_primary_gemini_api_key", null)
            ?: prefs.getString("flutter.vf_gemini_api_key", null)
        val backupKey = prefs.getString("flutter.vf_backup_gemini_api_key", null)

        val keys = listOfNotNull(
            primaryKey?.trim()?.takeIf { it.isNotBlank() && it != "YOUR_TEST_GEMINI_KEY" },
            backupKey?.trim()?.takeIf { it.isNotBlank() && it != "YOUR_TEST_GEMINI_KEY" && it != primaryKey }
        )
        if (keys.isNotEmpty()) {
            val models = getActiveGeminiModels()
            for (k in keys) {
                for (m in models) {
                    try {
                        val prompt = "Translate the given Bengali text into natural, fluent English. Output ONLY the English text."
                        val res = callGeminiGenerate(trimmed, prompt, m, k)
                        if (res.isNotBlank()) return res
                    } catch (_: Exception) {}
                }
            }
        }

        // Fallback: Google Translate GTX endpoint
        try {
            val encoded = java.net.URLEncoder.encode(trimmed, "UTF-8")
            val url = URL("https://translate.googleapis.com/translate_a/single?client=gtx&sl=bn&tl=en&dt=t&q=$encoded")
            val conn = url.openConnection() as HttpURLConnection
            conn.setRequestProperty("User-Agent", "Mozilla/5.0")
            conn.connectTimeout = 3000
            conn.readTimeout = 4000
            if (conn.responseCode == 200) {
                val resp = conn.inputStream.bufferedReader().use { it.readText() }
                val root = JSONArray(resp)
                val sentences = root.optJSONArray(0)
                if (sentences != null) {
                    val sb = StringBuilder()
                    for (i in 0 until sentences.length()) {
                        val part = sentences.optJSONArray(i)
                        val trans = part?.optString(0)
                        if (!trans.isNullOrEmpty()) sb.append(trans)
                    }
                    val res = sb.toString().trim()
                    if (res.isNotEmpty()) return res
                }
            }
        } catch (_: Exception) {}

        return trimmed
    }

    private fun checkVoiceSnippetMatch(spoken: String): String? {
        if (!isProUser()) return null
        val cleaned = spoken.trim().replace(Regex("[.。?!\n]+$"), "").trim()
        val lower = cleaned.lowercase()

        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val jsonStr = prefs.getString("flutter.vf_voice_snippets", null) ?: return null
            val array = JSONArray(jsonStr)
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                val trigger = item.optString("trigger", "").trim().replace(Regex("[.。?!\n]+$"), "").trim()
                if (trigger.isNotEmpty() && (trigger.equals(cleaned, ignoreCase = true) || trigger.lowercase() == lower)) {
                    val expansion = item.optString("expansion", "").trim()
                    if (expansion.isNotEmpty()) return expansion
                }
            }
        } catch (_: Exception) {}
        return null
    }

    private fun evaluateVoiceCommand(rawSegment: String): VoiceCommandAction {
        if (!isProUser()) return VoiceCommandAction.AppendText(rawSegment)

        val cleaned = rawSegment.trim().replace(Regex("[.。?!\n]+$"), "").trim()
        val lower = cleaned.lowercase()

        // Standalone command
        for (cmd in voiceCommandTable) {
            for (trigger in cmd.triggers) {
                if (lower == trigger.lowercase() || cleaned == trigger) {
                    return when (cmd.type) {
                        VoiceCommandType.DELETE_LAST_SENTENCE -> VoiceCommandAction.DeleteLastSentence
                        VoiceCommandType.CLEAR_SESSION -> VoiceCommandAction.RequestClearConfirmation
                        else -> VoiceCommandAction.AppendText(cmd.replacement ?: "")
                    }
                }
            }
        }

        // Utterance suffix check
        for (cmd in voiceCommandTable) {
            for (trigger in cmd.triggers) {
                val tLower = trigger.lowercase()
                if (lower.endsWith(" $tLower") || cleaned.endsWith(" $trigger")) {
                    val prefix = cleaned.substring(0, cleaned.length - trigger.length).trimEnd()
                    return when (cmd.type) {
                        VoiceCommandType.DELETE_LAST_SENTENCE -> VoiceCommandAction.DeleteLastSentence
                        VoiceCommandType.CLEAR_SESSION -> VoiceCommandAction.RequestClearConfirmation
                        VoiceCommandType.NEW_LINE -> VoiceCommandAction.AppendText("$prefix\n")
                        VoiceCommandType.DARI -> VoiceCommandAction.AppendText("$prefix। ")
                        VoiceCommandType.COMMA -> VoiceCommandAction.AppendText("$prefix, ")
                        VoiceCommandType.QUESTION_MARK -> VoiceCommandAction.AppendText("$prefix? ")
                    }
                }
            }
        }

        return VoiceCommandAction.AppendText(rawSegment)
    }

    private fun <T> runWithTimeout(timeoutMs: Long, block: () -> T): T? {
        val executor = java.util.concurrent.Executors.newSingleThreadExecutor()
        return try {
            executor.submit(java.util.concurrent.Callable { block() })
                .get(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)
        } catch (e: Exception) {
            Log.w(TAG, "AI step skipped (${e.javaClass.simpleName}) after ${timeoutMs}ms budget")
            null
        } finally {
            executor.shutdownNow()
        }
    }

    fun destroy() {
        disarmReadyWatchdog()
        finalFallback?.let { mainHandler.removeCallbacks(it) }
        finalFallback = null
        awaitingFinal = false
        isListening = false
        isContinuousSession = false
        stopSilenceDetection()
        try {
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (_: Exception) {}
    }
}
